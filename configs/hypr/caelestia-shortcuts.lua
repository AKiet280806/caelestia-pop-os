-- Windows-like shortcuts. Shared window state lives in caelestia-windows.lua.
-- Apply after HyprMod so app/workspace switches keep the pointer where it is.
hl.config({cursor = {no_warps = true, warp_on_change_workspace = 0,
    warp_on_monitor_change = 0, warp_on_toggle_special = 0}})

local runtime = assert(os.getenv("XDG_RUNTIME_DIR"), "XDG_RUNTIME_DIR is required") .. "/caelestia-window-state"
local cycle = nil
local function publish_switcher()
    local addresses = {}
    local selected = ""
    if cycle then
        for _, window in ipairs(cycle.windows) do
            if window.mapped then addresses[#addresses + 1] = string.format("%q", window.address) end
        end
        local window = cycle.windows[cycle.index]
        if window and window.mapped then selected = window.address end
    end
    local path = runtime .. "/switcher.json"
    local file = assert(io.open(path .. ".tmp", "w"))
    file:write(string.format('{"active":%s,"addresses":[%s],"selected":%q}\n',
        cycle and "true" or "false", table.concat(addresses, ","), selected))
    file:close(); assert(os.rename(path .. ".tmp", path))
end
function caelestia_alt_tab_cancel()
    cycle = nil
    publish_switcher()
end
function caelestia_alt_tab_finish()
    local window = cycle and cycle.windows[cycle.index]
    cycle = nil
    publish_switcher()
    if not window or not window.mapped or not window.workspace then return end
    if window.workspace.name == "special:minimized" then caelestia_restore_window(window)
    else hl.dispatch(hl.dsp.focus({window = window})) end
end
function caelestia_alt_tab_select(address)
    if not cycle then return end
    for index, window in ipairs(cycle.windows) do
        if window.mapped and window.address == address then
            cycle.index = index
            caelestia_alt_tab_finish()
            return
        end
    end
end
-- Clear any stale overlay when the compositor config is reloaded.
publish_switcher()
function caelestia_alt_tab(forward)
    if not cycle then
        local workspace = hl.get_active_workspace()
        if not workspace then return end
        local active = hl.get_active_window()
        local windows = {}
        for _, window in ipairs(hl.get_windows()) do
            if window.mapped and not window.hidden and window.class ~= "" and window.workspace
                and (window.workspace.name == "special:minimized" or window.workspace.id == workspace.id) then
                windows[#windows + 1] = window
            end
        end
        table.sort(windows, function(a, b)
            if a == active then return b ~= active end
            if b == active then return false end
            return a.focus_history_id < b.focus_history_id
        end)
        local index = 0
        for i, window in ipairs(windows) do if window == active then index = i; break end end
        cycle = {windows = windows, index = index}
    end
    local count = #cycle.windows
    if count == 0 then caelestia_alt_tab_cancel(); return end
    if cycle.index == 0 and forward == false then cycle.index = count + 1 end
    for _ = 1, count do
        cycle.index = ((cycle.index - 1 + (forward == false and -1 or 1)) % count) + 1
        local window = cycle.windows[cycle.index]
        if window.mapped and window.workspace then
            publish_switcher()
            return
        end
    end
    caelestia_alt_tab_cancel()
end
-- Match Alt by keysym, including remapped or virtual keyboards.
for _, key in ipairs({"Alt_L", "Alt_R"}) do
    hl.bind(key, caelestia_alt_tab_finish, {release = true, non_consuming = true, ignore_mods = true, transparent = true})
end
hl.bind("ALT + Tab", function() caelestia_alt_tab(true) end)
hl.bind("ALT + SHIFT + Tab", function() caelestia_alt_tab(false) end)
hl.bind("ALT + Escape", caelestia_alt_tab_cancel)

local function batch_path(workspace)
    return runtime .. "/desktop-" .. workspace.id
end
function caelestia_minimize_all()
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    local windows = {}
    for _, window in ipairs(hl.get_windows()) do
        if window.mapped and not window.hidden and not window.pinned and window.class ~= ""
            and window.workspace and window.workspace.id == workspace.id then
            windows[#windows + 1] = window
        end
    end
    -- Repeated Win+M on an empty desktop must not overwrite the restore batch.
    if #windows == 0 then return end
    table.sort(windows, function(a, b) return a.focus_history_id > b.focus_history_id end)
    local seen, ids = {}, {}
    local previous = io.open(batch_path(workspace), "r")
    if previous then
        for id in previous:lines() do
            if id:match("^%x+$") then seen[id] = true; ids[#ids + 1] = id end
        end
        previous:close()
    end
    for _, window in ipairs(windows) do
        if not seen[window.stable_id] then ids[#ids + 1] = window.stable_id end
    end
    local file = assert(io.open(batch_path(workspace) .. ".tmp", "w"))
    file:write(table.concat(ids, "\n") .. "\n"); file:close()
    assert(os.rename(batch_path(workspace) .. ".tmp", batch_path(workspace)))
    for _, window in ipairs(windows) do caelestia_minimize_window(window) end
end
function caelestia_restore_all()
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    local file = io.open(batch_path(workspace), "r")
    if not file then return end
    local windows = {}
    for _, window in ipairs(hl.get_windows()) do windows[window.stable_id] = window end
    for id in file:lines() do
        local window = windows[id]
        if window and window.workspace and window.workspace.name == "special:minimized" then
            caelestia_restore_window(window)
        end
    end
    file:close()
    os.remove(batch_path(workspace))
end
hl.bind("SUPER + M", caelestia_minimize_all)
hl.bind("SUPER + SHIFT + M", caelestia_restore_all)
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("foot -a btop -T 'System monitor' btop"))
