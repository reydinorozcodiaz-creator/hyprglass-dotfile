#!/bin/bash
set -euo pipefail

# Fast bluetooth status check
# Returns compact output optimized for waybar

if ! command -v bluetoothctl &> /dev/null; then
    echo '{"text": "󰂲", "class": "no-controller", "tooltip": "bluetoothctl not found"}'
    exit 0
fi

# Check if bluetooth controller exists
if ! bluetoothctl show >/dev/null 2>&1; then
    echo '{"text": "󰂲", "class": "no-controller", "tooltip": "No Bluetooth controller found"}'
    exit 0
fi

# Get powered state only (much faster than full show output)
powered=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

if [[ "$powered" != "yes" ]]; then
    echo '{"text": "󰂲", "class": "off", "tooltip": "Bluetooth disabled"}'
    exit 0
fi

# Count connected devices (very fast)
connected=$(bluetoothctl devices Connected | wc -l)

if [[ $connected -gt 0 ]]; then
    tooltip="Connected devices: $connected"
    icon="󰂱"
    class="connected"
else
    tooltip="Bluetooth on - No devices connected"
    icon="󰂯"
    class="on"
fi

# Output JSON
printf '{"text": "%s%s", "class": "%s", "tooltip": "%s"}\n' "$icon" \
    "$([ $connected -gt 0 ] && echo " ($connected)" || echo "")" \
    "$class" "$tooltip"
