# Use the desktop

[Tiếng Việt](../vi/USAGE.md) · [Install](INSTALL.md) · [Troubleshoot](TROUBLESHOOTING.md)

**Win / Super** means the Windows-logo key. Windows float by default. Click a window to focus it; passing the mouse over another window does not select it, and app/workspace switching does not warp your pointer.

## Keyboard reference

| Shortcut | Action |
| --- | --- |
| Win+Enter or Win+T | Open Foot terminal |
| Win+D | Search applications in the launcher |
| Win+E | Open COSMIC Files |
| Win+B | Open your configured/default browser |
| Alt+Tab | Hold Alt for visual window chooser; Tab advances; release Alt to select |
| Alt+Shift+Tab | Cycle the chooser backwards |
| Alt+Esc while choosing | Cancel without switching |
| Alt+F4 or Win+Q | Close focused window |
| Alt+F10 | Maximize/restore, leaving shell space visible |
| Win+F | Toggle fullscreen |
| Win+H | Minimize focused window |
| Win+Shift+H | Restore one minimized window into current workspace |
| Win+M | Minimize non-pinned windows in current workspace |
| Win+Shift+M | Restore the batch minimized with Win+M |
| Win+V | Toggle focused window between floating and tiled |
| Win+Shift+V | Open clipboard history |
| Win+arrow keys | Focus window in the chosen direction |
| Win+left mouse drag | Move window |
| Win+right mouse drag | Resize window |
| Win+1…9, 0 | Switch workspace; 0 means workspace 10 |
| Win+Shift+1…9, 0 | Move focused window to workspace |
| Win+N | Toggle notification sidebar |
| Win+L | Lock screen; test password unlock before relying on it |
| Ctrl+Shift+Esc | Open btop in a terminal |
| Print Screen | Capture full screen to clipboard; use Save in notification to save a file |
| Win+Shift+S | Select screenshot region; Esc cancels |
| Win+Ctrl+Shift+Q | Log out of Hyprland; save work first |

There is no duplicate Win+R launcher binding. Ctrl+Tab and Ctrl+Shift+Tab remain application-specific tab shortcuts. Laptop media and brightness keys are configured where the hardware exposes them; three-finger horizontal workspace gestures depend on touchpad support.

## Window controls and layouts

The titlebar has minimize, maximize/restore, and close buttons. Double-click the titlebar to maximize/restore. Maximizing differs from fullscreen: fullscreen can hide shell/titlebar controls, so press Win+F to leave it. Maximized floating windows keep their own state when you switch apps. Native application window actions are routed through the matching native plugin.

The sidebar's **Float/Tiling** control changes the global layout policy. Win+V affects one window. When experimenting with tiling, keep a terminal accessible and use the shortcut to recover awkward window placement.

The running-app bar shows one item per window, including windows on other workspaces and minimized windows. Hover for the title, scroll when the list is long. Click the selected window's icon to minimize it; click another to focus; click a minimized one to restore to your current workspace. A longer marker indicates selection; dimmed icons indicate minimized windows. Win+Shift+M restores only its stored batch, preserving windows minimized before that batch.

## Visual Alt+Tab

Hold Alt and press Tab to open the chooser. It includes windows on the current workspace and minimized windows, ordered by recent focus. Tab moves forward, Shift+Tab goes back, and releasing Alt commits the highlighted card. Click a card to choose directly. Esc while holding Alt or clicking outside cancels. A minimized window is restored only when you commit. Preview capture can be unavailable for an app; the card then uses its icon. The pointer stays where you left it.

## Launcher and clipboard

Win+D opens application search. The hover launcher can close when the pointer leaves until you start typing; typing keeps your search active. Use the keyboard shortcut if hover behavior is inconvenient.

