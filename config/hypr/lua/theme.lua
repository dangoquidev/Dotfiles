hl.config({
    general = {
        gaps_in  = 8,
        gaps_out = 12,
        border_size = 3,
        col = {
            active_border   = "rgba(ff8fa3ff)",
            inactive_border = "rgba(2a2a3aaa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 0,
        active_opacity     = 0.85,
        inactive_opacity   = 0.85,
        fullscreen_opacity = 0.95,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            xray = false,
            noise = 0.02,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.2,
            vibrancy_darkness = 0.5,
            popups = true,
            popups_ignorealpha = 0.2,
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        background_color = "rgba(1a1a2aff)",
    },
})
