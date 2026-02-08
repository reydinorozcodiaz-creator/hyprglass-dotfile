#!/bin/bash
# Idle daemon launcher.
# Prefers hypridle (Hyprland-native). Falls back to swayidle if hypridle is not installed.

set -euo pipefail

LOCK_CMD="$HOME/.config/hypr/scripts/system/lock.sh"

if command -v hypridle >/dev/null 2>&1; then
	exec hypridle
fi

if command -v swayidle >/dev/null 2>&1; then
	# 5 min: lock
	# 10 min: DPMS off
	# 2 h: suspend
	exec swayidle -w \
		timeout 300 "$LOCK_CMD" \
		timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on' \
		timeout 7200 'systemctl suspend' \
		before-sleep "$LOCK_CMD" \
		after-resume 'hyprctl dispatch dpms on'
fi

echo "No idle daemon found (need hypridle or swayidle)." >&2
exit 127
