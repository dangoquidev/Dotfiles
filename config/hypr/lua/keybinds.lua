local p = require("lua.programs")
local mainMod = "SUPER"
local function key(mods, k) return mods .. " + " .. k end
local exec = hl.dsp.exec_cmd

hl.bind(key(mainMod, "T"), exec(p.terminal))
hl.bind(key(mainMod, "Q"), hl.dsp.window.close())
hl.bind(key(mainMod, "M"), exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(key(mainMod, "E"), exec(p.fileManager))
hl.bind(key(mainMod, "V"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key(mainMod, "A"), exec(p.menu))

-- Super P — area → clipboard
hl.bind("SUPER + P", exec([[grim -g "$(slurp -d)" - | wl-copy]]))
-- Super Shift P — area → clipboard + swappy
hl.bind("SUPER + SHIFT + P", exec([[grim -g "$(slurp -d)" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png]]))
-- Super Ctrl P — area → saved file (+ clipboard)
hl.bind("SUPER + CTRL + P", exec([[mkdir -p ~/Pictures/Screenshots && grim -g "$(slurp -d)" - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy]]))
-- hl.bind(key(mainMod, "J"), hl.dsp.layout("togglesplit"))

hl.bind(key(mainMod, "B"), exec(p.browser))
hl.bind(key(mainMod, "C"), exec("hyprpicker -a"))
hl.bind(key(mainMod, "L"), exec("hyprlock"))
hl.bind(key(mainMod, "W"), exec("~/.config/waybar/scripts/wifi-menu.sh"))
hl.bind(key(mainMod, "SHIFT + W"), exec("pkill -SIGUSR2 waybar"))

hl.bind(key(mainMod, "left"),  hl.dsp.focus({ direction = "left" }))
hl.bind(key(mainMod, "right"), hl.dsp.focus({ direction = "right" }))
hl.bind(key(mainMod, "up"),    hl.dsp.focus({ direction = "up" }))
hl.bind(key(mainMod, "down"),  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local k = i % 10
    hl.bind(key(mainMod, k),             hl.dsp.focus({ workspace = i }))
    hl.bind(key(mainMod, "SHIFT + " .. k), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key(mainMod, "S"),         hl.dsp.workspace.toggle_special("magic"))
hl.bind(key(mainMod, "SHIFT + S"), hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(key(mainMod, "mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key(mainMod, "mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(key(mainMod, "mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key(mainMod, "mouse:273"), hl.dsp.window.resize(), { mouse = true })

hl.bind(key("CTRL + " .. mainMod, "left"),  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(key("CTRL + " .. mainMod, "right"), hl.dsp.focus({ workspace = "e+1" }))

hl.bind(key("CTRL + SHIFT + " .. mainMod, "left"),  hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(key("CTRL + SHIFT + " .. mainMod, "right"), hl.dsp.window.move({ workspace = "r+1" }))

-- Resize windows
local function resize(k, x, y, desc)
    hl.bind(key(mainMod, "SHIFT + " .. k), hl.dsp.window.resize({ x = x, y = y, relative = true }),
        { repeating = true, description = desc })
end
resize("Right",  30,   0, "resize window right")
resize("Left",  -30,   0, "resize window left")
resize("Up",      0, -30, "resize window up")
resize("Down",    0,  30, "resize window down")

local le = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), le)
hl.bind("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      le)
hl.bind("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     le)
hl.bind("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   le)
hl.bind("XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+"),                  le)
hl.bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"),                  le)

hl.bind("switch:on:Lid Switch", exec("hyprlock & systemctl suspend"), { locked = true })

local l = { locked = true }
hl.bind("XF86AudioNext",  exec("playerctl next"),       l)
hl.bind("XF86AudioPause", exec("playerctl play-pause"), l)
hl.bind("XF86AudioPlay",  exec("playerctl play-pause"), l)
hl.bind("XF86AudioPrev",  exec("playerctl previous"),   l)
