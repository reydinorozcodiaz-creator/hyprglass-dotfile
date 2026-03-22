#!/bin/bash

# AleatoryWall.sh - Wallpaper changer with debugging
# Enhanced version with better error handling and logging

set -euo pipefail

# Configuration
Script_Wall=$(basename "$0")
LOG_FILE="$HOME/.config/hypr/logs/aleatory-wall.log"
QUEUE_FILE="$HOME/.config/hypr/logs/.wallpaper-queue"
QUEUE_LOCK_FILE="$HOME/.config/hypr/logs/.wallpaper-queue.lock"
LOCK_WALLPAPER_LINK="$HOME/.config/hypr/logs/.lock-wallpaper"
LOCK_WALLPAPER_STILL="$HOME/.config/hypr/logs/.lock-wallpaper.png"
BACKEND=${BACKEND:-swww} # swww | mpvpaper
OUTPUT=${OUTPUT:-all}    # all | eDP-1 | DP-1 ...
# mpv defaults tuned for a wallpaper use-case (lower CPU/RAM while keeping smooth playback).
# You can override with: --mpv-options "..." or env vars MPV_OPTS/MPV_IMAGE_OPTS.
MPV_OPTS=${MPV_OPTS:-"no-audio --loop-file=inf --hwdec=auto-safe --cache=no --demuxer-max-bytes=20M --demuxer-max-back-bytes=10M --scale=bilinear --cscale=bilinear --dscale=bilinear"}
# For static images, keep mpv open and do NOT loop (looping can cause flicker).
MPV_IMAGE_OPTS=${MPV_IMAGE_OPTS:-"no-audio --keep-open=yes --image-display-duration=inf --loop-file=no --hwdec=auto-safe --cache=no --demuxer-max-bytes=5M --demuxer-max-back-bytes=2M"}
MPV_FILL_MODE=${MPV_FILL_MODE:-cover} # cover | fit | stretch
MPVPAPER_AUTO_PAUSE=${MPVPAPER_AUTO_PAUSE:-true}
MPVPAPER_AUTO_STOP=${MPVPAPER_AUTO_STOP:-true}
DEBUG=${DEBUG:-false}
USE_PYWAL=false

# Wallpaper directories (in order of preference)
WALL_DIRS=(
    "$HOME/Wallpapers"
    "$HOME/Pictures/Wallpapers"
    "$HOME/.local/share/wallpapers"
)

# Supported formats by backend
# swww: images + animated gif
SWWW_FORMATS=("*.png" "*.jpg" "*.jpeg" "*.webp" "*.gif" "*.bmp" "*.tiff")
# mpvpaper/mpv: images + common video formats
MPVPAPER_FORMATS=("*.png" "*.jpg" "*.jpeg" "*.webp" "*.gif" "*.bmp" "*.tiff" "*.webm" "*.mp4" "*.mkv" "*.mov")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}[AleatoryWall]${NC} $1" >&2
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

