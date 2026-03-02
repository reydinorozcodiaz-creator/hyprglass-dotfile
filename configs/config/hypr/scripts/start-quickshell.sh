#!/bin/bash

# Archivo de log
LOG_FILE="$HOME/.local/share/hyprland/logs/quickshell.log"
mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting quickshell script"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: $USER, Home: $HOME"
    
    # Esperar a que Hyprland esté completamente inicializado
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for Hyprland to initialize..."
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if command -v hyprctl &> /dev/null && hyprctl version &> /dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Hyprland is ready"
            break
        fi
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
    done
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Timeout waiting for Hyprland"
        exit 1
    fi
    
    # Dar un momento adicional para que las variables de entorno estén disponibles
    sleep 1
    
    # Obtener variables críticas de Hyprland
    if command -v hyprctl &> /dev/null; then
        # Obtener HYPRLAND_INSTANCE_SIGNATURE
        HYPR_SIGNATURE=$(hyprctl instances -j 2>/dev/null | grep -oP '"signature"\s*:\s*"\K[^"]+' | head -n1)
        if [ -n "$HYPR_SIGNATURE" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIGNATURE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] HYPRLAND_INSTANCE_SIGNATURE: $HYPRLAND_INSTANCE_SIGNATURE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Could not get HYPRLAND_INSTANCE_SIGNATURE"
        fi
    fi
    
    # Asegurar que WAYLAND_DISPLAY esté configurado
    if [ -z "$WAYLAND_DISPLAY" ]; then
        # Intentar detectar el display de Wayland
        for display in /run/user/$(id -u)/wayland-* ; do
            if [ -S "$display" ]; then
                export WAYLAND_DISPLAY=$(basename "$display")
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Set WAYLAND_DISPLAY to: $WAYLAND_DISPLAY"
                break
            fi
        done
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WAYLAND_DISPLAY already set: $WAYLAND_DISPLAY"
    fi
    
    # Configurar variables de entorno Qt/Wayland
    export QT_QPA_PLATFORM=wayland
    export QT_QPA_PLATFORMTHEME=qt6ct,qt5ct
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export QT_STYLE_OVERRIDE=kvantum
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Environment variables configured:"
    echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "  HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"
    echo "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
    echo "  QT_QPA_PLATFORMTHEME=$QT_QPA_PLATFORMTHEME"
    
    # Kill any existing quickshell instance
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Killing existing quickshell instances"
    pkill -x quickshell
    KILL_RESULT=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] pkill result: $KILL_RESULT"
    
    # Wait a moment to ensure clean shutdown
    sleep 0.5
    
    # Check if quickshell command exists
    if ! command -v quickshell &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: quickshell command not found"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current PATH: $PATH"
        exit 1
    fi
    
    # Start quickshell
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting quickshell from: $(which quickshell)"
    quickshell "$@"
    EXIT_CODE=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] quickshell exited with code: $EXIT_CODE"
} >> "$LOG_FILE" 2>&1
