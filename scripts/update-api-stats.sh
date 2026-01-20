#!/bin/bash
# Update API Stats - Tracks API/CGI endpoint usage statistics
# Part of CronLoop API Stats Dashboard (TASK-039)
#
# This script is called by queue-action.sh to log each API call
# and by a cron job to aggregate stats periodically

set -e

STATS_FILE="/var/www/cronloop.techtools.cz/api/api-stats.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/api-stats-history.json"
RATE_LIMIT_DIR="/tmp"
MAX_HISTORY_ENTRIES=2880  # 48 hours at 1-minute intervals

# Initialize stats file if needed
init_stats() {
    if [[ ! -f "$STATS_FILE" ]]; then
        cat > "$STATS_FILE" << 'EOF'
{
  "updated": null,
  "endpoints": {
    "action.cgi": {
      "total_calls": 0,
      "calls_today": 0,
      "calls_hour": 0,
      "successful": 0,
      "rate_limited": 0,
      "errors": 0,
      "by_action": {}
    }
  },
  "rate_limits": {},
  "peak_hour": null,
  "peak_hour_count": 0,
  "hourly_distribution": {}
}
EOF
    fi

    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo '{"history":[]}' > "$HISTORY_FILE"
    fi
}

# Log an API call - called from queue-action.sh
log_call() {
    local action_type="$1"
    local status="$2"  # success, rate_limited, error
    local timestamp=$(date -Iseconds)
    local hour=$(date +%H)
    local today=$(date +%Y-%m-%d)

    python3 << EOF
import json
from datetime import datetime

stats_file = "$STATS_FILE"
action_type = "$action_type"
status = "$status"
hour = "$hour"
today = "$today"
timestamp = "$timestamp"

try:
    with open(stats_file, 'r') as f:
        data = json.load(f)
except:
    data = {
        "updated": None,
        "endpoints": {
            "action.cgi": {
                "total_calls": 0,
                "calls_today": 0,
                "calls_hour": 0,
                "successful": 0,
                "rate_limited": 0,
                "errors": 0,
                "by_action": {}
            }
        },
        "rate_limits": {},
        "peak_hour": None,
        "peak_hour_count": 0,
        "hourly_distribution": {}
    }

# Ensure structure exists
if "endpoints" not in data:
    data["endpoints"] = {}
if "action.cgi" not in data["endpoints"]:
    data["endpoints"]["action.cgi"] = {
        "total_calls": 0,
        "calls_today": 0,
        "calls_hour": 0,
        "successful": 0,
        "rate_limited": 0,
        "errors": 0,
        "by_action": {}
    }
if "by_action" not in data["endpoints"]["action.cgi"]:
    data["endpoints"]["action.cgi"]["by_action"] = {}
if "hourly_distribution" not in data:
    data["hourly_distribution"] = {}
if "last_calls" not in data:
    data["last_calls"] = []

endpoint = data["endpoints"]["action.cgi"]

# Update totals
endpoint["total_calls"] = endpoint.get("total_calls", 0) + 1

# Update status counters
if status == "success":
    endpoint["successful"] = endpoint.get("successful", 0) + 1
elif status == "rate_limited":
    endpoint["rate_limited"] = endpoint.get("rate_limited", 0) + 1
else:
    endpoint["errors"] = endpoint.get("errors", 0) + 1

# Update by-action stats
if action_type not in endpoint["by_action"]:
    endpoint["by_action"][action_type] = {
        "total": 0,
        "successful": 0,
        "rate_limited": 0,
        "errors": 0,
        "last_call": None
    }

action_stats = endpoint["by_action"][action_type]
action_stats["total"] = action_stats.get("total", 0) + 1
action_stats["last_call"] = timestamp

if status == "success":
    action_stats["successful"] = action_stats.get("successful", 0) + 1
elif status == "rate_limited":
    action_stats["rate_limited"] = action_stats.get("rate_limited", 0) + 1
else:
    action_stats["errors"] = action_stats.get("errors", 0) + 1

# Update hourly distribution
if hour not in data["hourly_distribution"]:
    data["hourly_distribution"][hour] = 0
data["hourly_distribution"][hour] += 1

# Check peak hour
if data["hourly_distribution"][hour] > data.get("peak_hour_count", 0):
    data["peak_hour"] = hour
    data["peak_hour_count"] = data["hourly_distribution"][hour]

# Track last 50 calls for recent activity
data["last_calls"].append({
    "action": action_type,
    "status": status,
    "timestamp": timestamp
})
if len(data["last_calls"]) > 50:
    data["last_calls"] = data["last_calls"][-50:]

data["updated"] = timestamp

with open(stats_file, 'w') as f:
    json.dump(data, f, indent=2)
EOF
}

