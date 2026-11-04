# Workspace layout mode

The Float/Tiling button controls only the focused normal workspace. Unconfigured workspaces default to tiling. Store overrides by percent-encoded workspace name under `$XDG_STATE_HOME/caelestia/workspace-modes/`; leave the legacy global file unused. Named workspaces and numbered workspaces retain their own choice across reloads/logins.

1. Replace the global Lua policy with workspace-scoped preferences and window changes. Preserve floating geometry/maximize, exclude pinned and special-workspace windows, and associate minimized windows with their originating workspace. New windows in a floating workspace float; normal moves adopt the destination workspace policy. Restoring a minimized window in its original workspace retains its saved geometry; restoring elsewhere adopts that workspace's mode.
2. Make the sidebar read the focused workspace's preference, default to tiling, and label its scope. Switching workspaces updates the displayed mode without toggling any windows.
3. Verify isolation, named-workspace persistence, new windows, moves and minimize/restore with a mocked Lua harness and disposable live windows. Back up only the changed host files, reload config without restarting the compositor, and preserve the user's focus/cursor. Update human documentation and publish after checks.

Acceptance: toggling A does not change B or B's hidden windows; B/new workspaces default to tiling; a stored floating A remains floating after config reload; maximize geometry survives a float → tile → float round trip. Existing manually floating windows on a tiling workspace remain supported through Win+V.

Validation complete: the isolated Lua harness and live two-workspace terminal checks passed. The real bar button follows workspace changes, retains A's Float preference while B defaults to Tiling, and changes only the workspace captured at click time. Lua syntax, guide links, installer tests and QML lint passed. The host update replaced only the window-actions Lua module and layout button after a verified versioned backup; no compositor restart was performed.
