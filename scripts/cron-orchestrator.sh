#!/bin/bash
# Orchestrator script for running agents in sequence
# This ensures agents don't conflict with each other

set -e

HOME_DIR="/home/novakj"
SCRIPTS_DIR="$HOME_DIR/scripts"
LOCK_FILE="/tmp/agent-orchestrator.lock"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Another orchestrator is running (PID: $PID). Exiting."
        exit 0
    fi
fi

echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

cd "$HOME_DIR"

echo "=== Agent Orchestrator Started: $(date) ==="

# Pull latest changes first
echo "Pulling latest changes..."
git pull --rebase || true

# Run Idea Maker first (generates new ideas for backlog)
echo ""
echo ">>> Running Idea Maker Agent..."
"$SCRIPTS_DIR/run-actor.sh" idea-maker || true

# Wait a bit to avoid conflicts
sleep 5

# Run Project Manager (assigns tasks from backlog)
echo ""
echo ">>> Running Project Manager Agent..."
"$SCRIPTS_DIR/run-actor.sh" project-manager || true

# Wait a bit to avoid conflicts
sleep 5

# Then run Developer (implements tasks)
echo ""
echo ">>> Running Developer Agent..."
"$SCRIPTS_DIR/run-actor.sh" developer || true

# Wait a bit to avoid conflicts
sleep 5

# Finally run Tester (tests completed work and gives feedback)
echo ""
echo ">>> Running Tester Agent..."
"$SCRIPTS_DIR/run-actor.sh" tester || true

# Wait a bit to avoid conflicts
sleep 5

# Last: run Security (reviews for vulnerabilities)
echo ""
echo ">>> Running Security Agent..."
"$SCRIPTS_DIR/run-actor.sh" security || true

echo ""
echo "=== Agent Orchestrator Completed: $(date) ==="
