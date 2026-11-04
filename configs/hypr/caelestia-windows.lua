-- Shared window actions: preserve state before entering the shared hidden workspace.
local home = os.getenv("HOME")
local workspace_tiling
local restoring_window
local runtime = assert(os.getenv("XDG_RUNTIME_DIR"), "XDG_RUNTIME_DIR is required") .. "/caelestia-window-state"
os.execute("mkdir -p " .. string.format("%q", runtime))
local function window_for(selector)
    if selector == nil then return hl.get_active_window() end
    if type(selector) == "userdata" then return selector end
    return hl.get_window(selector)
end
local function path(window, kind)
    return runtime .. "/" .. kind .. "-" .. window.stable_id
end
local function workspace_key(workspace)
    if not workspace or workspace.name:match("^special:") then return nil end
    return (workspace.name:gsub("([^%w%-%_%.%!%~%*%'%(%)])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end
local function remember_origin(window)
    local key = workspace_key(window.workspace)
    if not key then return end
    local file = assert(io.open(path(window, "origin"), "w"))
    file:write(key); file:close()
end
local function origin(window)
    local file = io.open(path(window, "origin"), "r")
    if not file then return nil end
    local key = file:read("*a"); file:close(); return key
end
local function snapshot(window)
    return { floating = window.floating, internal = window.fullscreen,
        client = window.fullscreen_client, x = window.at.x, y = window.at.y,
        width = window.size.x, height = window.size.y }
end
local function save(window, kind, state)
    local file = assert(io.open(path(window, kind) .. ".tmp", "w"))
    file:write(string.format("%d %d %d %d %d %d %d\n", state.floating and 1 or 0,
        state.internal, state.client, state.x, state.y, state.width, state.height))
    file:close()
    assert(os.rename(path(window, kind) .. ".tmp", path(window, kind)))
end
local function load(window, kind)
    local file = io.open(path(window, kind), "r")
    if not file then return nil end
    local floating, internal, client, x, y, width, height = file:read("*n", "*n", "*n", "*n", "*n", "*n", "*n")
    file:close()
    if not height or width <= 0 or height <= 0 then return nil end
    return {floating = floating == 1, internal = internal, client = client,
        x = x, y = y, width = width, height = height}
end
local function fullscreen(window, internal, client)
    hl.dispatch(hl.dsp.window.fullscreen_state({window = window, internal = internal,
        client = client, action = "set"}))
end
local function geometry(window, state)
    hl.dispatch(hl.dsp.window.resize({window = window, x = state.width, y = state.height}))
    hl.dispatch(hl.dsp.window.move({window = window, x = state.x, y = state.y}))
end
-- Explicit internal/client state supports independent maximized floating apps.
function caelestia_set_maximized(selector, enabled)
    local window = window_for(selector)
    if not window or not window.mapped then return end
    if window.floating then
        local was_active = window == hl.get_active_window()
        fullscreen(window, enabled and 1 or 0, enabled and 1 or 0)
        if was_active then
            hl.dispatch(hl.dsp.focus({window = window}))
            hl.dispatch(hl.dsp.window.alter_zorder({window = window, mode = "top"}))
        end
    else
        hl.dispatch(hl.dsp.window.fullscreen({window = window, mode = "maximized",
            action = enabled and "set" or "unset"}))
    end
end
function caelestia_toggle_maximize(selector)
    local window = window_for(selector)
    if window then caelestia_set_maximized(window, window.fullscreen ~= 1) end
end
function caelestia_minimize_window(selector)
    local window = window_for(selector)
    if not window or not window.mapped or window.workspace.name == "special:minimized" then return end
    local state = snapshot(window)
    remember_origin(window)
    -- A workspace supports one fullscreen window. Never leave hidden windows fullscreen.
    fullscreen(window, 0, 0)
    if state.floating then
        local normal = snapshot(window)
        state.x, state.y, state.width, state.height = normal.x, normal.y, normal.width, normal.height
    end
    save(window, "min", state)
    hl.dispatch(hl.dsp.window.move({window = window, workspace = "special:minimized", follow = false}))
end
function caelestia_restore_window(selector)
    local window = window_for(selector)
    if not window or not window.mapped or window.workspace.name ~= "special:minimized" then return end
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    local state = load(window, "min") or snapshot(window)
    if origin(window) and origin(window) ~= workspace_key(workspace) then
        if workspace_tiling(workspace) then
            state.floating, state.internal, state.client = false, 0, 0
        else
            state = load(window, "float") or state
            state.floating = true
        end
    end
    fullscreen(window, 0, 0)
    restoring_window = window
    hl.dispatch(hl.dsp.window.move({window = window, workspace = workspace.id, follow = false}))
    restoring_window = nil
    hl.dispatch(hl.dsp.window.float({window = window, action = state.floating and "enable" or "disable"}))
    if state.floating then geometry(window, state) end
    hl.dispatch(hl.dsp.focus({window = window}))
    fullscreen(window, state.internal, state.client)
    os.remove(path(window, "min"))
    os.remove(path(window, "origin"))
end
function caelestia_minimize_active_window()
    caelestia_minimize_window()
end
hl.on("window.minimize", function(window, minimized)
    if minimized then caelestia_minimize_window(window)
    else caelestia_restore_window(window) end
end)
hl.on("window.close", function(window)
    os.remove(path(window, "min"))
    os.remove(path(window, "float"))
    os.remove(path(window, "origin"))
end)

-- Each normal workspace keeps its own preference. The legacy global file is
-- intentionally ignored; workspaces without an override default to tiling.
local state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local mode_dir = state_home .. "/caelestia/workspace-modes"
os.execute("mkdir -p " .. string.format("%q", mode_dir))
workspace_tiling = function(workspace)
    local key = workspace_key(workspace)
    if not key then return true end
    local file = io.open(mode_dir .. "/ws-" .. key, "r")
    if not file then return true end
    local mode = file:read("*l"); file:close()
    return mode ~= "floating"
end
local function write_mode(workspace, enabled)
    local destination = mode_dir .. "/ws-" .. assert(workspace_key(workspace))
    local file = assert(io.open(destination .. ".tmp", "w"))
    file:write(enabled and "tiling\n" or "floating\n"); file:close()
    assert(os.rename(destination .. ".tmp", destination))
end
local function apply_window_mode(window, enabled)
    if window.floating == (not enabled) then return end
    local state = snapshot(window)
    fullscreen(window, 0, 0)
    if enabled then
        local normal = snapshot(window)
        state.x, state.y, state.width, state.height = normal.x, normal.y, normal.width, normal.height
        save(window, "float", state)
        hl.dispatch(hl.dsp.window.float({window = window, action = "disable"}))
    else
        state = load(window, "float") or state
        hl.dispatch(hl.dsp.window.float({window = window, action = "enable"}))
        geometry(window, state)
        fullscreen(window, state.internal, state.client)
        os.remove(path(window, "float"))
    end
end
function caelestia_set_tiling(enabled, workspace_selector)
    local workspace
    if workspace_selector ~= nil then workspace = hl.get_workspace(workspace_selector)
    else workspace = hl.get_active_workspace() end
    local key = workspace_key(workspace)
    if not key then return end
    enabled = enabled == true
    local was_tiling = workspace_tiling(workspace)
    local focused = hl.get_active_window()
    write_mode(workspace, enabled)
    for _, window in ipairs(hl.get_windows()) do
        if window.class ~= "" and window.workspace and not window.pinned then
            if window.workspace.name == "special:minimized" and origin(window) == key then
                local state = load(window, "min") or snapshot(window)
                if enabled then
                    if not was_tiling then save(window, "float", state) end
                    state.floating, state.internal, state.client = false, 0, 0
                else
                    state = load(window, "float") or state
                    state.floating = true
                end
                save(window, "min", state)
            elseif workspace_key(window.workspace) == key then
                apply_window_mode(window, enabled)
            end
        end
    end
    if focused and focused.mapped and focused.workspace.name ~= "special:minimized" then
        hl.dispatch(hl.dsp.focus({window = focused}))
    end
end
function caelestia_toggle_tiling(workspace_selector)
    local workspace
    if workspace_selector ~= nil then workspace = hl.get_workspace(workspace_selector)
    else workspace = hl.get_active_workspace() end
    if workspace then caelestia_set_tiling(not workspace_tiling(workspace), workspace_selector) end
end
hl.on("window.open", function(window)
    if window.workspace and workspace_key(window.workspace) and not window.pinned
        and not workspace_tiling(window.workspace) then
        apply_window_mode(window, false)
    end
end)
hl.on("window.move_to_workspace", function(window, workspace)
    if window ~= restoring_window and workspace_key(workspace) and not window.pinned then
        apply_window_mode(window, workspace_tiling(workspace))
    end
end)

-- Keyboard/taskbar activation must also raise floating windows, like a desktop WM.
hl.on("window.active", function(window)
    if window and window.mapped and window.floating and window.workspace
        and not window.workspace.name:match("^special:") then
        if window.fullscreen > 0 then
            -- Raised floaters live in a separate pass above fullscreen/maximized.
            -- Put them behind when selecting the maximized app again.
            local windows = hl.get_windows()
            for i = #windows, 1, -1 do
                local other = windows[i]
                if other ~= window and other.floating and not other.pinned and other.workspace
                    and other.workspace.name == window.workspace.name then
                    hl.dispatch(hl.dsp.window.alter_zorder({window = other, mode = "bottom"}))
                end
            end
        end
        hl.dispatch(hl.dsp.window.alter_zorder({window = window, mode = "top"}))
    end
end)
