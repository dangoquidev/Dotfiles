#!/usr/bin/env bash
# cliphist helper for the Quickshell clipboard panel (ClipboardPanel.qml)
#   clipboard.sh list           newest first, one entry per line: <kind>\t<id>\t<text or image preview path>
#   clipboard.sh copy <id>      put that entry back on the clipboard
#   clipboard.sh delete <id>    remove it from the history
#   clipboard.sh wipe           clear the whole history
#
# Image previews are decoded once into $XDG_RUNTIME_DIR (RAM, gone at reboot), max 360px wide.

set -uo pipefail

MAX=150
CACHE="${XDG_RUNTIME_DIR:-/tmp}/qs-clipboard"

case "${1:-list}" in
    list)
        mkdir -p "$CACHE"
        cliphist list | head -n "$MAX" | while IFS=$'\t' read -r id preview; do
            if [[ "$preview" == "[[ binary data"* ]]; then
                thumb="$CACHE/$id.jpg"
                if [[ ! -f "$thumb" ]]; then
                    cliphist decode "$id" >"$CACHE/$id.raw" 2>/dev/null
                    VIPS_WARNING=0 vipsthumbnail "$CACHE/$id.raw" -s 360x240 -o "$thumb[Q=85,strip]" 2>/dev/null
                    rm -f "$CACHE/$id.raw"
                fi
                if [[ -f "$thumb" ]]; then
                    printf 'image\t%s\t%s\n' "$id" "$thumb"
                else
                    printf 'text\t%s\t%s\n' "$id" "$preview"   # not an image vips can read
                fi
            else
                printf 'text\t%s\t%s\n' "$id" "$preview"
            fi
        done
        ;;
    copy)
        cliphist decode "$2" | wl-copy
        ;;
    delete)
        cliphist list | awk -F'\t' -v id="$2" '$1 == id' | cliphist delete
        rm -f "$CACHE/$2.jpg"
        ;;
    wipe)
        cliphist wipe
        rm -rf "$CACHE"
        ;;
esac
