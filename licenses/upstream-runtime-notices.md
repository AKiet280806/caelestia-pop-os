# Runtime dependency notices

The installer downloads and builds the exact sources recorded in `pins.json`.
They remain independent upstream projects with their own licenses; this
repository's GPL license does not replace those licenses. Source checkouts keep
their copyright and license files in the private build cache. No prebuilt Qt,
Hyprland or third-party plugin binaries are distributed by this repository.

| Project | Source and license |
| --- | --- |
| Caelestia Shell | [caelestia-dots/shell](https://github.com/caelestia-dots/shell), GPL-3.0-or-later; the modified export and its license are included in `shell/`. |
| Caelestia CLI | [caelestia-dots/cli](https://github.com/caelestia-dots/cli), GPL-3.0-or-later; two local replacement files are included in `src/cli-overrides/`. |
| Quickshell | [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell), LGPL-3.0-only; consult its LICENSE and source notices. |
| Qt | [Qt open source licensing](https://www.qt.io/licensing/open-source-lgpl-obligations), principally LGPL-3.0/GPL-3.0 with module-specific terms. `aqtinstall` downloads the upstream archive; retain its LICENSES and module notices. |
| Wayland | [freedesktop Wayland](https://gitlab.freedesktop.org/wayland/wayland), MIT-style license and per-file notices. |
| libcava / cava | [LukashonakV/cava](https://github.com/LukashonakV/cava), MIT; includes Karl Stavestrand's copyright notice. |
| M3Shapes | [soramanew/m3shapes](https://github.com/soramanew/m3shapes), Apache-2.0. |
| cpptrace | [jeremy-rifkin/cpptrace](https://github.com/jeremy-rifkin/cpptrace), MIT; preserve licenses of its bundled dependencies too. |
| Hyprland and hyprbars | [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) and [hyprwm/hyprland-plugins](https://github.com/hyprwm/hyprland-plugins), BSD-3-Clause; Hypr Development and contributors. |
| Swappy | [jtheoof/swappy](https://github.com/jtheoof/swappy), MIT. |
| Hyprmod (optional) | [BlueManCZ/hyprmod](https://github.com/BlueManCZ/hyprmod), GPL-3.0-or-later. |
| uv | [astral-sh/uv](https://github.com/astral-sh/uv), Apache-2.0 OR MIT. |
| aqtinstall | [miurahr/aqtinstall](https://github.com/miurahr/aqtinstall), MIT. |
| Dart Sass | [sass/dart-sass](https://github.com/sass/dart-sass), MIT; the pinned standalone archive includes third-party notices. |

The Material Symbols Rounded font is from Google's
[material-design-icons](https://github.com/google/material-design-icons), whose
pinned repository LICENSE is Apache-2.0. Rubik is under the SIL Open Font License
1.1, from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/rubik).
CaskaydiaCove Nerd Font is from [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)
and retains the Cascadia Code SIL Open Font License and Nerd Fonts' icon notices.
Font artifacts and separately downloaded license files are checksum-pinned.
The font stage saves those licenses under
`$XDG_DATA_HOME/caelestia-pop-os/licenses/fonts` (default
`~/.local/share/caelestia-pop-os/licenses/fonts`).

Python dependencies retain their own metadata and bundled license files inside
the isolated tool environments. The installer pins the CLI's runtime dependency
versions and the optional Hyprmod runtime dependency versions in `pins.json`.
Build backends, distro apt packages and aqt's Qt archives are governed by their
upstream packaging and verification; this is a version-pinned installation,
not a promise of bit-for-bit reproducible binaries.

If distributing binaries you build using these scripts, review the applicable
upstream redistribution requirements and provide corresponding source and
notices where required. The source revisions and build commands needed to
identify those sources are present in this repository and its generated build
receipts.
