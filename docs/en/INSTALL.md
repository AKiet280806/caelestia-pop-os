# Install from the COSMIC desktop

[Tiếng Việt](../vi/INSTALL.md) · [README](../../README.md) · [Manual component guide](MANUAL.md)

This guide starts on **Pop!_OS 24.04 amd64**, already running the normal COSMIC desktop. It adds Hyprland and Caelestia as another login session. Version 0.2.0 is a pre-release: a complete installation on a clean machine has not yet been tested. Keep a copy of important files and keep COSMIC available.

## 1. Open a terminal and identify your machine

Use COSMIC's application launcher to open Terminal. Paste one command block at a time and wait for it to finish. A password prompt from `sudo` does not show characters while you type.

```bash
cat /etc/os-release
dpkg --print-architecture
uname -r
free -h
df -h "$HOME" /opt /tmp
lspci -nnk | sed -n '/VGA\|3D\|Display/,+3p'
ls -l /dev/dri/by-path/
```

Confirm Pop!_OS 24.04 and `amd64`. `lspci` reports graphics devices and their kernel drivers; `/dev/dri/by-path/` helps map device nodes to hardware. Keep this output for troubleshooting. A missing optional diagnostic command is different from a failed graphics driver.

For proprietary NVIDIA, also inspect:

```bash
nvidia-smi
sudo cat /sys/module/nvidia_drm/parameters/modeset
sudo system76-power graphics
```

