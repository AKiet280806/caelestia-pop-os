# Caelestia for Pop!_OS

A Hyprland desktop for **Pop!_OS 24.04**, with the Caelestia shell, familiar window controls, and a guided installation from COSMIC.

[![Source checks](https://github.com/AKiet280806/caelestia-pop-os/actions/workflows/checks.yml/badge.svg)](https://github.com/AKiet280806/caelestia-pop-os/actions/workflows/checks.yml)
![Platform: Pop!_OS 24.04 amd64](https://img.shields.io/badge/Pop!__OS-24.04_amd64-48B9C7)
![Status: 0.2.0 pre-release](https://img.shields.io/badge/status-0.2.0_pre--release-bd93f9)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)

**[Install · English](docs/en/INSTALL.md)** · **[Cài đặt · Tiếng Việt](docs/vi/INSTALL.md)** · [Shortcuts](docs/en/USAGE.md) · [AI agent guide](docs/agent/INSTALL.md)

![Caelestia desktop on Pop!_OS with a translucent sidebar, workspace controls and desktop clock](assets/screenshots/desktop.png)

## Gallery

One screenshot per feature. Click any image for full resolution.

| Dashboard | Media |
| --- | --- |
| [<img src="assets/screenshots/dashboard.png" alt="Calendar, clock, uptime, weather and media overview" width="400">](assets/screenshots/dashboard.png) | [<img src="assets/screenshots/media.png" alt="Media artwork, playback controls, track timeline and lyrics panel" width="400">](assets/screenshots/media.png) |

| Performance | Weather |
| --- | --- |
| [<img src="assets/screenshots/performance.png" alt="Live CPU, GPU, memory, storage, network and battery widgets" width="400">](assets/screenshots/performance.png) | [<img src="assets/screenshots/weather.png" alt="Current weather, sunrise, sunset and seven-day forecast for the demo city London" width="400">](assets/screenshots/weather.png) |

| Application launcher · Win+D | Clipboard history · Win+Shift+V |
| --- | --- |
| [<img src="assets/screenshots/launcher.png" alt="Application search in the translucent launcher" width="400">](assets/screenshots/launcher.png) | [<img src="assets/screenshots/clipboard.png" alt="Clipboard with real image thumbnails and a larger preview" width="400">](assets/screenshots/clipboard.png) |

| Visual window switcher · Alt+Tab | AI Usage · hover to open |
| --- | --- |
| [<img src="assets/screenshots/window-switcher.png" alt="Visual Alt+Tab chooser with previews of demonstration windows" width="400">](assets/screenshots/window-switcher.png) | [<img src="assets/screenshots/ai-usage.png" alt="Selected-provider quota windows, remaining limits and reset times" width="400">](assets/screenshots/ai-usage.png) |

| Notification centre · Win+N | Volume and brightness |
| --- | --- |
| [<img src="assets/screenshots/notifications.png" alt="Expanded group of demonstration notifications in the sidebar" width="400">](assets/screenshots/notifications.png) | [<img src="assets/screenshots/audio-brightness.png" alt="On-screen volume percentage and brightness controls" width="400">](assets/screenshots/audio-brightness.png) |

| Region screenshots · Win+Shift+S | Screen recorder and quick controls |
| --- | --- |
| [<img src="assets/screenshots/screenshot-selection.png" alt="Screenshot area picker with a selection outline" width="400">](assets/screenshots/screenshot-selection.png) | [<img src="assets/screenshots/utilities.png" alt="Screen recorder, keep-awake control and quick toggles" width="400">](assets/screenshots/utilities.png) |

| Floating windows | Tiled windows |
| --- | --- |
| [<img src="assets/screenshots/floating.png" alt="Overlapping floating windows with minimize, maximize and close buttons" width="400">](assets/screenshots/floating.png) | [<img src="assets/screenshots/tiling.png" alt="Tiled windows with titlebar controls and the per-workspace layout toggle" width="400">](assets/screenshots/tiling.png) |

| Wallpaper and style settings | Session controls |
| --- | --- |
| [<img src="assets/screenshots/appearance.png" alt="Nexus wallpaper, colours, transparency and dark theme settings" width="400">](assets/screenshots/appearance.png) | [<img src="assets/screenshots/session-controls.png" alt="Session menu for logout, shutdown, hibernate and reboot" width="400">](assets/screenshots/session-controls.png) |

Real desktop captures with the included [CC0 wallpaper](assets/wallpaper.svg) and a Dracula palette. Media, notifications, clipboard entries and terminal windows use demonstration content; Weather uses London as a demo location. Hardware statistics are live readings. Installed apps, scale and optional widgets depend on your setup. [Screenshot details](assets/README.md).

## Features

- **Choose your layout.** Tiling by default, with a saved Float/Tiling preference for each workspace. Float an individual window with Win+V.
- **Familiar window controls.** Minimize, maximize/restore and close buttons, a running-app sidebar, and a visual Alt+Tab switcher that keeps your pointer in place.
- **A coordinated shell.** Translucent panels, application search, notifications, media controls, desktop clock and animated wallpaper changes with automatic fallback recovery.
- **Everyday tools included.** Foot, COSMIC Files, a themed clipboard popup with image previews, search and type filters, region screenshots and screen recording with speaker audio. Keep your existing default browser.
- **Optional extras.** Vietnamese Telex with Fcitx5 + Unikey, HyprMod settings, and [AI Usage](docs/AI-USAGE.md) for one provider you select.
- **Source included.** Modified QML/C++ shell, native window-action plugin, configuration and staged installer. Exact runtime revisions live in [pins.json](pins.json).

## Install from COSMIC

**0.2.0 is a pre-release.** The desktop has been used on an existing Pop!_OS machine; a complete clean-machine installation is still unverified. Keep COSMIC available as your recovery session. Read the [installation guide](docs/en/INSTALL.md) before making system changes.

Start in a COSMIC terminal:

```bash
sudo apt update
sudo apt install --no-remove git
mkdir -p "$HOME/Projects"
cd "$HOME/Projects"
git clone https://github.com/AKiet280806/caelestia-pop-os.git
cd caelestia-pop-os
./setup.sh preflight
./setup.sh plan
./setup.sh install --dry-run
```

After reviewing the plan and prerequisites:

```bash
./setup.sh install --yes
./setup.sh doctor
```

Run as your normal user; the installer requests `sudo` for system changes. It downloads and compiles the runtime, then adds **Hyprland (Caelestia Pop!_OS)** to the COSMIC Greeter session menu. Save your work and follow the guide to log into the new session.

| Requirement | Default / support |
| --- | --- |
| Operating system | Pop!_OS 24.04 LTS, amd64 |
| Disk budget | 20 GiB free when build, runtime and reserve share a filesystem: 8 + 4 + 8 GiB |
| Build parallelism | 2 jobs |
| Display scale | 1.0; choose a suitable value with `--scale` |
| Graphics | Intel + NVIDIA laptop runtime exercised; other GPUs and multiple displays need testing |

COSMIC, its greeter, System76 power management and distribution NVIDIA drivers stay installed. The installer does not automatically log you out or reboot.

<details>
<summary>Optional features and installer commands</summary>

Choose only the options you need; this example enables all three extras:

```bash
./setup.sh install --yes --vietnamese --with-hyprmod --with-ai-usage --scale 1.5
```

`--with-codex` remains an alias for `--with-ai-usage`. AI Usage displays one selected provider; Codex account limits are separate from ordinary ChatGPT usage.

| Command | Purpose |
| --- | --- |
| `preflight` / `plan` | Inspect prerequisites and proposed changes |
| `install` | Run package, runtime, plugin and deployment stages |
| `packages` / `runtime` / `plugins` / `deploy` | Run an individual stage |
| `doctor` | Inspect the installed environment and current session |
| `rollback --backup latest --yes` | Restore managed configuration; retain shared packages |
| `clean-cache --yes` | Remove build directories; retain downloads, sources and receipts |

Prefix commands with `./setup.sh`. All accept `--dry-run`. See `./setup.sh --help` and the [full option reference](docs/en/INSTALL.md#choose-your-options).

</details>

## Documentation

| Guide | English | Tiếng Việt |
| --- | --- | --- |
| From COSMIC to the first Hyprland login | [Installation](docs/en/INSTALL.md) | [Cài đặt](docs/vi/INSTALL.md) |
| Build and install each component yourself | [Manual installation](docs/en/MANUAL.md) | [Cài thủ công](docs/vi/MANUAL.md) |
| Windows, shortcuts, screenshots and recording | [Usage](docs/en/USAGE.md) | [Cách dùng](docs/vi/USAGE.md) |
| Session, graphics, portals, fonts and input | [Troubleshooting](docs/en/TROUBLESHOOTING.md) | [Khắc phục lỗi](docs/vi/TROUBLESHOOTING.md) |
| Updates, rollback, uninstall and COSMIC recovery | [Maintenance](docs/en/MAINTENANCE.md) | [Bảo trì và khôi phục](docs/vi/MAINTENANCE.md) |
| Reclaim disk space | [Optional cleanup](docs/en/COSMIC-CLEANUP.md) | [Dọn dung lượng](docs/vi/COSMIC-CLEANUP.md) |

For an AI-assisted installation, start with [AGENTS.md](AGENTS.md) and the [agent installation guide](docs/agent/INSTALL.md). Provider setup is covered in [AI Usage](docs/AI-USAGE.md).

## Contributing and support

Bug reports, documentation fixes and improvements are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for source layout, local checks and contribution guidelines. [Open an issue](https://github.com/AKiet280806/caelestia-pop-os/issues/new/choose) with reproduction steps and sanitized diagnostics.

The runtime pins Hyprland 0.57.0 from `ppa:cppiber/hyprland`, Quickshell 0.3.1, Caelestia 2.5.0, private Qt 6.11.2 and private Wayland 1.26. Native plugins must match the compositor ABI. See the manual guide before changing dependencies. Fresh installs, suspend/resume, multiple displays and other GPU combinations remain areas for further validation.

## Credits and license

Built on [Caelestia shell](https://github.com/caelestia-dots/shell), [Caelestia CLI](https://github.com/caelestia-dots/cli), [Quickshell](https://quickshell.org/) and [Hyprland](https://hypr.land/). Inspired by [12errh/caelestia-ubuntu](https://github.com/12errh/caelestia-ubuntu).

Distributed under [GPL-3.0-or-later](LICENSE), with component licenses and attribution in [NOTICE](NOTICE), [shell/LICENSE](shell/LICENSE) and [licenses/](licenses/). The included wallpaper is CC0. This is a community project, independent of System76 and upstream Caelestia.
