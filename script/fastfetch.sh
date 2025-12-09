#!/bin/bash

# NOTE : Ce script est prévu pour être lancé par install.sh
# Il hérite des variables $DOTFILES_DIR et des couleurs.

TARGET_DIR="$HOME/.config"
SOURCE_FOLDER="fastfetch"

install_pkg() {
    echo -e "   [Info] Fastfetch non trouvé. Installation..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            arch|manjaro|endeavouros)
                sudo pacman -S --noconfirm fastfetch ;;
            fedora)
                sudo dnf install -y fastfetch ;;
            ubuntu|debian|pop|linuxmint|kali)
                if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
                     sudo add-apt-repository -y ppa:zhangjianfeng/fastfetch
                     sudo apt update
                fi
                sudo apt install -y fastfetch ;;
            opensuse*|suse)
                sudo zypper install -y fastfetch ;;
            *)
                echo -e "${RED}   [Erreur] Distro non gérée auto. Installe fastfetch manuellement.${NC}"
                exit 1 ;;
        esac
    else
        echo -e "${RED}   [Erreur] Impossible de détecter l'OS.${NC}"
        exit 1
    fi
}

# --- 2. Vérification présence binaire ---
if ! command -v fastfetch &> /dev/null; then
    install_pkg
else
    echo -e "   [Skip] Fastfetch est déjà installé."
fi

# --- 3. Configuration (Symlink) ---
mkdir -p "$TARGET_DIR"

# Chemin vers la config dans ton repo git
REPO_CONFIG="$DOTFILES_DIR/.config/$SOURCE_FOLDER"
# Chemin vers la config sur le PC
PC_CONFIG="$TARGET_DIR/$SOURCE_FOLDER"

# Vérification liens existants
if [ -d "$PC_CONFIG" ] || [ -L "$PC_CONFIG" ]; then
    CURRENT_LINK=$(readlink -f "$PC_CONFIG")
    
    if [ "$CURRENT_LINK" == "$REPO_CONFIG" ]; then
        echo -e "   [Skip] Lien symbolique déjà correct."
        exit 0
    fi

    echo -e "   [Backup] Sauvegarde de l'ancienne config vers .bak"
    rm -rf "${PC_CONFIG}.bak"
    mv "$PC_CONFIG" "${PC_CONFIG}.bak"
fi

# Création du lien
echo -e "   [Link] Création du lien symbolique..."
ln -s "$REPO_CONFIG" "$PC_CONFIG"

if [ -L "$PC_CONFIG" ]; then
    echo -e "   [OK] Configuration Fastfetch terminée."
else
    echo -e "${RED}   [Erreur] Échec du lien symbolique.${NC}"
    exit 1
fi