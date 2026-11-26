#!/usr/bin/env bash
# Night light (hyprsunset) for waybar and SUPER+N
#   nightlight.sh          → JSON status for waybar
#   nightlight.sh toggle   → on/off, then refresh the waybar module (signal 8)

TEMP=4000

state() { [[ "$(hyprctl hyprsunset identity get 2>/dev/null)" == false ]] && echo on || echo off; }

case "${1:-}" in
    toggle)
        if [[ "$(state)" == on ]]; then
            hyprctl hyprsunset identity >/dev/null
        else
            hyprctl hyprsunset temperature "$TEMP" >/dev/null
        fi
        pkill -RTMIN+8 waybar
        ;;
    *)
        if ! pgrep -x hyprsunset >/dev/null; then
            echo '{"text": "", "class": "off", "tooltip": "hyprsunset not running"}'
        elif [[ "$(state)" == on ]]; then
            echo "{\"text\": \"󰖔\", \"class\": \"on\", \"tooltip\": \"Night light on ($(hyprctl hyprsunset temperature) K)\"}"
        else
            echo '{"text": "󰖨", "class": "off", "tooltip": "Night light off"}'
        fi
        ;;
esac
