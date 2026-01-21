#!/bin/bash
# update-long-running-processes.sh - Identify processes running for extended periods
# Part of CronLoop web app - provides data for long-running process detector

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
PROCESSES_FILE="$API_DIR/processes.json"
HISTORY_FILE="$API_DIR/processes-history.json"

# Get timestamp
TIMESTAMP=$(date -Iseconds)
EPOCH=$(date +%s)

# Thresholds (in seconds)
THRESHOLD_24H=$((24 * 60 * 60))  # 24 hours
THRESHOLD_7D=$((7 * 24 * 60 * 60))  # 7 days
THRESHOLD_30D=$((30 * 24 * 60 * 60))  # 30 days

# List of expected long-running system processes to filter out
EXPECTED_LONG_RUNNING="^(systemd|init|kthread|kworker|ksoftirqd|migration|watchdog|rcu_|cpuhp|kcompactd|khugepaged|oom_reaper|writeback|kblockd|kswapd|md|edac|devfreq|mld|ipv6_addrconf|cryptd|crypto|kstrp|kintegrityd|zswap|bioset|charger_manager|scsi_|nvme-|ata_|loop|aio|dio|dm-|jbd2|ext4|btrfs|xfs|nfsd|rpciod|lockd|nfs|cifsd|sshd|nginx|apache|mysql|mariadb|postgres|redis|cron|atd|dbus|NetworkManager|systemd-|polkit|rsyslog|irqbalance|snapd|multipathd|lvm|udev|blkmapd|rpcbind|bluetooth|avahi|cups|pulse|gdm|lightdm|Xorg|gnome|kde|plymouth)"

# Function to calculate human-readable duration
format_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Function to get severity based on age
get_severity() {
    local age=$1
    if [ $age -ge $THRESHOLD_30D ]; then
        echo "critical"
    elif [ $age -ge $THRESHOLD_7D ]; then
        echo "warning"
    elif [ $age -ge $THRESHOLD_24H ]; then
        echo "info"
    else
        echo "ok"
    fi
}

# Get process information
# Using ps with elapsed time in seconds for accurate calculation
PROCESSES_JSON="[]"
WARNING_COUNT=0
CRITICAL_COUNT=0
TOTAL_LONG_RUNNING=0

