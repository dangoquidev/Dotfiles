hl.env("GTK_THEME", "catppuccin-mocha-pink-standard+default")
hl.env("XCURSOR_THEME", "catppuccin-mocha-pink-cursors")
hl.env("XCURSOR_SIZE", "24")

-- Electron apps (vesktop, VS Code, Teams…) run natively on Wayland instead of XWayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
