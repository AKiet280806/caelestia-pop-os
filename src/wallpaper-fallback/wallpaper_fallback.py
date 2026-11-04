#!/usr/bin/env python3
"""Keep a wallpaper underneath Caelestia, independent of shell reloads.

Uses hyprpaper 0.8+ IPC. Never changes the selected image, shell config or
compositor settings. The supervised process belongs to this dedicated unit.
"""
from pathlib import Path
import os
import signal
import socket
import subprocess
import tempfile
import time


def selected_image(state, fallback):
    try:
        candidate = Path(state.read_text().strip())
        if candidate.is_absolute() and candidate.is_file():
            return str(candidate)
    except (OSError, ValueError):
        pass
    return str(fallback) if fallback.is_file() else None


def set_wallpaper(image):
    # hyprpaper's IPC grammar uses commas as field separators. Refuse ambiguous
    # paths rather than interpreting a filename as monitor/options syntax.
    if not image or any(char in image for char in ',\n\r\x00'):
        return False
    try:
        result = subprocess.run(['hyprctl', 'hyprpaper', 'wallpaper', ', ' + image + ', cover'],
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=3)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def notify_ready():
    address = os.environ.get('NOTIFY_SOCKET')
    if not address:
        return
    if address.startswith('@'):
        address = '\0' + address[1:]
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as client:
        client.connect(address)
        client.sendall(b'READY=1\nSTATUS=Wallpaper fallback active')


def main():
    home = Path.home()
    state_home = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
    data_home = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    selected = state_home / 'caelestia/wallpaper/path.txt'
    fallback = data_home / 'caelestia-pop-os/wallpapers/wallpaper.png'
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with tempfile.TemporaryDirectory(prefix='caelestia-wallpaper-', dir=runtime) as directory:
        config = Path(directory) / 'hyprpaper.conf'
        config.write_text('ipc = true\nsplash = false\n')
        process = subprocess.Popen(['hyprpaper', '-c', str(config)],
                                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL)
        try:
            previous, ready = None, False
            deadline = time.monotonic() + 15
            while not stopping:
                if process.poll() is not None:
                    return 1
                image = selected_image(selected, fallback)
                if image and (image != previous or not ready) and set_wallpaper(image):
                    previous = image
                    if not ready:
                        notify_ready()
                        ready = True
                if not ready and time.monotonic() > deadline:
                    return 1
                time.sleep(1 if ready else .15)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
