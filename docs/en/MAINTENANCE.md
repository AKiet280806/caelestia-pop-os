# Recovery, updates and removal

[Tiếng Việt](../vi/MAINTENANCE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Disk cleanup](COSMIC-CLEANUP.md)

The installer keeps COSMIC and does not switch you out of the current session. Configuration rollback is separate from uninstalling system software.

## Return to COSMIC

Save work. In Hyprland use Win+Ctrl+Shift+Q to log out, then open COSMIC Greeter's session menu and select **COSMIC** before entering your password. If automatic login bypasses this menu, disable it manually in COSMIC Settings. Do not restart `cosmic-greeter` during an active session.

If the screen is unusable, press Ctrl+Alt+F3 and sign in on the text console. First inspect:

```bash
tail -n 120 "$HOME/.local/state/caelestia-pop-os/session.log"
```

You can inspect or roll back configuration from a text console. Do not run another compositor on top of an active COSMIC session or kill all processes belonging to your user. If COSMIC itself was removed outside this installer, [System76's desktop guide](https://system76.com/support/desktop-environment/) documents reinstalling `pop-desktop`; review the APT simulation and retain the current greeter/drivers before repair.

## Restore the previous configuration

Run from the repository as your ordinary user:

```bash
./setup.sh rollback --backup latest --dry-run
./setup.sh rollback --backup latest --yes
```

Read the selected backup identifier and manifest before applying it. Keep the backup directory and the repository. Deployment backs up managed paths before replacing them, including Hyprland/shell/profile configuration, user wrappers, units and the session integration where recorded. The backup manifest is authoritative: a file not recorded there is not restored by guessing.

Rollback restores configuration only. It leaves APT packages, private Qt/Wayland, built tools and caches installed. It refuses to overwrite files you edited after deployment; preserve those edits and resolve the conflict explicitly instead of forcing a deletion. A successful rollback does not log you out or prove that the old desktop session has started. Save work and re-login yourself when ready.

Useful files to inspect, with default XDG paths:

| Path | Role |
| --- | --- |
| `~/.config/hypr/hyprland.lua` | Main compositor config |
| `~/.config/hypr/caelestia-windows.lua` | Shared window state/actions |
| `~/.config/hypr/caelestia-shortcuts.lua` | Extra switcher/window shortcuts |
| `~/.config/hypr/hyprland-gui.lua` | Optional GUI settings integration |
| `~/.config/caelestia/shell.json`, `cli.json` | Shell and CLI preferences |
| `~/.config/caelestia-pop-os/profile.json`, `profile.env` | Generated session choices |
| `~/.local/bin/start-caelestia-session`, `start-caelestia-services` | Per-user session startup |
| `~/.local/state/caelestia-pop-os/session.log` | Startup diagnostics |

## Update deliberately

First return to COSMIC or finish your Hyprland work. Keep the previous checkout/revision and backup identifier. Record your current repository version and edits:

```bash
git status --short
git rev-parse HEAD
git fetch --tags origin
```

Read the new release notes and compare `pins.json` before selecting a release/commit. Do not overwrite local changes or assume `main` is always stable. On a clean checkout, a normal branch update can use `git pull --ff-only`; review it before running the installer.

```bash
./setup.sh preflight
./setup.sh plan
./setup.sh install --dry-run
```

Then run `install --yes` with the same desired options/cache/scale. Inspect the new backup and run `doctor`. Log into the updated session yourself and repeat the [first-login checks](INSTALL.md#7-first-login-checks). The installer is not a rolling ABI upgrade system: Quickshell, shell plugins, Hyprland and headers must remain compatible. Review APT upgrades that change the pinned compositor; never load a plugin built for a different Hyprland ABI.

An interrupted build can normally be rerun using the same cache after fixing the cause. It will validate pins/receipts. Preserve source changes; do not `git reset --hard` an unknown cache to make a check pass.

## Reclaim build space

```bash
./setup.sh clean-cache --dry-run
./setup.sh clean-cache --yes
```

For a custom cache, pass the same `--cache-dir PATH`. This removes only the installer's build directory inside that dedicated cache; it retains source/download/receipt data and installed binaries. Read the actual printed target before approving it. Do not replace this with `rm -rf ~/.cache`, and do not clean while a build is running.

## Remove this desktop's integration

There is no all-purpose `uninstall` command. The safe sequence is:

1. Log out of Hyprland and confirm COSMIC works.
2. Preview and apply the appropriate configuration rollback. Keep files with post-install edits until you have saved or merged them.
3. Inspect the session file and system wrapper if you want to remove the login option entirely:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
cat /usr/local/bin/caelestia-pop-os-session
```

If rollback has already removed the files, no further deletion is needed. If the files are still this project's versions **and no other user needs this session**, remove just these two integration files:

```bash
sudo rm -- /usr/share/wayland-sessions/hyprland-caelestia.desktop
sudo rm -- /usr/local/bin/caelestia-pop-os-session
```

Do not delete other Wayland session files. A multi-user machine shares these two system paths. Per-user managed files should be restored/removed through the recorded backup; do not delete your whole `~/.config/hypr` or `~/.config/caelestia` directory.

Shared APT packages and `/usr/local` tools deliberately remain. For deeper removal, inspect package dependencies and the build manifests under the dedicated cache's `builds/*/install_manifest.txt`, plus receipts and the package plan. Those manifests can include files used by other software; they are evidence for manual review, not input to a blanket deletion command. `/opt/qt6`, `/opt/caelestia-wayland`, Python environments, fonts and tools may be shared or contain later changes. Keep them unless you have established ownership and that nothing still uses them.

Removing the source checkout is optional after you preserve release information and backups. Never remove the only copy of your local modifications, credentials or personal recordings as part of desktop cleanup.
