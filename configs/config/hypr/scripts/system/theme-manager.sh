#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/theme-lib.sh"

ROFI_THEME="$HOME/.config/hypr/rofi/themes/launcher.rasi"
UNIFIER="$SCRIPT_DIR/theme-unifier.sh"

rofi_menu() {
    local prompt="$1"
    local message="$2"
    local -a args=(-dmenu -i -p "$prompt")

    command -v rofi >/dev/null 2>&1 || {
        echo "rofi is not installed" >&2
        return 1
    }

    if [[ -n "$message" ]]; then
        args+=(-mesg "$message")
    fi
    if [[ -f "$ROFI_THEME" ]]; then
        args+=(-theme "$ROFI_THEME")
    fi

    rofi "${args[@]}"
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Theme Manager" "$1" -i preferences-desktop-theme
}

apply_current_state() {
    "$UNIFIER" apply
}

select_theme() {
    local themes
    local icons
    local selected_theme=""
    local selected_icon=""

    load_theme_state
    themes="$(get_installed_themes)"
    icons="$(get_installed_icons)"

    [[ -n "$themes" ]] || {
        echo "No GTK themes found" >&2
        return 1
    }
    [[ -n "$icons" ]] || {
        echo "No icon themes found" >&2
        return 1
    }

    selected_theme=$(printf '%s\n' "$themes" | rofi_menu "GTK Theme" "")
    [[ -n "$selected_theme" ]] || return 0

    selected_icon=$(printf '%s\n' "$icons" | rofi_menu "Icon Theme" "")
    [[ -n "$selected_icon" ]] || selected_icon="$ICON_THEME"

    save_theme_state "$selected_theme" "$selected_icon" "$CURSOR_THEME" "$CURSOR_SIZE"
    apply_current_state
    notify "GTK: $selected_theme\nIcons: $selected_icon"
}

select_cursor() {
    local cursors
    local selected_cursor=""

    load_theme_state
    cursors="$(get_installed_cursors)"
    [[ -n "$cursors" ]] || {
        echo "No cursor themes found" >&2
        return 1
    }

    selected_cursor=$(printf '%s\n' "$cursors" | rofi_menu "Cursor Theme" "")
    [[ -n "$selected_cursor" ]] || return 0

    save_theme_state "$GTK_THEME" "$ICON_THEME" "$selected_cursor" "$CURSOR_SIZE"
    apply_current_state
    notify "Cursor: $selected_cursor"
}

show_presets() {
    local presets="Sweet default
Arc dark
Breeze dark
Adwaita light
Dracula"
    local selected=""

    selected=$(printf '%s\n' "$presets" | rofi_menu "Preset" "")
    [[ -n "$selected" ]] || return 0

    case "$selected" in
        "Sweet default")
            save_theme_state "Sweet" "BeautyLine" "Sweet-cursors" "24"
            ;;
        "Arc dark")
            save_theme_state "Arc-Dark" "Papirus-Dark" "Sweet-cursors" "24"
            ;;
        "Breeze dark")
            save_theme_state "Breeze-Dark" "breeze-dark" "breeze_cursors" "24"
            ;;
        "Adwaita light")
            save_theme_state "Adwaita" "Adwaita" "Adwaita" "24"
            ;;
        "Dracula")
            save_theme_state "Dracula" "Papirus-Dark" "Sweet-cursors" "24"
            ;;
    esac

    apply_current_state
    notify "Preset: $selected"
}

show_status() {
    "$UNIFIER" status
}

show_help() {
    cat <<'EOF'
theme-manager.sh select|cursor|preset|apply|status|help
EOF
}

case "${1:-select}" in
    select)
        select_theme
        ;;
    cursor)
        select_cursor
        ;;
    preset)
        show_presets
        ;;
    apply)
        apply_current_state
        notify "Theme state applied"
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
