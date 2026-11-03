-- Shared window actions: preserve state before entering the shared hidden workspace.
local home = os.getenv("HOME")
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
    fullscreen(window, 0, 0)
    hl.dispatch(hl.dsp.window.move({window = window, workspace = workspace.id, follow = false}))
    hl.dispatch(hl.dsp.window.float({window = window, action = state.floating and "enable" or "disable"}))
    if state.floating then geometry(window, state) end
    hl.dispatch(hl.dsp.focus({window = window}))
    fullscreen(window, state.internal, state.client)
    os.remove(path(window, "min"))
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
end)

-- One persistent preference controls new windows and the sidebar switch.
local state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local mode_dir = state_home .. "/caelestia"
os.execute("mkdir -p " .. string.format("%q", mode_dir))
local mode_path = mode_dir .. "/window-mode"
local function write_mode(mode)
    local file = assert(io.open(mode_path .. ".tmp", "w"))
    file:write(mode .. "\n")
    file:close()
    assert(os.rename(mode_path .. ".tmp", mode_path))
end
local file = io.open(mode_path, "r")
local tiling = file and file:read("*l") == "tiling" or false
if file then file:close() else write_mode("floating") end
local float_rule = hl.window_rule({name = "caelestia-floating-default", match = {class = ".*"}, float = true})
float_rule:set_enabled(not tiling)

function caelestia_set_tiling(enabled)
    enabled = enabled == true
    local focused = hl.get_active_window()
    float_rule:set_enabled(not enabled)
    for _, window in ipairs(hl.get_windows()) do
        if window.class ~= "" and window.workspace then
            if window.workspace.name == "special:minimized" then
                local state = load(window, "min") or snapshot(window)
                if enabled then
                    if not tiling then save(window, "float", state) end
                    state.floating, state.internal, state.client = false, 0, 0
                else
                    state = load(window, "float") or state
                    state.floating = true
                end
                save(window, "min", state)
            elseif not window.workspace.name:match("^special:") then
                local state = snapshot(window)
                fullscreen(window, 0, 0)
                if enabled then
                    if not tiling then
                        local normal = snapshot(window)
                        state.x, state.y, state.width, state.height = normal.x, normal.y, normal.width, normal.height
                        save(window, "float", state)
                    end
                    hl.dispatch(hl.dsp.window.float({window = window, action = "disable"}))
                else
                    state = load(window, "float") or state
                    hl.dispatch(hl.dsp.window.float({window = window, action = "enable"}))
                    geometry(window, state)
                    fullscreen(window, state.internal, state.client)
                    os.remove(path(window, "float"))
                end
            end
        end
    end
    tiling = enabled
    write_mode(tiling and "tiling" or "floating")
    if focused and focused.mapped and focused.workspace.name ~= "special:minimized" then
        hl.dispatch(hl.dsp.focus({window = focused}))
    end
end
function caelestia_toggle_tiling()
    caelestia_set_tiling(not tiling)
end

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
