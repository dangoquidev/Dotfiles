#!/usr/bin/env bash
# Rofi Wi-Fi menu for waybar (NetworkManager / nmcli)
#   - first click opens the menu, a second click closes it
#   - networks deduplicated by SSID (best signal), active network first
#   - connects by SSID (not BSSID) so roaming between APs / bands keeps working

set -uo pipefail

THEME="$HOME/.config/rofi/theme.rasi"

# --- helpers ----------------------------------------------------------------

notify() {  # notify <message> [urgency] — replaces the previous wifi notification (dunst)
    notify-send -a "Wi-Fi" -u "${2:-low}" -h string:x-dunst-stack-tag:wifi-menu "Wi-Fi" "$1"
}

rofi_list() {  # rofi_list <prompt> — reads lines on stdin, prints the selected index
    local args=(-dmenu -i -no-custom -format i -p "$1")
    [[ -f "$THEME" ]] && args+=(-theme "$THEME")
    rofi "${args[@]}"
}

rofi_input() {  # rofi_input <prompt> [password] — prints the typed text
    local args=(-dmenu -p "$1" -theme-str 'listview { enabled: false; }')
    [[ -f "$THEME" ]] && args=(-theme "$THEME" "${args[@]}")
    [[ "${2:-}" == password ]] && args+=(-password)
    rofi "${args[@]}" </dev/null
}

nm_unescape() {  # unescape an `nmcli -t` field (\: and \\)
    local s="${1//\\\\/$'\x01'}"
    s="${s//\\:/:}"
    printf '%s' "${s//$'\x01'/\\}"
}

nm_error() {  # extract the useful part of an nmcli error output
    sed -n 's/^Error: //p' <<<"$1" | head -n1 | cut -c1-160
}

signal_icon() {
    local s="${1:-0}"
    [[ "$s" =~ ^[0-9]+$ ]] || s=0
    if   (( s >= 75 )); then printf '󰤨'
    elif (( s >= 50 )); then printf '󰤥'
    elif (( s >= 25 )); then printf '󰤢'
    else                     printf '󰤟'
    fi
}

# --- NetworkManager state ---------------------------------------------------

get_iface() {
    nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == "wifi" { print $1; exit }'
}

wifi_enabled() { [[ "$(nmcli radio wifi 2>/dev/null)" == enabled ]]; }

active_uuid() {  # UUID of the active connection on the interface ("" if none)
    nmcli -g GENERAL.CON-UUID device show "$IFACE" 2>/dev/null
}

saved_uuid_for_ssid() {  # UUID of the most recently used profile for an SSID ("" if none)
    local ssid="$1" uuid type ts best="" best_ts=-1
    while IFS=: read -r uuid type ts; do
        [[ "$type" == 802-11-wireless ]] || continue
        [[ "$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)" == "$ssid" ]] || continue
        (( ts > best_ts )) && { best="$uuid"; best_ts="$ts"; }
    done < <(nmcli -t -f UUID,TYPE,TIMESTAMP connection show)
    printf '%s' "$best"
}

forget_ssid() {  # forget_ssid <ssid> — remove every trace of a network
    local ssid="$1" uuid type n=0
    [[ -z "$ssid" ]] && return
    # every NM profile for this SSID (there can be duplicates: "SSID 1", "SSID 2"…)
    while IFS=: read -r uuid type; do
        [[ "$type" == 802-11-wireless ]] || continue
        [[ "$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)" == "$ssid" ]] || continue
        nmcli connection delete uuid "$uuid" >/dev/null 2>&1 && n=$((n + 1))
    done < <(nmcli -t -f UUID,TYPE connection show)

    # with the iwd backend, iwd keeps its own copy of the password in /var/lib/iwd:
    # without this, the network reconnects later without asking for the password
    if command -v iwctl >/dev/null; then
        iwctl known-networks "$ssid" forget >/dev/null 2>&1 && n=$((n + 1))
    fi

    if (( n )); then notify "Forgot $ssid"; else notify "Could not forget $ssid" critical; fi
}

