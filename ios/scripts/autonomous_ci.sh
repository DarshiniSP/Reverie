#!/bin/zsh
# Autonomous CI monitoring - starts background polling and provides status checks
# Usage: ./autonomous_ci.sh [start|stop|status]

SCRIPT_DIR="${0:a:h}"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.ci_monitor.pid"
LOG_FILE="$PROJECT_ROOT/ci_monitor.log"

start_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "✓ CI monitoring already running (PID: $pid)"
            echo "  Log: $LOG_FILE"
            return 0
        else
            rm "$PID_FILE"
        fi
    fi
    
    echo "🚀 Starting autonomous CI monitoring..."
    
    # Start poll_ci.sh in background with logging
    nohup "$SCRIPT_DIR/poll_ci.sh" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    echo "✓ CI monitoring started (PID: $pid)"
    echo "  Log: $LOG_FILE"
    echo "  Status: ./scripts/autonomous_ci.sh status"
    echo "  Stop: ./scripts/autonomous_ci.sh stop"
}

stop_monitoring() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "⚠ CI monitoring not running"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "🛑 Stopping CI monitoring (PID: $pid)..."
        kill "$pid"
        rm "$PID_FILE"
        echo "✓ CI monitoring stopped"
    else
        echo "⚠ Process $pid not found (stale PID file)"
        rm "$PID_FILE"
    fi
}

show_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "✓ CI monitoring running (PID: $pid)"
            echo ""
            echo "Recent activity:"
            tail -20 "$LOG_FILE" 2>/dev/null || echo "  (no log yet)"
        else
            echo "✗ CI monitoring stopped (stale PID: $pid)"
            rm "$PID_FILE"
        fi
    else
        echo "✗ CI monitoring not running"
        echo ""
        echo "Start with: ./scripts/autonomous_ci.sh start"
    fi
}

case "${1:-status}" in
    start)
        start_monitoring
        ;;
    stop)
        stop_monitoring
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 [start|stop|status]"
        echo ""
        echo "Commands:"
        echo "  start   - Start autonomous CI monitoring in background"
        echo "  stop    - Stop the monitoring process"
        echo "  status  - Show current status and recent activity"
        exit 1
        ;;
esac