debug() {
    if [[ "$DEBUG" == "true" ]]; then
        local message="[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
        echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

ensure_queue() {
    # Creates (or recreates) a shuffled queue of wallpapers.
    # The queue prevents repeats until a full cycle is completed.
    if [[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]]; then
        debug "(Re)building wallpaper queue"
        printf '%s\n' "${WALL[@]}" | shuf > "$QUEUE_FILE" || true

        # Avoid immediate repeat of current wallpaper when starting a new cycle.
        if [[ -f "$HOME/.config/hypr/logs/.current-wallpaper" ]]; then
            local current
            current=$(cat "$HOME/.config/hypr/logs/.current-wallpaper" 2>/dev/null || true)
            if [[ -n "$current" ]]; then
                local first
                first=$(head -n 1 "$QUEUE_FILE" 2>/dev/null || true)
                if [[ "$first" == "$current" ]] && [[ $(wc -l < "$QUEUE_FILE") -gt 1 ]]; then
                    debug "Rotating queue to avoid immediate repeat"
                    tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && echo "$first" >> "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
                fi
            fi
        fi
    fi
}

get_next_wallpaper() {
    local lock_fd
    if command -v flock >/dev/null 2>&1; then
        exec {lock_fd}>"$QUEUE_LOCK_FILE"
        flock -x "$lock_fd"
    fi

    ensure_queue

    local next
    next=$(head -n 1 "$QUEUE_FILE" 2>/dev/null || true)

    if [[ -z "$next" ]]; then
        # Queue unexpectedly empty; rebuild once.
        : > "$QUEUE_FILE" || true
        ensure_queue
        next=$(head -n 1 "$QUEUE_FILE" 2>/dev/null || true)
    fi

    if [[ -z "$next" ]]; then
        if [[ -n "${lock_fd:-}" ]]; then
            flock -u "$lock_fd" 2>/dev/null || true
            exec {lock_fd}>&-
        fi
        return 1
    fi

    # Pop the first entry from the queue.
    tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp" 2>/dev/null || true
    mv "$QUEUE_FILE.tmp" "$QUEUE_FILE" 2>/dev/null || true

    if [[ -n "${lock_fd:-}" ]]; then
        flock -u "$lock_fd" 2>/dev/null || true
        exec {lock_fd}>&-
    fi

    echo "$next"
}

kill_previous_instances() {
    debug "Checking for previous instances of $Script_Wall"
    local pids=$(pgrep -f "$Script_Wall" 2>/dev/null || true)

    for pid in $pids; do
        if [[ "$pid" != "$$" ]]; then
            debug "Killing previous instance with PID: $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
    done
}

load_wallpapers() {
    debug "Searching for image files in $WALL_DIR"
    local -a formats
    if [[ "$BACKEND" == "mpvpaper" ]]; then
        formats=("${MPVPAPER_FORMATS[@]}")
    else
        formats=("${SWWW_FORMATS[@]}")
    fi

    mapfile -t WALL < <(
        for format in "${formats[@]}"; do
            find "$WALL_DIR" -type f -iname "$format" 2>/dev/null
        done | sort -u
    )

    # Warn if user has video wallpapers but backend can't show them.
    if [[ "$BACKEND" != "mpvpaper" ]]; then
        local webm_count
        webm_count=$(find "$WALL_DIR" -maxdepth 1 -type f -iname '*.webm' 2>/dev/null | wc -l | tr -d ' ')
        if [[ "${webm_count:-0}" -gt 0 ]]; then
            log "Found $webm_count .webm file(s). swww only supports images/gifs, so .webm will be skipped. Use --backend mpvpaper if you want video wallpapers."
        fi
    fi
}

find_wallpaper_directory() {
    debug "Searching for wallpaper directories..."

    local -a formats
    if [[ "$BACKEND" == "mpvpaper" ]]; then
        formats=("${MPVPAPER_FORMATS[@]}")
    else
        formats=("${SWWW_FORMATS[@]}")
    fi

    for dir in "${WALL_DIRS[@]}"; do
        debug "Checking directory: $dir"

        if [[ -L "$dir" ]]; then
            local real_dir=$(readlink -f "$dir")
            debug "Directory $dir is a symlink pointing to: $real_dir"
            dir="$real_dir"
        fi

        if [[ -d "$dir" ]]; then
            debug "Directory exists: $dir"

            local image_count=0
            for format in "${formats[@]}"; do
                local count=$(find "$dir" -type f -iname "$format" 2>/dev/null | wc -l)
                image_count=$((image_count + count))
            done

            if [[ $image_count -gt 0 ]]; then
                success "Found wallpaper directory: $dir ($image_count images)"
                echo "$dir"
                return 0
            else
                debug "Directory $dir exists but contains no images"
            fi
        else
            debug "Directory does not exist: $dir"
        fi
    done

    error "No wallpaper directory found with images"
    return 1
}

WALL_DIR=$(find_wallpaper_directory)
if [[ $? -ne 0 ]]; then
    error "Cannot find any wallpaper directory. Please create one of:"
    for dir in "${WALL_DIRS[@]}"; do
        error "  - $dir"
    done
    exit 1
fi

debug "Using wallpaper directory: $WALL_DIR"

load_wallpapers

if [[ ${#WALL[@]} -eq 0 ]]; then
    error "No image files found in $WALL_DIR"
    if [[ "$BACKEND" == "mpvpaper" ]]; then
        error "Supported formats (mpvpaper): ${MPVPAPER_FORMATS[*]}"
    else
        error "Supported formats (swww): ${SWWW_FORMATS[*]}"
    fi
    exit 1
fi

success "Found ${#WALL[@]} wallpaper(s) in $WALL_DIR"

check_dependencies() {
    local required_deps=()
    local optional_deps=("wal")
    local missing_required=()

    if [[ "$BACKEND" == "mpvpaper" ]]; then
        required_deps=("mpvpaper")
    else
        required_deps=("swww")
    fi

    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_required+=("$dep")
        fi
    done

    if [[ ${#missing_required[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_required[*]}"
        error "Please install the missing packages"
        return 1
    fi

    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            debug "Optional dependency not found: $dep (features may be limited)"
        fi
    done

    debug "All required dependencies are available"
    return 0
}

get_outputs() {
    if [[ "$OUTPUT" != "all" ]]; then
        echo "$OUTPUT"
        return 0
    fi

    # Parse Hyprland monitor names (e.g., eDP-1, DP-1)
    hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}'
}

get_output_resolution() {
    # Prints: <width> <height> for a given output name.
    local out="$1"
    hyprctl monitors 2>/dev/null | awk -v out="$out" '
        $1=="Monitor" && $2==out {inmon=1; next}
        inmon && $1 ~ /^[0-9]+x[0-9]+@/ {
            split($1, a, "@");
            split(a[1], b, "x");
            print b[1], b[2];
            exit
        }
        $1=="Monitor" && $2!=out {inmon=0}
    '
}

media_kind() {
    # Returns: image | gif | video
    local path="$1"
    local ext="${path##*.}"
    ext="${ext,,}"
    case "$ext" in
        gif) echo "gif";;
        png|jpg|jpeg|webp|bmp|tiff) echo "image";;
        webm|mp4|mkv|mov) echo "video";;
        *) echo "video";;
    esac
}

update_lock_wallpaper() {
    # Hyprlock needs an image path. If current wallpaper is a video/gif, extract a still.
    local src="$1"
    local kind
    kind=$(media_kind "$src")

    if [[ "$kind" == "image" ]]; then
        ln -sf "$src" "$LOCK_WALLPAPER_LINK" 2>/dev/null || true
        return 0
    fi

    # For gif/video, create a still if possible.
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -hide_banner -loglevel error -y -i "$src" -vframes 1 "$LOCK_WALLPAPER_STILL" >/dev/null 2>&1 || true
        if [[ -f "$LOCK_WALLPAPER_STILL" ]]; then
            ln -sf "$LOCK_WALLPAPER_STILL" "$LOCK_WALLPAPER_LINK" 2>/dev/null || true
        fi
    fi
}

build_mpv_vf_for_output() {
    local out="$1"
    local w h
    read -r w h < <(get_output_resolution "$out" || true)
    if [[ -z "${w:-}" || -z "${h:-}" ]]; then
        # If we can't detect size, don't force a vf.
        return 0
    fi

    case "$MPV_FILL_MODE" in
        stretch)
            echo "scale=${w}:${h}"
            ;;
        fit)
            echo "scale=${w}:${h}:force_original_aspect_ratio=decrease,pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2"
            ;;
        cover|*)
            # Fill screen without distortion by cropping.
            echo "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}"
            ;;
    esac
}

