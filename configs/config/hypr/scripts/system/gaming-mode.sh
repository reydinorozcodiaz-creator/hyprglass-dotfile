#!/bin/bash
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# █▀░ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
# Script de modo gaming para Hyprland

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Función de log
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

info() {
    echo -e "${PURPLE}[ℹ]${NC} $1"
}

# Variables de estado
GAMING_MODE_FILE="$HOME/.config/hypr/.gaming_mode"
CONFIG_DIR="$HOME/.config/hypr"
ORIGINAL_CONFIG="$CONFIG_DIR/hyprland.conf.backup"
CURRENT_CONFIG="$CONFIG_DIR/hyprland.conf"

# Lista de procesos de juegos conocidos
GAMING_PROCESSES=(
    # Steam
    "steam"
    "Steam"
    # Wine/Proton
    "wine"
    "wineserver"
    # Juegos populares
    "csgo_linux64"
    "hl2_linux"
    "left4dead2"
    "dota2"
    "tf2"
    "gmod"
    "rust"
    "minecraft"
    "javaw"
    "factorio"
    "rimworld"
    "stardewvalley"
    "terraria"
    "celeste"
    "hollowknight"
    "deadcells"
    "hades"
    "bindingofisaac"
    "ftl"
    "intellijidea"
    "pycharm"
    "code"
    "atom"
    "sublime_text"
    # Emuladores
    "retroarch"
    "dolphin-emu"
    "pcsx2"
    "rpcs3"
    "cemu"
    "yuzu"
    "ryujinx"
    "citra"
    "melonDS"
    "mgba"
    "ppsspp"
    # Lanzadores
    "lutris"
    "heroic"
    "bottles"
    "proton"
    # Otros
    "gamemode"
    "mangohud"
)

# Función para detectar si hay juegos ejecutándose
detect_games() {
    for process in "${GAMING_PROCESSES[@]}"; do
        if pgrep -x "$process" > /dev/null 2>&1; then
            info "Juego detectado: $process"
            return 0
        fi
    done
    return 1
}

# Función para crear respaldo de configuración original
create_backup() {
    if [ ! -f "$ORIGINAL_CONFIG" ]; then
        log "Creando respaldo de configuración original..."
        cp "$CURRENT_CONFIG" "$ORIGINAL_CONFIG"
        success "Respaldo creado: $ORIGINAL_CONFIG"
    fi
}

# Función para aplicar configuración gaming
apply_gaming_config() {
    log "Aplicando configuración gaming..."

    # Crear configuración gaming temporal
    cat > "$CONFIG_DIR/hyprland-gaming.conf" << 'EOF'
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# █▀░ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
# Configuración gaming optimizada para Hyprland

# Desactivar animaciones para máximo rendimiento
animations {
    enabled = false
}

# Configuración minimalista
decoration {
    rounding = 0
    blur {
        enabled = false
    }
    drop_shadow = false
    shadow_range = 0
    shadow_render_power = 0
}

# Bordes mínimos
general {
    gaps_in = 0
    gaps_out = 0
    border_size = 1
    col.active_border = rgba(00ff00ff)
    col.inactive_border = rgba(333333ff)
}

# Desactivar efectos innecesarios
misc {
    disable_hyprland_logo = true
    vfr = true
    enable_stdout_logs = false
}

# Reglas específicas para juegos
windowrulev2 = fullscreen, class:(steam_app_.*)
windowrulev2 = fullscreen, class:(.*wine.*)
windowrulev2 = fullscreen, class:(.*proton.*)
windowrulev2 = fullscreen, class:(lutris)
windowrulev2 = fullscreen, class:(heroic)
windowrulev2 = fullscreen, class:(minecraft)
windowrulev2 = fullscreen, class:(dolphin-emu)
windowrulev2 = fullscreen, class:(pcsx2)
windowrulev2 = fullscreen, class:(rpcs3)
windowrulev2 = fullscreen, class:(cemu)
windowrulev2 = fullscreen, class:(yuzu)
windowrulev2 = fullscreen, class:(ryujinx)
windowrulev2 = fullscreen, class:(retroarch)

# Desactivar blur en ventanas de juegos
windowrulev2 = noblur, class:(steam_app_.*)
windowrulev2 = noblur, class:(.*wine.*)
windowrulev2 = noblur, class:(lutris)
windowrulev2 = noblur, class:(heroic)

# Prioridad alta para procesos de juegos
windowrulev2 = stayfocused, class:(steam_app_.*)
windowrulev2 = stayfocused, class:(.*wine.*)
EOF

    success "Configuración gaming aplicada"
}

