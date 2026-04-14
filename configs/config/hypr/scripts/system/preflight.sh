#!/usr/bin/env bash

# HyprGlass Pre-flight Dependency Checker
# This script ensures that all critical components are installed before starting the session.

set -euo pipefail

CRITICAL_DEPS=(
    "hyprland"
    "hyprctl"
    "rofi"
    "notify-send"
    "bc"
    "xdg-user-dir"
    "wl-paste"
    "cliphist"
    "dbus-update-activation-environment"
)

check_deps() {
    local missing=()
    for dep in "${CRITICAL_DEPS[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        local msg="Missing critical dependencies: ${missing[*]}"
        echo "ERROR: $msg" >&2
        
        # Try to notify if notify-send is available
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "HyprGlass Error" "$msg"
        fi
        
        # Log to a temporary file
        echo "$(date): $msg" >> "${XDG_STATE_HOME:-$HOME/.local/state}/hypr/preflight.log"
        return 1
    fi
    return 0
}

check_deps
