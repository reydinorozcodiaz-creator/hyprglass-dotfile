#!/bin/bash
# SWWW Control Script
# Easy control for swww wallpaper daemon

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
WALLPAPER_DIRS=(
    "$HOME/Wallpapers"
    "$HOME/Pictures/Wallpapers"
    "$HOME/.local/share/wallpapers"
    "/usr/share/pixmaps"
    "/usr/share/backgrounds"
)

IMAGE_FORMATS=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.bmp" "*.webp")

show_help() {
    echo -e "${CYAN}SWWW Control Script${NC}"
    echo "===================="
    echo
    echo -e "${YELLOW}Usage:${NC} $0 [OPTION]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}start${NC}     Start swww daemon"
    echo -e "  ${GREEN}stop${NC}      Stop swww daemon"
    echo -e "  ${GREEN}restart${NC}   Restart swww daemon"
    echo -e "  ${GREEN}status${NC}    Show daemon status"
    echo -e "  ${GREEN}random${NC}    Set random wallpaper"
    echo -e "  ${GREEN}set${NC}       Set specific wallpaper (interactive)"
    echo -e "  ${GREEN}list${NC}      List available wallpapers"
    echo -e "  ${GREEN}current${NC}   Show current wallpaper info"
    echo -e "  ${GREEN}help${NC}      Show this help"
    echo
}

start_daemon() {
    if pgrep -x "swww-daemon" >/dev/null; then
        echo -e "${YELLOW}⚠️  swww-daemon is already running${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🚀 Starting swww daemon...${NC}"
    swww-daemon &
    sleep 2
    
    if pgrep -x "swww-daemon" >/dev/null; then
        echo -e "${GREEN}✅ swww-daemon started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start swww-daemon${NC}"
        return 1
    fi
}

stop_daemon() {
    if ! pgrep -x "swww-daemon" >/dev/null; then
        echo -e "${YELLOW}⚠️  swww-daemon is not running${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🛑 Stopping swww daemon...${NC}"
    pkill -x "swww-daemon"
    sleep 1
    
    if ! pgrep -x "swww-daemon" >/dev/null; then
        echo -e "${GREEN}✅ swww-daemon stopped successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Force killing swww-daemon...${NC}"
        pkill -9 -x "swww-daemon"
        echo -e "${GREEN}✅ swww-daemon force stopped${NC}"
    fi
}

restart_daemon() {
    echo -e "${BLUE}🔄 Restarting swww daemon...${NC}"
    stop_daemon
    sleep 1
    start_daemon
}

show_status() {
    echo -e "${CYAN}📊 SWWW Status${NC}"
    echo "==============="
    echo
    
    if pgrep -x "swww-daemon" >/dev/null; then
        local pid=$(pgrep -x "swww-daemon")
        echo -e "${GREEN}✅ Daemon Status:${NC} Running (PID: $pid)"
        
        # Show current wallpaper if available
        if command -v swww >/dev/null 2>&1; then
            local current_info=$(swww query 2>/dev/null)
            if [[ -n "$current_info" ]]; then
                echo -e "${BLUE}🖼️  Current Wallpaper:${NC}"
                echo "$current_info" | while read line; do
                    echo -e "   ${YELLOW}│${NC} $line"
                done
            fi
        fi
    else
        echo -e "${RED}❌ Daemon Status:${NC} Not running"
    fi
    echo
}

find_wallpaper_directory() {
    for dir in "${WALLPAPER_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            local count=0
            for format in "${IMAGE_FORMATS[@]}"; do
                count=$((count + $(find "$dir" -type f -iname "$format" 2>/dev/null | wc -l)))
            done
            
            if [[ $count -gt 0 ]]; then
                echo "$dir"
                return 0
            fi
        fi
    done
    return 1
}

