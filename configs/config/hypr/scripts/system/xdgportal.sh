#!/usr/bin/env bash
set -u

debug=0
for arg in "$@"; do
	case "$arg" in
		--debug|-d) debug=1 ;;
	esac
done

if [[ "${XDGPORTAL_DEBUG:-0}" == "1" ]]; then
	debug=1
fi

log() {
	(( debug == 1 )) || return 0
	echo "[xdgportal] $*" >&2
}

bg_pids=()

run() {
	if (( debug == 1 )); then
		log "+ $*"
		"$@"
	else
		"$@" >/dev/null 2>&1
	fi
}

start_bg() {
	if (( debug == 1 )); then
		log "+ (bg) $*"
		"$@" &
		bg_pids+=("$!")
	else
		"$@" >/dev/null 2>&1 &
	fi
}

kill_and_wait() {
	# Use -f to avoid the 15-char comm limitation and to match full cmdline.
	# Argument should be a regex that matches the executable name.
	local pattern="$1"
	local timeout_s="${2:-2}"
	local step_s="0.1"
	local waited="0"

	if pgrep -f "$pattern" >/dev/null 2>&1; then
		log "killing: $pattern"
		run pkill -f "$pattern" || true
		while pgrep -f "$pattern" >/dev/null 2>&1; do
			if awk -v w="$waited" -v t="$timeout_s" 'BEGIN{exit !(w>=t)}'; then
				log "timeout waiting for exit: $pattern"
				break
			fi
			sleep "$step_s"
			waited="$(awk -v w="$waited" -v s="$step_s" 'BEGIN{printf "%.1f", w+s}')"
		done
		log "stopped: $pattern"
	else
		log "not running: $pattern"
	fi
}

sleep 1

# Ensure portal sees the right desktop/session.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
	export XDG_CURRENT_DESKTOP="Hyprland"
	export XDG_SESSION_DESKTOP="Hyprland"
fi

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"

log "env: WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
log "env: XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"
log "env: XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
log "env: XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
	run dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP || true
fi

if command -v systemctl >/dev/null 2>&1; then
	run systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP || true
	# Stop units if they exist (ignore errors if they don't).
	run systemctl --user stop xdg-desktop-portal-hyprland.service xdg-desktop-portal-wlr.service xdg-desktop-portal.service || true
fi

# Kill any leftover processes and wait to avoid D-Bus name conflicts.
kill_and_wait "(^|/)xdg-desktop-portal-hyprland($| )" 3
kill_and_wait "(^|/)xdg-desktop-portal-wlr($| )" 3
kill_and_wait "(^|/)xdg-desktop-portal($| )" 3

# Start backend first, then the main portal.
if command -v systemctl >/dev/null 2>&1 && systemctl --user status xdg-desktop-portal-hyprland.service >/dev/null 2>&1; then
	run systemctl --user restart xdg-desktop-portal-hyprland.service
else
	if [[ -x /usr/lib/xdg-desktop-portal-hyprland ]]; then
		start_bg /usr/lib/xdg-desktop-portal-hyprland
	elif command -v xdg-desktop-portal-hyprland >/dev/null 2>&1; then
		start_bg xdg-desktop-portal-hyprland
	else
		log "hyprland portal backend not found"
	fi
fi

sleep 1

if command -v systemctl >/dev/null 2>&1 && systemctl --user status xdg-desktop-portal.service >/dev/null 2>&1; then
	run systemctl --user restart xdg-desktop-portal.service
else
	if [[ -x /usr/lib/xdg-desktop-portal ]]; then
		start_bg /usr/lib/xdg-desktop-portal
	elif command -v xdg-desktop-portal >/dev/null 2>&1; then
		start_bg xdg-desktop-portal
	else
		log "xdg-desktop-portal not found"
	fi
fi

if (( debug == 1 )) && (( ${#bg_pids[@]} > 0 )); then
	log "debug mode: waiting on portal processes (Ctrl+C to stop)"
	wait "${bg_pids[@]}"
fi