activate() {  # activate <uuid> <name> — bring a saved profile up, return nmcli's status
    local out
    notify "Connecting to $2…"
    if out="$(nmcli --wait 30 connection up uuid "$1" 2>&1)"; then
        notify "Connected to $2"
    else
        notify "Failed: $(nm_error "$out")" critical
        return 1
    fi
}

# --- actions ----------------------------------------------------------------

connect_ssid() {  # connect_ssid <ssid> <security>
    local ssid="$1" security="$2" uuid out pass

    # 1. saved profile → just bring it up
    uuid="$(saved_uuid_for_ssid "$ssid")"
    if [[ -n "$uuid" ]]; then
        activate "$uuid" "$ssid" && return
        # most likely the password changed → ask for the new one
        [[ -z "$security" ]] && return
        pass="$(rofi_input "󰌾  New password ($ssid)" password)" || return
        [[ -z "$pass" ]] && return
        nmcli connection modify uuid "$uuid" wifi-sec.psk "$pass" >/dev/null 2>&1
        activate "$uuid" "$ssid"
        return
    fi

    # 2. new network
    local args=(--wait 30 device wifi connect "$ssid" ifname "$IFACE")
    if [[ -n "$security" ]]; then
        pass="$(rofi_input "󰌾  Password ($ssid)" password)" || return
        [[ -z "$pass" ]] && return
        args+=(password "$pass")
    fi

    notify "Connecting to $ssid…"
    if out="$(nmcli "${args[@]}" 2>&1)"; then
        notify "Connected to $ssid"
    else
        # don't leave a broken profile behind (otherwise: "SSID 1", "SSID 2"… duplicates)
        uuid="$(saved_uuid_for_ssid "$ssid")"
        [[ -n "$uuid" ]] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1
        notify "Failed: $(nm_error "$out")" critical
    fi
}

connect_hidden() {
    local ssid pass out args
    ssid="$(rofi_input "󱛅  Hidden SSID")" || return
    [[ -z "$ssid" ]] && return
    pass="$(rofi_input "󰌾  Password (empty = open)" password)" || return

    args=(--wait 30 device wifi connect "$ssid" ifname "$IFACE" hidden yes)
    [[ -n "$pass" ]] && args+=(password "$pass")

    notify "Connecting to $ssid…"
    if out="$(nmcli "${args[@]}" 2>&1)"; then
        notify "Connected to $ssid"
    else
        notify "Failed: $(nm_error "$out")" critical
    fi
}

saved_menu() {
    local uuids=() names=() lines=() uuid type auto name active idx
    active="$(active_uuid)"

    while IFS=: read -r uuid type auto name; do
        [[ "$type" == 802-11-wireless ]] || continue
        name="$(nm_unescape "$name")"
        uuids+=("$uuid"); names+=("$name")
        local mark="" autostr="auto"
        [[ "$uuid" == "$active" ]] && mark="  ✓"
        [[ "$auto" == yes ]] || autostr="manual"
        lines+=("󰓹  $name$mark  [$autostr]")
    done < <(nmcli -t -f UUID,TYPE,AUTOCONNECT,NAME connection show)

    (( ${#lines[@]} )) || { notify "No saved networks"; return; }

    idx="$(printf '%s\n' "${lines[@]}" | rofi_list "󰓹  Saved networks")" || return
    [[ -z "$idx" ]] && return
    uuid="${uuids[$idx]}"; name="${names[$idx]}"

    local actions=("󰖩  Connect" "󰯄  Toggle autoconnect" "󰅖  Forget")
    idx="$(printf '%s\n' "${actions[@]}" | rofi_list "$name")" || return
    case "$idx" in
        0)  activate "$uuid" "$name" ;;
        1)  if [[ "$(nmcli -g connection.autoconnect connection show uuid "$uuid")" == yes ]]; then
                nmcli connection modify uuid "$uuid" connection.autoconnect no && notify "Autoconnect off: $name"
            else
                nmcli connection modify uuid "$uuid" connection.autoconnect yes && notify "Autoconnect on: $name"
            fi ;;
        2)  forget_ssid "$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)" ;;
    esac
}