mpv_options_for_media_on_output() {
    local out="$1"
    local media="$2"

    local kind
    kind=$(media_kind "$media")

    local opts
    if [[ "$kind" == "image" ]]; then
        # IMPORTANT: do NOT use loop for static images, it can cause rapid reload/flicker.
        opts="$MPV_IMAGE_OPTS"
    else
        # video/gif
        opts="$MPV_OPTS"
    fi

    # Apply scaling/cropping unless user already specified a vf.
    if [[ "$opts" != *"vf="* && "$opts" != *"vf-add="* ]]; then
        local vf
        vf=$(build_mpv_vf_for_output "$out" || true)
        if [[ -n "${vf:-}" ]]; then
            opts="$opts vf=$vf"
        fi
    fi

    echo "$opts"
}

stop_mpvpaper() {
    pkill -x mpvpaper 2>/dev/null || true
}

stop_swww_daemon() {
    pkill -x swww-daemon 2>/dev/null || true
}

ensure_swww_daemon() {
    debug "Checking if swww daemon is running"
    if ! pgrep -x "swww-daemon" >/dev/null 2>&1; then
        debug "Starting swww daemon"
        swww-daemon &
        sleep 2
        debug "swww daemon started"
    else
        debug "swww daemon already running"
    fi
}

set_wallpaper_mpvpaper() {
    local media="$1"

    # mpvpaper warns that swww-daemon may block it; stop it proactively.
    stop_swww_daemon
    stop_mpvpaper

    local outputs
    outputs=$(get_outputs | tr '\n' ' ')
    if [[ -z "${outputs// }" ]]; then
        error "No outputs found (hyprctl monitors returned empty)"
        return 1
    fi

    local kind
    kind=$(media_kind "$media")

    for out in $(get_outputs); do
        # --auto-pause / --auto-stop save resources when wallpaper isn't visible.
        # NOTE: auto-stop can be too aggressive for static images (may look like flicker).
        local -a mpvpaper_args
        mpvpaper_args=(--fork)
        if [[ "$MPVPAPER_AUTO_PAUSE" == "true" ]]; then
            mpvpaper_args+=(--auto-pause)
        fi
        if [[ "$MPVPAPER_AUTO_STOP" == "true" && "$kind" != "image" ]]; then
            mpvpaper_args+=(--auto-stop)
        fi
        local opts
        opts=$(mpv_options_for_media_on_output "$out" "$media")
        mpvpaper_args+=(--mpv-options "$opts" "$out" "$media")

        mpvpaper "${mpvpaper_args[@]}" >/dev/null 2>&1 || {
            error "mpvpaper failed on output $out"
            return 1
        }
    done
}


