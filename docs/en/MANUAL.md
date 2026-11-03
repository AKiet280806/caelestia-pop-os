# Build and install component by component

[Installation from COSMIC](INSTALL.md) · [Vietnamese](../vi/MANUAL.md)

Start in COSMIC on Pop!_OS 24.04 amd64. Read the installation guide, clone the repository, and remain logged in as your ordinary user. Keep COSMIC and the distribution drivers installed. These steps expose the same implementation used by `install`; they are useful for inspecting a failure or resuming a stage. The complete clean-machine installation is still unverified.

## 1. Inspect prerequisites and exact dependencies

```bash
./setup.sh preflight --json
./setup.sh plan --json --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
```

`plan.packages` contains the complete apt package list for the selected options, defined in `installer/install.py`. It includes the C/C++ toolchain, GCC/G++ 14, CMake, Ninja, Meson, autotools, Qt/Wayland build dependencies, audio/graphics/PAM development libraries, the Hyprland plugin development dependencies, desktop portals, Foot, clipboard tools, screenshots, recording, brightness, and authentication agent. Fcitx5/Unikey frontends are included only with `--vietnamese`.

On NVIDIA, unreadable modesetting requires a normal terminal authentication (`sudo -v`) and another preflight. Do not disable the check or change drivers as part of this guide. Check available storage on the root and cache filesystems; keep the default reserve and use two build jobs unless you deliberately select otherwise.

## 2. Install distro dependencies

```bash
./setup.sh packages --yes --vietnamese
```

This adds `ppa:cppiber/hyprland`, refreshes apt, requires the exact Hyprland Debian version in `pins.json`, simulates the complete transaction, rejects removals, then installs with `--no-remove`. The `hyprland` package contains its headers; `hyprland-plugin-deps` supplies their external development dependencies. There is no separate `hyprland-dev` requirement. Do not substitute `power-profiles-daemon` for System76 power management.

## 3. Select a private build cache

All following commands are run in the repository. Use the same environment for every stage:

```bash
export CAELESTIA_CACHE_DIR="$HOME/.cache/caelestia-pop-os"
export CAELESTIA_JOBS=2
```

The cache contains `sources/`, `builds/`, `downloads/`, `receipts/`, and `logs/`. A stage locks this cache to prevent concurrent builders. Source checkouts use full commit pins and refuse uncommitted edits. Downloads with recorded hashes reject checksum mismatches. Do not reset a dirty checkout or erase logs to conceal a failure.

## 4. Install private Qt and managed Python

```bash
installer/runtime.sh toolchain
```

This installs pinned uv into an isolated pipx environment, managed Python 3.13 for the Caelestia CLI, and aqtinstall. aqt downloads the Qt **6.11.2 binary SDK** with imageformats and shadertools to `/opt/qt6/6.11.2/gcc_64`. It does not compile Qt or replace system Python. Existing incomplete or mismatched Qt prefixes are rejected; preserve them and investigate before retrying.

## 5. Build private Wayland, libcava, Quickshell and shell modules

Run sequentially and stop on the first error:

```bash
installer/runtime.sh wayland
installer/runtime.sh cava
installer/runtime.sh quickshell
installer/runtime.sh m3shapes
installer/runtime.sh shell
```

Wayland **1.26** installs to `/opt/caelestia-wayland`, with no global loader configuration replacing distro Wayland. The libcava fork provides the shell's audio visualizer and terminal Cava. Quickshell uses the pinned cpptrace source and private Qt/Wayland; M3Shapes and Caelestia's C++ modules install under `/usr/local/lib/qt6/qml`. Shell helpers install under `/usr/local/lib/caelestia`. Only extras/plugins are installed by CMake; user configuration is deployed later with backups.

The build scripts set RPATH on managed binaries/modules so the session does not export `LD_LIBRARY_PATH` to unrelated applications. Check a binary when diagnosing linkage:

```bash
env -u LD_LIBRARY_PATH /usr/local/bin/qs --version
ldd /usr/local/bin/qs
```

## 6. Install the CLI, fonts and desktop tools

```bash
installer/runtime.sh cli
installer/runtime.sh fonts
installer/runtime.sh tools
```

The CLI lives in an isolated managed Python 3.13 tool environment. The installer verifies its git provenance before applying the recorder and Cava overrides in `src/cli-overrides/`. Recording uses wf-recorder, H.264 and optional AAC speaker-monitor audio; `libx264` is portable and `h264_nvenc` requires working NVIDIA encoding. Pause is unavailable with this backend.

Fonts include Rubik, Material Symbols Rounded and CaskaydiaCove Nerd Font, downloaded with their notices and verified hashes. The tools stage installs standalone Dart Sass and builds Swappy; a system Node upgrade is unnecessary. Desktop tools from apt include grim/slurp, wl-clipboard/cliphist, brightnessctl, btop and the portals.

## 7. Build matching native plugins

```bash
./setup.sh plugins --yes
```

The build checks the installed Hyprland package version, source hash, header digest and pkg-config version before compiling hyprbars and native window actions. The latter restores fullscreen/maximize state and handles native minimize requests. Products install atomically under `~/.local/share/hypr/plugins/`; never truncate a library already mapped into a compositor. A mismatched ABI must be rebuilt from matching pins, not bypassed.

## 8. Optional HyprMod and Codex

```bash
installer/runtime.sh hyprmod
```

HyprMod uses an isolated distro Python 3.12 environment with GTK4/libadwaita. It edits `hyprland-gui.lua`; the main Lua loads window shortcuts afterward so pointer warps remain disabled. The installation does not launch its settings UI.

The Codex widget is deployed with `--with-codex`; it requires your own working Codex CLI/account. It reads account rate limits, not ordinary ChatGPT usage. It neither installs credentials nor sends a prompt to measure quota. Omit the flag to hide the widget and avoid running its reader.

## 9. Back up and deploy configuration

Repeat your selected options explicitly:

```bash
./setup.sh deploy --dry-run --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
./setup.sh deploy --yes --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
./setup.sh doctor
```

Deployment backs up every managed destination and verifies its contents before replacement. Symlinked config trees are refused; preserve your dotfiles and choose an intentional migration instead of replacing links. User files include the complete modified shell, Lua modules, shell/CLI config, portal preference, session helpers, selected IME config, optional Codex reader and user units. System files are limited to the session desktop entry, its root-owned launcher, and `/etc/pam.d/quickshell`, which uses Ubuntu's common PAM includes.

The session callback starts the shell, clipboard watchers, authentication agent and selected integrations only after Hyprland starts. Deployment does not start them in COSMIC. Idle timeouts and fingerprint unlock are initially disabled. Test password locking with a recovery path before enabling automatic lock/sleep.

## 10. Select the session and verify

Save work and log out yourself. In COSMIC Greeter's application-menu session selector, choose **Hyprland (Caelestia Pop!_OS)**, then enter your password. Follow [first-session checks](INSTALL.md#7-first-login-checks), [shortcuts](USAGE.md), and [recovery](MAINTENANCE.md). A successful build or doctor result does not prove a successful physical GPU login.

To perform the build sequence above in one resumable runtime invocation, use `./setup.sh runtime --yes` with your optional flags. To perform packages, runtime/plugins and deployment together, use `./setup.sh install --yes`. Keep the same cache and options when recovering.
