# Validation and known limits

This is a **0.1.0 pre-release**, not a clean-install certification. Tests below were performed while developing the project on an existing Pop!_OS 24.04 desktop. The new installer has not been run end to end from a fresh COSMIC installation through a physical GPU login.

## Source and installer checks

Run from the repository without installing the desktop:

```bash
python3 -m unittest discover -s tests -v
python3 -m unittest discover -s src/codex-usage -v
python3 scripts/runtime-metadata.py validate
python3 tests/check_sources.py
shellcheck setup.sh installer/runtime*.sh scripts/build-plugins.sh scripts/start-* scripts/open-*
./setup.sh install --dry-run --vietnamese --with-hyprmod --with-codex --scale 1.5
```

The installer tests isolate HOME and system destinations in temporary directories. They cover dry-run execution without commands/filesystem changes, unsupported platforms, disk accounting, apt removal rejection, optional template deployment, verified backups, rollback, user-edit conflicts, symlink refusal, hostile manifests, interrupted deployment journals, and cache cleanup boundaries. Codex tests check quota normalization, stale/error behavior and exclusion of credential-shaped fixture data.

The declared apt transaction, including Vietnamese frontends and Hyprland plugin development dependencies, was simulated against the maintainer's Pop!_OS repositories with no removals. This does not ensure the PPA retains the same version indefinitely. The build refuses unavailable exact compositor versions or mismatched headers.

## Live window and fullscreen regressions

Observed runtime: Hyprland 0.57.0-1ppa3, Quickshell 0.3.1, Qt 6.11.2, Intel + NVIDIA RTX 4050 laptop graphics, NVIDIA driver 595.104.02, internal display. Development tests used private test windows/workspaces and restored the previous focus afterward.

| Scenario | Observed result |
| --- | --- |
| Two floating windows maximized with Alt+F10; eight real Alt+Tab switches | Both retained maximize and size; pixel checks confirmed the selected app was on top |
| Maximize/restore helper; minimize then restore through Alt+Tab | Only the selected app changed state; normal geometry and peer maximize were retained |
| Two GTK applications using native maximize/unmaximize | Independent maximize was retained through four switches |
| Reload configuration with native plugin loaded | Window maximize states retained; plugin still loaded |
| Real HTML video in a disposable Brave profile, maximize → fullscreen → exit | Returned to internal/client maximize `1/1` in both floating and tiled modes |
| OSD over a blank fullscreen test window | Dedicated `caelestia-fullscreen-osd` surface appeared on Overlay, showed `Volume · N%`, and disappeared when the normal timer expired; speaker volume was unchanged by the test |

The fullscreen defect was reproduced before the fix: Brave still reported a maximized browser window, while compositor state dropped to `0/0`. Hyprland 0.57 translates native xdg maximize requests into toggles; Chromium reasserts `set_maximized` after fullscreen exit. Native window actions preserve the prior modes and distinguish this protocol echo from a genuine unmaximize request.

Changing the existing drawers surface's layer while it was occluded did not reliably move its compositor layer. The fix maps a separate, input-transparent Overlay surface only while the fullscreen OSD is active. It does not globally expose the bar over videos. The ordinary OSD remains interactive outside fullscreen.

## Checks still required on a fresh target

- Entire download/build/deploy sequence and first login from COSMIC.
- Password lock/unlock and recovery, suspend/resume, and external/multiple monitors.
- Every GPU/driver combination and graphics-switching mode. Native fullscreen output redirection is not certified.
- Actual recording with the selected encoder and speaker audio, microphone behavior, brightness, IME in each application's sandbox, portals and keyring unlock.
- All optional feature combinations and upgrade/rollback across future source or package revisions.

Follow [the agent verification guide](agent/VERIFY.md) or the human [English](en/INSTALL.md) / [Vietnamese](vi/INSTALL.md) guides. Keep COSMIC until these checks have passed on your machine. Do not reinterpret a successful static check, apt simulation, or build receipt as a successful fresh-machine login.