# Función para restaurar configuración normal
restore_normal_config() {
    log "Restaurando configuración normal..."

    # Recargar configuración original
    hyprctl reload 2>/dev/null || warning "No se pudo recargar configuración"

    success "Configuración normal restaurada"
}

# Función para activar modo gaming
enable_gaming_mode() {
    if [ -f "$GAMING_MODE_FILE" ]; then
        warning "Modo gaming ya está activo"
        return
    fi

    log "Activando modo gaming..."

    # Crear respaldo si no existe
    create_backup

    # Aplicar configuración gaming
    apply_gaming_config

    # Crear archivo de estado
    echo "$(date)" > "$GAMING_MODE_FILE"
    echo "Gaming Mode: ON" >> "$GAMING_MODE_FILE"

    # Aplicar configuración
    hyprctl reload 2>/dev/null || warning "No se pudo recargar configuración"

    # Ejecutar gamemode si está disponible
    if command -v gamemode &> /dev/null; then
        log "Ejecutando gamemode..."
        gamemode &
    fi

    success "Modo gaming activado"
    info "Animaciones desactivadas, efectos visuales minimizados"
}

# Función para desactivar modo gaming
disable_gaming_mode() {
    if [ ! -f "$GAMING_MODE_FILE" ]; then
        warning "Modo gaming no está activo"
        return
    fi

    log "Desactivando modo gaming..."

    # Restaurar configuración normal
    restore_normal_config

    # Eliminar archivo de estado
    rm -f "$GAMING_MODE_FILE"

    success "Modo gaming desactivado"
    info "Animaciones y efectos visuales restaurados"
}

# Función para mostrar estado actual
show_status() {
    if [ -f "$GAMING_MODE_FILE" ]; then
        info "Estado: MODO GAMING ACTIVO"
        echo "Activado desde: $(cat "$GAMING_MODE_FILE" | head -1)"
        echo "Procesos de juegos detectados:"

        # Mostrar procesos de juegos activos
        for process in "${GAMING_PROCESSES[@]}"; do
            if pgrep -x "$process" > /dev/null 2>&1; then
                echo "  ✓ $process"
            fi
        done
    else
        info "Estado: MODO NORMAL"
        echo "No hay juegos detectados"
    fi
}

# Función para monitoreo automático
monitor_games() {
    log "Iniciando monitoreo automático de juegos..."

    while true; do
        sleep 5

        if detect_games; then
            # Si detecta juegos y no está en modo gaming, activarlo
            if [ ! -f "$GAMING_MODE_FILE" ]; then
                info "Juego detectado, activando modo gaming automáticamente..."
                enable_gaming_mode
            fi
        else
            # Si no detecta juegos y está en modo gaming, desactivarlo
            if [ -f "$GAMING_MODE_FILE" ]; then
                info "No se detectan juegos, desactivando modo gaming..."
                disable_gaming_mode
            fi
        fi
    done
}

# Función de ayuda
show_help() {
    cat << 'EOF'
🎮 MODO GAMING PARA HYPRLAND

USO:
    gaming-mode.sh [COMANDO]

COMANDOS:
    on, enable      Activar modo gaming manualmente
    off, disable    Desactivar modo gaming manualmente
    status          Mostrar estado actual
    monitor         Iniciar monitoreo automático
    auto            Ejecutar en modo automático (por defecto)
    help            Mostrar esta ayuda

EJEMPLOS:
    ./gaming-mode.sh on        # Activar modo gaming
    ./gaming-mode.sh status    # Ver estado actual
    ./gaming-mode.sh monitor   # Monitoreo automático

CARACTERÍSTICAS:
    • Desactiva animaciones y efectos visuales
    • Minimiza decoración de ventanas
    • Configura juegos en pantalla completa
    • Ejecuta gamemode si está disponible
    • Monitoreo automático de procesos de juegos

JUEGOS DETECTADOS:
    Steam, Wine/Proton, juegos nativos Linux,
    emuladores (RetroArch, Dolphin, PCSX2, etc.)
EOF
}

# Función principal
main() {
    case "${1:-auto}" in
        "on"|"enable")
            enable_gaming_mode
            ;;
        "off"|"disable")
            disable_gaming_mode
            ;;
        "status")
            show_status
            ;;
        "monitor")
            monitor_games
            ;;
        "auto")
            # Si hay juegos ejecutándose, activar modo gaming
            if detect_games; then
                enable_gaming_mode
            fi
            # Iniciar monitoreo
            monitor_games
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Comando no reconocido: $1"
            echo "Usa 'help' para ver opciones disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar función principal con argumentos
main "$@"
