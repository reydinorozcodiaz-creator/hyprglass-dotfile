#!/usr/bin/env bash
set -u

debug=0
if [[ "${POLKIT_AGENT_DEBUG:-0}" == "1" ]] || [[ "${1:-}" == "--debug" ]]; then
	debug=1
fi

log() {
	(( debug == 1 )) || return 0
	echo "[polkit-agent] $*" >&2
}

# Start a Polkit authentication agent for graphical privilege escalation (pkexec, gparted, etc.).
# Pick the first available agent.

candidates=(
	"/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
	"/usr/libexec/polkit-gnome-authentication-agent-1"
	"polkit-gnome-authentication-agent-1"
	"/usr/lib/polkit-kde-authentication-agent-1"
	"polkit-kde-authentication-agent-1"
	"/usr/lib/lxqt-policykit-agent"
	"lxqt-policykit-agent"
	"/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
	"/usr/lib/polkit-mate/polkit-mate-authentication-agent-1"
)

for candidate in "${candidates[@]}"; do
	log "checking candidate: $candidate"
	original_candidate="$candidate"

	# Resolve command if it's in PATH
	if [[ "$candidate" != /* ]]; then
		resolved="$(command -v "$candidate" 2>/dev/null || true)"
		if [[ -z "$resolved" ]]; then
			log "  not in PATH: $candidate"
			continue
		fi
		candidate="$resolved"
		log "  resolved: $original_candidate -> $candidate"
	fi

	if [[ ! -x "$candidate" ]]; then
		log "  not executable: $candidate"
		continue
	fi

	# Avoid duplicates (pgrep name length limit -> use -f).
	base_name="$(basename "$candidate")"
	if pgrep -f "(^|/)${base_name//./\\.}($| )" >/dev/null 2>&1; then
		log "  already running: $base_name"
		exit 0
	fi

	log "  starting: $candidate"
	"$candidate" >/dev/null 2>&1 &
	log "  started pid: $!"
	exit 0

done

# No agent found; keep silent to avoid spam in Hyprland logs.
log "no polkit authentication agent found"
exit 0
