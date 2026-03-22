#!/usr/bin/env bash
# HyprGlass - Minimal Installation Script
# Adopted from Hyprland Glass installer by @Shidohs

set -euo pipefail

# --- Styles & Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color
GRADIENT1='\033[38;5;81m'   # Light blue
GRADIENT2='\033[38;5;75m'   # Medium blue
GRADIENT3='\033[38;5;69m'   # Dark blue

# --- Configuration ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/configs/config"
HOME_DIR="$REPO_ROOT/configs/home"
REQUIREMENTS_FILE="$REPO_ROOT/requirements/arch-pacman.txt"
LOG_FILE="$REPO_ROOT/install.log"
BACKUP_DIR="$HOME/.config/hyprglass-backups"

# --- UI Functions ---

show_banner() {
    clear
    echo
    echo -e "${BOLD}${GRADIENT1}"
    cat << 'END'
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║    ██╗  ██╗██╗   ██╗██████╗ ██████╗  ██████╗ ██╗      █████╗ ███████╗    ║
    ║    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔════╝ ██║     ██╔══██╗██╔════╝    ║
    ║    ███████║ ╚████╔╝ ██████╔╝██████╔╝██║  ███╗██║     ███████║███████╗    ║
    ║    ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══██║╚════██║    ║
    ║    ██║  ██║   ██║   ██║     ██║  ██║╚██████╔╝███████╗██║  ██║███████║    ║
    ║    ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝    ║
    ║                                                                          ║
    ║                        ✨ Minimal Edition ✨                             ║
    ╚══════════════════════════════════════════════════════════════════════════╝
END
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}                 🔧 Automated Installer v1.0 🔧${NC}"
    echo
}

separator() {
    echo -e "${GRAY}$(printf '─%.0s' {1..60})${NC}"
}

log() { echo -e "${BLUE}${BOLD}⏰ [$(date +'%H:%M')]${NC} ${WHITE}$1${NC}"; echo "[INFO] $1" >> "$LOG_FILE"; }
success() { echo -e "${GREEN}${BOLD}✅ [OK]${NC} ${WHITE}$1${NC}"; echo "[OK] $1" >> "$LOG_FILE"; }
warn() { echo -e "${YELLOW}${BOLD}⚠️  [WARN]${NC} ${YELLOW}$1${NC}"; echo "[WARN] $1" >> "$LOG_FILE"; }
error() { echo -e "${RED}${BOLD}❌ [ERROR]${NC} ${RED}$1${NC}"; echo "[ERROR] $1" >> "$LOG_FILE"; }
step() { echo -e "\n${PURPLE}${BOLD}🔸 [STEP]${NC} ${WHITE}$1${NC}"; separator; }

