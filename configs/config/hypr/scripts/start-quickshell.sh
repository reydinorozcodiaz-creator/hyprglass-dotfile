#!/bin/bash

# Archivo de log
LOG_FILE="$HOME/.local/share/hyprland/logs/quickshell.log"
mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting quickshell script"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: $USER, Home: $HOME"
    
    # Variables Qt/Wayland ya inyectadas por Hyprland (env = en config/15-environment.conf
    # y config/10-theme-unifier-env.conf). No re-exportar aquí para evitar tres fuentes de verdad.

    # Kill any existing quickshell instance
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Killing existing quickshell instances"
    pkill -x quickshell
    
    # Wait a moment to ensure clean shutdown
    sleep 0.5
    
    # Check if quickshell command exists
    if ! command -v quickshell &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: quickshell command not found"
        exit 1
    fi
    
    # Start quickshell
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting quickshell from: $(which quickshell)"
    quickshell "$@"
} 2>&1 | tail -c 10M >> "$LOG_FILE"