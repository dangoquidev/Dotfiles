#!/usr/bin/env bash
# Do not disturb (dunst) for waybar
#   dnd.sh          → JSON status      dnd.sh toggle → pause/resume notifications (signal 9)

case "${1:-}" in
    toggle)
        dunstctl set-paused toggle
        pkill -RTMIN+9 waybar
        ;;
    *)
        if [[ "$(dunstctl is-paused 2>/dev/null)" == true ]]; then
            n=$(dunstctl count waiting 2>/dev/null || echo 0)
            echo "{\"text\": \"󰂛\", \"class\": \"on\", \"tooltip\": \"Do not disturb ($n waiting)\"}"
        else
            echo '{"text": "󰂚", "class": "off", "tooltip": "Notifications on"}'
        fi
        ;;
esac
