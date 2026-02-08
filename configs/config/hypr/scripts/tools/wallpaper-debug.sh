#!/bin/bash
# Wallpaper Debug Script
# Helps diagnose issues with AleatoryWall.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔍 Wallpaper System Diagnostic${NC}"
echo "=================================="
echo

# Check wallpaper directories
echo -e "${CYAN}📁 Checking wallpaper directories:${NC}"
WALL_DIRS=(
    "$HOME/Wallpapers"
    "$HOME/Pictures/Wallpapers" 
    "$HOME/.local/share/wallpapers"
    "/usr/share/pixmaps"
    "/usr/share/backgrounds"
)

for dir in "${WALL_DIRS[@]}"; do
    if [[ -L "$dir" ]]; then
        real_dir=$(readlink -f "$dir")
        echo -e "  ${YELLOW}🔗${NC} $dir -> $real_dir"
        if [[ -d "$real_dir" ]]; then
            image_count=$(find "$real_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | wc -l)
            echo -e "     ${GREEN}✓${NC} Target exists ($image_count images)"
        else
            echo -e "     ${RED}✗${NC} Target does not exist"
        fi
    elif [[ -d "$dir" ]]; then
        image_count=$(find "$dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓${NC} $dir ($image_count images)"
    else
        echo -e "  ${RED}✗${NC} $dir (not found)"
    fi
done

echo

# Check dependencies
echo -e "${CYAN}🔧 Checking dependencies:${NC}"
deps=("swww" "wal" "swaync-client" "find" "shuf")
for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        version=$(command -v "$dep" 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} $dep ($version)"
    else
        echo -e "  ${RED}✗${NC} $dep (not found)"
    fi
done

echo

# Check running processes
echo -e "${CYAN}🔄 Checking running processes:${NC}"
if pgrep -f "AleatoryWall" >/dev/null; then
    echo -e "  ${GREEN}✓${NC} AleatoryWall is running"
    pgrep -f "AleatoryWall" | while read pid; do
        echo -e "    PID: $pid"
    done
else
    echo -e "  ${YELLOW}⚠${NC} AleatoryWall is not running"
fi

if pgrep -x "swww-daemon" >/dev/null; then
    echo -e "  ${GREEN}✓${NC} swww-daemon is running"
else
    echo -e "  ${YELLOW}⚠${NC} swww-daemon is not running"
fi

echo

# Check logs
echo -e "${CYAN}📋 Checking logs:${NC}"
LOG_FILE="$HOME/.config/hypr/logs/aleatory-wall.log"
if [[ -f "$LOG_FILE" ]]; then
    echo -e "  ${GREEN}✓${NC} Log file exists: $LOG_FILE"
    echo -e "  ${BLUE}📄${NC} Last 10 log entries:"
    tail -n 10 "$LOG_FILE" | while read line; do
        echo -e "    ${YELLOW}│${NC} $line"
    done
else
    echo -e "  ${YELLOW}⚠${NC} No log file found at $LOG_FILE"
fi

echo

# Check current wallpaper
echo -e "${CYAN}🖼️  Current wallpaper info:${NC}"
CURRENT_WALL="$HOME/.config/hypr/.current-wallpaper"
if [[ -f "$CURRENT_WALL" ]]; then
    current=$(cat "$CURRENT_WALL")
    echo -e "  ${GREEN}✓${NC} Current: $(basename "$current")"
    echo -e "  ${BLUE}📍${NC} Path: $current"
    if [[ -f "$current" ]]; then
        size=$(du -h "$current" | cut -f1)
        echo -e "  ${BLUE}📏${NC} Size: $size"
    else
        echo -e "  ${RED}✗${NC} File no longer exists"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No current wallpaper info"
fi

echo

# Test wallpaper change
echo -e "${CYAN}🧪 Testing wallpaper change:${NC}"
echo -e "  ${BLUE}ℹ${NC} Running AleatoryWall once..."

# Run the script once in debug mode
DEBUG=true "$HOME/.config/hypr/scripts/tools/AleatoryWall.sh" --once 2>&1 | while read line; do
    echo -e "    ${YELLOW}│${NC} $line"
done

echo
echo -e "${GREEN}✅ Diagnostic complete!${NC}"
echo
echo -e "${YELLOW}💡 Troubleshooting tips:${NC}"
echo -e "  • Make sure your wallpaper directory has images"
echo -e "  • Check that symlinks point to valid directories"
echo -e "  • Verify all dependencies are installed"
echo -e "  • Check the log file for detailed error messages"
echo -e "  • Run: DEBUG=true ~/.config/hypr/scripts/tools/AleatoryWall.sh --debug"
