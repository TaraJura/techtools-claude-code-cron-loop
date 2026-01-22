#!/bin/bash
# update-swap.sh - Monitor swap usage and identify processes using swap memory
# Part of CronLoop web app - provides data for /swap.html

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
SWAP_FILE="$API_DIR/swap.json"
SWAP_HISTORY_FILE="$API_DIR/swap-history.json"

# Get timestamp
TIMESTAMP=$(date -Iseconds)
EPOCH=$(date +%s)

# Get swap information from /proc/meminfo
SWAP_TOTAL_KB=$(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}')
SWAP_FREE_KB=$(grep "^SwapFree:" /proc/meminfo | awk '{print $2}')
SWAP_CACHED_KB=$(grep "^SwapCached:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
SWAP_TOTAL_KB=${SWAP_TOTAL_KB:-0}
SWAP_FREE_KB=${SWAP_FREE_KB:-0}
SWAP_CACHED_KB=${SWAP_CACHED_KB:-0}

SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
SWAP_TOTAL_MB=$((SWAP_TOTAL_KB / 1024))
SWAP_FREE_MB=$((SWAP_FREE_KB / 1024))
SWAP_USED_MB=$((SWAP_USED_KB / 1024))
SWAP_CACHED_MB=$((SWAP_CACHED_KB / 1024))

# Calculate percentage
if [ "$SWAP_TOTAL_KB" -gt 0 ]; then
    SWAP_PERCENT=$((SWAP_USED_KB * 100 / SWAP_TOTAL_KB))
else
    SWAP_PERCENT=0
fi

# Determine status based on percentage
if [ "$SWAP_PERCENT" -ge 80 ]; then
    STATUS="critical"
elif [ "$SWAP_PERCENT" -ge 50 ]; then
    STATUS="warning"
elif [ "$SWAP_PERCENT" -ge 25 ]; then
    STATUS="elevated"
else
    STATUS="healthy"
fi

# Get swap in/out rates from vmstat (last 3 samples, 1 second each)
VMSTAT_OUTPUT=$(vmstat 1 3 2>/dev/null | tail -1)
SWAP_IN=$(echo "$VMSTAT_OUTPUT" | awk '{print $7}')
SWAP_OUT=$(echo "$VMSTAT_OUTPUT" | awk '{print $8}')
SWAP_IN=${SWAP_IN:-0}
SWAP_OUT=${SWAP_OUT:-0}

# Get processes using swap, sorted by swap usage
# Read from /proc/[pid]/status for VmSwap
PROCESSES_JSON="["
FIRST_PROCESS=true
TOTAL_PROCESS_SWAP=0

while read -r pid; do
    # Skip if not a process directory
    [ ! -f "/proc/$pid/status" ] && continue

    # Get VmSwap from status
    VMSWAP=$(grep "^VmSwap:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}')
    VMSWAP=${VMSWAP:-0}

    # Skip processes with 0 swap
    [ "$VMSWAP" -eq 0 ] && continue

    # Get process info
    COMM=$(cat "/proc/$pid/comm" 2>/dev/null | head -1 || echo "unknown")
    CMDLINE=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | head -c 200 || echo "")
    USER=$(stat -c '%U' "/proc/$pid" 2>/dev/null || echo "unknown")

    # Get memory stats
    VMRSS=$(grep "^VmRSS:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "0")
    VMSIZE=$(grep "^VmSize:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "0")

    # Convert to MB
    VMSWAP_MB=$((VMSWAP / 1024))
    VMRSS_MB=$((VMRSS / 1024))
    VMSIZE_MB=$((VMSIZE / 1024))

    TOTAL_PROCESS_SWAP=$((TOTAL_PROCESS_SWAP + VMSWAP))

    # Escape special characters for JSON
    COMM_ESCAPED=$(echo "$COMM" | sed 's/\\/\\\\/g; s/"/\\"/g')
    CMDLINE_ESCAPED=$(echo "$CMDLINE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')

    if [ "$FIRST_PROCESS" = true ]; then
        FIRST_PROCESS=false
    else
        PROCESSES_JSON="$PROCESSES_JSON,"
    fi

    PROCESSES_JSON="$PROCESSES_JSON
    {
      \"pid\": $pid,
      \"name\": \"$COMM_ESCAPED\",
      \"command\": \"$CMDLINE_ESCAPED\",
      \"user\": \"$USER\",
      \"swap_kb\": $VMSWAP,
      \"swap_mb\": $VMSWAP_MB,
      \"rss_kb\": $VMRSS,
      \"rss_mb\": $VMRSS_MB,
      \"vsize_kb\": $VMSIZE,
      \"vsize_mb\": $VMSIZE_MB
    }"

done < <(ls -1 /proc 2>/dev/null | grep -E '^[0-9]+$' | head -100)

PROCESSES_JSON="$PROCESSES_JSON
  ]"

TOTAL_PROCESS_SWAP_MB=$((TOTAL_PROCESS_SWAP / 1024))

# Get swap devices info
SWAP_DEVICES_JSON="["
FIRST_DEVICE=true

while read -r line; do
    # Skip header
    [ "$line" = "Filename" ] && continue

    FILENAME=$(echo "$line" | awk '{print $1}')
    TYPE=$(echo "$line" | awk '{print $2}')
    SIZE=$(echo "$line" | awk '{print $3}')
    USED=$(echo "$line" | awk '{print $4}')
    PRIORITY=$(echo "$line" | awk '{print $5}')

    [ -z "$FILENAME" ] && continue

    SIZE=${SIZE:-0}
    USED=${USED:-0}
    PRIORITY=${PRIORITY:-0}
    SIZE_MB=$((SIZE / 1024))
    USED_MB=$((USED / 1024))

    if [ "$SIZE" -gt 0 ]; then
        DEVICE_PERCENT=$((USED * 100 / SIZE))
    else
        DEVICE_PERCENT=0
    fi

    if [ "$FIRST_DEVICE" = true ]; then
        FIRST_DEVICE=false
    else
        SWAP_DEVICES_JSON="$SWAP_DEVICES_JSON,"
    fi

    SWAP_DEVICES_JSON="$SWAP_DEVICES_JSON
    {
      \"filename\": \"$FILENAME\",
      \"type\": \"$TYPE\",
      \"size_kb\": $SIZE,
      \"size_mb\": $SIZE_MB,
      \"used_kb\": $USED,
      \"used_mb\": $USED_MB,
      \"priority\": $PRIORITY,
      \"percent\": $DEVICE_PERCENT
    }"

done < <(cat /proc/swaps 2>/dev/null | tail -n +2)

SWAP_DEVICES_JSON="$SWAP_DEVICES_JSON
  ]"

# Get memory pressure info (if available)
MEMORY_PRESSURE="false"
if [ -f "/proc/pressure/memory" ]; then
    MEM_PRESSURE_AVG10=$(cat /proc/pressure/memory 2>/dev/null | grep "^some" | awk '{print $2}' | cut -d= -f2)
    if [ -n "$MEM_PRESSURE_AVG10" ] && [ "$MEM_PRESSURE_AVG10" != "0.00" ]; then
        MEMORY_PRESSURE="true"
    fi
fi

# Get swappiness setting
SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")

# Build main JSON output
cat > "$SWAP_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "status": "$STATUS",
  "summary": {
    "total_kb": $SWAP_TOTAL_KB,
    "total_mb": $SWAP_TOTAL_MB,
    "free_kb": $SWAP_FREE_KB,
    "free_mb": $SWAP_FREE_MB,
    "used_kb": $SWAP_USED_KB,
    "used_mb": $SWAP_USED_MB,
    "cached_kb": $SWAP_CACHED_KB,
    "cached_mb": $SWAP_CACHED_MB,
    "percent": $SWAP_PERCENT,
    "process_swap_total_kb": $TOTAL_PROCESS_SWAP,
    "process_swap_total_mb": $TOTAL_PROCESS_SWAP_MB
  },
  "rates": {
    "swap_in_per_sec": $SWAP_IN,
    "swap_out_per_sec": $SWAP_OUT
  },
  "thresholds": {
    "warning": 50,
    "critical": 80
  },
  "system": {
    "swappiness": $SWAPPINESS,
    "memory_pressure": $MEMORY_PRESSURE
  },
  "devices": $SWAP_DEVICES_JSON,
  "processes": $PROCESSES_JSON
}
EOF

# Update history file (keep last 48 entries = 24 hours at 30-min intervals)
MAX_HISTORY=48

SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "used_mb": $SWAP_USED_MB,
  "percent": $SWAP_PERCENT,
  "swap_in": $SWAP_IN,
  "swap_out": $SWAP_OUT,
  "status": "$STATUS"
}
EOF
)

if [ ! -f "$SWAP_HISTORY_FILE" ]; then
    cat > "$SWAP_HISTORY_FILE" <<EOF
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
    with open("$SWAP_HISTORY_FILE", "r") as f:
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

with open("$SWAP_HISTORY_FILE", "w") as f:
    json.dump(history, f, indent=2)
PYEOF
fi

echo "Swap usage scan completed: $SWAP_FILE"
echo "Status: $STATUS | Used: ${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB (${SWAP_PERCENT}%) | Swap I/O: in=${SWAP_IN}/s out=${SWAP_OUT}/s"
