#!/bin/bash

bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

trap "killall cava 2>/dev/null; exit 0" SIGPIPE SIGTERM SIGINT EXIT

while true; do
    if ! pgrep -x spotify >/dev/null; then
        killall cava 2>/dev/null
        echo ""
        sleep 2
        continue
    fi

    cava -p ~/.config/cava/waybar.conf 2>/dev/null | while IFS=';' read -r -a values; do
        if ! pgrep -x spotify >/dev/null; then
            killall cava 2>/dev/null
            break
        fi

        output=""
        for val in "${values[@]}"; do
            [[ -z "$val" ]] && continue
            output+="${bars[$val]}"
        done
        echo "$output" 2>/dev/null || exit 0
    done

    sleep 1
done
