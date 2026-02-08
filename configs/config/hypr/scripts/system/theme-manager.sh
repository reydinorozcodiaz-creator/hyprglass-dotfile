#!/bin/bash
# Theme Manager GUI using existing rofi themes

# Use Hypr-managed rofi launcher theme (includes required variable definitions)
ROFI_THEME="$HOME/.config/hypr/rofi/themes/launcher.rasi"

UNIFIER="$HOME/.config/hypr/scripts/system/theme-unifier.sh"

get_installed_gtk_themes() {
    local -a theme_dirs=(
        "/usr/share/themes"
        "$HOME/.themes"
        "$HOME/.local/share/themes"
    )

    local -a installed=()
    local dir theme_path
    for dir in "${theme_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for theme_path in "$dir"/*; do
            [[ -d "$theme_path" ]] || continue
            if [[ -d "$theme_path/gtk-4.0" || -d "$theme_path/gtk-3.0" || -d "$theme_path/gtk-2.0" ]]; then
                installed+=("$(basename "$theme_path")")
            fi
        done
    done

    printf '%s\n' "${installed[@]}" | sort -u
}

get_installed_icon_themes() {
    local -a icon_dirs=(
        "/usr/share/icons"
        "$HOME/.icons"
        "$HOME/.local/share/icons"
    )

    local -a installed=()
    local dir icon_path
    for dir in "${icon_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for icon_path in "$dir"/*; do
            [[ -d "$icon_path" ]] || continue
            [[ -f "$icon_path/index.theme" ]] || continue
            installed+=("$(basename "$icon_path")")
        done
    done

    printf '%s\n' "${installed[@]}" | sort -u
}

get_installed_cursor_themes() {
    local -a icon_dirs=(
        "/usr/share/icons"
        "$HOME/.icons"
        "$HOME/.local/share/icons"
    )

    local -a installed=()
    local dir cursor_path
    for dir in "${icon_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for cursor_path in "$dir"/*; do
            [[ -d "$cursor_path" ]] || continue
            [[ -d "$cursor_path/cursors" ]] || continue
            installed+=("$(basename "$cursor_path")")
        done
    done

    printf '%s\n' "${installed[@]}" | sort -u
}

set_unifier_var() {
    local key="$1"
    local value="$2"

    [[ -f "$UNIFIER" ]] || return 1
    sed -i "s/^${key}=\".*\"/${key}=\"${value//\"/\\\"}\"/" "$UNIFIER"
}

apply_unifier() {
    [[ -x "$UNIFIER" ]] || return 1
    "$UNIFIER" apply
}

rofi_menu() {
    local prompt="$1"
    local message="$2"

    if ! command -v rofi >/dev/null 2>&1; then
        echo "rofi is not installed" >&2
        return 1
    fi

    local -a args=(-dmenu -i -p "$prompt")
    if [[ -n "$message" ]]; then
        args+=( -mesg "$message" )
    fi
    if [[ -f "$ROFI_THEME" ]]; then
        args+=( -theme "$ROFI_THEME" )
    fi

    rofi "${args[@]}"
}

show_main_menu() {
    local options="🎨 GTK/Qt Themes
🖼️ Icon Themes  
🖱️ Cursor Themes
🔄 Apply Unified Theme
📋 Current Status
⚙️ Quick Presets
❌ Exit"

    echo "$options" | rofi_menu "Theme Manager" "Select theme category to manage"
}

show_gtk_themes() {
    local themes
    themes=$(get_installed_gtk_themes)

    if [[ -z "$themes" ]]; then
        notify-send "Theme Manager" "No GTK themes found in system/user theme directories" -i dialog-warning
        return 1
    fi
    
    local selected
    selected=$(echo "$themes" | rofi_menu "Select GTK Theme" "")
    
    if [[ -n "$selected" ]]; then
        if [[ -f "$UNIFIER" ]]; then
            set_unifier_var "GTK_THEME" "$selected" || true
            apply_unifier >/dev/null 2>&1 || true
        else
            gsettings set org.gnome.desktop.interface gtk-theme "$selected"
            gsettings set org.gnome.desktop.wm.preferences theme "$selected"
        fi
        notify-send "Theme Applied" "GTK Theme: $selected" -i preferences-desktop-theme
    fi
}

