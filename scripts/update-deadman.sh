#!/bin/bash
# Dead Man's Switch Heartbeat Update Script
# This script updates the deadman.json and alive.json files with current heartbeat data
# Should be called by the orchestrator at the end of each run

set -e

DEADMAN_FILE="/var/www/cronloop.techtools.cz/api/deadman.json"
ALIVE_FILE="/var/www/cronloop.techtools.cz/api/alive.json"
AGENT_STATUS_FILE="/var/www/cronloop.techtools.cz/api/agent-status.json"
SYSTEM_METRICS_FILE="/var/www/cronloop.techtools.cz/api/system-metrics.json"
CANARY_FILE="/tmp/cronloop-canary-test"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get uptime
UPTIME_SECONDS=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)

# Get last orchestrator run and agent info from agent-status.json
LAST_ORCHESTRATOR_RUN=""
LAST_AGENT_COMPLETED=""
if [ -f "$AGENT_STATUS_FILE" ]; then
    LAST_ORCHESTRATOR_RUN=$(python3 -c "import json; d=json.load(open('$AGENT_STATUS_FILE')); print(d.get('orchestrator_started', ''))" 2>/dev/null || echo "")

    # Find the last completed agent
    LAST_AGENT_COMPLETED=$(python3 << 'EOF'
import json
try:
    with open('/var/www/cronloop.techtools.cz/api/agent-status.json') as f:
        data = json.load(f)
    agents = data.get('agents', {})
    latest = None
    latest_time = None
    for name, info in agents.items():
        completed = info.get('last_completed')
        if completed:
            if latest_time is None or completed > latest_time:
                latest_time = completed
                latest = f"{name}:{completed}"
    print(latest or '')
except:
    print('')
EOF
)
fi

# Canary test - write and read a predictable value
CANARY_VALUE="cronloop-canary-$(date +%s)"
CANARY_RESULT="pass"
echo "$CANARY_VALUE" > "$CANARY_FILE" 2>/dev/null || CANARY_RESULT="fail"
if [ "$CANARY_RESULT" = "pass" ]; then
    READ_VALUE=$(cat "$CANARY_FILE" 2>/dev/null || echo "")
    if [ "$READ_VALUE" != "$CANARY_VALUE" ]; then
        CANARY_RESULT="fail"
    fi
fi
rm -f "$CANARY_FILE" 2>/dev/null || true

# Determine overall health
HEALTH="healthy"
if [ -f "$SYSTEM_METRICS_FILE" ]; then
    MEM_PERCENT=$(python3 -c "import json; print(json.load(open('$SYSTEM_METRICS_FILE')).get('memory',{}).get('percent', 0))" 2>/dev/null || echo "0")
    DISK_PERCENT=$(python3 -c "import json; d=json.load(open('$SYSTEM_METRICS_FILE')).get('disk',[]); print(max([x.get('percent',0) for x in d]) if d else 0)" 2>/dev/null || echo "0")

    if [ "$MEM_PERCENT" -gt 90 ] || [ "$DISK_PERCENT" -gt 90 ]; then
        HEALTH="critical"
    elif [ "$MEM_PERCENT" -gt 75 ] || [ "$DISK_PERCENT" -gt 75 ]; then
        HEALTH="warning"
    fi
fi

# Update alive.json
cat > "$ALIVE_FILE" << EOF
{
  "alive": true,
  "timestamp": "$TIMESTAMP",
  "system": "cronloop",
  "version": "1.0",
  "uptime_seconds": $UPTIME_SECONDS,
  "last_orchestrator_run": "$LAST_ORCHESTRATOR_RUN",
  "last_agent_completed": "$LAST_AGENT_COMPLETED",
  "health": "$HEALTH"
}
EOF

# Update deadman.json with heartbeat
python3 << PYTHON
import json
from datetime import datetime, timedelta

DEADMAN_FILE = "$DEADMAN_FILE"
TIMESTAMP = "$TIMESTAMP"
CANARY_RESULT = "$CANARY_RESULT"
CANARY_VALUE = "$CANARY_VALUE"

try:
    with open(DEADMAN_FILE, 'r') as f:
        data = json.load(f)
except:
    data = {
        "status": "alive",
        "heartbeat_interval_minutes": 30,
        "max_missed_heartbeats": 2,
        "considered_dead_after_minutes": 60,
        "last_heartbeat": None,
        "heartbeat_count": 0,
        "consecutive_missed": 0,
        "last_death": None,
        "last_recovery": None,
        "total_deaths": 0,
        "total_uptime_minutes": 0,
        "history": [],
        "canary": {},
        "external_checks": {}
    }

# Update heartbeat
previous_heartbeat = data.get("last_heartbeat")
data["last_heartbeat"] = TIMESTAMP
data["heartbeat_count"] = data.get("heartbeat_count", 0) + 1
data["consecutive_missed"] = 0

# Check if we were dead and are now recovering
if data.get("status") == "dead":
    data["status"] = "alive"
    data["last_recovery"] = TIMESTAMP
    # Add recovery event to history
    history = data.get("history", [])
    history.append({
        "event": "recovery",
        "timestamp": TIMESTAMP,
        "death_timestamp": data.get("last_death"),
        "downtime_minutes": None  # Could calculate from death to recovery
    })
    # Keep only last 50 events
    data["history"] = history[-50:]
else:
    data["status"] = "alive"

# Calculate uptime since last heartbeat
if previous_heartbeat:
    try:
        prev = datetime.fromisoformat(previous_heartbeat.replace('Z', '+00:00'))
        now = datetime.fromisoformat(TIMESTAMP.replace('Z', '+00:00'))
        minutes = (now - prev).total_seconds() / 60
        data["total_uptime_minutes"] = data.get("total_uptime_minutes", 0) + minutes
    except:
        pass

# Update canary test
data["canary"] = {
    "last_test": TIMESTAMP,
    "last_result": CANARY_RESULT,
    "test_value": CANARY_VALUE
}

# Write updated data
with open(DEADMAN_FILE, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Heartbeat updated: {TIMESTAMP}")
PYTHON

echo "Dead man's switch heartbeat updated at $TIMESTAMP"