# Get all processes with their start time and stats
# Filter for processes running > 1 hour (3600 seconds) to start
while read -r PID USER ELAPSED_RAW COMMAND CPU MEM RSS FULL_CMD; do
    # Trim whitespace
    PID=$(echo "$PID" | tr -d ' ')
    USER=$(echo "$USER" | tr -d ' ')
    ELAPSED_RAW=$(echo "$ELAPSED_RAW" | tr -d ' ')
    COMMAND=$(echo "$COMMAND" | tr -d ' ')
    CPU=$(echo "$CPU" | tr -d ' ')
    MEM=$(echo "$MEM" | tr -d ' ')
    RSS=$(echo "$RSS" | tr -d ' ')

    # Skip empty lines
    [ -z "$PID" ] && continue

    # Skip if it matches expected long-running processes
    if echo "$COMMAND" | grep -qE "$EXPECTED_LONG_RUNNING"; then
        continue
    fi

    # Parse elapsed time format: [[DD-]hh:]mm:ss
    # Convert to seconds
    ELAPSED_SEC=0
    if [[ "$ELAPSED_RAW" =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        # DD-hh:mm:ss - strip leading zeros with 10# prefix
        DAYS=$((10#${BASH_REMATCH[1]}))
        HOURS=$((10#${BASH_REMATCH[2]}))
        MINS=$((10#${BASH_REMATCH[3]}))
        SECS=$((10#${BASH_REMATCH[4]}))
        ELAPSED_SEC=$((DAYS * 86400 + HOURS * 3600 + MINS * 60 + SECS))
    elif [[ "$ELAPSED_RAW" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        # hh:mm:ss - strip leading zeros with 10# prefix
        HOURS=$((10#${BASH_REMATCH[1]}))
        MINS=$((10#${BASH_REMATCH[2]}))
        SECS=$((10#${BASH_REMATCH[3]}))
        ELAPSED_SEC=$((HOURS * 3600 + MINS * 60 + SECS))
    elif [[ "$ELAPSED_RAW" =~ ^([0-9]+):([0-9]+)$ ]]; then
        # mm:ss - strip leading zeros with 10# prefix
        MINS=$((10#${BASH_REMATCH[1]}))
        SECS=$((10#${BASH_REMATCH[2]}))
        ELAPSED_SEC=$((MINS * 60 + SECS))
    fi

    # Only include if running > 1 hour
    if [ "$ELAPSED_SEC" -lt 3600 ]; then
        continue
    fi

    TOTAL_LONG_RUNNING=$((TOTAL_LONG_RUNNING + 1))

    # Get severity
    SEVERITY=$(get_severity $ELAPSED_SEC)

    if [ "$SEVERITY" = "critical" ]; then
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    elif [ "$SEVERITY" = "warning" ]; then
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi

    # Format duration for display
    DURATION_DISPLAY=$(format_duration $ELAPSED_SEC)

    # Get start time
    START_TIME=$(ps -o lstart= -p "$PID" 2>/dev/null | xargs || echo "Unknown")

    # Convert RSS to MB
    RSS_MB=$(echo "scale=1; $RSS / 1024" | bc 2>/dev/null || echo "0")

    # Escape special chars in command for JSON
    FULL_CMD_ESCAPED=$(echo "$FULL_CMD" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | head -c 200)

    # Add to JSON array
    PROCESS_ENTRY=$(cat <<EOF
{
    "pid": $PID,
    "user": "$USER",
    "command": "$COMMAND",
    "full_command": "$FULL_CMD_ESCAPED",
    "elapsed_seconds": $ELAPSED_SEC,
    "elapsed_display": "$DURATION_DISPLAY",
    "start_time": "$START_TIME",
    "cpu_percent": $CPU,
    "mem_percent": $MEM,
    "rss_mb": $RSS_MB,
    "severity": "$SEVERITY"
}
EOF
)

    if [ "$PROCESSES_JSON" = "[]" ]; then
        PROCESSES_JSON="[$PROCESS_ENTRY"
    else
        PROCESSES_JSON="$PROCESSES_JSON,$PROCESS_ENTRY"
    fi

done < <(ps -eo pid,user,etime,comm,%cpu,%mem,rss,args --no-headers 2>/dev/null | sort -k3 -r)

# Close JSON array
if [ "$PROCESSES_JSON" != "[]" ]; then
    PROCESSES_JSON="$PROCESSES_JSON]"
fi

# Calculate overall status
if [ $CRITICAL_COUNT -gt 0 ]; then
    OVERALL_STATUS="critical"
elif [ $WARNING_COUNT -gt 0 ]; then
    OVERALL_STATUS="warning"
elif [ $TOTAL_LONG_RUNNING -gt 0 ]; then
    OVERALL_STATUS="info"
else
    OVERALL_STATUS="healthy"
fi

# Get system uptime for context
UPTIME_SECONDS=$(cat /proc/uptime | awk '{print int($1)}')
UPTIME_DISPLAY=$(format_duration $UPTIME_SECONDS)

# Count total processes
TOTAL_PROCESSES=$(ps aux | wc -l)

# Build JSON output
cat > "$PROCESSES_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "overall_status": "$OVERALL_STATUS",
  "summary": {
    "total_processes": $TOTAL_PROCESSES,
    "long_running_count": $TOTAL_LONG_RUNNING,
    "warning_count": $WARNING_COUNT,
    "critical_count": $CRITICAL_COUNT,
    "threshold_24h": $THRESHOLD_24H,
    "threshold_7d": $THRESHOLD_7D,
    "threshold_30d": $THRESHOLD_30D
  },
  "system": {
    "uptime_seconds": $UPTIME_SECONDS,
    "uptime_display": "$UPTIME_DISPLAY"
  },
  "processes": $PROCESSES_JSON
}
EOF

# Update history file (keep last 48 entries = 24 hours at 30-min intervals)
MAX_HISTORY=48

SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$OVERALL_STATUS",
  "long_running": $TOTAL_LONG_RUNNING,
  "warning": $WARNING_COUNT,
  "critical": $CRITICAL_COUNT
}
EOF
)

if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" <<EOF
{
  "last_updated": "$TIMESTAMP",
  "retention_hours": 24,
  "snapshots": [$SNAPSHOT]
}
EOF
else
    python3 << PYEOF
import json

try:
    with open("$HISTORY_FILE", "r") as f:
        history = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    history = {"last_updated": "$TIMESTAMP", "retention_hours": 24, "snapshots": []}

new_snapshot = json.loads('''$SNAPSHOT''')

if "snapshots" not in history or not isinstance(history["snapshots"], list):
    history["snapshots"] = []

history["snapshots"].append(new_snapshot)

MAX_HISTORY = $MAX_HISTORY
if len(history["snapshots"]) > MAX_HISTORY:
    history["snapshots"] = history["snapshots"][-MAX_HISTORY:]

history["last_updated"] = "$TIMESTAMP"

with open("$HISTORY_FILE", "w") as f:
    json.dump(history, f, indent=2)
PYEOF
fi

echo "Long-running process scan completed: $PROCESSES_FILE"
echo "Status: $OVERALL_STATUS | Long-running: $TOTAL_LONG_RUNNING | Warning: $WARNING_COUNT | Critical: $CRITICAL_COUNT"
