#!/usr/bin/env bash
# Wallpaper switcher (SUPER+SHIFT+B)
#   wallpaper.sh            carousel picker (Quickshell, ~/.config/quickshell/wallpaper/shell.qml)
#                           images from ~/.config/hypr/wallpapers + ~/Pictures/Wallpapers
#   wallpaper.sh <image>    set this wallpaper
#   wallpaper.sh --restore  session start: last wallpaper (or the default), lockscreen image if missing,
#                           carousel previews in the background
#   wallpaper.sh --previews build missing carousel previews (parallel), drop those of deleted images
#
# The carousel gets a JSON list (path + cached card-sized preview + current index)
# and calls this script back with the chosen image.
#
# Every change also regenerates the hyprlock background: a small pre-blurred,
# darkened JPEG (~/.cache/hypr/lock.jpg) so the lockscreen appears instantly.

set -uo pipefail

DEFAULT="$HOME/.config/hypr/wallpapers/yuki-nagato-stars.png"
DIRS=("$HOME/.config/hypr/wallpapers" "$HOME/Pictures/Wallpapers")
[[ -n "${WALLPAPER_DIRS:-}" ]] && IFS=: read -r -a DIRS <<<"$WALLPAPER_DIRS"   # override, e.g. for testing
LOCK="$HOME/.cache/hypr/lock.jpg"
CAROUSEL="$HOME/.config/quickshell/wallpaper"
THUMBS="$HOME/.cache/hypr/wallpaper-previews"
SELF="$(realpath "$0")"

# --- helpers ------------------------------------------------------------------

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
    awww img "$1" --transition-type grow --transition-pos center \
        --transition-duration 1 --transition-fps 60
    make_lock "$1" &
}

list_files() {  # every wallpaper, sorted, one per line
    local d
    for d in "${DIRS[@]}"; do
        [[ -d "$d" ]] || continue
        find -L "$d" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) \
            ! -iname '*-lock.*' | sort
    done
}

PREVIEW_W=440   # = carousel card size (shell.qml)
PREVIEW_H=275

preview_path() {  # preview_path <image>
    printf '%s/%s.jpg' "$THUMBS" "$(printf '%s' "$1" | md5sum | cut -c1-16)"
}

make_previews() {  # build missing/outdated card-sized previews (center-cropped to fill), in parallel
    local f out todo=()
    for f in "$@"; do
        out=$(preview_path "$f")
        [[ -f "$out" && ! "$f" -nt "$out" ]] || todo+=("$f" "$out")
    done
    (( ${#todo[@]} )) || return 0
    mkdir -p "$THUMBS"
    printf '%s\0' "${todo[@]}" | VIPS_WARNING=0 xargs -0 -n 2 -P "$(nproc)" sh -c \
        'vipsthumbnail "$0" -s '"${PREVIEW_W}x${PREVIEW_H}"' --smartcrop centre -o "$1[Q=90,strip]" 2>/dev/null'
}

prune_previews() {  # prune_previews <image>... : delete previews of images that are gone
    [[ -d "$THUMBS" && -z "${WALLPAPER_DIRS:-}" ]] || return 0   # never with a test override
    local f p
    local -A keep=()
    for f in "$@"; do keep["$(preview_path "$f")"]=1; done
    for p in "$THUMBS"/*.jpg; do
        [[ -e "$p" && -z "${keep[$p]:-}" ]] && rm -f -- "$p"
    done
    return 0
}

json_str() {  # json_str <text> → "escaped"
    local s=${1//\\/\\\\}
    s=${s//\"/\\\"}
    printf '"%s"' "$s"
}

open_carousel() {
    # toggle: a second SUPER+SHIFT+B closes it
    if pkill -f "quickshell -p $CAROUSEL" 2>/dev/null; then exit 0; fi

    local files=() f i
    mapfile -t files < <(list_files)
    (( ${#files[@]} )) || { notify-send -a Wallpaper "Wallpaper" "No images in ${DIRS[*]}"; exit 1; }
    make_previews "${files[@]}"   # normally already done at login (--previews)
    prune_previews "${files[@]}" &

    local cur idx=0 list="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-carousel.json"
    cur=$(current)
    {
        printf '{"walls":['
        for i in "${!files[@]}"; do
            [[ "${files[$i]}" == "$cur" ]] && idx=$i
            (( i )) && printf ','
            printf '{"path":%s,"thumb":%s}' "$(json_str "${files[$i]}")" "$(json_str "$(preview_path "${files[$i]}")")"
        done
        printf '],"current":%d}\n' "$idx"
    } >"$list"

    WALLPAPER_LIST="$list" WALLPAPER_SCRIPT="$SELF" exec quickshell -p "$CAROUSEL"
}

# --- entry points --------------------------------------------------------------

case "${1:-}" in
    --restore)
        wait_daemon || exit 1
        awww restore 2>/dev/null || awww img "$DEFAULT"
        [[ -f "$LOCK" ]] || make_lock "$(current || true)" 2>/dev/null || make_lock "$DEFAULT"
        # carousel previews ready before the first SUPER+SHIFT+B
        mapfile -t _files < <(list_files)
        (( ${#_files[@]} )) && nice -n 10 "$SELF" --previews >/dev/null 2>&1 &
        ;;
    --previews)
        mapfile -t _files < <(list_files)
        (( ${#_files[@]} )) && make_previews "${_files[@]}"
        prune_previews "${_files[@]}"
        ;;
    "")
        open_carousel
        ;;
    *)
        [[ -f "$1" ]] || { echo "no such file: $1" >&2; exit 1; }
        set_wallpaper "$(realpath "$1")"
        ;;
esac
