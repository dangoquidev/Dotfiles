#!/usr/bin/env bash
# Wallpaper switcher (SUPER+SHIFT+B)
#   wallpaper.sh            rofi picker with previews (~/.config/hypr/wallpapers + ~/Pictures/Wallpapers)
#   wallpaper.sh <image>    set this wallpaper
#   wallpaper.sh --restore  session start: last wallpaper (or the default), lockscreen image if missing
#
# Every change also regenerates the hyprlock background: a small pre-blurred,
# darkened JPEG (~/.cache/hypr/lock.jpg) so the lockscreen appears instantly.

set -uo pipefail

DEFAULT="$HOME/.config/hypr/wallpapers/yuki-nagato-stars.png"
DIRS=("$HOME/.config/hypr/wallpapers" "$HOME/Pictures/Wallpapers")
LOCK="$HOME/.cache/hypr/lock.jpg"
THEME="$HOME/.config/rofi/theme.rasi"

wait_daemon() {  # up to ~3s for awww-daemon to answer
    for _ in $(seq 60); do awww query >/dev/null 2>&1 && return 0; sleep 0.05; done
    return 1
}

current() {  # image awww is displaying now
    awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1
}

make_lock() {  # make_lock <image>
    mkdir -p "$(dirname "$LOCK")"
    python3 -I - "$1" "$LOCK" <<'PY'
import sys
from PIL import Image, ImageFilter, ImageEnhance
im = Image.open(sys.argv[1]).convert("RGB")
im.thumbnail((960, 960))
im = im.filter(ImageFilter.GaussianBlur(9))
im = ImageEnhance.Brightness(ImageEnhance.Color(im).enhance(1.2)).enhance(0.7)
im.save(sys.argv[2], quality=92)
PY
}

set_wallpaper() {  # set_wallpaper <image>
    awww img "$1" --transition-type grow --transition-pos top-right \
        --transition-duration 1 --transition-fps 60
    make_lock "$1" &
}

pick() {
    local files=() f
    for d in "${DIRS[@]}"; do
        [[ -d "$d" ]] || continue
        while IFS= read -r -d '' f; do files+=("$f"); done < <(
            find -L "$d" -maxdepth 1 -type f \
                \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) \
                ! -iname '*-lock.*' -print0 | sort -z)
    done
    (( ${#files[@]} )) || { notify-send -a Wallpaper "Wallpaper" "No images in ${DIRS[*]}"; exit 1; }

    local cur; cur=$(current)
    local sel
    sel=$(for f in "${files[@]}"; do
            printf '%s\0icon\x1f%s\n' "$(basename "${f%.*}")$([[ "$f" == "$cur" ]] && echo '  (current)')" "$f"
          done | rofi -dmenu -i -show-icons -format i -p "Wallpaper" -theme "$THEME" \
                -theme-str 'element-icon { size: 96px; } listview { lines: 5; } window { width: 640px; }') || exit 0
    set_wallpaper "${files[$sel]}"
}

case "${1:-}" in
    --restore)
        wait_daemon || exit 1
        awww restore 2>/dev/null || awww img "$DEFAULT"
        [[ -f "$LOCK" ]] || make_lock "$(current || true)" 2>/dev/null || make_lock "$DEFAULT"
        ;;
    "")
        pick
        ;;
    *)
        [[ -f "$1" ]] || { echo "no such file: $1" >&2; exit 1; }
        set_wallpaper "$(realpath "$1")"
        ;;
esac
