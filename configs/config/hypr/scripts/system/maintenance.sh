#!/bin/bash
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# █▀░ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
# Script de mantenimiento para Hyprland

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Verificar si se ejecuta como root para algunas operaciones
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

log "Iniciando mantenimiento del sistema Hyprland..."

# Función para limpiar cachés
clean_caches() {
    log "Limpiando cachés..."

    # Cache de Hyprland
    if [ -d "$HOME/.cache/hyprland" ]; then
        rm -rf "$HOME/.cache/hyprland"
        success "Cache de Hyprland eliminado"
    fi

    # Cache de shaders
    if [ -d "$HOME/.cache/shader-cache" ]; then
        rm -rf "$HOME/.cache/shader-cache"
        success "Cache de shaders eliminado"
    fi

    # Thumbnails
    if [ -d "$HOME/.cache/thumbnails" ]; then
        rm -rf "$HOME/.cache/thumbnails"
        success "Thumbnails eliminados"
    fi

    # Cache de fuentes
    if [ -d "$HOME/.cache/fontconfig" ]; then
        rm -rf "$HOME/.cache/fontconfig"
        success "Cache de fuentes eliminado"
    fi
}

# Función para limpiar cachés de aplicaciones
clean_app_caches() {
    log "Limpiando cachés de aplicaciones..."

    # Firefox
    if [ -d "$HOME/.cache/mozilla/firefox" ]; then
        rm -rf "$HOME/.cache/mozilla/firefox"/*.default*/cache2
        success "Cache de Firefox eliminado"
    fi

    # Chromium
    if [ -d "$HOME/.cache/chromium" ]; then
        rm -rf "$HOME/.cache/chromium"/*/Cache
        success "Cache de Chromium eliminado"
    fi

    # Otros navegadores
    for cache_dir in "$HOME/.cache"/*; do
        if [[ -d "$cache_dir" && ("$cache_dir" =~ .*chrome.* || "$cache_dir" =~ .*brave.*) ]]; then
            rm -rf "$cache_dir"/*/Cache
            success "Cache de $(basename "$cache_dir") eliminado"
        fi
    done
}

# Función para optimizar base de datos de localizaciones
optimize_locales() {
    log "Optimizando configuración regional..."
    if command -v locale-gen &> /dev/null; then
        $SUDO locale-gen --purge 2>/dev/null || warning "No se pudo regenerar locales"
    fi
}

# Función para limpiar paquetes huérfanos
clean_orphans() {
    log "Buscando paquetes huérfanos..."

    if command -v pacman &> /dev/null; then
        orphans=$(pacman -Qdtq 2>/dev/null || true)
        if [ -n "$orphans" ]; then
            warning "Paquetes huérfanos encontrados:"
            echo "$orphans"
            echo "¿Deseas eliminarlos? (s/N)"
            read -r respuesta
            if [[ "$respuesta" =~ ^[Ss]$ ]]; then
                $SUDO pacman -Rns $orphans
                success "Paquetes huérfanos eliminados"
            fi
        else
            success "No se encontraron paquetes huérfanos"
        fi
    fi
}

# Función para limpiar journal de systemd
clean_journal() {
    log "Limpiando journal de systemd..."
    if command -v journalctl &> /dev/null; then
        $SUDO journalctl --vacuum-time=7days 2>/dev/null || warning "No se pudo limpiar journal"
        success "Journal limpiado (últimos 7 días)"
    fi
}

# Función para verificar servicios de usuario
check_user_services() {
    log "Verificando servicios de usuario..."

    # Reiniciar servicios importantes
    systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || warning "No se pudieron reiniciar servicios de audio"

    # Verificar estado de servicios críticos
    if systemctl --user is-active --quiet hypridle; then
        success "Hypridle activo"
    else
        warning "Hypridle no está activo"
        systemctl --user start hypridle 2>/dev/null && success "Hypridle iniciado"
    fi
}

# Función para verificar permisos
check_permissions() {
    log "Verificando permisos de archivos..."

    # Verificar permisos de scripts
    find "$HOME/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Verificar permisos de configuración
    chmod 644 "$HOME/.config/hypr/"*.conf 2>/dev/null || true
    chmod 644 "$HOME/.config/hypr/config/"*.conf 2>/dev/null || true

    success "Permisos verificados"
}

# Función para mostrar estadísticas del sistema
show_stats() {
    log "Estadísticas del sistema:"
    echo "Uso de disco:"
    df -h | grep -E "(Filesystem|/dev/)" | head -6

    echo
    echo "Uso de memoria:"
    free -h

    echo
    echo "Procesos de Hyprland:"
    ps aux | grep -E "(hypr|waybar|dunst|rofi)" | grep -v grep | wc -l | xargs echo "- procesos activos"
}

# Menú principal
main() {
    echo "🧹 Mantenimiento de Hyprland"
    echo "============================"
    echo "1. Limpiar cachés del sistema"
    echo "2. Limpiar cachés de aplicaciones"
    echo "3. Optimizar configuración regional"
    echo "4. Buscar y limpiar paquetes huérfanos"
    echo "5. Limpiar journal de systemd"
    echo "6. Verificar servicios de usuario"
    echo "7. Verificar permisos"
    echo "8. Mostrar estadísticas"
    echo "9. Ejecutar mantenimiento completo"
    echo "0. Salir"
    echo
    echo "Selecciona una opción:"

    read -r opcion

    case $opcion in
        1) clean_caches ;;
        2) clean_app_caches ;;
        3) optimize_locales ;;
        4) clean_orphans ;;
        5) clean_journal ;;
        6) check_user_services ;;
        7) check_permissions ;;
        8) show_stats ;;
        9)
            clean_caches
            clean_app_caches
            optimize_locales
            clean_journal
            check_user_services
            check_permissions
            show_stats
            ;;
        0)
            echo "¡Hasta luego!"
            exit 0
            ;;
        *)
            error "Opción no válida"
            ;;
    esac

    echo
    echo "¿Deseas realizar otra operación? (s/N)"
    read -r respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        main
    fi
}

# Ejecutar menú si no hay argumentos
if [ $# -eq 0 ]; then
    main
else
    # Si se pasan argumentos, ejecutar mantenimiento completo automáticamente
    case $1 in
        "auto")
            clean_caches
            clean_app_caches
            optimize_locales
            clean_journal
            check_user_services
            check_permissions
            success "Mantenimiento automático completado"
            ;;
        *)
            echo "Uso: $0 [auto]"
            echo "  sin argumentos: menú interactivo"
            echo "  auto: mantenimiento completo automático"
            exit 1
            ;;
    esac
fi
