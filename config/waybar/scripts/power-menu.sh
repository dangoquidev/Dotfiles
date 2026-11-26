#!/usr/bin/env bash
# Rofi power menu for waybar / SUPER+Escape
#   - fullscreen, blurred backdrop (layer rule on the "rofi" namespace in windowrules.lua)
#   - first click opens the menu, a second click closes it
#   - runs as a rofi *script mode*: rofi stays on screen while an action starts,
#     so there is never a frame of bare desktop between the menu and the result:
#       lock / suspend → the menu closes only once hyprlock holds the session
#       log out / reboot / shut down / UEFI → confirmed in place (no close/reopen),
#                                       then the menu stays up until the session dies

set -uo pipefail

THEME="$HOME/.config/rofi/power.rasi"
SELF="$(realpath "$0")"

# ---------------------------------------------------------------------------
# Launcher (called by waybar / keybind): rofi is not running us yet
# ---------------------------------------------------------------------------
if [[ -z "${ROFI_RETV:-}" ]]; then
    # Toggle: a second click closes whatever rofi menu is open
    if pgrep -x rofi >/dev/null; then
        pkill -x rofi
        exit 0
    fi

    # Instant open/close (see PowerMenuNoAnim in windowrules.lua); restored on exit
    no_anim() { hyprctl eval "PowerMenuNoAnim:set_enabled($1)" >/dev/null 2>&1; }
    no_anim true
    trap 'no_anim false' EXIT

    rofi -show power -modi "power:$SELF" -theme "$THEME" -eh 2
    exit 0
fi

# ---------------------------------------------------------------------------
# Script mode (called by rofi): print rows, or act on the selected row
# ---------------------------------------------------------------------------
opt()   { printf '\0%s\x1f%s\n' "$1" "$2"; }                    # rofi mode option
entry() { printf '%s\n<span size="38%%">%s</span>\0info\x1f%s|' "$1" "$2" "$3"; }  # icon label id

can_firmware() {  # firmware supports "reboot into UEFI setup"
    [[ "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager CanRebootToFirmwareSetup 2>/dev/null)" == 's "yes"' ]]
}

main_menu() {
    local cols=5; can_firmware && cols=6
    opt prompt "Up $(uptime -p | sed 's/^up //')"
    opt theme "listview { columns: $cols; }"
    opt markup-rows true
    opt no-custom true
    opt delim '|'
    entry "󰌾" "Lock"      lock
    entry "󰤄" "Suspend"   suspend
    entry "󰍃" "Log out"   ask:logout
    entry "󰜉" "Reboot"    ask:reboot
    entry "󰐥" "Shut down" ask:poweroff
    if (( cols == 6 )); then entry "󰒓" "UEFI" ask:firmware; fi
}

confirm_menu() {  # confirm_menu <action> <question> — "No" preselected
    opt prompt "$2"
    opt theme "listview { columns: 2; }"
    opt markup-rows true
    opt no-custom true
    opt keep-selection true
    opt new-selection 1
    opt delim '|'
    entry "󰄬" "Yes" "do:$1"
    entry "󰜺" "No"  back
}

lock_and_wait() {  # start hyprlock and return once the session is actually locked
    pgrep -x hyprlock >/dev/null && return 0
    local log="${XDG_RUNTIME_DIR:-/tmp}/power-menu-hyprlock.log"
    : >"$log"
    setsid -f hyprlock --verbose --no-fade-in >"$log" 2>&1 </dev/null
    for _ in $(seq 200); do                      # up to ~2s
        grep -q 'onLockLocked' "$log" 2>/dev/null && return 0
        sleep 0.01
    done
}

logout() {  # same behaviour as SUPER+M
    if command -v hyprshutdown >/dev/null 2>&1; then
        hyprshutdown
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

hold() { sleep 15; }  # keep the menu on screen while the session goes down

case "${ROFI_RETV}:${ROFI_INFO:-}" in
    0:*)            main_menu ;;
    1:lock)         lock_and_wait ;;
    1:suspend)      lock_and_wait; systemctl suspend ;;
    1:ask:logout)   confirm_menu logout   "Log out?" ;;
    1:ask:reboot)   confirm_menu reboot   "Reboot?" ;;
    1:ask:poweroff) confirm_menu poweroff "Shut down?" ;;
    1:ask:firmware) confirm_menu firmware "Reboot into UEFI setup?" ;;
    1:do:logout)    logout;              hold ;;
    1:do:reboot)    systemctl reboot;    hold ;;
    1:do:poweroff)  systemctl poweroff;  hold ;;
    1:do:firmware)  systemctl reboot --firmware-setup; hold ;;
    1:back)         main_menu ;;
esac
# printing nothing closes rofi