# Update rate limit status from /tmp files
update_rate_limits() {
    python3 << EOF
import json
import os
import time
from datetime import datetime

stats_file = "$STATS_FILE"
rate_limit_dir = "$RATE_LIMIT_DIR"

try:
    with open(stats_file, 'r') as f:
        data = json.load(f)
except:
    data = {"rate_limits": {}}

if "rate_limits" not in data:
    data["rate_limits"] = {}

# Valid action types
action_types = ["health_check", "refresh_metrics", "sync_logs", "cleanup_logs",
                "update_security", "git_status", "create_backup"]

now = time.time()

for action in action_types:
    limit_file = f"{rate_limit_dir}/action-rate-limit_{action}"

    if os.path.exists(limit_file):
        try:
            with open(limit_file, 'r') as f:
                last_time = int(f.read().strip())

            remaining = max(0, 60 - (now - last_time))
            data["rate_limits"][action] = {
                "cooldown_remaining": int(remaining),
                "last_call_epoch": last_time,
                "last_call": datetime.fromtimestamp(last_time).isoformat()
            }
        except:
            data["rate_limits"][action] = {"cooldown_remaining": 0, "last_call_epoch": 0, "last_call": None}
    else:
        data["rate_limits"][action] = {"cooldown_remaining": 0, "last_call_epoch": 0, "last_call": None}

data["updated"] = datetime.now().isoformat()

with open(stats_file, 'w') as f:
    json.dump(data, f, indent=2)
EOF
}

# Aggregate stats for history (called periodically by cron)
aggregate_stats() {
    python3 << EOF
import json
from datetime import datetime, timedelta

stats_file = "$STATS_FILE"
history_file = "$HISTORY_FILE"
max_entries = $MAX_HISTORY_ENTRIES

timestamp = datetime.now().isoformat()
epoch = int(datetime.now().timestamp())

# Read current stats
try:
    with open(stats_file, 'r') as f:
        stats = json.load(f)
except:
    stats = {}

# Read history
try:
    with open(history_file, 'r') as f:
        history_data = json.load(f)
except:
    history_data = {"history": []}

if "history" not in history_data:
    history_data["history"] = []

# Create snapshot
endpoint_stats = stats.get("endpoints", {}).get("action.cgi", {})

snapshot = {
    "timestamp": timestamp,
    "epoch": epoch,
    "total_calls": endpoint_stats.get("total_calls", 0),
    "successful": endpoint_stats.get("successful", 0),
    "rate_limited": endpoint_stats.get("rate_limited", 0),
    "errors": endpoint_stats.get("errors", 0),
    "by_action": {}
}

# Add per-action snapshot
for action, action_stats in endpoint_stats.get("by_action", {}).items():
    snapshot["by_action"][action] = {
        "total": action_stats.get("total", 0),
        "successful": action_stats.get("successful", 0),
        "rate_limited": action_stats.get("rate_limited", 0)
    }

history_data["history"].append(snapshot)

# Trim to max entries
if len(history_data["history"]) > max_entries:
    history_data["history"] = history_data["history"][-max_entries:]

history_data["updated"] = timestamp

with open(history_file, 'w') as f:
    json.dump(history_data, f, indent=2)

print(f"Aggregated stats. History now has {len(history_data['history'])} entries.")
EOF
}

# Reset daily/hourly counters (called daily at midnight)
reset_daily_counters() {
    python3 << EOF
import json
from datetime import datetime

stats_file = "$STATS_FILE"

try:
    with open(stats_file, 'r') as f:
        data = json.load(f)
except:
    data = {}

if "endpoints" in data and "action.cgi" in data["endpoints"]:
    data["endpoints"]["action.cgi"]["calls_today"] = 0

# Reset hourly distribution
data["hourly_distribution"] = {}
data["peak_hour"] = None
data["peak_hour_count"] = 0

data["updated"] = datetime.now().isoformat()
data["last_daily_reset"] = datetime.now().isoformat()

with open(stats_file, 'w') as f:
    json.dump(data, f, indent=2)

print("Daily counters reset.")
EOF
}

# Calculate calls in last hour
update_hourly_count() {
    python3 << EOF
import json
from datetime import datetime, timedelta

stats_file = "$STATS_FILE"

try:
    with open(stats_file, 'r') as f:
        data = json.load(f)
except:
    data = {}

# Count calls in last hour from last_calls
if "last_calls" in data:
    now = datetime.now()
    hour_ago = now - timedelta(hours=1)

    calls_hour = 0
    calls_today = 0
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    for call in data["last_calls"]:
        try:
            call_time = datetime.fromisoformat(call["timestamp"].replace("Z", "+00:00"))
            # Make naive for comparison if needed
            if call_time.tzinfo:
                call_time = call_time.replace(tzinfo=None)
            if call_time >= hour_ago:
                calls_hour += 1
            if call_time >= today_start:
                calls_today += 1
        except:
            pass

    if "endpoints" in data and "action.cgi" in data["endpoints"]:
        data["endpoints"]["action.cgi"]["calls_hour"] = calls_hour
        data["endpoints"]["action.cgi"]["calls_today"] = max(
            data["endpoints"]["action.cgi"].get("calls_today", 0),
            calls_today
        )

data["updated"] = datetime.now().isoformat()

with open(stats_file, 'w') as f:
    json.dump(data, f, indent=2)
EOF
}

# Main command handler
case "${1:-update}" in
    log)
        init_stats
        log_call "$2" "${3:-success}"
        ;;
    rate_limits)
        init_stats
        update_rate_limits
        ;;
    aggregate)
        init_stats
        aggregate_stats
        ;;
    reset_daily)
        init_stats
        reset_daily_counters
        ;;
    update|*)
        init_stats
        update_rate_limits
        update_hourly_count
        ;;
esac
