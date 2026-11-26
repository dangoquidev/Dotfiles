#!/usr/bin/env bash

set -uo pipefail

THEME_FILE="$HOME/.config/rofi/theme.rasi"
SEP=$'\x1f'

ACTION_TOGGLE="󰖪  Toggle Wi-Fi"
ACTION_RESCAN="󰑓  Rescan Networks"
ACTION_DISCONNECT="󰤭  Disconnect Current"
ACTION_HIDDEN="󱛅  Connect Hidden Network"
ACTION_SAVED="󰓹  Saved Networks"
ACTION_FORGET_CURRENT="󰅖  Forget Current Network"

notify() {
    notify-send "WiFi" "$1" -t "${2:-2500}"
}

rofi_cmd_base() {
    local cmd=(rofi -dmenu -i -p "$1")
    if [ -f "$THEME_FILE" ]; then
        cmd+=( -theme "$THEME_FILE" )
    else
        cmd+=( -theme-str 'window {width: 460px;}' )
    fi
    printf '%s\0' "${cmd[@]}"
}

rofi_menu() {
    local prompt="$1"
    local custom="${2:-false}"
    local password="${3:-false}"
    local cmd=()

    while IFS= read -r -d '' item; do
        cmd+=("$item")
    done < <(rofi_cmd_base "$prompt")

    [ "$custom" = "false" ] && cmd+=( -no-custom )
    [ "$password" = "true" ] && cmd+=( -password )

    "${cmd[@]}"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        notify "Missing command: $1" 3500
        exit 1
    }
}

get_iface() {
    nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2 == "wifi" {print $1; exit}'
}

wifi_enabled() {
    [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ]
}

current_ssid() {
    nmcli -t -f ACTIVE,SSID device wifi | awk -F: '$1 == "yes" {print $2; exit}'
}

signal_icon() {
    local signal="$1"
    if [ "$signal" -ge 80 ]; then
        printf '󰤨'
    elif [ "$signal" -ge 60 ]; then
        printf '󰤥'
    elif [ "$signal" -ge 40 ]; then
        printf '󰤢'
    else
        printf '󰤟'
    fi
}

connect_open_or_prompt() {
    local iface="$1"
    local bssid="$2"
    local ssid="$3"

    if nmcli device wifi connect "$bssid" ifname "$iface" >/dev/null 2>&1; then
        notify "Connected to $ssid"
        return 0
    fi

    local pass
    pass=$(rofi_menu "󰌾  Password for $ssid" true true)
    [ -z "$pass" ] && return 1

    if nmcli device wifi connect "$bssid" ifname "$iface" password "$pass" >/dev/null 2>&1; then
        notify "Connected to $ssid"
        return 0
    fi

    notify "Connection failed: $ssid" 3500
    return 1
}

connect_hidden_network() {
    local iface="$1"
    local ssid pass

    ssid=$(rofi_menu "󱛅  Hidden SSID" true false)
    [ -z "$ssid" ] && return

    pass=$(rofi_menu "󰌾  Password (empty = open)" true true)

    if [ -z "$pass" ]; then
        if nmcli device wifi connect "$ssid" ifname "$iface" hidden yes >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to connect hidden network" 3500
        fi
    else
        if nmcli device wifi connect "$ssid" ifname "$iface" password "$pass" hidden yes >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to connect hidden network" 3500
        fi
    fi
}

saved_networks_menu() {
    local entries profile choice
    mapfile -t entries < <(
        nmcli -t -f NAME,UUID,TYPE,AUTOCONNECT connection show | awk -F: '
        $3 == "802-11-wireless" {
            autoconnect = ($4 == "yes") ? "auto:on" : "auto:off"
            print "󰓹  " $1 " [" autoconnect "]" "\t" $2 "\t" $4
        }'
    )

    if [ "${#entries[@]}" -eq 0 ]; then
        notify "No saved Wi-Fi profiles"
        return
    fi

    local display=()
    local uuids=()
    for profile in "${entries[@]}"; do
        display+=("${profile%%$'\t'*}")
        profile="${profile#*$'\t'}"
        uuids+=("${profile%%$'\t'*}")
    done

    choice=$(printf '%s\n' "${display[@]}" | rofi_menu "󰓹  Saved Wi-Fi" false false)
    [ -z "$choice" ] && return

    local idx=-1
    local i
    for i in "${!display[@]}"; do
        if [ "${display[$i]}" = "$choice" ]; then
            idx="$i"
            break
        fi
    done

    [ "$idx" -lt 0 ] && return

    local uuid="${uuids[$idx]}"
    local name
    name=$(nmcli -g connection.id connection show "$uuid" 2>/dev/null)
    [ -z "$name" ] && return

    local action
    action=$(printf '%s\n' "󰓛  Connect" "󰅖  Forget" "󰯄  Toggle Autoconnect" | rofi_menu "$name" false false)
    [ -z "$action" ] && return

    case "$action" in
        *"Connect"*)
            if nmcli connection up "$uuid" >/dev/null 2>&1; then
                notify "Connected profile: $name"
            else
                notify "Failed to connect profile: $name" 3500
            fi
            ;;
        *"Forget"*)
            if nmcli connection delete "$uuid" >/dev/null 2>&1; then
                notify "Deleted profile: $name"
            else
                notify "Failed to delete profile: $name" 3500
            fi
            ;;
        *"Toggle Autoconnect"*)
            local current
            current=$(nmcli -g connection.autoconnect connection show "$uuid" 2>/dev/null)
            if [ "$current" = "yes" ]; then
                nmcli connection modify "$uuid" connection.autoconnect no >/dev/null 2>&1 && notify "Autoconnect OFF: $name"
            else
                nmcli connection modify "$uuid" connection.autoconnect yes >/dev/null 2>&1 && notify "Autoconnect ON: $name"
            fi
            ;;
    esac
}

