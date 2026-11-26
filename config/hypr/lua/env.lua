hl.env("GTK_THEME", "catppuccin-mocha-pink-standard+default")
hl.env("XCURSOR_THEME", "catppuccin-mocha-pink-cursors")
hl.env("XCURSOR_SIZE", "24")

-- Electron apps (vesktop, VS Code, Teams…) run natively on Wayland instead of XWayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- fcitx5 input method (pinyin); GTK uses Wayland text-input, so no GTK_IM_MODULE
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "wayland;fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
