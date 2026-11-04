-- Behavioral harness for the shipped Lua module; HOME/runtime are temporary.
local workspaces = {{id=1,name="1"},{id=2,name="2"},{id=-1337,name="dev / cloud"}}
local hidden = {id=-99,name="special:minimized"}
local active, focused, windows = workspaces[1], nil, {}
local events = {}
local function operation(name) return function(options) return {name=name, options=options} end end
hl = {dsp={window={}}, on=function(name, callback) events[name]=callback end,
    get_active_workspace=function() return active end,
    get_workspace=function(id) for _,ws in ipairs(workspaces) do if ws.id==id then return ws end end end,
    get_active_window=function() return focused end,
    get_windows=function() return windows end,
    get_window=function(selector) return selector end}
for _, name in ipairs({"fullscreen_state","fullscreen","resize","move","float","alter_zorder"}) do
    hl.dsp.window[name]=operation(name)
end
hl.dsp.focus=operation("focus")
function hl.dispatch(command)
    local o=command.options
    local w=o.window
    if command.name=="float" then w.floating=o.action=="enable"
    elseif command.name=="fullscreen_state" then w.fullscreen,w.fullscreen_client=o.internal,o.client
    elseif command.name=="fullscreen" then w.fullscreen=o.action=="set" and 1 or 0
    elseif command.name=="resize" then w.size={x=o.x,y=o.y}
    elseif command.name=="move" and o.workspace then
        w.workspace=hidden
        for _,ws in ipairs(workspaces) do if ws.id==o.workspace then w.workspace=ws end end
        if events["window.move_to_workspace"] then events["window.move_to_workspace"](w,w.workspace) end
    elseif command.name=="move" then w.at={x=o.x,y=o.y}
    elseif command.name=="focus" then focused=w end
end
local function new_window(id,ws,floating,maximized)
    local w={stable_id=id,class="test",mapped=true,pinned=false,workspace=ws,
        floating=floating,fullscreen=maximized and 1 or 0,fullscreen_client=maximized and 1 or 0,
        at={x=100+id,y=120},size={x=640,y=480}}
    windows[#windows+1]=w;return w
end
local function read(path)
    local f=io.open(path,"r");if not f then return nil end
    local result=f:read("*a");f:close();return result
end
local state=os.getenv("XDG_STATE_HOME").."/caelestia/workspace-modes/ws-"
local runtime=os.getenv("XDG_RUNTIME_DIR").."/caelestia-window-state/"
dofile(arg[1])
local a=new_window(1,workspaces[1],true,true)
local b=new_window(2,workspaces[2],true,true)
focused=b;active=workspaces[2];caelestia_minimize_window(b)
local hidden_before=assert(read(runtime.."min-2"))
active=workspaces[1];focused=a
caelestia_set_tiling(false)
assert(read(state.."1")=="floating\n" and read(state.."2")==nil,"defaults or scoped persistence")
caelestia_set_tiling(true)
assert(not a.floating and b.workspace==hidden,"A did not tile")
assert(read(runtime.."min-2")==hidden_before,"A changed B's hidden state")
caelestia_set_tiling(false)
assert(a.floating and a.fullscreen==1 and a.size.x==640,"floating maximize/geometry lost")
local pinned=new_window(3,workspaces[1],true,false);pinned.pinned=true
caelestia_set_tiling(true);assert(pinned.floating,"pinned window changed")
caelestia_set_tiling(false)
local opened=new_window(4,workspaces[1],false,false)
events["window.open"](opened);assert(opened.floating,"new A window did not float")
local tiled=new_window(5,workspaces[2],false,false)
events["window.open"](tiled);assert(not tiled.floating,"default B window floated")
hl.dispatch(hl.dsp.window.move({window=opened,workspace=2}))
assert(not opened.floating,"move did not adopt destination tiling")
caelestia_minimize_window(a);caelestia_set_tiling(true);caelestia_restore_window(a)
assert(not a.floating and a.workspace==workspaces[1],"hidden A did not adopt A toggle")
caelestia_set_tiling(false);assert(a.floating and a.fullscreen==1,"hidden A floating state lost")
active=workspaces[2];caelestia_restore_window(b)
assert(b.floating and b.fullscreen==1,"unrelated B restore lost original manual float/maximize")
active=workspaces[1];caelestia_minimize_window(a)
active=workspaces[2];caelestia_restore_window(a)
assert(not a.floating,"cross-workspace restore ignored destination")
active=workspaces[3];caelestia_set_tiling(false)
assert(read(state.."dev%20%2F%20cloud")=="floating\n","named workspace persistence encoding")
dofile(arg[1]);local named=new_window(6,workspaces[3],false,false)
events["window.open"](named);assert(named.floating,"preference did not survive reload")
active=workspaces[2];caelestia_toggle_tiling(1)
assert(read(state.."1")=="tiling\n" and read(state.."2")==nil,"captured workspace toggle changed current workspace instead")
active=hidden;caelestia_toggle_tiling();assert(not read(state.."special%3Aminimized"),"special workspace preference written")
print("Workspace isolation, default tiling, geometry/maximize, hidden windows, moves, named state and reload verified")
