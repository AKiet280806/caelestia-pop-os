import re
import shutil
import subprocess
import time
from argparse import Namespace
from datetime import datetime
from pathlib import Path

from caelestia.utils import hypr
from caelestia.utils.notify import close_notification, notify
from caelestia.utils.paths import get_config, recording_notif_path, recording_path, recordings_dir

RECORDER = get_config().get("record", {}).get("backend", "gpu-screen-recorder")
if RECORDER not in ("gpu-screen-recorder", "wf-recorder"):
    raise ValueError("Unsupported recording backend")

# Handles the "Recording stopped" notification actions in a tiny detached shell
# process, so `caelestia record` can exit as soon as the recording is saved.
_STOPPED_NOTIF_HANDLER = r"""
path=$1
uri=$2
directory=$3

action=$(notify-send -a caelestia-cli \
    --action=watch=Watch \
    --action=open=Open \
    --action=delete=Delete \
    "Recording stopped" \
    "Recording saved in $path") || exit 0

case "$action" in
    watch)
        exec xdg-open "$path"
        ;;
    open)
        if ! dbus-send --session \
            --dest=org.freedesktop.FileManager1 \
            --type=method_call \
            /org/freedesktop/FileManager1 \
            org.freedesktop.FileManager1.ShowItems \
            "array:string:$uri" \
            "string:"; then
            exec xdg-open "$directory"
        fi
        ;;
    delete)
        rm -f -- "$path"
        ;;
esac
"""


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        if self.args.pause:
            if RECORDER == "wf-recorder":
                notify("Pause unavailable", "This recording backend supports start and stop only.")
                return
            subprocess.run(["pkill", "-USR2", "-x", RECORDER], stdout=subprocess.DEVNULL)
        elif self.proc_running():
            self.stop()
        else:
            self.start()

    def proc_running(self) -> bool:
        return subprocess.run(["pidof", RECORDER], stdout=subprocess.DEVNULL).returncode == 0

    def intersects(self, a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
        return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]

    def start(self) -> None:
        args = [] if RECORDER == "wf-recorder" else ["-w"]

        monitors = hypr.message("monitors")
        if self.args.region:
            if self.args.region == "slurp":
                region = subprocess.check_output(
                    ["slurp", "-f", "%wx%h+%x+%y"],
                    text=True,
                    stdin=subprocess.DEVNULL,
                )
            else:
                region = self.args.region.strip()

            m = re.match(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", region)
            if not m:
                raise ValueError(f"Invalid region: {region}")

            w, h, x, y = map(int, m.groups())
            r = x, y, w, h
            if RECORDER == "wf-recorder":
                args += ["-g", f"{x},{y} {w}x{h}"]
            else:
                args += ["region", "-region", region]
            max_rr = 0
            for monitor in monitors:
                if self.intersects((monitor["x"], monitor["y"], monitor["width"], monitor["height"]), r):
                    rr = round(monitor["refreshRate"])
                    max_rr = max(max_rr, rr)
            args += ["-r" if RECORDER == "wf-recorder" else "-f",
                     str(min(max_rr or 60, 60))]
        else:
            focused_monitor = next(monitor for monitor in monitors if monitor["focused"])
            if focused_monitor:
                if RECORDER == "wf-recorder":
                    args += ["-o", focused_monitor["name"], "-r", "60"]
                else:
                    args += [focused_monitor["name"], "-f",
                             str(min(round(focused_monitor["refreshRate"]), 60))]

        if self.args.sound:
            if RECORDER == "wf-recorder":
                # Explicitly record speaker output, never the default microphone.
                sink = subprocess.check_output(["pactl", "get-default-sink"], text=True).strip()
                args += [f"--audio={sink}.monitor", "-C", "aac"]
            else:
                args += ["-a", "default_output"]

        config = get_config()
        extra = config.get("record", {}).get("extraArgs", [])
        if not isinstance(extra, list) or not all(isinstance(arg, str) for arg in extra):
            raise ValueError("Config option 'record.extraArgs' must be an array of strings")
        args += extra

        if RECORDER == "wf-recorder":
            encoder = config.get("record", {}).get("encoder", "libx264")
            if encoder == "h264_nvenc":
                args += ["-c", encoder, "-p", "preset=p4", "-p", "cq=25", "-x", "yuv420p"]
            elif encoder == "libx264":
                args += ["-c", encoder, "-p", "preset=veryfast", "-p", "crf=23", "-x", "yuv420p"]
            else:
                raise ValueError("record.encoder must be libx264 or h264_nvenc")

        recording_path.parent.mkdir(parents=True, exist_ok=True)
        # The recorder outlives this command, so it must not inherit our stdio
        log_path = recording_path.parent / "recorder.log"
        log_file = log_path.open("w")
        proc = subprocess.Popen(
            [RECORDER, *args, "-f" if RECORDER == "wf-recorder" else "-o", str(recording_path)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=log_file,
            start_new_session=True,
        )
        log_file.close()

        notif = notify("-p", "Recording started", "Recording...")
        recording_notif_path.write_text(notif)

        try:
            if proc.wait(1) != 0:
                close_notification(notif)
                notify(
                    "Recording failed",
                    "An error occurred attempting to start recorder. "
                    f"Command `{' '.join(proc.args)}` failed with exit code {proc.returncode}",
                )
        except subprocess.TimeoutExpired:
            pass

    def stop(self) -> None:
        # Start killing recording process
        subprocess.run(["pkill", "-INT" if RECORDER == "wf-recorder" else "-TERM", "-x", RECORDER], stdout=subprocess.DEVNULL)

        # Wait for recording to finish to avoid corrupted video file
        deadline = time.monotonic() + 30
        while self.proc_running():
            if time.monotonic() > deadline:
                raise RuntimeError("Recorder is still finalising; the temporary file has been preserved.")
            time.sleep(0.1)

        # Move to recordings folder
        new_path = recordings_dir / f"recording_{datetime.now().strftime('%Y%m%d_%H-%M-%S')}.mp4"
        recordings_dir.mkdir(exist_ok=True, parents=True)
        shutil.move(recording_path, new_path)

        # Close start notification
        try:
            close_notification(recording_notif_path.read_text())
        except IOError:
            pass

        if self.args.clipboard:
            file_uri = Path(new_path).resolve().as_uri() + "\n"
            subprocess.run(["wl-copy", "--type", "text/uri-list"], input=file_uri.encode())

        recording = new_path.resolve()

        # The action notification's lifetime is the user's interaction with it,
        # not this command's, so hand it off to a detached lightweight handler
        subprocess.Popen(
            [
                "sh",
                "-c",
                _STOPPED_NOTIF_HANDLER,
                "sh",
                str(recording),
                recording.as_uri(),
                str(recording.parent),
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            cwd="/",
        )
