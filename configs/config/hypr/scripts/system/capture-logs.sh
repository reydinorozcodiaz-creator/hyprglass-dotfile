#!/bin/bash
# Script para capturar logs de Hyprland automáticamente

LOGS_DIR="$HOME/.local/share/hyprland/logs"
mkdir -p "$LOGS_DIR"

# Crear archivo de log con timestamp
LOG_FILE="$LOGS_DIR/hyprland-$(date +%Y-%m-%d_%H-%M-%S).log"

# Ejecutar Hyprland y capturar output
Hyprland > "$LOG_FILE" 2>&1

echo "Logs guardados en: $LOG_FILE"
