# Visual assets

## Wallpaper

`wallpaper.svg` is an original abstract geometric illustration created for this repository and dedicated to the public domain under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/). `wallpaper.png` is its 2560×1600 raster rendering for Qt image support. Render the source SVG with librsvg or another compatible renderer.

## Desktop screenshots

Each feature has one screenshot in `screenshots/`, linked from the main README:

| Capture | Shows |
| --- | --- |
| `desktop.png` | Sidebar, workspaces, layout control and desktop clock |
| `dashboard.png` | Calendar, clock, uptime, weather, resources and media overview |
| `media.png` | Artwork, playback controls, timeline, player selector and lyrics panel |
| `performance.png` | Live CPU, GPU, memory, storage, network and battery readings |
| `weather.png` | Current conditions and seven-day forecast for London |
| `launcher.png` | Application search |
| `clipboard.png` | Clipboard search with an isolated demo history |
| `window-switcher.png` | Visual Alt+Tab with disposable demonstration windows |
| `ai-usage.png` | Selected-provider quota and reset times |
| `notifications.png` | Expanded group of demonstration notifications |
| `audio-brightness.png` | Volume percentage and brightness controls |
| `screenshot-selection.png` | Screenshot area-selection overlay |
| `utilities.png` | Screen recording, keep-awake and quick toggles |
| `appearance.png` | Nexus wallpaper and style settings |
| `floating.png`, `tiling.png` | The two window layouts and titlebar controls |
| `session-controls.png` | Session menu, displayed without executing an action |

These are real interface captures using the included wallpaper and a Dracula palette. Terminal text, preview-window selection, media metadata and notification content are staged for demonstration. The media screenshot uses a local MPRIS demo player; it does not demonstrate audible playback or a live lyrics source. Weather uses London as a demo location. Performance statistics are actual readings from the demo machine.

Clipboard entries were generated in an isolated history database; no personal clipboard data was read or selected. Session controls and the screenshot picker were opened and cancelled without performing their actions. The optional AI widget shows numeric limits without an account identity. Installed apps and display scale reflect the demo machine.

Screenshots document the interface; they do not establish clean-machine installer support. UI elements and application icons retain their upstream rights. The provider icon attribution is recorded in [the icon manifest](../shell/assets/ai-providers/provenance.json) and [Lobe Icons license](../licenses/Lobe-Icons-MIT.txt).
