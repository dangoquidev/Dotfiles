local home = os.getenv("HOME")

return {
    home        = home,
    terminal    = "kitty",
    fileManager = "thunar",
    menu        = "rofi -show drun -theme " .. home .. "/.config/rofi/theme.rasi",
    browser     = "zen-browser",
    wallpaper   = home .. "/.config/hypr/wallpapers/yuki-nagato-stars.png",
}
