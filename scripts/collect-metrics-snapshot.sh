#!/bin/bash
# collect-metrics-snapshot.sh - Collects system metrics and appends to history file
# Used for trend analysis in the CronLoop web app
# Run via cron every 15 minutes
# Data is auto-rotated to keep only the last 7 days

set -e

HISTORY_FILE="/var/www/cronloop.techtools.cz/api/metrics-history.json"
MAX_ENTRIES=672  # 7 days * 24 hours * 4 snapshots/hour = 672 entries

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

# Collect memory stats
MEM_TOTAL=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
MEM_USED_MB=$((MEM_USED / 1024))
MEM_TOTAL_MB=$((MEM_TOTAL / 1024))

# Collect CPU load averages
read LOAD_1M LOAD_5M LOAD_15M _ <<< $(cat /proc/loadavg)
CPU_CORES=$(nproc)

# Collect disk usage for root partition
read DISK_USED_GB DISK_TOTAL_GB DISK_PERCENT <<< $(df -BG / | awk 'NR==2 {gsub("G",""); print $3, $2, $5}' | tr -d '%')

# Calculate load ratio (load / cores) - ensure leading zero for JSON compliance
LOAD_RATIO=$(echo "scale=2; $LOAD_1M / $CPU_CORES" | bc)
# Add leading zero if needed (bc outputs ".05" instead of "0.05")
[[ "$LOAD_RATIO" == .* ]] && LOAD_RATIO="0$LOAD_RATIO"

# Create snapshot JSON
SNAPSHOT=$(cat <<EOF
{
    "timestamp": "$TIMESTAMP",
    "epoch": $EPOCH,
    "memory": {
        "used_mb": $MEM_USED_MB,
        "total_mb": $MEM_TOTAL_MB,
        "percent": $MEM_PERCENT
    },
    "cpu": {
        "load_1m": $LOAD_1M,
        "load_5m": $LOAD_5M,
        "load_15m": $LOAD_15M,
        "cores": $CPU_CORES,
        "load_ratio": $LOAD_RATIO
    },
    "disk": {
        "used_gb": $DISK_USED_GB,
        "total_gb": $DISK_TOTAL_GB,
        "percent": $DISK_PERCENT
    }
}
EOF
)

# Initialize history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"snapshots":[]}' > "$HISTORY_FILE"
fi

# Use Python for safe JSON manipulation (handles edge cases better than jq)
python3 << PYTHON
import json
import sys

history_file = "$HISTORY_FILE"
max_entries = $MAX_ENTRIES

# Read current history
try:
    with open(history_file, 'r') as f:
        history = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    history = {"snapshots": []}

# Parse new snapshot
snapshot = json.loads('''$SNAPSHOT''')

# Append new snapshot
history["snapshots"].append(snapshot)

# Rotate: keep only last max_entries
if len(history["snapshots"]) > max_entries:
    history["snapshots"] = history["snapshots"][-max_entries:]

# Update metadata
history["last_updated"] = "$TIMESTAMP"
history["entry_count"] = len(history["snapshots"])

# Write back
with open(history_file, 'w') as f:
    json.dump(history, f, indent=2)

print(f"Snapshot saved. Total entries: {len(history['snapshots'])}")
PYTHON
