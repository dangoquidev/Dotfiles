#!/bin/bash

export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_SRC="$DOTFILES_DIR/config"
SCRIPT_DIR="$DOTFILES_DIR/script"
BACKUP_DIR="$DOTFILES_DIR/backups"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if ! command -v whiptail &> /dev/null; then
    echo -e "${RED}Error: whiptail is not installed.${NC}"
    echo "Install it with: sudo pacman -S newt (or apt install whiptail)"
    exit 1
fi

CHOICE=$(whiptail --title "Dotfiles Manager" --menu "What do you want to do?" 15 60 2 \
"1" "Install configurations" \
"2" "Uninstall and restore backups" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus != 0 ]; then exit 0; fi

if [ "$CHOICE" = "1" ]; then

    OPTIONS=()
    while IFS= read -r folder; do
        OPTIONS+=("$folder" "Config" "OFF")
    done < <(find "$CONFIG_SRC" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

    SELECTED_CONFIGS=$(whiptail --title "Config Selection" --checklist \
    "Check with SPACE, confirm with ENTER" 20 78 10 \
    "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    echo -e "${BLUE}>>> Starting installation...${NC}"

    SELECTED_CONFIGS="${SELECTED_CONFIGS//\"/}"

    if [ ! -z "$SELECTED_CONFIGS" ]; then
        bash "$SCRIPT_DIR/install.sh" $SELECTED_CONFIGS
    else
        echo -e "${RED}No configuration selected.${NC}"
    fi

elif [ "$CHOICE" = "2" ]; then
    if (whiptail --title "Restoration" --yesno "This will remove symlinks and restore backups. Continue?" 10 60); then
        bash "$SCRIPT_DIR/uninstall.sh"
    fi
fi

echo -e "${GREEN}>>> Operations completed!${NC}"