#!/usr/bin/env bash
# Low battery alerts (started by autostart.lua), checked every minute:
#   ≤ 15 % → warning   ≤ 5 % → critical (stays on screen)
# Each alert fires once per discharge; plugging the charger resets them.

set -uo pipefail

LOW=15
CRITICAL=5

bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
[[ -n "$bat" ]] || exit 0   # no battery (desktop)

# only one instance
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/battery-notify.lock"
flock -n 9 || exit 0

notified=""   # "", "low" or "critical"

while true; do
    cap=$(<"$bat/capacity")
    status=$(<"$bat/status")

    if [[ "$status" != "Discharging" ]]; then
        notified=""
    elif (( cap <= CRITICAL )) && [[ "$notified" != critical ]]; then
        notify-send -a Battery -u critical -i battery-empty-symbolic \
            -h string:x-dunst-stack-tag:battery "Battery critical: ${cap}%" "Plug in the charger now"
        notified=critical
    elif (( cap <= LOW )) && [[ -z "$notified" ]]; then
        notify-send -a Battery -u normal -i battery-caution-symbolic \
            -h string:x-dunst-stack-tag:battery "Battery low: ${cap}%" "Consider plugging in the charger"
        notified=low
    fi

    sleep 60 9>&-   # don't let sleep inherit the lock
done
