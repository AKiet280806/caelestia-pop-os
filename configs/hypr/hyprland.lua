-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pop!_OS 24.04 + pinned Hyprland 0.57.0. @SCALE@ is set by the installer.
-- Keep hardware-specific changes in hyprland-gui.lua or a separate local module.
local home = assert(os.getenv("HOME"), "HOME is required")
local data = os.getenv("XDG_DATA_HOME") or (home .. "/.local/share")
hl.monitor({output = "", mode = "preferred", position = "auto", scale = @SCALE@})
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.config({
    general = {gaps_in = 5, gaps_out = 10, border_size = 2, layout = "dwindle",
        col = {active_border = "rgba(7aa2f7ff)", inactive_border = "rgba(1e2030ff)"}},
    decoration = {rounding = 10, active_opacity = 1.0, inactive_opacity = 0.97,
        blur = {enabled = true, size = 3, passes = 2}},
    animations = {enabled = true},
    input = {kb_layout = "us", follow_mouse = 0, float_switch_override_focus = 0,
        touchpad = {natural_scroll = true, tap_to_click = true}},
    dwindle = {preserve_split = true},
    misc = {disable_hyprland_logo = true, force_default_wallpaper = -1},
    debug = {disable_scale_checks = true},
})
hl.curve("riceEase", {type = "bezier", points = {{0.05, 0.9}, {0.1, 1.0}}})
hl.animation({leaf = "windows", enabled = true, speed = 5, bezier = "riceEase"})
hl.animation({leaf = "fade", enabled = true, speed = 5, bezier = "default"})
hl.animation({leaf = "workspaces", enabled = true, speed = 5, bezier = "default"})
hl.gesture({fingers = 3, direction = "horizontal", action = "workspace"})
hl.on("hyprland.start", function() hl.exec_cmd("start-caelestia-services") end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("caelestia-open-files"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("caelestia-open-browser"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("qs -c caelestia ipc call drawers toggle launcher"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c caelestia ipc call drawers toggle sidebar"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("qs -c caelestia ipc call lock lock"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({action = "toggle"}))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({action = "toggle"}))
hl.bind("SUPER + CTRL + SHIFT + Q", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
for _, direction in ipairs({"left", "right", "up", "down"}) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({direction = direction}))
end
for i = 1, 10 do
    hl.bind("SUPER + " .. i % 10, hl.dsp.focus({workspace = i}))
    hl.bind("SUPER + SHIFT + " .. i % 10, hl.dsp.window.move({workspace = i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse = true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse = true})
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {locked = true, repeating = true})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {locked = true, repeating = true})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {locked = true})
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs -c caelestia ipc call brightness set +5%"), {locked = true, repeating = true})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c caelestia ipc call brightness set 5%-"), {locked = true, repeating = true})
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("ALT + F10", function() caelestia_toggle_maximize() end)
hl.bind("SUPER + H", hl.dsp.exec_cmd("qs -c caelestia ipc call windowControls minimize"))
hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("qs -c caelestia ipc call windowControls restore"))
hl.bind("Print", hl.dsp.exec_cmd("caelestia screenshot"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs -c caelestia ipc call picker openClip"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("caelestia-clipboard"))

require("caelestia-windows")
hl.plugin.load(data .. "/hypr/plugins/native-minimize-0.57.0.so")
hl.plugin.load(data .. "/hypr/plugins/hyprbars-0.57.0.so")
if hl.plugin.hyprbars then
    hl.config({plugin = {hyprbars = {
        bar_height = 32, bar_text_size = 12, bar_text_font = "Rubik",
        bar_color = "rgb(1e2030)", ["col.text"] = "rgb(cdd6f4)",
        bar_buttons_alignment = "right", bar_button_padding = 7,
        bar_padding = 10, buttons_on_hover = false, bar_blur = false,
        on_double_click = [[hyprctl eval 'caelestia_toggle_maximize()']],
    }}})
    hl.plugin.hyprbars.add_button({bg_color="rgb(f38ba8)",fg_color="rgb(1e2030)",size=18,icon="×",action=[[hyprctl dispatch 'hl.dsp.window.close()']]})
    hl.plugin.hyprbars.add_button({bg_color="rgb(a6e3a1)",fg_color="rgb(1e2030)",size=18,icon="□",action=[[hyprctl eval 'caelestia_toggle_maximize()']]})
    hl.plugin.hyprbars.add_button({bg_color="rgb(f9e2af)",fg_color="rgb(1e2030)",size=18,icon="−",action=[[hyprctl eval 'caelestia_minimize_active_window()']]})
end
require("hyprland-gui")
require("caelestia-shortcuts")

-- Toggle automatic edge/bar popups.
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("qs -c caelestia ipc call popupHover toggle"))
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("qs -c caelestia ipc call windowLayout toggle"))
