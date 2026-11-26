hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.layer_rule({
    -- Blur behind rofi; only visible where rofi is translucent (the power menu backdrop)
    name         = "blur-rofi",
    match        = { namespace = "^rofi$" },
    blur         = true,
    ignore_alpha = 0,
})

-- No open/close animation for rofi, disabled by default (the launcher keeps its fade).
-- power-menu.sh turns it on while it runs (`hyprctl eval`), so the menu doesn't
-- linger fading out behind hyprlock, and switching to the Yes/No prompt doesn't flicker.
PowerMenuNoAnim = hl.layer_rule({
    name    = "rofi-no-anim",
    match   = { namespace = "^rofi$" },
    no_anim = true,
})
PowerMenuNoAnim:set_enabled(false)
