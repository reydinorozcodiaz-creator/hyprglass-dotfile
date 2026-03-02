#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_LOCAL_PATH="$REPO_ROOT/configs/system/sddm/themes/sddm-astronaut-theme"
THEME_NAME="sddm-astronaut-theme"
SDDM_THEMES_DIR="/usr/share/sddm/themes"

echo "Installing SDDM and dependencies..."
if command -v pacman &> /dev/null; then
    sudo pacman -S --noconfirm --needed sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg ghostscript
else
    echo "Package manager not supported in this script (pacman not found)."
    exit 1
fi

echo "Checking for theme in $THEME_LOCAL_PATH..."
if [ ! -d "$THEME_LOCAL_PATH" ]; then
    echo "Theme not found locally. Cloning Astronaut SDDM theme..."
    mkdir -p "$THEME_LOCAL_PATH"
    git clone https://github.com/Keyitdev/sddm-astronaut-theme.git "$THEME_LOCAL_PATH"
else
    echo "Theme found locally."
fi

echo "Installing theme to $SDDM_THEMES_DIR/$THEME_NAME..."
if [ -d "$SDDM_THEMES_DIR/$THEME_NAME" ]; then
    echo "Theme already exists in system. Overwriting..."
    sudo rm -rf "$SDDM_THEMES_DIR/$THEME_NAME"
fi

sudo mkdir -p "$SDDM_THEMES_DIR/$THEME_NAME"
# Copy contents (excluding .git via cp usually copies everything, we rely on just copying)
sudo cp -r "$THEME_LOCAL_PATH/"* "$SDDM_THEMES_DIR/$THEME_NAME/"

# Install fonts if present
if [ -d "$THEME_LOCAL_PATH/Fonts" ]; then
    echo "Installing fonts from theme..."
    sudo mkdir -p /usr/share/fonts/TTF
    sudo cp -n "$THEME_LOCAL_PATH/Fonts/"*.ttf /usr/share/fonts/TTF/ || true
    fc-cache -f
fi

echo "Deploying SDDM configuration..."
sudo cp "$REPO_ROOT/configs/system/sddm/sddm.conf" /etc/sddm.conf

echo "Enabling SDDM service..."
sudo systemctl enable sddm --force

echo "SDDM setup complete! Reboot to see changes."
