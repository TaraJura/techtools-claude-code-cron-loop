#!/bin/bash
# Show status of all agents and their recent activity

HOME_DIR="/home/novakj"

echo "========================================"
echo "       AGENT SYSTEM STATUS"
echo "========================================"
echo ""

# Show tasks summary
echo "=== TASK BOARD SUMMARY ==="
echo ""
grep -E "^### TASK-|Status:|Assigned:" "$HOME_DIR/tasks.md" 2>/dev/null | head -30
echo ""

# Show recent logs for each actor
for actor in idea-maker project-manager developer tester; do
    ACTOR_DIR="$HOME_DIR/actors/$actor"
    LOG_DIR="$ACTOR_DIR/logs"

    echo "=== $actor - Recent Activity ==="

    if [ -d "$LOG_DIR" ]; then
        LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo "Latest log: $LATEST_LOG"
            echo "---"
            tail -20 "$LATEST_LOG"
        else
            echo "No logs yet"
        fi
    else
        echo "No logs directory"
    fi
    echo ""
done

echo "========================================"
echo "Run './scripts/cron-orchestrator.sh' to trigger agents manually"
echo "========================================"
