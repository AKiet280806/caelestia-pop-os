# Verify the first Hyprland session

Run this after the human has selected **Hyprland (Caelestia Pop!_OS)** and logged in. Never start Caelestia in COSMIC to simulate this state. Record each case as **pass**, **fail**, **untested**, or **not applicable**, with concise evidence. A successful installer or static CI result cannot replace these cases.

## Establish the live session

```sh
printf '%s\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}"
hyprctl version
hyprctl configerrors
./setup.sh doctor --json
systemctl --user is-active caelestia-shell.service
systemctl --user is-active caelestia-clipboard@text.service
systemctl --user is-active caelestia-clipboard@image.service
```

Expected: an actual Hyprland Wayland session, the exact pinned compositor ABI, empty configuration errors, active Caelestia shell and both clipboard watchers. Check the installed unit definitions if names differ; do not invent a success. Read focused service logs privately when a unit fails. Avoid collecting application titles, clipboard data, or full client listings in public evidence.

If `hyprctl` cannot connect, first check that the command is running in the logged-in user's actual session with its environment. Do not export an arbitrary socket identifier from another user/session. An ABI/plugin load error blocks affected window-function tests; inspect exact build/runtime versions and follow [RECOVERY.md](RECOVERY.md).

## Interaction and media cases

Use disposable test windows with no unsaved work. Restore changed volume, brightness, geometry, and test preferences afterward. Actual graphical inspection may require the human or an available UI tool; when unavailable, leave the case untested.

| Case | Procedure | Pass evidence |
| --- | --- | --- |
| Window buttons | On a disposable window, use minimize, restore, maximize/restore, and close. Repeat on a floating window. | Correct target window changes state; close affects only the disposable window; restore returns expected geometry. |
| Float/tile | Toggle a test window between tiled and floating using the installed bindings/UI. Move and resize it while floating, then repeat. | Window remains reachable and geometry/state transitions are consistent. |
| Alt-Tab | Open at least three disposable windows, including normal, maximized, and floating states. Test Alt-Tab, Alt-Shift-Tab, release Alt to accept, and Alt-Escape to cancel. Minimize and restore another test window. | Selection matches focus after acceptance; cancellation preserves prior focus; several maximized windows retain their maximized state; normal geometry survives switching/minimize/restore. |
| Pointer | Leave the cursor at a known position while using Alt-Tab and changing workspaces. | No cursor warp to the focused window or monitor. |
| Minimize batch | Use Super-M on disposable windows, repeat on the empty desktop, then Super-Shift-M. | The original batch restores; repeating minimize does not erase the restore state. |
| Launcher hover/typing pin | Open the launcher by hover and move away without typing. Repeat, then type a harmless search. Move the pointer away and finally close it normally. | Untouched hover launcher closes on leave; typing keeps it open until explicitly dismissed; input and close remain usable. |
| Clipboard | Copy a harmless test phrase and image in disposable apps and verify history through the intended UI. | Both watchers store usable items; do not dump real clipboard history. |
| Brave Wayland | Only if Brave is installed, open a disposable window and inspect its own graphics/platform diagnostic or a private compositor query. | Native Wayland operation established; appearance alone does not prove it. Do not collect browsing history or private tabs. |
| Brightness | Read the initial `brightnessctl get` value, change brightness slightly through the UI, check the raw value and visible display, then restore it. | Actual device value and display change; original value restored. An OSD animation alone is insufficient. Missing controllable backlight is not applicable. |
| Audio/Cava | Play an authorized harmless sound, inspect output selection, move volume slightly, and observe visualizer activity; restore volume. | Audible playback on the intended output and Cava activity while playing; no unexplained activity when stopped. |
| Region recording | Ensure no unrelated recorder is running. Read `caelestia record --help`, select a harmless region, enable speaker sound, record a short sample, and stop through Caelestia. | Stop completes and a playable file is saved; correct region, H.264 video, AAC speaker audio, and nonzero duration verified. Confirm no microphone capture was selected. |
| Vietnamese | If installed, activate Fcitx5/Unikey Telex in a disposable editor, type `tieengs Vieetj`, then erase it. | Text becomes `tiếng Việt`; switching back to the prior input method works. Test a second app if available. |

Recording notes: inspect the saved file locally with `ffprobe` (for example, `ffprobe -v error -show_entries stream=codec_type,codec_name -show_entries format=duration -of json /path/to/test.mp4`). Listen to playback to establish that the audio is the intended speaker output. Codec metadata does not prove the selected audio source or audible playback. Keep recordings and their absolute paths private; do not commit media or recorder logs. Delete only this disposable test recording when finished and authorized by the test scope. A muted/missing stream or recorder that fails to stop is a failed case, not a pass with a notification.

## Portals and checks with human involvement

Portal checks need a real application request: exercise a file picker and, where available, a screen-share request using harmless content. Verify the intended Hyprland portal backend serves this session and that returning to COSMIC does not require global portal masks. A running portal process alone does not prove file-picker or screen-share behavior.

Coordinate these disruptive or physical checks with the human; do not trigger them automatically in an active desktop:

- Lock and unlock with the human entering the password. Verify the display is actually locked and unlocked.
- Sleep and resume at a time the human chooses. Verify restored display, input, audio, and networking.
- Multi-monitor layout, scale, hotplug, and monitor power behavior on actual connected hardware. Record which layouts were tested. A single-monitor test is not multi-monitor validation.

Continue independent read-only checks while waiting. If human testing is deferred, mark these cases **untested** and identify the next action. Keep COSMIC available as a recovery session throughout.

## Optional AI usage

Only test if `--with-ai-usage` was selected. Hover the logo, open the provider selector, search and select a provider, and verify exactly one widget and persisted selection. Refresh and filter the list while the pointer is inside; the popup must not shrink away. Missing authentication must show unavailable, without data from the previous provider. See [AI Usage](../AI-USAGE.md). For Codex: Use the existing user-owned Codex installation/session without copying credentials or authenticating on the user's behalf. The integration uses read-only `account/rateLimits/read`; do not send a prompt to measure quota. Verify the display handles available limits, reset times, and unavailable/unauthenticated states without a crash. Report that it concerns Codex account rate limits, not regular ChatGPT usage. Never put account identifiers, authentication files, or raw credential-bearing RPC traffic into reports.

## Completion report

Report the exact revision/options, installed stage results, backup identifier (private), `doctor` findings, live session version, and this test matrix's outcomes. Explicitly list failed and untested cases, including GPU login, portals, lock, sleep/resume, and multi-monitor when applicable. State whether the install was performed on a clean machine or an already configured one. Existing-host success does not establish clean-machine support.

## Fullscreen regressions

Use a disposable video page or a non-sensitive video with the human's permission. Maximize the browser, enter video fullscreen, then exit. Both floating and tiled cases should restore the previous maximize state; a normal floating window should return to its normal geometry. Adjust volume only when authorized, confirm the percentage OSD appears above the video and auto-hides, and restore the previous volume. The dedicated overlay must pass clicks to the video and leave the bar hidden. See [recorded validation](../VALIDATION.md) for what was exercised during development.
