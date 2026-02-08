#!/bin/bash
# Theme Selector Script
# Interactive theme selection for Qt/GTK

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Rofi theme (GUI)
# Prefer the Hypr-managed theme if present; otherwise fall back to default rofi styling.
ROFI_THEME_FILE="$HOME/.config/hypr/rofi/themes/launcher.rasi"

# Available themes
declare -A THEMES=(
    ["Adwaita-dark"]="Dark theme (default)"
    ["Adwaita"]="Light theme"
    ["Arc-Dark"]="Arc dark theme"
    ["Arc"]="Arc light theme"
    ["Materia-dark"]="Materia dark theme"
    ["Materia"]="Materia light theme"
    ["Numix"]="Numix theme"
    ["Breeze-Dark"]="KDE Breeze dark"
    ["Breeze"]="KDE Breeze light"
)

declare -A ICON_THEMES=(
    ["Adwaita"]="Default GNOME icons"
    ["Papirus-Dark"]="Papirus dark icons"
    ["Papirus"]="Papirus light icons"
    ["candy-icons"]="Candy icons"
    ["Numix-Circle"]="Numix circle icons"
    ["Arc"]="Arc icons"
    ["Breeze"]="KDE Breeze icons"
)

show_help() {
    echo -e "${CYAN}Theme Selector Script${NC}"
    echo "===================="
    echo
    echo -e "${YELLOW}Usage:${NC} $0 [OPTION]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}select${NC}    Interactive theme selection (default)"
    echo -e "  ${GREEN}quick${NC}     Quick apply specific theme"
    echo -e "  ${GREEN}list${NC}      List available themes"
    echo -e "  ${GREEN}current${NC}   Show current theme"
    echo -e "  ${GREEN}help${NC}      Show this help"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 select                    # Interactive selector"
    echo -e "  $0 quick Arc-Dark Papirus    # Quick apply theme + icons"
    echo -e "  $0 list                      # List available themes"
    echo
}

list_available_themes() {
    echo -e "${CYAN}📁 Available GTK Themes:${NC}"
    echo "========================="
    echo
    
    local count=0
    for theme in "${!THEMES[@]}"; do
        count=$((count + 1))
        echo -e "  ${GREEN}$count.${NC} $theme - ${THEMES[$theme]}"
    done
    
    echo
    echo -e "${CYAN}🎨 Available Icon Themes:${NC}"
    echo "=========================="
    echo
    
    count=0
    for icons in "${!ICON_THEMES[@]}"; do
        count=$((count + 1))
        echo -e "  ${BLUE}$count.${NC} $icons - ${ICON_THEMES[$icons]}"
    done
    echo
}

get_installed_themes() {
    local theme_dirs=(
        "/usr/share/themes"
        "$HOME/.themes"
        "$HOME/.local/share/themes"
    )
    
    local installed_themes=()
    
    for dir in "${theme_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for theme_path in "$dir"/*; do
                if [[ -d "$theme_path/gtk-3.0" ]] || [[ -d "$theme_path/gtk-2.0" ]]; then
                    local theme_name=$(basename "$theme_path")
                    installed_themes+=("$theme_name")
                fi
            done
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${installed_themes[@]}" | sort -u
}

get_installed_icons() {
    local icon_dirs=(
        "/usr/share/icons"
        "$HOME/.icons"
        "$HOME/.local/share/icons"
    )
    
    local installed_icons=()
    
    for dir in "${icon_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for icon_path in "$dir"/*; do
                if [[ -d "$icon_path" ]] && [[ -f "$icon_path/index.theme" ]]; then
                    local icon_name=$(basename "$icon_path")
                    # Skip cursor themes
                    if [[ ! -d "$icon_path/cursors" ]] || [[ -d "$icon_path/apps" ]]; then
                        installed_icons+=("$icon_name")
                    fi
                fi
            done
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${installed_icons[@]}" | sort -u
}

show_current_theme() {
    echo -e "${CYAN}🎨 Current Theme Configuration${NC}"
    echo "=============================="
    echo
    
    # Get current theme from gsettings
    if command -v gsettings >/dev/null 2>&1; then
        local current_gtk=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        local current_icons=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
        local current_cursor=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
        
        echo -e "${YELLOW}Current Configuration:${NC}"
        echo -e "  GTK Theme: ${GREEN}$current_gtk${NC}"
        echo -e "  Icon Theme: ${GREEN}$current_icons${NC}"
        echo -e "  Cursor Theme: ${GREEN}$current_cursor${NC}"
    else
        echo -e "${RED}❌ gsettings not available${NC}"
    fi
    echo
}

