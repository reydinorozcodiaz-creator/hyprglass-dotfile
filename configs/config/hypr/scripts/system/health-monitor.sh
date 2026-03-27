#!/bin/bash
# Hyprland System Health Monitor

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
LOG_FILE="$STATE_DIR/health.log"

mkdir -p "$(dirname "$LOG_FILE")"

check_hyprland_health() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    {
        echo "[$timestamp] Health Check"
        
        # Check if Hyprland is running
        if pgrep -x "Hyprland" > /dev/null; then
            echo "✅ Hyprland: Running"
        else
            echo "❌ Hyprland: Not running"
            return 1
        fi
        
        # Check memory usage
        local mem_usage=$(ps -o pid,ppid,cmd,%mem --sort=-%mem | grep Hyprland | head -1 | awk '{print $4}')
        echo "📊 Memory usage: ${mem_usage}%"
        
        # Check if memory usage is too high
        if (( $(echo "$mem_usage > 10" | bc -l) )); then
            echo "⚠️  High memory usage detected"
        fi
        
        # Check essential components
        for component in quickshell rofi hypridle; do
            if pgrep -x "$component" > /dev/null; then
                echo "✅ $component: Running"
            else
                echo "⚠️  $component: Not running"
            fi
        done
        
        echo "---"
        
    } >> "$LOG_FILE"
}

# Run health check
check_hyprland_health

# Keep only last 100 lines of log
tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
