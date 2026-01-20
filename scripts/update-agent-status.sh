#!/bin/bash
# Script to update agent status JSON for the web dashboard
# Called by cron-orchestrator.sh when agents start/finish

set -e

STATUS_FILE="/var/www/cronloop.techtools.cz/api/agent-status.json"

# Arguments: <agent-name> <status> [message]
# Status can be: running, idle, completed, error
AGENT="$1"
STATUS="$2"
MESSAGE="${3:-}"

if [ -z "$AGENT" ] || [ -z "$STATUS" ]; then
    echo "Usage: $0 <agent-name> <status> [message]"
    echo "  agent-name: idea-maker, project-manager, developer, developer2, tester, security, supervisor"
    echo "  status: running, idle, completed, error"
    exit 1
fi

# Valid agents
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Check if agent is valid
VALID=0
for a in "${AGENTS[@]}"; do
    if [ "$a" == "$AGENT" ]; then
        VALID=1
        break
    fi
done

if [ "$VALID" -eq 0 ]; then
    echo "Error: Invalid agent name: $AGENT"
    exit 1
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize status file if it doesn't exist
if [ ! -f "$STATUS_FILE" ]; then
    cat > "$STATUS_FILE" <<'INIT'
{
    "timestamp": "",
    "orchestrator_running": false,
    "orchestrator_started": null,
    "current_agent": null,
    "agents": {
        "idea-maker": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "project-manager": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "developer": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "developer2": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "tester": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "security": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        },
        "supervisor": {
            "status": "idle",
            "last_run": null,
            "last_completed": null,
            "message": ""
        }
    }
}
INIT
fi

# Create temporary file
TEMP_FILE=$(mktemp)

# Read current status and update
python3 << PYTHON
import json
import sys

try:
    with open("$STATUS_FILE", "r") as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    data = {
        "timestamp": "",
        "orchestrator_running": False,
        "orchestrator_started": None,
        "current_agent": None,
        "agents": {
            "idea-maker": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "project-manager": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "developer": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "developer2": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "tester": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "security": {"status": "idle", "last_run": None, "last_completed": None, "message": ""},
            "supervisor": {"status": "idle", "last_run": None, "last_completed": None, "message": ""}
        }
    }

agent = "$AGENT"
status = "$STATUS"
message = """$MESSAGE"""
timestamp = "$TIMESTAMP"

# Update timestamp
data["timestamp"] = timestamp

# Update agent status
if agent in data["agents"]:
    data["agents"][agent]["status"] = status
    if message:
        data["agents"][agent]["message"] = message

    if status == "running":
        data["agents"][agent]["last_run"] = timestamp
        data["current_agent"] = agent
        data["orchestrator_running"] = True
    elif status in ["completed", "idle", "error"]:
        data["agents"][agent]["last_completed"] = timestamp
        if data.get("current_agent") == agent:
            data["current_agent"] = None

with open("$TEMP_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYTHON

# Move temp file to status file
mv "$TEMP_FILE" "$STATUS_FILE"
chmod 644 "$STATUS_FILE"
