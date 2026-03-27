#!/usr/bin/env bash

set -euo pipefail

ENGINE="$HOME/.config/hypr/scripts/tools/AleatoryWall.sh"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"
CURRENT_WALLPAPER_FILE="$STATE_ROOT/current-wallpaper"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Wallpaper" "$1"
}

current_wallpaper() {
    [[ -f "$CURRENT_WALLPAPER_FILE" ]] || return 1
    cat "$CURRENT_WALLPAPER_FILE"
}

status_output() {
    local backend="${BACKEND:-swww}"
    local current="unset"
    local dep_status="missing"
    local dependency="swww"

    if [[ "$backend" == "mpvpaper" ]]; then
        dependency="mpvpaper"
    fi
    if command -v "$dependency" >/dev/null 2>&1; then
        dep_status="ok"
    fi
    if current="$(current_wallpaper 2>/dev/null)"; then
        :
    else
        current="unset"
    fi

    printf 'backend=%s\ndependency=%s:%s\ncurrent=%s\n' \
        "$backend" \
        "$dependency" \
        "$dep_status" \
        "$current"
}

show_status() {
    local output

    output="$(status_output)"
    printf '%s\n' "$output"
    notify "$output"
}

apply_change() {
    "$ENGINE" "$@"
    if current="$(current_wallpaper 2>/dev/null)"; then
        notify "Changed to $(basename "$current")"
    else
        notify "Wallpaper changed"
    fi
}

apply_set() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        echo "Usage: wallpaper-control.sh set <path>" >&2
        exit 1
    fi

    "$ENGINE" --file "$target"
    if current="$(current_wallpaper 2>/dev/null)"; then
        notify "Changed to $(basename "$current")"
    fi
}

case "${1:-change}" in
    change)
        shift
        apply_change "$@"
        ;;
    set)
        shift
        apply_set "${1:-}"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: wallpaper-control.sh change [engine args] | set <path> | status" >&2
        exit 1
        ;;
esac