# --- main menu --------------------------------------------------------------

main_menu() {  # main_menu [rescan]
    local rescan="${1:-no}"

    if ! wifi_enabled; then
        local idx
        idx="$(printf '%s\n' "󰖩  Enable Wi-Fi" | rofi_list "󰖪  Wi-Fi off")" || return
        [[ "$idx" == 0 ]] && nmcli radio wifi on && notify "Wi-Fi enabled"
        return
    fi

    # scan: IN-USE,SIGNAL,SECURITY,SSID — SSID last because it can contain ':'
    declare -A best_signal=() best_sec=() in_use=()
    local inuse signal security ssid
    while IFS=: read -r inuse signal security ssid; do
        ssid="$(nm_unescape "$ssid")"
        [[ -z "$ssid" ]] && continue            # hidden networks → dedicated action
        [[ "$security" == "--" ]] && security=""
        [[ "$inuse" == "*" ]] && in_use[$ssid]=1
        if (( signal > ${best_signal[$ssid]:--1} )); then
            best_signal[$ssid]="$signal"; best_sec[$ssid]="$security"
        fi
    done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list ifname "$IFACE" --rescan "$rescan" 2>/dev/null)

    # sort: active network first, then by signal strength
    local ssids=() lines=()
    while IFS=$'\t' read -r _ _ ssid; do
        ssids+=("$ssid")
        local lock="" mark=""
        [[ -n "${best_sec[$ssid]}" ]] && lock="  󰌾"
        [[ -n "${in_use[$ssid]:-}" ]] && mark="  ✓"
        lines+=("$(signal_icon "${best_signal[$ssid]}")  $ssid$lock$mark")
    done < <(for s in "${!best_signal[@]}"; do
                 printf '%s\t%s\t%s\n' "${in_use[$s]:-0}" "${best_signal[$s]}" "$s"
             done | sort -t$'\t' -k1,1nr -k2,2nr)

    # actions (below the networks)
    local actions=("󰑓  Rescan")
    [[ -n "$(active_uuid)" ]] && actions+=("󰤭  Disconnect" "󰅖  Forget current network")
    actions+=("󰓹  Saved networks" "󱛅  Hidden network…" "󰖪  Disable Wi-Fi")

    local idx
    idx="$(printf '%s\n' "${lines[@]}" "${actions[@]}" | rofi_list "󰤨  Wi-Fi")" || return
    [[ -z "$idx" ]] && return

    if (( idx < ${#ssids[@]} )); then
        ssid="${ssids[$idx]}"
        if [[ -n "${in_use[$ssid]:-}" ]]; then
            notify "Already connected to $ssid"
        else
            connect_ssid "$ssid" "${best_sec[$ssid]}"
        fi
        return
    fi

    case "${actions[$(( idx - ${#ssids[@]} ))]}" in
        *Rescan*)          notify "Scanning…"; main_menu yes ;;
        *Disconnect*)      nmcli device disconnect "$IFACE" >/dev/null 2>&1 && notify "Disconnected" ;;
        *Forget*)          forget_ssid "$(nmcli -g 802-11-wireless.ssid connection show uuid "$(active_uuid)" 2>/dev/null)" ;;
        *Saved*)           saved_menu ;;
        *Hidden*)          connect_hidden ;;
        *Disable*)         nmcli radio wifi off && notify "Wi-Fi disabled" ;;
    esac
}

# --- main -------------------------------------------------------------------

# second click on the waybar module → close the menu that is already open
if pgrep -x rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

for cmd in nmcli rofi notify-send; do
    command -v "$cmd" >/dev/null || { notify-send "Wi-Fi" "Missing command: $cmd" 2>/dev/null; exit 1; }
done

IFACE="$(get_iface)"
[[ -z "$IFACE" ]] && { notify "No Wi-Fi interface found" critical; exit 1; }

main_menu
