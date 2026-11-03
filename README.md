# Caelestia for Pop!_OS

**[Tiếng Việt — bắt đầu cài từ COSMIC](docs/vi/INSTALL.md)** · [English installation](docs/en/INSTALL.md) · [Shortcuts](docs/en/USAGE.md) · [Recovery](docs/en/MAINTENANCE.md)

A source-included Hyprland + Caelestia desktop for **Pop!_OS 24.04, amd64**, with floating windows, familiar window controls, a visual Alt+Tab switcher, and a practical path from the standard COSMIC desktop.

**Version 0.1.0 is a pre-release.** The customized desktop has been exercised on a live machine; the complete installer has **not** been validated on a clean Pop!_OS installation. Static checks and isolated installer tests do not establish that a fresh-machine installation succeeds. Keep COSMIC as your recovery session and read the installation guide before running commands.

## What you get

- Caelestia sidebar, launcher, notifications, media controls, utilities, and a bar of running windows.
- Floating windows by default; a global Float/Tiling control and a shortcut to float one window.
- Per-window minimize, maximize/restore, and close controls; independent maximized floating windows.
- Fullscreen video restores the previous maximized state; volume OSD stays visible above video and shows its percentage.
- A visual, most-recently-used Alt+Tab chooser. Hold Alt, cycle, then release to commit; the pointer stays put.
- Foot terminal, retained COSMIC Files, your existing default browser, clipboard history, screenshots, and screen recording with speaker audio.
- Optional Vietnamese Telex input through Fcitx5 + Unikey, HyprMod settings, and a Codex usage widget.
- The complete modified Caelestia shell in this repository, native plugin source, recorder overrides, and scripts to build the required runtime.

This adds a session named **Hyprland (Caelestia Pop!_OS)** to COSMIC Greeter. COSMIC, `cosmic-greeter`, System76 power management, and distribution NVIDIA drivers stay installed. No automatic logout or reboot is performed.

## Start from COSMIC

Open Terminal in COSMIC. These commands download the repository and inspect the proposed installation; they do not install the desktop:

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

Read the output, check free disk space and GPU support, then follow the [full installation guide](docs/en/INSTALL.md). A basic installation is:

```bash
./setup.sh install --yes
./setup.sh doctor
```

Run the installer as your normal user; it requests `sudo` for system changes. Installation downloads and compiles software and can take substantial time. Default scale is **1.0**, build parallelism is **2 jobs**, and the disk budget includes **8 GiB build/cache + 4 GiB runtime + 8 GiB reserve** when these share a filesystem. `--scale 1.5` is an explicit choice tested with a 14-inch 2560×1600 panel, not a universal display setting.

## Guides

| Task | English | Tiếng Việt |
| --- | --- | --- |
| Install from COSMIC; select the login session | [Installation](docs/en/INSTALL.md) | [Cài đặt](docs/vi/INSTALL.md) |
| Understand and build every component | [Manual installation](docs/en/MANUAL.md) | [Cài thủ công](docs/vi/MANUAL.md) |
| Learn windows, launcher, shortcuts, recording | [Usage](docs/en/USAGE.md) | [Cách dùng và phím tắt](docs/vi/USAGE.md) |
| Diagnose session, graphics, portals, fonts, input | [Troubleshooting](docs/en/TROUBLESHOOTING.md) | [Khắc phục lỗi](docs/vi/TROUBLESHOOTING.md) |
| Return to COSMIC; update, rollback, uninstall | [Maintenance and recovery](docs/en/MAINTENANCE.md) | [Khôi phục và gỡ cài đặt](docs/vi/MAINTENANCE.md) |
| Reclaim disk space while keeping a recovery desktop | [Optional cleanup](docs/en/COSMIC-CLEANUP.md) | [Dọn dung lượng tùy chọn](docs/vi/COSMIC-CLEANUP.md) |

