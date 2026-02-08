#!/bin/bash
set -euo pipefail

case "$1" in
--check)
    pacman -Qu 2>/dev/null | wc -l || echo "0"
    ;;
--update)
    sakura -e sudo pacman -Syyu --noconfirm && notify-send "Update done" && pkill -SIGRTMIN+8 waybar
    exit 0
    ;;
esac