interactive_theme_selection() {
    echo -e "${CYAN}🎨 Interactive Theme Selection${NC}"
    echo "==============================="
    echo
    
    # Get installed themes
    local installed_themes=$(get_installed_themes)
    local installed_icons=$(get_installed_icons)
    
    if [[ -z "$installed_themes" ]]; then
        echo -e "${RED}❌ No GTK themes found${NC}"
        return 1
    fi
    
    if ! command -v rofi >/dev/null 2>&1; then
        echo -e "${RED}❌ rofi is not installed (required for the GUI selector)${NC}"
        return 1
    fi

    local -a rofi_theme_args=()
    if [[ -f "$ROFI_THEME_FILE" ]]; then
        rofi_theme_args=(-theme "$ROFI_THEME_FILE")
    fi

    # Select GTK theme
    echo -e "${YELLOW}Select GTK Theme:${NC}"
    local selected_theme
    selected_theme=$(echo "$installed_themes" | rofi -dmenu -i \
        -p "Select GTK Theme" \
        "${rofi_theme_args[@]}")
    
    if [[ -z "$selected_theme" ]]; then
        echo -e "${YELLOW}⚠️  No theme selected${NC}"
        return 1
    fi
    
    # Select Icon theme
    echo -e "${YELLOW}Select Icon Theme:${NC}"
    local selected_icons
    selected_icons=$(echo "$installed_icons" | rofi -dmenu -i \
        -p "Select Icon Theme" \
        "${rofi_theme_args[@]}")
    
    if [[ -z "$selected_icons" ]]; then
        echo -e "${YELLOW}⚠️  No icon theme selected, using Adwaita${NC}"
        selected_icons="Adwaita"
    fi
    
    # Apply the selected themes
    apply_theme "$selected_theme" "$selected_icons"
}

apply_theme() {
    local gtk_theme="$1"
    local icon_theme="$2"
    local cursor_theme="${3:-Sweet-cursors}"
    
    if [[ -z "$gtk_theme" ]]; then
        echo -e "${RED}❌ No GTK theme specified${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🎨 Applying Theme Configuration:${NC}"
    echo -e "  GTK Theme: ${GREEN}$gtk_theme${NC}"
    echo -e "  Icon Theme: ${GREEN}$icon_theme${NC}"
    echo -e "  Cursor Theme: ${GREEN}$cursor_theme${NC}"
    echo
    
    # Update the theme-unifier script
    sed -i "s/GTK_THEME=\".*\"/GTK_THEME=\"$gtk_theme\"/" ~/.config/hypr/scripts/system/theme-unifier.sh
    sed -i "s/ICON_THEME=\".*\"/ICON_THEME=\"$icon_theme\"/" ~/.config/hypr/scripts/system/theme-unifier.sh
    sed -i "s/CURSOR_THEME=\".*\"/CURSOR_THEME=\"$cursor_theme\"/" ~/.config/hypr/scripts/system/theme-unifier.sh
    
    # Apply the theme
    ~/.config/hypr/scripts/system/theme-unifier.sh apply
    
    # Show notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Theme Applied" "GTK: $gtk_theme, Icons: $icon_theme" -i preferences-desktop-theme
    fi
    
    echo -e "${GREEN}✅ Theme configuration applied!${NC}"
    echo -e "${YELLOW}💡 Restart applications to see full changes${NC}"
}

quick_apply() {
    local gtk_theme="$1"
    local icon_theme="$2"
    
    if [[ -z "$gtk_theme" ]]; then
        echo -e "${RED}❌ Usage: $0 quick <gtk_theme> [icon_theme]${NC}"
        return 1
    fi
    
    if [[ -z "$icon_theme" ]]; then
        icon_theme="Adwaita"
    fi
    
    apply_theme "$gtk_theme" "$icon_theme"
}

# Main execution
case "${1:-select}" in
    select)
        interactive_theme_selection
        ;;
    quick)
        quick_apply "$2" "$3"
        ;;
    list)
        list_available_themes
        echo -e "${CYAN}📋 Installed Themes:${NC}"
        echo "==================="
        echo
        echo -e "${YELLOW}GTK Themes:${NC}"
        get_installed_themes | while read theme; do
            echo -e "  • $theme"
        done
        echo
        echo -e "${YELLOW}Icon Themes:${NC}"
        get_installed_icons | while read icons; do
            echo -e "  • $icons"
        done
        ;;
    current)
        show_current_theme
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        echo
        show_help
        exit 1
        ;;
esac