AI contributors should read [AGENTS.md](AGENTS.md) and [the agent documentation](docs/agent/INSTALL.md) before changing the system or installer.

## Installer commands

| Command | Purpose |
| --- | --- |
| `./setup.sh preflight` | Inspect OS, architecture, hardware, memory and storage prerequisites |
| `./setup.sh plan` | Show dependency/install plan |
| `./setup.sh install --yes` | Run package, runtime, plugin and deployment stages |
| `./setup.sh packages --yes` | Add the required package source and APT dependencies |
| `./setup.sh runtime --yes` | Build/install private runtimes and desktop tools |
| `./setup.sh plugins --yes` | Build the compatible compositor plugins |
| `./setup.sh deploy --yes` | Back up and deploy user configuration and session integration |
| `./setup.sh doctor` | Inspect the installed environment; run inside Hyprland for session checks |
| `./setup.sh rollback --backup latest --yes` | Restore backed-up configuration; packages are retained |
| `./setup.sh clean-cache --yes` | Remove installer build directories; preserve sources, downloads and receipts |

All commands accept `--dry-run`. `preflight`, `plan`, and `doctor` support `--json`. Installation and stages accept `--scale`, `--vietnamese`, `--with-hyprmod`, `--with-codex`, `--encoder auto|libx264|h264_nvenc`, `--jobs`, `--reserve-gib`, and `--cache-dir`. See [installation options](docs/en/INSTALL.md#choose-your-options).

## Source and dependency design

```text
shell/                      Complete modified Caelestia QML/C++ shell
src/native-window-actions/  Native application window-action integration
src/codex-usage/             Optional local Codex usage reader and tests
src/cli-overrides/           Pop!_OS recording/Cava adaptations
configs/                    Hyprland, shell and portal configuration
scripts/                    Session helpers
installer/                  Staged package/build/deployment logic
setup.sh                    Public command-line entry point
docs/en/  docs/vi/           Human guides
docs/agent/                 Agent implementation and safety guidance
```

The desktop uses a pinned **Hyprland 0.57.0** package from the third-party `ppa:cppiber/hyprland`, matching headers/plugins, **Quickshell 0.3.1**, and **Caelestia 2.5.0**. Private **Qt 6.11.2** lives under `/opt/qt6`; private **Wayland 1.26** lives under `/opt/caelestia-wayland`. This avoids replacing Pop!_OS's global Qt, Python, or Wayland libraries. Package operations refuse removals. The upstream `power-profiles-daemon` dependency is deliberately omitted because Pop!_OS uses `system76-power`; the shell's upstream power-profile UI is not promised to work.

See the [test evidence and remaining checks](docs/VALIDATION.md).

## Validation and limits

Observed live runtime: Intel graphics + RTX 4050, NVIDIA driver 595.104.02, NVIDIA graphics mode, internal display; floating/minimize/maximize/restore/close actions, switcher and recording workflows were exercised. This is one hardware configuration. Other GPUs, multiple displays, suspend/resume, and a complete clean-machine install require further testing. A different graphics mode may suit your machine better.

When reporting an issue, include your OS, GPU/driver, selected scale, installer stage, `./setup.sh doctor` output, and relevant session log excerpts. Remove tokens, account details, paths identifying private projects, and screenshots containing personal content.

## Credits and licenses

Built on [Caelestia shell](https://github.com/caelestia-dots/shell), [Caelestia CLI](https://github.com/caelestia-dots/cli), [Quickshell](https://quickshell.org/), and [Hyprland](https://hypr.land/). Inspired by [12errh/caelestia-ubuntu](https://github.com/12errh/caelestia-ubuntu).

The exported shell base is `454f46da16ae75cc57f34adf48dea74db0fa5175`; local modifications are included in `shell/`. See [LICENSE](LICENSE), [shell/LICENSE](shell/LICENSE), and [licenses/](licenses/) for redistribution terms and attribution. Components retain their own licenses. This is a community project, not an official System76 or upstream Caelestia release.
