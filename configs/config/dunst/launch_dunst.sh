#!/bin/bash

# Lista de notifiers conocidos que queremos cerrar si están corriendo (excepto dunst)
NOTIFIERS=("xfce4-notifyd" "mako" "notify-osd" "mate-notification-daemon")

# Cerrar todos los notificadores excepto dunst
for notifier in "${NOTIFIERS[@]}"; do
    if pgrep -f "$notifier" > /dev/null; then
        echo "Cerrando $notifier..."
        pkill -x "$notifier"
    fi
done

# Exportar todas las variables de pywal al entorno
set -a
source "$HOME/.cache/wal/colors.sh"
set +a
envsubst < "$HOME/.config/dunst/dunstrc.template" > "$HOME/.config/dunst/dunstrc"
# También matar otras instancias de dunst, por si acaso
pkill -x dunst

# Esperar un momento antes de lanzar dunst
sleep 1

# Ejecutar dunst como demonio
echo "Usando dunstrc generado con colores pywal"
dunst &