build_network_menu() {
    local iface="$1"
    local raw=()
    local menu_lines=()
    local map_lines=()
    local line safe inuse bssid ssid signal security icon lock active hidden short_bssid

    mapfile -t raw < <(nmcli -t -f IN-USE,BSSID,SSID,SIGNAL,SECURITY device wifi list ifname "$iface")

    for line in "${raw[@]}"; do
        safe="${line//\\:/$SEP}"
        IFS=':' read -r inuse bssid ssid signal security <<< "$safe"

        bssid="${bssid//$SEP/:}"
        ssid="${ssid//$SEP/:}"
        signal="${signal//$SEP/:}"
        security="${security//$SEP/:}"

        [ -z "$bssid" ] && continue

        if [ -z "$ssid" ]; then
            hidden="[hidden]"
            ssid="$hidden"
        fi

        icon=$(signal_icon "${signal:-0}")
        lock=""
        active=""
        short_bssid="${bssid##*:}"

        [ -n "$security" ] && [ "$security" != "--" ] && lock=" 󰌾"
        [ "$inuse" = "*" ] && active=" ✓"

        menu_lines+=("$icon  $ssid$lock$active  [$signal%] [$short_bssid]")
        map_lines+=("$bssid$SEP$ssid")
    done

    printf '%s\n' \
        "$ACTION_TOGGLE" \
        "$ACTION_RESCAN" \
        "$ACTION_DISCONNECT" \
        "$ACTION_HIDDEN" \
        "$ACTION_SAVED" \
        "$ACTION_FORGET_CURRENT"

    [ "${#menu_lines[@]}" -gt 0 ] && printf '%s\n' "${menu_lines[@]}"

    printf '\n__MAP__\n'
    [ "${#map_lines[@]}" -gt 0 ] && printf '%s\n' "${map_lines[@]}"
}

forget_current_network() {
    local current="$1"
    [ -z "$current" ] && {
        notify "No active network"
        return
    }

    if nmcli connection delete "$current" >/dev/null 2>&1; then
        notify "Forgot current network: $current"
    else
        notify "Could not forget network: $current" 3500
    fi
}

main() {
    require_cmd nmcli
    require_cmd rofi
    require_cmd notify-send

    local iface
    iface=$(get_iface)

    if [ -z "$iface" ]; then
        notify "No Wi-Fi interface found" 3500
        exit 1
    fi

    local current radio_state prompt choice menu_blob menu_entries map_entries
    current=$(current_ssid)
    radio_state="OFF"
    wifi_enabled && radio_state="ON"
    prompt="󰤨  Wi-Fi ($radio_state)"

    menu_blob=$(build_network_menu "$iface")
    menu_entries=$(printf '%s\n' "$menu_blob" | sed '/^__MAP__$/,$d')
    map_entries=$(printf '%s\n' "$menu_blob" | sed -n '/^__MAP__$/,$p' | sed '1d')

    choice=$(printf '%s\n' "$menu_entries" | sed '/^$/d' | rofi_menu "$prompt" false false)
    [ -z "$choice" ] && exit 0

    case "$choice" in
        "$ACTION_TOGGLE")
            if wifi_enabled; then
                nmcli radio wifi off >/dev/null 2>&1 && notify "Wi-Fi turned OFF"
            else
                nmcli radio wifi on >/dev/null 2>&1 && notify "Wi-Fi turned ON"
            fi
            exit 0
            ;;
        "$ACTION_RESCAN")
            nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1 && notify "Scanning networks..."
            exit 0
            ;;
        "$ACTION_DISCONNECT")
            nmcli device disconnect "$iface" >/dev/null 2>&1 && notify "Disconnected"
            exit 0
            ;;
        "$ACTION_HIDDEN")
            connect_hidden_network "$iface"
            exit 0
            ;;
        "$ACTION_SAVED")
            saved_networks_menu
            exit 0
            ;;
        "$ACTION_FORGET_CURRENT")
            forget_current_network "$current"
            exit 0
            ;;
    esac

    local selected_map=""
    local map_line bssid ssid
    while IFS= read -r map_line; do
        [ -z "$map_line" ] && continue
        bssid="${map_line%%$SEP*}"
        ssid="${map_line#*$SEP}"
        local short_bssid="${bssid##*:}"

        if printf '%s' "$choice" | grep -q "\[$short_bssid\]$"; then
            if [ "$ssid" = "[hidden]" ]; then
                connect_hidden_network "$iface"
            else
                connect_open_or_prompt "$iface" "$bssid" "$ssid"
            fi
            selected_map="1"
            break
        fi
    done <<< "$map_entries"

    [ -z "$selected_map" ] && notify "No action executed" 1800
}

main "$@"
