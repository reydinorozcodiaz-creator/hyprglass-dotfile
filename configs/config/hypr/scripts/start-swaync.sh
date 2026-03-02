#!/bin/bash

# Fix GSettings and GTK schemas for swaync
export XDG_DATA_DIRS=/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS
export GTK_THEME=Adwaita:dark

# Start swaync
swaync "$@"
