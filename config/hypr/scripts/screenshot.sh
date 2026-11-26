#!/usr/bin/env bash
# Screenshot → ~/Pictures/Screenshots + clipboard, with a notification.
#   screenshot.sh          full screen
#   screenshot.sh window   active window only
# The notification icon is a small JPEG thumbnail (~10 KB), not the full PNG:
# dunst can crash when its image loader chokes on a large screenshot.

set -uo pipefail

dir="$HOME/Pictures/Screenshots"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
thumb="${XDG_RUNTIME_DIR:-/tmp}/screenshot-thumb-$$.jpg"

mkdir -p "$dir"
geometry=()
if [[ "${1:-}" == window ]]; then
    # "at: X,Y" and "size: W,H" → grim -g "X,Y WxH"
    g=$(hyprctl activewindow | awk '/^\tat:/ {at=$2} /^\tsize:/ {split($2, s, ","); print at " " s[1] "x" s[2]}')
    [[ -n "$g" ]] && geometry=(-g "$g")
fi

grim "${geometry[@]}" - | tee "$file" | wl-copy --type image/png || exit 1

# thumbnail + notification don't hold anything up
(
    if VIPS_WARNING=0 vipsthumbnail "$file" -s 256 -o "$thumb[Q=80,strip]" 2>/dev/null; then
        icon="$thumb"
    else
        icon="image-x-generic"
    fi
    notify-send -a Screenshot -i "$icon" "Screenshot" "Saved and copied: $(basename "$file")"
    sleep 5; rm -f "$thumb"
) &
