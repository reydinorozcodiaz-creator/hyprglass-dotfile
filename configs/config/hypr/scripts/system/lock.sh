#!/bin/bash
set -euo pipefail

# Unified lock entrypoint.
# Prefers hyprlock on Hyprland, falls back to swaylock-fancy/swaylock if installed.

if command -v hyprlock >/dev/null 2>&1; then
  # --immediate avoids waiting for animations/idle.
  exec hyprlock --immediate
fi

if command -v swaylock-fancy >/dev/null 2>&1; then
  exec swaylock-fancy
fi

if command -v swaylock >/dev/null 2>&1; then
  exec swaylock -f -c 000000
fi

echo "No lock binary found (need hyprlock or swaylock)." >&2
exit 127