update_quickshell_state() {
    local wallpaper="$1"
    local state_file="$HOME/.config/quickshell/state.json"
    
    debug "Updating quickshell state.json with new wallpaper"
    
    if [[ ! -f "$state_file" ]]; then
        debug "state.json not found, skipping quickshell update"
        return 0
    fi
    
    # Use jq if available, otherwise use python
    if command -v jq >/dev/null 2>&1; then
        local tmp_file="${state_file}.tmp"
        jq --arg wp "$wallpaper" '.wallpaper.current = $wp' "$state_file" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$state_file"
        debug "Quickshell state updated with jq"
    elif command -v python3 >/dev/null 2>&1; then
        python3 <<-EOF 2>/dev/null
import json
try:
    with open("$state_file", "r") as f:
        data = json.load(f)
    if "wallpaper" not in data:
        data["wallpaper"] = {}
    data["wallpaper"]["current"] = "$wallpaper"
    with open("$state_file", "w") as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
EOF
        debug "Quickshell state updated with python"
    else
        debug "Neither jq nor python3 available, skipping quickshell update"
    fi
}

apply_wallpaper() {
    local wallpaper="$1"
    local wallpaper_name
    wallpaper_name=$(basename "$wallpaper")

    log "Changing wallpaper to: $wallpaper_name"

    if [[ ! -f "$wallpaper" ]]; then
        error "Wallpaper file not found: $wallpaper"
        return 1
    fi

    if [[ ! -r "$wallpaper" ]]; then
        error "Cannot read wallpaper file: $wallpaper"
        return 1
    fi

    if [[ "$BACKEND" == "mpvpaper" ]]; then
        debug "Setting wallpaper with mpvpaper"
        set_wallpaper_mpvpaper "$wallpaper" || return 1
        debug "mpvpaper wallpaper set successfully"
    else
        # If we are switching back to swww, make sure mpvpaper is not still running.
        stop_mpvpaper
        ensure_swww_daemon

        debug "Setting wallpaper with swww"
        if swww img "$wallpaper" --transition-type wipe --transition-duration 2 >/dev/null 2>&1; then
            debug "swww wallpaper set successfully"
        else
            error "Failed to set wallpaper with swww"
            return 1
        fi
    fi

    if [[ "$USE_PYWAL" == "true" ]]; then
        if command -v wal >/dev/null 2>&1; then
            debug "Generating color palette with pywal"
            if wal -i "$wallpaper" --backend wal -q >/dev/null 2>&1; then
                debug "Color palette generated successfully"
            else
                debug "Failed to generate color palette (non-critical)"
            fi
        else
            debug "pywal not available, skipping color generation"
        fi
    else
        debug "pywal not requested, skipping color generation"
    fi


    success "Wallpaper changed to: $wallpaper_name"
    echo "$wallpaper" > "$HOME/.config/hypr/logs/.current-wallpaper" 2>/dev/null || true
    update_quickshell_state "$wallpaper"
    update_lock_wallpaper "$wallpaper"
}


