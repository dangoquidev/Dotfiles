#!/bin/bash

# --- 1. Variables Globales (accessibles par les sous-scripts) ---
# On définit le chemin racine du repo et on l'exporte pour que 
# les scripts dans /script puissent l'utiliser sans le recalculer.
export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_DIR="$DOTFILES_DIR/script"

# --- Couleurs ---
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

echo -e "${BLUE}#################################${NC}"
echo -e "${BLUE}###     Installing dotfiles   ###${NC}"
echo -e "${BLUE}#################################${NC}"
echo -e "Dossier racine détecté : $DOTFILES_DIR\n"

# --- 2. Exécution des scripts modulaires ---

if [ -d "$SCRIPT_DIR" ]; then
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            SCRIPT_NAME=$(basename "$script")
            echo -e "${YELLOW}>>> Lancement du script : $SCRIPT_NAME ${NC}"
            
            chmod +x "$script"
            
            "$script"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}>>> $SCRIPT_NAME terminé avec succès.${NC}\n"
            else
                echo -e "${RED}>>> Erreur lors de l'exécution de $SCRIPT_NAME.${NC}\n"
            fi
        fi
    done
else
    echo -e "${RED}Erreur : Le dossier 'script' est introuvable.${NC}"
fi

echo -e "${BLUE}Installation terminée !${NC}"