`nvidia-smi` should recognize your GPU and driver; DRM modeset should report `Y`. If these fail, first repair your Pop!_OS graphics stack using System76's guidance. Do not copy another user's `/dev/dri/card*` mapping or replace distribution drivers to match a screenshot. The query above does not change graphics mode. Consult [System76 graphics switching](https://support.system76.com/support/graphics-switch-pop/) before deliberately changing it.

The observed machine used Intel + RTX 4050, driver 595.104.02, NVIDIA mode, and no external monitor. That is a test description, not a requirement to force every laptop into NVIDIA mode. Hybrid/integrated setups, other GPUs, multi-monitor and suspend need their own validation.

## 2. Check disk space and updates

Allow approximately **8 GiB for downloads/builds**, **4 GiB for installed runtime**, and **8 GiB additional free reserve**. On one filesystem the default preflight budget is therefore about **20 GiB free**. Separate filesystems must each have room for their assigned files. Builds can need more as upstream dependencies change; preflight is an estimate, not a disk quota.

The default is two parallel build jobs. On a memory-constrained machine use `--jobs 1`; a fast CPU does not make unlimited parallelism safe. Use the normal COSMIC updater for pending operating-system updates, finish them, and reboot yourself if the updater requires it before building the desktop.

## 3. Download the full source

```bash
sudo apt update
sudo apt install --no-remove git
mkdir -p "$HOME/Projects"
cd "$HOME/Projects"
git clone https://github.com/AKiet280806/caelestia-pop-os.git
cd caelestia-pop-os
```

Keep this directory. Commands below assume you are inside it. Review `setup.sh`, `installer/`, and [the component guide](MANUAL.md) before granting installation access. Do not run `sudo ./setup.sh`: the installer needs your normal user's home and asks for elevated privileges only where required.

## 4. Inspect before installing

```bash
./setup.sh preflight
./setup.sh plan
./setup.sh install --dry-run
```

Resolve reported OS, disk, APT, or version problems first. The Hyprland package source is **third-party** `ppa:cppiber/hyprland`. The supported build targets Hyprland 0.57.0 and its matching headers, including package version `0.57.0-1ppa3`; it is not a promise that any future PPA release will work. APT operations must not remove packages. If a solver proposes removal of `pop-desktop`, `cosmic-greeter`, `system76-power`, or drivers, stop and inspect the dependency conflict.

`--dry-run` is a plan preview; it does not prove downloads, compilation, or hardware compatibility. JSON output is available for reports:

```bash
./setup.sh preflight --json
./setup.sh plan --json
```

## Choose your options

| Option | Meaning |
| --- | --- |
| `--scale 1.0` | Default display scale; explicitly choose a value suited to your panel |
| `--scale 1.5` | A tested choice for a 14-inch 2560×1600 internal panel |
| `--vietnamese` | Install/configure Fcitx5 + Unikey for Vietnamese Telex |
| `--with-hyprmod` | Include optional HyprMod 0.5 settings interface |
| `--with-ai-usage` | One AI Usage widget with a persistent provider selector |
| `--encoder libx264` | Portable CPU H.264 recording; default portable choice |
| `--encoder auto` | Let installer selection inspect available encoders; check the result |
| `--encoder h264_nvenc` | Explicit NVIDIA encoding choice after checking hardware/FFmpeg |
| `--jobs 2` | Parallel build jobs; use 1 if memory is limited |
| `--reserve-gib 8` | Keep this much free disk space beyond estimated installation needs |
| `--cache-dir PATH` | Place downloads/builds on a filesystem with enough free space |

A cache directory should be dedicated to this project, writable by your user, and retained for subsequent stages. Pass the same path on reruns; do not point it at your home directory itself. Scale 1.67 is not a universal default.

For explicit NVIDIA recording, inspect first:

```bash
nvidia-smi
ffmpeg -hide_banner -encoders | rg 'libx264|h264_nvenc'
```

The presence of an encoder name alone does not prove that encoding will work. Start with `libx264` when uncertain, then test a short recording.

## 5. Install

Basic desktop:

```bash
./setup.sh install --yes
```

Example with Vietnamese input and the optional settings UI:

```bash
./setup.sh install --yes --scale 1.5 --vietnamese --with-hyprmod --encoder libx264 --jobs 2 --reserve-gib 8
```

Use only the options you want. The installer installs packages, builds private runtimes/tools and matching plugins, backs up affected configuration, and deploys the session. Keep the terminal open and save the final output. Qt/source compilation can be lengthy. It does not log you out, reboot, change display manager, remove COSMIC, install `power-profiles-daemon`, or replace system Python/Wayland.

You can inspect and run stages separately; each requires prior prerequisites:

```bash
./setup.sh packages --yes
./setup.sh runtime --yes
./setup.sh plugins --yes
./setup.sh deploy --yes
./setup.sh doctor
```

Pass your chosen options consistently to each stage. Do not bypass a failed stage and log into a partially built desktop. See [manual installation](MANUAL.md) for dependency order and the build scripts.

## 6. Choose Hyprland in COSMIC Greeter

1. Save work and close applications normally. Use COSMIC's own **Log Out** action yourself.
2. At **COSMIC Greeter**, select your user if needed.
3. Open the **session menu** in the user/session/status region. Current greeter source uses an application-menu icon (`application-menu-symbolic`); appearance and position can vary. This is not an instruction to search for GDM's gear icon.
4. Select **Hyprland (Caelestia Pop!_OS)**.
5. Enter your password and log in.

The menu is evidenced in [COSMIC Greeter's session button source](https://github.com/pop-os/cosmic-greeter/blob/master/src/greeter.rs). If automatic login skips the chooser, disable automatic login in COSMIC Settings, save your work and log out again. Do not restart the greeter service during an active desktop session.

If the entry is missing, return to the terminal in COSMIC and inspect:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
command -v Hyprland
./setup.sh doctor
```

The desktop file's `Exec=` target must exist and be executable. Use [troubleshooting](TROUBLESHOOTING.md#session-does-not-start) rather than changing the display manager.

## 7. First login checks

Open Foot with **Win+Enter**. Here Win means the Windows/Super key.

```bash
./setup.sh doctor
hyprctl version
hyprctl monitors
systemctl --user status caelestia-shell.service --no-pager
```

Run `setup.sh` from the downloaded repository if the terminal starts in your home directory. Open an application with Win+D. Test Alt+Tab, window controls, volume, brightness, a screenshot and a short recording. The sidebar's running-app icons include minimized windows. Read [usage and shortcuts](USAGE.md).

With Vietnamese enabled, inspect Fcitx5 Configuration, add/select **Unikey**, choose Telex as appropriate, and test in a normal text field. Individual Flatpak applications may need their own input-method support; do not fix one app by exporting global Qt paths into COSMIC.

The optional AI Usage widget shows one selected provider. Hover it, click the provider name and choose from the searchable list. Connect the provider locally using its supported CLI or CodexBar configuration; see [AI Usage](../AI-USAGE.md). Codex subscription quota and OpenAI API billing are separate sources; neither represents ordinary ChatGPT chat-message quota.

## 8. Keep a working way back

Use Win+Ctrl+Shift+Q to log out of Hyprland after saving work, then select COSMIC from the same greeter session menu. If the graphical session is unusable, use **Ctrl+Alt+F3**, sign in on the text console and inspect the session log:

```bash
tail -n 100 "$HOME/.local/state/caelestia-pop-os/session.log"
```

Do not delete configurations or purge packages to diagnose a blank screen. [Maintenance and recovery](MAINTENANCE.md) explains configuration rollback and removing only this project's session integration.

For the single-provider AI Usage selector and account setup, see [AI Usage](../AI-USAGE.md).
