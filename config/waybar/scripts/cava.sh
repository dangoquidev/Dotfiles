#!/usr/bin/env bash
# Cava visualizer for waybar, only while Spotify runs.
#   - checks for Spotify once a second (not on every frame)
#   - only ever kills its own cava, never one you run in a terminal

bars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
cava_pid=""

stop_cava() { [[ -n "$cava_pid" ]] && kill "$cava_pid" 2>/dev/null; cava_pid=""; }
trap 'stop_cava; exit 0' SIGPIPE SIGTERM SIGINT EXIT

while true; do
    if ! pgrep -x spotify >/dev/null; then
        echo ""
        sleep 2
        continue
    fi

    exec 3< <(exec cava -p ~/.config/cava/waybar.conf 2>/dev/null)
    cava_pid=$!
    last_check=$SECONDS

    while IFS=';' read -r -a values <&3; do
        if (( SECONDS != last_check )); then
            last_check=$SECONDS
            pgrep -x spotify >/dev/null || break
        fi
        out=""
        for v in "${values[@]}"; do
            [[ -n "$v" ]] && out+="${bars[$v]}"
        done
        echo "$out" || exit 0
    done

    stop_cava
    exec 3<&-
    echo ""
    sleep 1
done
