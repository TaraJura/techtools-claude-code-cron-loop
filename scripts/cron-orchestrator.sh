#!/bin/bash
# Orchestrator script for running agents in sequence
# Builds the PDF Editor web application at cronloop.techtools.cz

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

# Run Idea Maker first (generates new PDF editor feature ideas)
echo ""
echo ">>> Running Idea Maker Agent..."
"$SCRIPTS_DIR/run-actor.sh" idea-maker || echo "WARNING: idea-maker failed"

sleep 5

# Run Project Manager (assigns tasks from backlog)
echo ""
echo ">>> Running Project Manager Agent..."
"$SCRIPTS_DIR/run-actor.sh" project-manager || echo "WARNING: project-manager failed"

sleep 5

# Run Developer (implements PDF editor features)
echo ""
echo ">>> Running Developer Agent..."
"$SCRIPTS_DIR/run-actor.sh" developer || echo "WARNING: developer failed"

sleep 5

# Run Developer 2 (implements features in parallel)
echo ""
echo ">>> Running Developer 2 Agent..."
"$SCRIPTS_DIR/run-actor.sh" developer2 || echo "WARNING: developer2 failed"

sleep 5

# Run Tester (tests completed PDF editor features)
echo ""
echo ">>> Running Tester Agent..."
"$SCRIPTS_DIR/run-actor.sh" tester || echo "WARNING: tester failed"

sleep 5

# Run Security (reviews file handling, XSS, upload validation)
echo ""
echo ">>> Running Security Agent..."
"$SCRIPTS_DIR/run-actor.sh" security || echo "WARNING: security failed"

echo ""
echo "=== Agent Orchestrator Completed: $(date) ==="