type_text() {
    local text="$1"
    local delay=0.01
    for (( i=0; i<${#text}; i++ )); do
        printf "%c" "${text:$i:1}"
        sleep $delay
    done
    echo
}

# --- Tasks ---

install_deps() {
    step "Installing Packages"

    log "Checking for AUR helper..."
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
    else
        warn "No AUR helper found. Installing yay-bin..."
        if ! command -v git &> /dev/null; then
             sudo pacman -S --noconfirm git base-devel
        fi
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        (cd /tmp/yay-bin && makepkg -si --noconfirm)
        AUR_HELPER="yay"
    fi
    success "Using $AUR_HELPER"

    log "Reading $REQUIREMENTS_FILE..."
    PACKAGES=$(grep -vE '^\s*#' "$REQUIREMENTS_FILE" | grep -vE '^\s*$' | tr '\n' ' ')
    
    log "Installing packages (this may take a while)..."
    $AUR_HELPER -S --needed --noconfirm $PACKAGES
    success "All packages installed."
}

link_file_safe() {
    local src="$1"
    local dst="$2"
    local backup_ts="$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_ts/$(basename "$dst")"

    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$(readlink -f "$dst")" == "$src" ]; then
            log "  • Skipping $(basename "$dst") (already correct)"
            return
        fi
        
        # Move to backup
        mkdir -p "$(dirname "$backup_path")"
        mv "$dst" "$backup_path"
        log "  • Backup: $(basename "$dst") -> backups/$backup_ts/"
    fi
    
    ln -s "$src" "$dst"
    echo -e "  ${GREEN}✓${NC} Linked: $(basename "$dst")"
}

setup_configs() {
    step "Deploying Dotfiles"
    log "Creating backups in: $BACKUP_DIR"

    # User Configs ~/.config
    log "Linking ~/.config files..."
    for Item in "$CONFIG_DIR"/*; do
        [ -e "$Item" ] || continue
        link_file_safe "$Item" "$HOME/.config/$(basename "$Item")"
    done

    # Home Configs ~/
    log "Linking Home files..."
    for Item in "$HOME_DIR"/*; do
        [ -e "$Item" ] || continue
        link_file_safe "$Item" "$HOME/$(basename "$Item")"
    done
    
    success "Dotfiles deployed successfully."
}

setup_sddm() {
    step "Setting up SDDM Display Manager"
    if [ -f "$REPO_ROOT/scripts/install_sddm.sh" ]; then
        log "Executing SDDM install script..."
        "$REPO_ROOT/scripts/install_sddm.sh"
        success "SDDM configured."
    else
        error "SDDM script missing!"
    fi
}

setup_zsh() {
    step "Configuring ZSH & Oh My Zsh"
    
    # 1. Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "Installing Oh My Zsh..."
        # KEEP_ZSHRC=yes evita que OMZ sobrescriba un .zshrc existente (por ejemplo, si ya enlazamos los dotfiles)
        KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log "Oh My Zsh already installed."
    fi

    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # 2. Install Powerlevel10k
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        log "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi

    # 3. Change shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Changing default shell to zsh..."
        chsh -s "$(which zsh)" || warn "Could not change shell automatically. Please run: chsh -s $(which zsh)"
    fi
    
    success "ZSH configured."
}

setup_grub() {
    step "Configuring GRUB Theme (Lain)"
    
    local THEME_NAME="lain"
    local THEME_SRC="$REPO_ROOT/configs/system/grub/themes/$THEME_NAME"
    local THEME_DST="/boot/grub/themes/$THEME_NAME"
    
    if [ ! -d "$THEME_SRC" ]; then
        error "GRUB theme source not found: $THEME_SRC"
        return
    fi

    log "Installing GRUB theme to $THEME_DST..."
    if [ ! -d "/boot/grub/themes" ]; then
        sudo mkdir -p "/boot/grub/themes"
    fi
    
    sudo cp -r "$THEME_SRC" "$(dirname "$THEME_DST")"
    
    log "Updating /etc/default/grub..."
    # Backup
    sudo cp /etc/default/grub /etc/default/grub.bak.$(date +%Y%m%d_%H%M%S)
    
    # Update GRUB_THEME line
    if grep -q "^GRUB_THEME=" /etc/default/grub; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DST/theme.txt\"|" /etc/default/grub
    else
        echo "GRUB_THEME=\"$THEME_DST/theme.txt\"" | sudo tee -a /etc/default/grub
    fi
    
    log "Updating GRUB config (grub-mkconfig)..."
    if command -v grub-mkconfig &> /dev/null; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        success "GRUB theme installed and config updated."
    else
        warn "grub-mkconfig not found. Please update grub manually."
    fi
}

setup_power_management() {
    step "Configuring Power Manager (tuned)"

    if ! command -v systemctl &> /dev/null; then
        warn "systemctl not found. Skipping tuned setup."
        return
    fi

    if systemctl cat tuned.service &> /dev/null; then
        log "Enabling tuned service..."
        if sudo systemctl enable --now tuned; then
            success "tuned service enabled and running."
        else
            warn "Could not enable tuned automatically. Run: sudo systemctl enable --now tuned"
        fi
    else
        warn "tuned.service not found. Verify the tuned package is installed."
    fi

    if systemctl cat tuned-ppd.service &> /dev/null; then
        log "Enabling optional tuned-ppd compatibility service..."
        if sudo systemctl enable --now tuned-ppd; then
            success "tuned-ppd compatibility service enabled."
        else
            warn "Could not enable tuned-ppd automatically. Optional command: sudo systemctl enable --now tuned-ppd"
        fi
    else
        log "Optional tuned-ppd service not found. Skipping compatibility service."
    fi
}

setup_misc() {
    step "Post-Install Tasks"
    if command -v fc-cache &> /dev/null; then
        log "Updating font cache..."
        fc-cache -f
    fi
    success "Post-install tasks done."
}

# --- Main Interaction ---

main() {
    show_banner
    
    echo -e "${WHITE}Installation Options:${NC}"
    echo -e "${GRAY}Select what you want to perform:${NC}"
    echo
    
    echo -e "  [1] ${CYAN}Full Installation${NC} (All of the above)"
    echo -e "  [2] ${CYAN}Packages Only${NC} (From requirements.txt)"
    echo -e "  [3] ${CYAN}Dotfiles Only${NC} (Link configs)"
    echo -e "  [4] ${CYAN}SDDM Only${NC} (Theme & Config)"
    echo -e "  [5] ${CYAN}ZSH Only${NC} (Oh My Zsh + Plugins)"
    echo -e "  [6] ${CYAN}GRUB Only${NC} (Lain Theme)"
    echo -e "  [0] ${RED}Exit${NC}"
    echo
    
    read -p "  Enter selection [1]: " -n 1 -r SELECTION
    echo
    SELECTION=${SELECTION:-1}

    case $SELECTION in
        1)
            type_text "Starting Full Installation..."
            install_deps
            setup_power_management
            setup_zsh
            setup_configs
            setup_sddm
            setup_grub
            setup_misc
            ;;
        2)
            type_text "Starting Package Installation..."
            install_deps
            ;;
        3)
            type_text "Starting Dotfile Deployment..."
            setup_configs
            setup_misc
            ;;
        4)
            type_text "Starting SDDM Setup..."
            setup_sddm
            ;;
        5)
            type_text "Starting ZSH Setup..."
            setup_zsh
            ;;
        6)
            type_text "Starting GRUB Setup..."
            setup_grub
            ;;
        0)
            echo "Exiting."
            exit 0
            ;;
        *)
            error "Invalid selection."
            exit 1
            ;;
    esac

    echo
    separator
    echo -e "${GREEN}${BOLD}🎉 Installation Complete! 🎉${NC}"
    echo -e "${WHITE}Please reboot your system to apply all changes.${NC}"
    echo
}

main
