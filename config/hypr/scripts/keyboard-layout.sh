#!/usr/bin/env bash
# SUPER+Space — cycle English (US intl) → Français (AZERTY) → 中文 (Pinyin)
# fcitx5 switches the input method (pinyin: type, Space picks the candidate);
# Hyprland's xkb layout follows (index into kb_layout "us,fr" in input.lua)
# so apps that bypass the input method get the same keyboard.
# Without fcitx5 installed it only toggles US intl ↔ AZERTY.

set -uo pipefail

ims=(keyboard-us-intl keyboard-fr pinyin)
labels=("English (US intl)" "Français (AZERTY)" "中文 (Pinyin)")
xkb=(0 1 0)

# show the new keyboard in the Quickshell OSD pill (config/quickshell/shell/Osd.qml),
# dunst notification if Quickshell isn't running
notify() {
    quickshell -c shell ipc call osd keyboard "$1" >/dev/null 2>&1 && return
    notify-send -a Keyboard -u low -t 1500 -i input-keyboard-symbolic \
        -h string:x-dunst-stack-tag:keyboard "Clavier actuel : $1" "${2:-}"
}

# active xkb layout index of the main keyboard
xkb_index() {
    hyprctl devices | awk '/active layout index:/ { i = $NF } /main: yes/ { print i; exit }'
}

if command -v fcitx5 >/dev/null; then
    if ! fcitx5-remote >/dev/null 2>&1; then
        fcitx5 -d --replace
        for _ in {1..20}; do fcitx5-remote >/dev/null 2>&1 && break; sleep 0.1; done
    fi
    cur=$(fcitx5-remote -n 2>/dev/null)
    i=0
    for k in "${!ims[@]}"; do [[ ${ims[k]} == "$cur" ]] && i=$k; done
    next=$(( (i + 1) % ${#ims[@]} ))
    fcitx5-remote -s "${ims[next]}"
    hyprctl switchxkblayout all "${xkb[next]}" >/dev/null
    notify "${labels[next]}"
else
    cur=$(xkb_index)
    next=$(( ${cur:-0} == 0 ? 1 : 0 ))
    hyprctl switchxkblayout all "$next" >/dev/null
    notify "${labels[next]}" "fcitx5 absent : pas de pinyin"
fi
