#!/bin/bash
# Orchestrator script for running agents in sequence
# This ensures agents don't conflict with each other

set -e

HOME_DIR="/home/novakj"
SCRIPTS_DIR="$HOME_DIR/scripts"
LOCK_FILE="/tmp/agent-orchestrator.lock"
STATUS_SCRIPT="$SCRIPTS_DIR/update-agent-status.sh"

# Helper function to update agent status
update_status() {
    local agent="$1"
    local status="$2"
    local message="${3:-}"
    "$STATUS_SCRIPT" "$agent" "$status" "$message" 2>/dev/null || true
}

# Helper function to mark orchestrator start/end
update_orchestrator_status() {
    local running="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local status_file="/var/www/cronloop.techtools.cz/api/agent-status.json"

    # Convert bash boolean to Python boolean
    local py_running="False"
    if [ "$running" = "true" ]; then
        py_running="True"
    fi

    if [ -f "$status_file" ]; then
        python3 << PYTHON
import json
try:
    with open("$status_file", "r") as f:
        data = json.load(f)
    data["orchestrator_running"] = $py_running
    data["timestamp"] = "$timestamp"
    if $py_running:
        data["orchestrator_started"] = "$timestamp"
    else:
        # Mark all agents as idle when orchestrator finishes
        for agent in data.get("agents", {}):
            if data["agents"][agent]["status"] == "running":
                data["agents"][agent]["status"] = "idle"
        data["current_agent"] = None
    with open("$status_file", "w") as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f"Error: {e}")
PYTHON
    fi
}

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Another orchestrator is running (PID: $PID). Exiting."
        exit 0
    fi
fi

echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE; update_orchestrator_status false" EXIT

cd "$HOME_DIR"

echo "=== Agent Orchestrator Started: $(date) ==="

# Mark orchestrator as running
update_orchestrator_status true

# Pull latest changes first
echo "Pulling latest changes..."
git pull --rebase || true

# Run Idea Maker first (generates new ideas for backlog)
echo ""
echo ">>> Running Idea Maker Agent..."
update_status "idea-maker" "running" "Generating feature ideas"
"$SCRIPTS_DIR/run-actor.sh" idea-maker && update_status "idea-maker" "completed" || update_status "idea-maker" "error" "Agent failed"

# Wait a bit to avoid conflicts
sleep 5

# Run Project Manager (assigns tasks from backlog)
echo ""
echo ">>> Running Project Manager Agent..."
update_status "project-manager" "running" "Assigning tasks"
"$SCRIPTS_DIR/run-actor.sh" project-manager && update_status "project-manager" "completed" || update_status "project-manager" "error" "Agent failed"

# Wait a bit to avoid conflicts
sleep 5

# Then run Developer (implements tasks)
echo ""
echo ">>> Running Developer Agent..."
update_status "developer" "running" "Implementing tasks"
"$SCRIPTS_DIR/run-actor.sh" developer && update_status "developer" "completed" || update_status "developer" "error" "Agent failed"

# Wait a bit to avoid conflicts
sleep 5

# Then run Developer 2 (implements tasks assigned to developer2)
echo ""
echo ">>> Running Developer 2 Agent..."
update_status "developer2" "running" "Implementing tasks"
"$SCRIPTS_DIR/run-actor.sh" developer2 && update_status "developer2" "completed" || update_status "developer2" "error" "Agent failed"

# Wait a bit to avoid conflicts
sleep 5

# Finally run Tester (tests completed work and gives feedback)
echo ""
echo ">>> Running Tester Agent..."
update_status "tester" "running" "Verifying work"
"$SCRIPTS_DIR/run-actor.sh" tester && update_status "tester" "completed" || update_status "tester" "error" "Agent failed"

# Wait a bit to avoid conflicts
sleep 5

# Last: run Security (reviews for vulnerabilities)
echo ""
echo ">>> Running Security Agent..."
update_status "security" "running" "Security review"
"$SCRIPTS_DIR/run-actor.sh" security && update_status "security" "completed" || update_status "security" "error" "Agent failed"

# Update dead man's switch heartbeat
echo ""
echo ">>> Updating dead man's switch heartbeat..."
"$SCRIPTS_DIR/update-deadman.sh" 2>/dev/null || echo "Warning: Could not update dead man's switch"

echo ""
echo "=== Agent Orchestrator Completed: $(date) ==="
