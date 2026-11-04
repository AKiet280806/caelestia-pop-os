# Caelestia shell · Pop!_OS edition

This directory contains the modified [Caelestia shell](https://github.com/caelestia-dots/shell) used by [Caelestia for Pop!_OS](../README.md).

For installation, use the repository's [English](../docs/en/INSTALL.md) or [Vietnamese](../docs/vi/INSTALL.md) guide. The shell is built and deployed by the root installer with the runtime revisions in [pins.json](../pins.json).

## Local changes

- Running-window sidebar, per-workspace Float/Tiling control and visual Alt+Tab switcher.
- Familiar window controls, fullscreen volume OSD and launcher hover behavior.
- One selectable AI usage provider with local provider logos.
- Pop!_OS integration, recording adaptations and wallpaper recovery coordination.

The upstream base revision is `454f46da16ae75cc57f34adf48dea74db0fa5175`. The full modified QML/C++ source is included here. See the root [contribution guide](../CONTRIBUTING.md) before making changes.

Upstream copyright notices and the [GPL-3.0 license](LICENSE) are preserved. See [NOTICE](../NOTICE) and [component notices](../licenses/upstream-runtime-notices.md) for attribution.
