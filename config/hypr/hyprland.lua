-- Config Hyprland (Lua, >= 0.57) — convertie depuis conf/*.conf
-- Modules dans lua/, chargés dans l ordre ci-dessous.

require("lua.monitors")
require("lua.autostart")
require("lua.env")
require("lua.theme")
require("lua.animations")
require("lua.layout")
require("lua.input")
require("lua.keybinds")
require("lua.windowrules")
