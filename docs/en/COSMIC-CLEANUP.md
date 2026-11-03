# Optional disk cleanup while retaining COSMIC

[Tiếng Việt](../vi/COSMIC-CLEANUP.md) · [Maintenance](MAINTENANCE.md)

Keeping COSMIC is the supported recovery arrangement for this pre-release. Installing Hyprland does not require removing COSMIC. There is no automatic COSMIC removal step. Removing an entire desktop is a separate migration with dependency and recovery consequences; this guide concentrates on reclaiming space without doing that.

## Measure first

```bash
df -h "$HOME" /opt /tmp
du -sh "$HOME/.cache/caelestia-pop-os" 2>/dev/null
du -sh "$HOME/.local/share/caelestia-pop-os" 2>/dev/null
du -sh "$HOME/Videos/Recordings" 2>/dev/null
sudo du -sh /var/cache/apt/archives /opt/qt6 /opt/caelestia-wayland
flatpak list --app --columns=application,size
```

Use the selected cache/XDG paths if different. A missing directory or `flatpak` command can simply mean it is not installed. Build artifacts, downloaded package archives, old recordings and unused applications can consume more space than the fallback session.

## Prefer bounded cleanup

From the repository, preview then clean only project build artifacts:

```bash
./setup.sh clean-cache --dry-run
./setup.sh clean-cache --yes
```

Add your original `--cache-dir PATH` if needed. Sources/downloads/receipts and installed runtimes remain. Keep the deployment backup: it is not a disposable build directory.

APT's package-download cache can be cleared independently of installed packages:

```bash
sudo apt clean
```

This does not uninstall COSMIC or free the space occupied by installed libraries. Review old videos/screenshots in the file manager and delete only ones you no longer need. Empty Trash after checking it. For optional apps, use COSMIC's app management or remove a specific package/Flatpak after inspecting it. Do not remove an application simply because it has `cosmic` in its name: this desktop intentionally keeps `cosmic-files` and the greeter.

## Inspect any proposed package removal

These commands only report information; substitute a real, individually selected optional package before considering removal:

```bash
apt-cache rdepends --installed PACKAGE_NAME
apt-get --simulate remove PACKAGE_NAME
```

Read the complete removal list. Cancel if it includes recovery desktop, greeter, System76 power/driver integration, networking, audio, portals, keyring or a package you still need. Never use `sudo apt purge 'cosmic*'`, a broad desktop package glob, blanket `autoremove`, or orphan-package cleanup here. Do not remove `pop-desktop` just to make a package manager's list look tidy.

Leave `cosmic-greeter`, `system76-power`, NVIDIA packages, PipeWire, NetworkManager, keyring and working portal backends intact. Do not install `power-profiles-daemon` as a replacement. Keep enough reserve for kernel/driver and OS updates; the installer's default 8 GiB future reserve is deliberate.

If space is still insufficient, relocate the dedicated build cache to a larger disk, reduce retained build artifacts, or expand the filesystem. Read [recovery](MAINTENANCE.md) before deliberately undertaking a separate COSMIC removal project.
