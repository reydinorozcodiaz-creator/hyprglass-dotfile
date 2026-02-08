#!/usr/bin/bash
# Screenshot selection (area) copied to clipboard
grim -g "$(slurp)" - | wl-copy -t image/png
notify-send "Screenshot copied to clipboard"
