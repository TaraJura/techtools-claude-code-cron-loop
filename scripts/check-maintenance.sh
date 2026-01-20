#!/bin/bash
# Check if system is in maintenance mode
# Usage: check-maintenance.sh [agent-name]
# Returns: 0 if maintenance is NOT active (OK to run)
#          1 if maintenance is active (should NOT run)
#          2 if maintenance is active but agent is not affected
#
# Also outputs the maintenance status as JSON for integration

MAINTENANCE_FILE="/var/www/cronloop.techtools.cz/api/maintenance.json"
AGENT_NAME="${1:-}"

# Check if maintenance file exists
if [ ! -f "$MAINTENANCE_FILE" ]; then
    echo '{"in_maintenance": false, "reason": "No maintenance file"}'
    exit 0
fi

# Use Python to parse and check maintenance status
python3 - "$AGENT_NAME" << 'PYTHON_SCRIPT'
import json
import sys
from datetime import datetime, timezone

maintenance_file = "/var/www/cronloop.techtools.cz/api/maintenance.json"
agent_name = sys.argv[1] if len(sys.argv) > 1 else ""

try:
    with open(maintenance_file, 'r') as f:
        data = json.load(f)
except Exception as e:
    print(json.dumps({"in_maintenance": False, "reason": f"Error reading file: {e}"}))
    sys.exit(0)

now = datetime.now(timezone.utc).replace(tzinfo=None)
scheduled = data.get('scheduled', [])

active_window = None
for window in scheduled:
    try:
        start_str = window['start'].replace('Z', '')
        end_str = window['end'].replace('Z', '')
        # Handle ISO format with or without timezone
        if '+' in start_str:
            start_str = start_str.split('+')[0]
        if '+' in end_str:
            end_str = end_str.split('+')[0]

        start = datetime.fromisoformat(start_str)
        end = datetime.fromisoformat(end_str)

        if start <= now <= end:
            active_window = window
            break
    except Exception as e:
        continue

if not active_window:
    print(json.dumps({"in_maintenance": False, "reason": "No active maintenance window"}))
    sys.exit(0)

# Check if specific agent is affected
agents_affected = active_window.get('agents', ['all'])
if agent_name and 'all' not in agents_affected and agent_name not in agents_affected:
    print(json.dumps({
        "in_maintenance": False,
        "reason": f"Agent {agent_name} not affected by current maintenance",
        "window": active_window.get('description', 'Unknown')
    }))
    sys.exit(2)

# Maintenance is active and affects this agent
pause_level = active_window.get('pauseLevel', 'full')
result = {
    "in_maintenance": True,
    "pause_level": pause_level,
    "description": active_window.get('description', 'Maintenance'),
    "start": active_window.get('start'),
    "end": active_window.get('end'),
    "agents": agents_affected,
    "window_id": active_window.get('id')
}

print(json.dumps(result))

# Exit codes based on pause level
if pause_level == 'full':
    sys.exit(1)  # Full stop - do not run
elif pause_level == 'readonly':
    sys.exit(1)  # Read-only - still block normal execution
else:
    sys.exit(0)  # Warnings only - can still run
PYTHON_SCRIPT