set_random_wallpaper() {
    if ! pgrep -x "swww-daemon" >/dev/null; then
        echo -e "${RED}❌ swww-daemon is not running. Starting it...${NC}"
        start_daemon || return 1
    fi
    
    local wall_dir=$(find_wallpaper_directory)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ No wallpaper directory found with images${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Finding wallpapers in $wall_dir...${NC}"
    
    local wallpapers=()
    for format in "${IMAGE_FORMATS[@]}"; do
        while IFS= read -r -d '' file; do
            wallpapers+=("$file")
        done < <(find "$wall_dir" -type f -iname "$format" -print0 2>/dev/null)
    done
    
    if [[ ${#wallpapers[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No wallpapers found${NC}"
        return 1
    fi
    
    local random_wallpaper="${wallpapers[RANDOM % ${#wallpapers[@]}]}"
    local wallpaper_name=$(basename "$random_wallpaper")
    
    echo -e "${BLUE}🎨 Setting wallpaper: ${YELLOW}$wallpaper_name${NC}"
    
    if swww img "$random_wallpaper" --transition-type wipe --transition-duration 2; then
        echo -e "${GREEN}✅ Wallpaper set successfully${NC}"
        
        # Save current wallpaper info
        echo "$random_wallpaper" > "$HOME/.config/hypr/.current-wallpaper" 2>/dev/null || true
        
        # Generate colors with pywal if available
        if command -v wal >/dev/null 2>&1; then
            echo -e "${BLUE}🎨 Generating color palette...${NC}"
            wal -i "$random_wallpaper" --backend wal -q >/dev/null 2>&1 || true
        fi
    else
        echo -e "${RED}❌ Failed to set wallpaper${NC}"
        return 1
    fi
}

list_wallpapers() {
    local wall_dir=$(find_wallpaper_directory)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ No wallpaper directory found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📁 Available wallpapers in $wall_dir:${NC}"
    echo
    
    local count=0
    for format in "${IMAGE_FORMATS[@]}"; do
        while IFS= read -r file; do
            count=$((count + 1))
            local name=$(basename "$file")
            local size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo -e "${GREEN}$count.${NC} $name ${YELLOW}($size)${NC}"
        done < <(find "$wall_dir" -type f -iname "$format" 2>/dev/null | sort)
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No wallpapers found${NC}"
    else
        echo
        echo -e "${BLUE}📊 Total: $count wallpapers${NC}"
    fi
}

show_current() {
    echo -e "${CYAN}🖼️  Current Wallpaper Info${NC}"
    echo "=========================="
    echo
    
    if command -v swww >/dev/null 2>&1 && pgrep -x "swww-daemon" >/dev/null; then
        local current_info=$(swww query 2>/dev/null)
        if [[ -n "$current_info" ]]; then
            echo -e "${GREEN}✅ From swww query:${NC}"
            echo "$current_info" | while read line; do
                echo -e "   ${YELLOW}│${NC} $line"
            done
        else
            echo -e "${YELLOW}⚠️  No wallpaper info from swww${NC}"
        fi
    else
        echo -e "${RED}❌ swww-daemon not running${NC}"
    fi
    
    # Check saved wallpaper info
    local current_file="$HOME/.config/hypr/.current-wallpaper"
    if [[ -f "$current_file" ]]; then
        local saved_wallpaper=$(cat "$current_file")
        echo
        echo -e "${GREEN}✅ Saved wallpaper info:${NC}"
        echo -e "   ${YELLOW}│${NC} Path: $saved_wallpaper"
        echo -e "   ${YELLOW}│${NC} Name: $(basename "$saved_wallpaper")"
        if [[ -f "$saved_wallpaper" ]]; then
            local size=$(du -h "$saved_wallpaper" 2>/dev/null | cut -f1)
            echo -e "   ${YELLOW}│${NC} Size: $size"
        else
            echo -e "   ${RED}│${NC} File no longer exists"
        fi
    else
        echo -e "${YELLOW}⚠️  No saved wallpaper info${NC}"
    fi
}

# Main execution
case "${1:-help}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        restart_daemon
        ;;
    status)
        show_status
        ;;
    random)
        set_random_wallpaper
        ;;
    list)
        list_wallpapers
        ;;
    current)
        show_current
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        echo
        show_help
        exit 1
        ;;
esac