Win+Shift+V opens clipboard history. Select an item and press Enter, then Ctrl+V in the target app. Text and images are collected by session-bound clipboard watchers; content copied before these start may not appear. Clipboard history may contain private copied text. Inspect before sharing logs or screenshots, and use `cliphist wipe` if you deliberately want to clear the whole history.

## Screenshots and recording

Print Screen captures the display; Win+Shift+S lets you draw a region. Esc cancels region selection. Swappy supplies screenshot annotation/editing where invoked by the screenshot flow.

Open **Utilities → Screen recorder / Record screen**. Choose full display or a region, with or without sound. Drag to select a region. Press **Stop** to finish and wait for the saved notification. Files go to `~/Videos/Recordings`. Audio means the current output's **speaker monitor**, encoded as AAC, not automatic microphone recording. Only one recording should run at a time. Pause is disabled because the wf-recorder backend does not support it.

The CLI can also toggle recording:

```bash
caelestia record
caelestia record -s
caelestia record -r
```

Run one start command for your desired mode, then `caelestia record` again to stop. `-s` selects sound and `-r` region selection. Check `caelestia record --help` for combinations. Use a short test before an important capture, especially with NVENC. A configured NVIDIA encoder does not make an unsupported GPU work.

## Vietnamese input and optional tools

With `--vietnamese`, the session starts Fcitx5 and selects Unikey. Use Fcitx5 Configuration to check the engine and Telex settings. Common Telex examples: `tieengs Vieetj` → `tiếng Việt`; input behavior follows your Unikey options. Check the configured activation key rather than assuming every installation uses the same toggle.

HyprMod is optional and does not replace the installer or OS updater. Review monitor/scale changes before applying; keep the session profile and backup available. Your existing browser remains the default unless you choose another yourself.

AI Usage shows one provider you choose. Hover the sidebar widget, click the current provider name, search and select another. That choice persists after login; only its quota windows or balances are fetched. Connect the corresponding account locally, then refresh. Missing values stay unknown. See [provider setup and sources](../AI-USAGE.md).

## Lock, idle and power

Automatic idle timeouts and fingerprint authentication are disabled initially. Save work, test Win+L and password/PAM unlock manually, and only then configure auto-lock, display sleep or suspend. Sleep/wake and authentication need validation on your hardware.

Pop!_OS keeps `system76-power`. The upstream shell's power-profile control is not guaranteed to work because this project does not install the conflicting `power-profiles-daemon`. To inspect supported actions without changing profiles:

```bash
system76-power help
system76-power profile --help
```

Read the help for your installed version before making a deliberate power-profile change. GPU mode, CPU power profile, screen brightness and suspend are separate controls.

## Terminal Cava and HyprMod

Run `cava` (or `terminalcava`) in Foot while music plays through the selected speaker output. The CLI's color-template adaptation selects `noncurses` output with PulseAudio monitor input; it is independent of the desktop background visualizer. The first wallpaper/scheme application generates the terminal config. If the screen is blank, confirm you can hear music, inspect `pactl get-default-sink`, and check `~/.config/cava/config` for `method = noncurses` in the output section and `method = pulse`, `source = auto` in the input section. Muting or very low output can leave no useful signal.

If installed, launch `hyprmod` from the app launcher or terminal. Save monitor/scale changes deliberately; they belong in `hyprland-gui.lua`. The installer does not automatically open it or change GPU mode.

## Sharp browser text on fractional scale

Use the browser's native Wayland mode when possible. For Brave, inspect `brave://version` and `brave://gpu`. Test a separate launch with `--ozone-platform=wayland`; an already running instance may ignore new startup flags. For the Brave Flatpak, flags can be stored in `~/.var/app/com.brave.Browser/config/brave-flags.conf`. Preserve existing flags and append only `--ozone-platform=wayland` if needed. Save forms and work before closing/reopening the browser yourself. This installer retains your chosen browser and does not overwrite browser profiles.

For the single-provider AI Usage selector and account setup, see [AI Usage](../AI-USAGE.md).