change_wallpaper() {
    debug "Starting wallpaper change process"
    local wallpaper
    wallpaper=$(get_next_wallpaper) || {
        error "Failed to get next wallpaper from queue"
        return 1
    }
    apply_wallpaper "$wallpaper"
}

cleanup() {
    log "Script terminating, cleaning up..."
    exit 0
}

trap cleanup SIGTERM SIGINT



main() {
    log "=== AleatoryWall Script Started ==="

    if ! check_dependencies; then
        exit 1
    fi

    local requested_once=false
    local requested_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG=true
                debug "Debug mode enabled"
                shift
                ;;
            --once)
                requested_once=true
                shift
                ;;
            --file)
                requested_file="${2:-}"
                shift 2
                ;;
            --backend)
                BACKEND="${2:-}"
                shift 2
                ;;
            --output)
                OUTPUT="${2:-all}"
                shift 2
                ;;
            --mpv-options)
                MPV_OPTS="${2:-$MPV_OPTS}"
                shift 2
                ;;
            --pywal|-p)
                USE_PYWAL=true
                log "pywal enabled via argument"
                shift
                ;;

            --help|-h)
                echo "AleatoryWall - Automatic wallpaper changer"
                echo "Usage: $0 [--debug] [--once] [--file PATH_OR_NAME] [--backend swww|mpvpaper] [--output all|OUTPUT] [--mpv-options \"...\"] [--pywal|-p] [--help]"
                echo "  --debug                 Enable debug output"
                echo "  --once                  Change wallpaper once and exit"
                echo "  --file PATH_OR_NAME      Force a specific wallpaper (absolute path or basename in the wallpaper dir)"
                echo "  --backend               Wallpaper backend: swww (default) or mpvpaper"
                echo "  --output                Output name (e.g., eDP-1) or 'all'"
                echo "  --mpv-options \"...\"     mpv options forwarded by mpvpaper (default: no-audio loop)"
                echo "  (mpvpaper image defaults) Uses MPV_IMAGE_OPTS=\"no-audio --image-display-duration=inf\" to avoid flicker"
                echo "  (mpvpaper scaling)        Uses MPV_FILL_MODE=cover|fit|stretch (default: cover)"
                echo "  (mpvpaper defaults)      Uses MPVPAPER_AUTO_PAUSE=true and MPVPAPER_AUTO_STOP=true to reduce CPU/RAM when hidden"
                echo "  --pywal|-p              Apply pywal color scheme after wallpaper change"
                echo "  --help                  Show this help"
                exit 0
                ;;
            *)
                echo "Unknown arg: $1" >&2
                exit 2
                ;;
        esac
    done

    if [[ "$BACKEND" != "swww" && "$BACKEND" != "mpvpaper" ]]; then
        echo "Invalid --backend: $BACKEND (use swww|mpvpaper)" >&2
        exit 2
    fi

    if [[ -n "$requested_file" ]]; then
        local target="$requested_file"
        # If not an existing file path, try to resolve as a name inside the wallpaper directory.
        if [[ ! -f "$target" ]]; then
            if [[ -f "$WALL_DIR/$target" ]]; then
                target="$WALL_DIR/$target"
            fi
        fi

        if [[ ! -f "$target" ]]; then
            error "Requested file not found: $requested_file"
            error "Tried: $requested_file and $WALL_DIR/$requested_file"
            exit 1
        fi

        # Force a single apply and exit.
        apply_wallpaper "$target"
        exit 0
    fi

    # Detect if a daemon instance is already running (exclude current PID).
    local other_pid=""
    other_pid=$(pgrep -f "${Script_Wall}" 2>/dev/null | awk -v me="$$" '$1 != me {print $1; exit}')

    if [[ -n "$other_pid" ]]; then
        log "Another instance is already running (PID: $other_pid) — changing wallpaper once"
    else
        log "Running AleatoryWall.sh in single-change mode"
    fi

    change_wallpaper
    exit 0
}

main "$@"
