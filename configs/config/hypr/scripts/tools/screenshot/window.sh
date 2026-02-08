#!/usr/bin/bash
# Screenshot active window copied to clipboard
grimblast copy active || exit
notify-send "Screenshot copied to clipboard"
