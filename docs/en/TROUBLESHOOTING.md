# Troubleshooting

[Tiếng Việt](../vi/TROUBLESHOOTING.md) · [Recovery](MAINTENANCE.md) · [Install](INSTALL.md)

Start with evidence. Keep COSMIC installed and use it while repairing Hyprland. Do not resolve an installation failure by replacing system Python, copying arbitrary shared libraries into `/usr/lib`, globally exporting private Qt paths, masking every desktop portal, or allowing APT to remove Pop!_OS components.

## Collect a useful report

From the repository:

```bash
./setup.sh preflight --json
./setup.sh doctor --json
cat /etc/os-release
hyprctl version
hyprctl monitors
systemctl --user status caelestia-shell.service --no-pager
journalctl --user -u caelestia-shell.service -b -n 100 --no-pager
tail -n 100 "$HOME/.local/state/caelestia-pop-os/session.log"
```

`hyprctl` requires a running Hyprland session; failure in COSMIC/TTY is expected. Some session checks only make sense after login. Include installer stage, options, GPU driver, and whether the issue reproduces in COSMIC. Review output before posting; redact tokens, private paths, account data and unrelated application content.

## Session does not start

If the login entry is missing:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
ls -l /usr/local/bin/caelestia-pop-os-session
ls -l "$HOME/.local/bin/start-caelestia-session"
command -v Hyprland
```

The `Exec=` wrapper must exist, be executable and lead to the correct user's wrapper. A partial deploy may leave an entry without its runtime. Run `doctor`, repair the failed stage and deploy again only after inspecting the backup behavior. Automatic login can bypass the session menu: turn it off manually in COSMIC Settings. Do not restart the display manager during active work.

For a black screen or immediate return to greeter, press **Ctrl+Alt+F3**, log in on the text console and read `~/.local/state/caelestia-pop-os/session.log`. Return to greeter/COSMIC when the graphical session is available; console key assignment can vary by system. If Hyprland still owns the screen, do not kill unrelated user sessions or processes. See [recovery](MAINTENANCE.md).

## APT asks to remove packages or cannot find the pinned version

Stop at the failed package stage. Inspect without installing:

```bash
apt-cache policy hyprland hyprland-dev system76-power pop-desktop cosmic-greeter
apt-mark showhold
dpkg --audit
```

The supported compositor and development headers must match. Repository publication/retention can change; a missing pin needs a reviewed pin update, not `--allow-downgrades`, an arbitrary compositor upgrade, or removal of COSMIC. Review `pins.json`, the package stage, and current APT source metadata. Preserve System76/NVIDIA packages and do not add `power-profiles-daemon` to satisfy an upstream checklist.

## Build fails, runs out of RAM, or runs out of disk

```bash
free -h
df -h "$HOME" /opt /tmp
./setup.sh preflight
```

Read the first compiler/configure error, not just the final `ninja failed`. Use `--jobs 1` consistently on reruns if memory is tight. Move the dedicated cache with `--cache-dir` to a larger filesystem before rebuilding. Do not erase a dirty source checkout: save local changes or select a new empty project cache. Build scripts validate source pins/checksums and may reject an altered checkout intentionally. `clean-cache --dry-run` shows the supported cleanup scope; it does not remove installed runtimes or preserve an interrupted compilation state.

## Shell missing, QML errors, blank symbols or broken audio visualizer

```bash
systemctl --user status caelestia-shell.service --no-pager
journalctl --user -u caelestia-shell.service -b -n 120 --no-pager
ls -ld /opt/qt6 /opt/caelestia-wayland
fc-match Rubik
fc-match 'Material Symbols Rounded'
fc-match 'CaskaydiaCove NF'
fc-cache -f
```

Private Qt must have the required QML modules; Quickshell, m3shapes and shell plugins must be built against the same private toolchain. Inspect `installer/runtime.sh` and rerun the failed component/stage. A QML import error is not fixed by symlinking an unrelated system Qt plugin. Cava needs both the command and libcava with working PipeWire input; its noncurses build requires `libtool` during compilation.

`caelestia-shell.service` is session-managed. It should run in the Hyprland session, not be globally enabled so it also starts in COSMIC. After a deliberate repair, restarting the shell can close its UI; save work and ensure the screen is unlocked before doing so.

## NVIDIA, scale, external monitors or a distorted screen

Inspect `nvidia-smi`, DRM modeset, `lspci -nnk`, `/dev/dri/by-path/`, `hyprctl monitors`, and the log. Proprietary NVIDIA DRM modeset should be `Y`. Keep drivers provided for Pop!_OS. Check the generated `~/.config/caelestia-pop-os/profile.json`, `profile.env`, and `~/.config/hypr/hyprland.lua`; do not globally force one user's GPU device index.

Scale defaults to 1.0; 1.5 was tested on one 14-inch 2560×1600 panel. A scale suitable for one display can be wrong for another. Make one change at a time, preserve the old file, then validate through the matching Hyprland 0.57 configuration API. Do not apply older `.conf` syntax blindly to the Lua configuration. Multi-monitor, hybrid graphics and suspend remain hardware-specific tests.

## File chooser, sharing or Flatpak apps fail

```bash
systemctl --user list-units 'xdg-desktop-portal*' --all
journalctl --user -b --no-pager | grep -i 'portal' | tail -n 80
printf '%s\n' "$XDG_CURRENT_DESKTOP" "$XDG_SESSION_TYPE"
cat "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
```

Use the per-desktop portal selection shipped in `configs/xdg-desktop-portal/`. COSMIC and Hyprland need their appropriate portal backends in their own sessions. Do not globally mask COSMIC/GTK portals to force a particular backend. Re-login after fixing session environment. Browser screen sharing and direct wf-recorder capture use different mechanisms; success of one does not validate the other.

## No clipboard history, no Vietnamese, no brightness control

Clipboard: inspect session helpers and `systemctl --user list-units 'caelestia-clipboard@*' --all`. Copy new text after the watchers start, then open Win+Shift+V. Existing content copied earlier may not have been captured.

Vietnamese: run `pgrep -a fcitx5`, `fcitx5-remote -n`, and `fcitx5-diagnose` in Hyprland. Confirm Unikey is installed, included in the input-method list and selected; check activation/Telex settings. Use `scripts/start-fcitx-unikey` only within the intended session. A private Qt app or Flatpak can need matching input support; keep input environment session-local.

Brightness: inspect `brightnessctl --list` and `ddcutil detect`. Internal backlight devices differ from external DDC/CI monitors. The `brightness-udev` rules grant appropriate access; avoid world-writable device nodes or running the desktop as root. Some external displays do not support DDC/CI.

## Recording fails or has no audio

```bash
command -v wf-recorder ffmpeg
ffmpeg -hide_banner -encoders | grep -E 'libx264|h264_nvenc'
wpctl status
pactl get-default-sink
pactl list short sources
```

Check free space in `~/Videos/Recordings`. The audio source is the output sink's monitor; there may be no active monitor for a disconnected output. A headset/output change can change the sink. Test `--encoder libx264` via the installer configuration if NVENC fails. Avoid editing installed Python packages directly; recorder source lives in `src/cli-overrides/record.py`. Pause is intentionally unavailable with wf-recorder.

## Lock or suspend is unreliable

Automatic timeouts and fingerprint unlock are off initially. Use password unlock and test Win+L while you have a working TTY/COSMIC recovery path. Inspect PAM/lock logs before enabling idle lock or suspend. Do not enable fingerprint simply because the laptop has a sensor. Sleep/wake is not validated for every GPU configuration.

## Optional AI Usage widget has no data

First verify the selected provider in the popup and its authentication/source requirements in [AI Usage](../AI-USAGE.md). For Codex, check that the official `codex` command exists in the session's PATH and is signed in as your own account. Inspect widget/backend status without copying credentials. Missing RPC quota data, an expired login, an unsupported account or stale data should display as unavailable/stale. It does not establish the remaining quota of ordinary ChatGPT messages. Report sanitized status and version details, never `auth.json`, access tokens or your entire Codex state directory.

The compatibility service name is `caelestia-codex-usage.service`; generic cache errors and supported-source limits are explained in [AI Usage](../AI-USAGE.md).

## Missing hyprland-guiutils at login

`hyprland-guiutils` provides Hyprland dialogs, including permission prompts. It is a required runtime package in this installer. Check `command -v hyprland-dialog` and `apt-cache policy hyprland-guiutils`. For an older installation, simulate `apt-get -s --no-install-recommends install hyprland-guiutils`, check that it removes nothing and retains the pinned compositor, then install with `sudo apt-get install --no-remove --no-install-recommends hyprland-guiutils`. Do not hide the warning by disabling the GUI-utilities check. A new login is the final check for a startup-only warning; do not restart the compositor during active work.

## Black wallpaper after replacing the shell

Hyprland 0.57 can leave a background layer at compositor alpha 0 when it maps during fullscreen, even though Qt reports the image Ready and opaque. The packaged `caelestia-wallpaper.service` keeps an independent controller active before the shell. It runs hyprpaper only while the Caelestia background is missing/transparent, so the native wallpaper animation remains visible when healthy, and follows the selected image in `~/.local/state/caelestia/wallpaper/path.txt`. Inspect `systemctl --user status caelestia-wallpaper.service`; an active service with no hyprpaper child is normal standby. `hyprctl hyprpaper listactive` applies only while recovery is rendering. No image is deleted or replaced. The bridge uses hyprpaper 0.8+ IPC and rejects comma/newline-containing filenames because commas delimit its IPC fields.

The text `Segmentation fault (core dumped)` can also be a built-in Hyprland splash, rather than evidence of a crash. Confirm a real crash using its process logs or crash report. Existing applications launched by the shell may still share its systemd control group; restarting that service can terminate those applications. Save work and inspect the process group before restarting it. The wallpaper fallback does not require a shell restart.
