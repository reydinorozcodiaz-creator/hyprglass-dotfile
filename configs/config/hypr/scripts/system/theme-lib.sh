#!/usr/bin/env bash

THEME_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
THEME_STATE_FILE="$THEME_STATE_DIR/theme.conf"
HYPR_THEME_ENV_CONF="$HOME/.config/hypr/config/10-theme-unifier-env.conf"

THEME_DEFAULT_GTK="Sweet"
THEME_DEFAULT_ICONS="BeautyLine"
THEME_DEFAULT_CURSOR="Sweet-cursors"
THEME_DEFAULT_CURSOR_SIZE="24"

ensure_theme_state() {
    mkdir -p "$THEME_STATE_DIR"

    if [[ ! -f "$THEME_STATE_FILE" ]]; then
        save_theme_state \
            "$THEME_DEFAULT_GTK" \
            "$THEME_DEFAULT_ICONS" \
            "$THEME_DEFAULT_CURSOR" \
            "$THEME_DEFAULT_CURSOR_SIZE"
    fi
}

load_theme_state() {
    ensure_theme_state

    GTK_THEME=""
    ICON_THEME=""
    CURSOR_THEME=""
    CURSOR_SIZE=""

    # shellcheck disable=SC1090
    source "$THEME_STATE_FILE"

    : "${GTK_THEME:=$THEME_DEFAULT_GTK}"
    : "${ICON_THEME:=$THEME_DEFAULT_ICONS}"
    : "${CURSOR_THEME:=$THEME_DEFAULT_CURSOR}"
    : "${CURSOR_SIZE:=$THEME_DEFAULT_CURSOR_SIZE}"
}

save_theme_state() {
    local gtk_theme="$1"
    local icon_theme="$2"
    local cursor_theme="$3"
    local cursor_size="$4"

    mkdir -p "$THEME_STATE_DIR"
    cat > "$THEME_STATE_FILE" <<EOF
GTK_THEME="$gtk_theme"
ICON_THEME="$icon_theme"
CURSOR_THEME="$cursor_theme"
CURSOR_SIZE="$cursor_size"
EOF
}

get_installed_themes() {
    local -a theme_dirs=(
        "/usr/share/themes"
        "$HOME/.themes"
        "$HOME/.local/share/themes"
    )
    local -a installed=()
    local dir
    local theme_path

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

get_installed_icons() {
    local -a icon_dirs=(
        "/usr/share/icons"
        "$HOME/.icons"
        "$HOME/.local/share/icons"
    )
    local -a installed=()
    local dir
    local icon_path

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

get_installed_cursors() {
    local -a icon_dirs=(
        "/usr/share/icons"
        "$HOME/.icons"
        "$HOME/.local/share/icons"
    )
    local -a installed=()
    local dir
    local cursor_path

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
