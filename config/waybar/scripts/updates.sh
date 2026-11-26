#!/usr/bin/env bash
# Pending updates for waybar (repo: checkupdates from pacman-contrib, AUR: yay)
#   hidden when everything is up to date; click opens kitty with yay -Syu

repo=$(checkupdates 2>/dev/null | wc -l)
aur=0
command -v yay >/dev/null && aur=$(yay -Qua 2>/dev/null | wc -l)
total=$((repo + aur))

if (( total == 0 )); then
    echo '{"text": "", "class": "none"}'
else
    echo "{\"text\": \"󰚰 $total\", \"class\": \"pending\", \"tooltip\": \"$repo repo, $aur AUR\\nClick to update\"}"
fi
