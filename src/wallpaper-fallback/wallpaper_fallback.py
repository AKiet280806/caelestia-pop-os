#!/usr/bin/env python3
"""Keep a wallpaper underneath Caelestia, independent of shell reloads.

Uses hyprpaper 0.8+ IPC. Never changes the selected image, shell config or
compositor settings. The supervised process belongs to this dedicated unit.
"""
from pathlib import Path
import json
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


def query_hyprland(kind):
    try:
        result = subprocess.run(['hyprctl', '-j', kind], capture_output=True,
                                text=True, timeout=3, check=True)
        return json.loads(result.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def primary_visible():
    """None means unknown; never tear down a working fallback on an IPC error."""
    monitors = query_hyprland('layers')
    if not isinstance(monitors, dict) or not monitors:
        return None
    for monitor in monitors.values():
        entries = [entry for level in monitor.get('levels', {}).values() for entry in level]
        if not any(entry.get('namespace') == 'caelestia-background'
                   and entry.get('alpha', 0) >= .99 for entry in entries):
            return False
    return True


def covering_fullscreen():
    monitors, windows = query_hyprland('monitors'), query_hyprland('clients')
    if not isinstance(monitors, list) or not isinstance(windows, list):
        return True  # Retry later; mapping under fullscreen can produce alpha 0.
    active = {monitor.get('specialWorkspace', {}).get('name') or
              monitor.get('activeWorkspace', {}).get('name') for monitor in monitors}
    return any(window.get('mapped') and window.get('fullscreen', 0) > 1
               and window.get('workspace', {}).get('name') in active for window in windows)


def stop_renderer(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


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
        process = None
        previous, ready, healthy_since = None, False, None
        deadline = time.monotonic() + 15
        try:
            while not stopping:
                if process is not None and process.poll() is not None:
                    return 1
                primary = primary_visible()
                now = time.monotonic()
                if primary is True:
                    healthy_since = healthy_since if healthy_since is not None else now
                    if process is not None and now - healthy_since >= 2:
                        # Let Qt finish decoding its first frame before revealing
                        # the native animated wallpaper. Only stop our own child.
                        stop_renderer(process)
                        process, previous = None, None
                    if not ready:
                        notify_ready()
                        ready = True
                elif primary is False:
                    healthy_since = None
                    if process is None and not covering_fullscreen():
                        process = subprocess.Popen(['hyprpaper', '-c', str(config)],
                                                   stdin=subprocess.DEVNULL,
                                                   stdout=subprocess.DEVNULL,
                                                   stderr=subprocess.DEVNULL)
                        previous = None
                else:
                    healthy_since = None
                image = selected_image(selected, fallback)
                if process is not None and image and image != previous and set_wallpaper(image):
                    previous = image
                    if not ready:
                        notify_ready()
                        ready = True
                if not ready and now > deadline:
                    return 1
                time.sleep(1 if ready else .15)
        finally:
            stop_renderer(process)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
