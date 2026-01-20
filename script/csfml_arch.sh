#!/bin/bash

# =============================================================================
#  SFML 2.6.1 + CSFML 2.6.1 Installation for Arch Linux
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SFML_VERSION="2.6.1"
CSFML_VERSION="2.6.1"
PREFIX="/opt/sfml-2.6"
WORK_DIR="$HOME/.csfml_install_tmp"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         CSFML 2.6.1 Installer for Arch Linux                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check sudo
if ! sudo -v; then
    echo -e "${RED}Error: sudo privileges required${NC}"
    exit 1
fi

# =============================================================================
# 1. Cleanup
# =============================================================================
echo -e "${YELLOW}[1/6] Cleaning up...${NC}"
sudo rm -rf /usr/local/lib/libcsfml* 2>/dev/null || true
sudo rm -rf /usr/local/lib/libsfml* 2>/dev/null || true
sudo rm -rf /usr/local/include/SFML 2>/dev/null || true
sudo rm -rf /usr/local/include/CSFML 2>/dev/null || true
sudo rm -rf "$PREFIX" 2>/dev/null || true
sudo rm -f /etc/ld.so.conf.d/csfml-epitech.conf 2>/dev/null || true
rm -rf "$WORK_DIR" 2>/dev/null || true

# =============================================================================
# 2. Dependencies
# =============================================================================
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
sudo pacman -S --needed --noconfirm \
    base-devel cmake \
    libx11 libxrandr libxcursor libxi \
    freetype2 flac libogg libvorbis openal \
    systemd-libs unzip wget

# =============================================================================
# 3. Download
# =============================================================================
echo -e "${YELLOW}[3/6] Downloading...${NC}"
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

wget -q --show-progress "https://www.sfml-dev.org/files/SFML-${SFML_VERSION}-sources.zip"
wget -q --show-progress "https://www.sfml-dev.org/files/CSFML-${CSFML_VERSION}-sources.zip"

unzip -q "SFML-${SFML_VERSION}-sources.zip"
unzip -q "CSFML-${CSFML_VERSION}-sources.zip"

# =============================================================================
# 4. Build SFML
# =============================================================================
echo -e "${YELLOW}[4/6] Building SFML ${SFML_VERSION}...${NC}"
cd "$WORK_DIR/SFML-${SFML_VERSION}"
mkdir build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSFML_BUILD_EXAMPLES=OFF \
    -DSFML_BUILD_DOC=OFF
make -j$(nproc)
sudo make install

# =============================================================================
# 5. Build CSFML
# =============================================================================
echo -e "${YELLOW}[5/6] Building CSFML ${CSFML_VERSION}...${NC}"
cd "$WORK_DIR/CSFML-${CSFML_VERSION}"
mkdir build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DSFML_DIR="$PREFIX/lib/cmake/SFML" \
    -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install

# =============================================================================
# 6. System configuration
# =============================================================================
echo -e "${YELLOW}[6/6] Configuring...${NC}"

# ldconfig
echo "$PREFIX/lib" | sudo tee /etc/ld.so.conf.d/csfml-epitech.conf > /dev/null
sudo ldconfig

# Fish configuration
FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ] || [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish"
    
    # Clean old entries
    sed -i '/# CSFML Epitech/,/^$/d' "$FISH_CONFIG" 2>/dev/null || true
    
    cat >> "$FISH_CONFIG" << 'EOF'

# CSFML Epitech
set -gx LD_LIBRARY_PATH "/opt/sfml-2.6/lib" $LD_LIBRARY_PATH
set -gx LIBRARY_PATH "/opt/sfml-2.6/lib" $LIBRARY_PATH
set -gx C_INCLUDE_PATH "/opt/sfml-2.6/include" $C_INCLUDE_PATH
set -gx CPLUS_INCLUDE_PATH "/opt/sfml-2.6/include" $CPLUS_INCLUDE_PATH
set -gx PKG_CONFIG_PATH "/opt/sfml-2.6/lib/pkgconfig" $PKG_CONFIG_PATH
EOF
    echo -e "${GREEN}Fish config added${NC}"
fi

# Bash/Zsh configuration (just in case)
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        sed -i '/# CSFML Epitech/,/^$/d' "$rc" 2>/dev/null || true
        cat >> "$rc" << 'EOF'

# CSFML Epitech
export LD_LIBRARY_PATH="/opt/sfml-2.6/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="/opt/sfml-2.6/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="/opt/sfml-2.6/include:$C_INCLUDE_PATH"
export CPLUS_INCLUDE_PATH="/opt/sfml-2.6/include:$CPLUS_INCLUDE_PATH"
export PKG_CONFIG_PATH="/opt/sfml-2.6/lib/pkgconfig:$PKG_CONFIG_PATH"
EOF
    fi
done

# Wrapper for easy compilation
sudo tee /usr/local/bin/ecc > /dev/null << 'EOF'
#!/bin/bash
exec gcc -I/opt/sfml-2.6/include -L/opt/sfml-2.6/lib "$@" -Wl,-rpath,/opt/sfml-2.6/lib
EOF
sudo chmod +x /usr/local/bin/ecc

# Cleanup
rm -rf "$WORK_DIR"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Installation complete!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installed in:${NC} $PREFIX"
echo ""