show_icon_themes() {
    local themes
    themes=$(get_installed_icon_themes)

    if [[ -z "$themes" ]]; then
        notify-send "Theme Manager" "No icon themes found in system/user icon directories" -i dialog-warning
        return 1
    fi
    
    local selected
    selected=$(echo "$themes" | rofi_menu "Select Icon Theme" "")
    
    if [[ -n "$selected" ]]; then
        if [[ -f "$UNIFIER" ]]; then
            set_unifier_var "ICON_THEME" "$selected" || true
            apply_unifier >/dev/null 2>&1 || true
        else
            gsettings set org.gnome.desktop.interface icon-theme "$selected"
        fi
        notify-send "Icons Applied" "Icon Theme: $selected" -i folder-pictures
    fi
}

show_cursor_themes() {
    local themes
    themes=$(get_installed_cursor_themes)

    if [[ -z "$themes" ]]; then
        notify-send "Theme Manager" "No cursor themes found in system/user icon directories" -i dialog-warning
        return 1
    fi
    
    local selected
    selected=$(echo "$themes" | rofi_menu "Select Cursor Theme" "")
    
    if [[ -n "$selected" ]]; then
        if [[ -f "$UNIFIER" ]]; then
            set_unifier_var "CURSOR_THEME" "$selected" || true
            apply_unifier >/dev/null 2>&1 || true
        else
            gsettings set org.gnome.desktop.interface cursor-theme "$selected"
        fi
        notify-send "Cursor Applied" "Cursor Theme: $selected" -i input-mouse
    fi
}

show_presets() {
    local presets="🌙 Dark Preset
☀️ Light Preset  
🎯 Arc Preset
🔵 Breeze Preset
🟣 Dracula Preset"

    local selected
    selected=$(echo "$presets" | rofi_menu "Select Preset" "")

    case "$selected" in
        *"Dark Preset"*)
            apply_preset "Sweet-Dark-v40" "Papirus-Dark" "Sweet-cursors"
            ;;
        *"Light Preset"*)
            apply_preset "Adwaita" "Adwaita" "Adwaita"
            ;;
        *"Arc Preset"*)
            apply_preset "Arc-Dark" "Papirus-Dark" "Sweet-cursors"
            ;;
        *"Breeze Preset"*)
            apply_preset "Breeze-Dark" "breeze-dark" "breeze_cursors"
            ;;
        *"Dracula Preset"*)
            apply_preset "Dracula" "Papirus-Dark" "Sweet-cursors"
            ;;
    esac
}

apply_preset() {
    local gtk_theme="$1"
    local icon_theme="$2" 
    local cursor_theme="$3"
    
    # Apply all themes (prefer unifier so Qt configs get updated too)
    if [[ -f "$UNIFIER" ]]; then
        set_unifier_var "GTK_THEME" "$gtk_theme" || true
        set_unifier_var "ICON_THEME" "$icon_theme" || true
        set_unifier_var "CURSOR_THEME" "$cursor_theme" || true
        apply_unifier >/dev/null 2>&1 || true
    else
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
        gsettings set org.gnome.desktop.wm.preferences theme "$gtk_theme"
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
        gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
    fi
    
    notify-send "Preset Applied" "GTK: $gtk_theme\nIcons: $icon_theme\nCursor: $cursor_theme" -i preferences-desktop-theme
}

show_current_status() {
    local gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")
    local icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
    local cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    
    local status="Current Configuration:

🎨 GTK Theme: $gtk_theme
🖼️ Icon Theme: $icon_theme  
🖱️ Cursor Theme: $cursor_theme

Press ESC to return"

    echo "$status" | rofi_menu "Current Status" "Theme Status"
}

# Main loop
while true; do
    choice=$(show_main_menu)
    
    case "$choice" in
        *"GTK/Qt Themes"*)
            show_gtk_themes
            ;;
        *"Icon Themes"*)
            show_icon_themes
            ;;
        *"Cursor Themes"*)
            show_cursor_themes
            ;;
        *"Apply Unified"*)
            if [[ -f ~/.config/hypr/scripts/system/theme-unifier.sh ]]; then
                ~/.config/hypr/scripts/system/theme-unifier.sh apply
                notify-send "Themes Unified" "All themes synchronized" -i preferences-desktop-theme
            else
                notify-send "Error" "theme-unifier.sh not found" -i dialog-error
            fi
            ;;
        *"Current Status"*)
            show_current_status
            ;;
        *"Quick Presets"*)
            show_presets
            ;;
        *"Exit"*|"")
            break
            ;;
    esac
done
