#!/bin/bash

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
BACKUP_DIR="$DOTFILES_DIR/backups"
TARGET_DIR="$HOME/.config"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}--- Restoring configurations ---${NC}"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}No backup folder found ($BACKUP_DIR).${NC}"
    exit 0
fi

for backup_path in "$BACKUP_DIR"/*.bak; do
    [ -e "$backup_path" ] || continue

    filename=$(basename "$backup_path")
    folder_name="${filename%.bak}"
    DEST="$TARGET_DIR/$folder_name"

    echo -e "${BLUE}Restoring: $folder_name${NC}"

    if [ -L "$DEST" ]; then
        echo -e "  -> Removing dotfiles symlink"
        rm "$DEST"
    fi

    if [ -d "$backup_path" ]; then
        echo -e "  -> Restoring original folder"
        mv "$backup_path" "$DEST"
    fi
done

if [ -z "$(ls -A "$BACKUP_DIR")" ]; then
   rm -rf "$BACKUP_DIR"
   echo -e "${GREEN}Backup folder deleted (empty).${NC}"
else
   echo -e "${RED}Backup folder is not empty, some files were not restored.${NC}"
fi