#!/bin/bash

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CONFIG_SRC="$DOTFILES_DIR/config"
BACKUP_DIR="$DOTFILES_DIR/backups"
DEFAULT_TARGET_DIR="$HOME/.config"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

install_if_missing() {
    if ! pacman -Qs "$1" > /dev/null; then
        echo -e "${YELLOW}>>> Missing package: $1. Installing...${NC}"
        yay -S --noconfirm "$1"
    else
        echo -e "${GREEN}>>> $1 is already installed.${NC}"
    fi
}

mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}--- Processing configurations ---${NC}"

for folder in "$@"; do
    SRC="$CONFIG_SRC/$folder"
    DEST="$DEFAULT_TARGET_DIR/$folder"
    SKIP_SYMLINK=false

    echo -e "\n${BLUE}### Processing: $folder ###${NC}"

    case "$folder" in
        "fish")
            echo -e "${YELLOW}>>> Finalizing Fish...${NC}"
            
            # On vérifie si fish est installé pour lancer les commandes
            if command -v fish &> /dev/null; then
                # Installation de Fisher (le plugin manager) s'il n'est pas là
                # On lance un shell fish temporaire pour exécuter l'installation
                echo -e "  -> Installation de Fisher et des plugins..."
                
                fish -c '
                if not functions -q fisher
                    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
                end
                
                # Une fois fisher installé, on force la mise à jour des plugins
                # Cela va lire le fichier ~/.config/fish/fish_plugins (qu on vient de symlink)
                # et installer Tide automatiquement.
                fisher update
                '
                
                echo -e "${GREEN}>>> Fish, Fisher et Tide sont prêts !${NC}"
            fi
            ;;
        
        "themes")
            echo -e "${YELLOW}>>> Detecting Vesktop configuration (themes)${NC}"
            
            install_if_missing "vesktop-bin"
            
            DEST="$HOME/.config/vesktop/themes"
            
            mkdir -p "$HOME/.config/vesktop"
            ;;

        "spicetify")
            echo -e "${YELLOW}>>> Detecting Spicetify configuration${NC}"

            install_if_missing "spotify"
            install_if_missing "spicetify-cli"

            echo -e "${YELLOW}>>> Applying permissions for Spicetify...${NC}"
            sudo chmod a+wr /opt/spotify
            sudo chmod a+wr /opt/spotify/Apps -R

            ;;
            
        *)
            ;;
    esac

    if [ ! -d "$SRC" ]; then
        echo -e "${RED}Error: Source folder '$SRC' not found.${NC}"
        continue
    fi

    echo -e "${YELLOW}>>> Setting up links to: $DEST${NC}"

    BACKUP="$BACKUP_DIR/$(basename "$DEST").bak"
    
    if [ -d "$DEST" ] && [ ! -L "$DEST" ]; then
        echo -e "  -> Backing up existing to $BACKUP"
        rm -rf "$BACKUP"
        mv "$DEST" "$BACKUP"
    elif [ -L "$DEST" ]; then
        echo -e "  -> Removing old symbolic link"
        rm "$DEST"
    fi

    ln -s "$SRC" "$DEST"
    echo -e "${GREEN}  -> Link created successfully.${NC}"

    case "$folder" in
        "spicetify")
            echo -e "${YELLOW}>>> Applying Spicetify theme...${NC}"
            
            spicetify config current_theme System24
            spicetify config color_scheme base
            spicetify config inject_css 1 replace_colors 1 overwrite_assets 1
            
            if spicetify apply; then
                echo -e "${GREEN}>>> Spicetify patched successfully!${NC}"
            else
                echo -e "${RED}>>> Error during 'spicetify apply'. Try running 'spicetify backup apply' manually.${NC}"
                spicetify backup apply
            fi
            ;;
    esac

done

echo -e "${BLUE}--- Configuration completed ---${NC}"