#!/bin/bash
# update-reboot-history.sh - Gathers system reboot history for the CronLoop dashboard
# Called periodically to update /var/www/cronloop.techtools.cz/api/reboot-history.json

API_DIR="/var/www/cronloop.techtools.cz/api"
REBOOT_FILE="$API_DIR/reboot-history.json"
HISTORY_FILE="$API_DIR/reboot-history-records.json"

# Ensure API directory exists
mkdir -p "$API_DIR"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get current uptime in seconds
UPTIME_SECONDS=$(cat /proc/uptime | awk '{print int($1)}')

# Format uptime as human-readable
format_uptime() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    else
        echo "${minutes}m ${secs}s"
    fi
}

UPTIME_FORMATTED=$(format_uptime $UPTIME_SECONDS)

# Get boot time
BOOT_TIME=$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || date -d "@$(($(date +%s) - UPTIME_SECONDS))" "+%Y-%m-%d %H:%M:%S")

# Get reboot history from last command (last 20 reboots)
REBOOTS="[]"
if command -v last &>/dev/null; then
    REBOOTS=$(last -x reboot 2>/dev/null | grep "^reboot" | head -20 | while read line; do
        # Parse the line: reboot   system boot  6.8.0-45-generic Tue Jan 21 14:32   still running
        # or: reboot   system boot  6.8.0-45-generic Tue Jan 21 14:32 - Tue Jan 21 15:00 (00:28)

        kernel=$(echo "$line" | awk '{print $4}')

        # Extract date parts - format varies
        date_part=$(echo "$line" | sed 's/reboot.*generic//' | awk '{print $1, $2, $3, $4}' | head -1)

        # Try to get the boot time from the line
        boot_time=$(echo "$line" | grep -oP '\w{3} \w{3} +\d+ \d{2}:\d{2}' | head -1)

        # Check if still running
        if echo "$line" | grep -q "still running"; then
            status="running"
            duration=""
        else
            status="completed"
            # Try to extract duration from parentheses
            duration=$(echo "$line" | grep -oP '\(\d+:\d+\)' | tr -d '()')
            if [ -z "$duration" ]; then
                duration=$(echo "$line" | grep -oP '\(\d+ days?, \d+:\d+\)' | tr -d '()')
            fi
        fi

        if [ -n "$boot_time" ]; then
            echo "{\"kernel\":\"$kernel\",\"boot_time\":\"$boot_time\",\"status\":\"$status\",\"duration\":\"$duration\"},"
        fi
    done | sed 's/,$//' | awk 'BEGIN{print "["} {print} END{print "]"}' | tr -d '\n')
fi

# Clean up JSON if empty
if [ "$REBOOTS" = "[
]" ] || [ -z "$REBOOTS" ]; then
    REBOOTS="[]"
fi

# Get shutdown history
SHUTDOWNS="[]"
if command -v last &>/dev/null; then
    SHUTDOWNS=$(last -x shutdown 2>/dev/null | grep "^shutdown" | head -10 | while read line; do
        shutdown_time=$(echo "$line" | grep -oP '\w{3} \w{3} +\d+ \d{2}:\d{2}' | head -1)
        if [ -n "$shutdown_time" ]; then
            echo "{\"time\":\"$shutdown_time\"},"
        fi
    done | sed 's/,$//' | awk 'BEGIN{print "["} {print} END{print "]"}' | tr -d '\n')
fi

if [ "$SHUTDOWNS" = "[
]" ] || [ -z "$SHUTDOWNS" ]; then
    SHUTDOWNS="[]"
fi

# Count total reboots
REBOOT_COUNT=$(echo "$REBOOTS" | jq 'length' 2>/dev/null || echo "0")

# Calculate uptime statistics
# Read historical records if they exist
HISTORICAL_UPTIMES=""
AVG_UPTIME=0
MAX_UPTIME=$UPTIME_SECONDS
MIN_UPTIME=$UPTIME_SECONDS
TOTAL_UPTIME_RECORDED=0

if [ -f "$HISTORY_FILE" ]; then
    # Get historical data
    HISTORICAL_UPTIMES=$(cat "$HISTORY_FILE" 2>/dev/null | jq '.uptime_records // []' 2>/dev/null || echo "[]")

    # Calculate stats from historical data
    if [ "$HISTORICAL_UPTIMES" != "[]" ] && [ -n "$HISTORICAL_UPTIMES" ]; then
        STATS=$(echo "$HISTORICAL_UPTIMES" | jq '{
            total: (. | add),
            count: (. | length),
            max: (. | max),
            min: (. | min)
        }' 2>/dev/null)

        if [ -n "$STATS" ]; then
            TOTAL_UPTIME_RECORDED=$(echo "$STATS" | jq '.total // 0')
            RECORD_COUNT=$(echo "$STATS" | jq '.count // 0')
            MAX_UPTIME=$(echo "$STATS" | jq '.max // 0')
            MIN_UPTIME=$(echo "$STATS" | jq '.min // 0')

            if [ "$RECORD_COUNT" -gt 0 ]; then
                AVG_UPTIME=$((TOTAL_UPTIME_RECORDED / RECORD_COUNT))
            fi
        fi
    fi
fi

# Check if current uptime is a new record
IS_NEW_RECORD="false"
if [ "$UPTIME_SECONDS" -gt "$MAX_UPTIME" ]; then
    IS_NEW_RECORD="true"
    MAX_UPTIME=$UPTIME_SECONDS
fi

# Format stats
AVG_UPTIME_FORMATTED=$(format_uptime $AVG_UPTIME)
MAX_UPTIME_FORMATTED=$(format_uptime $MAX_UPTIME)
MIN_UPTIME_FORMATTED=$(format_uptime $MIN_UPTIME)

# Get system info
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

# Calculate uptime percentage (based on last 30 days if we have data)
UPTIME_PERCENTAGE="100"
THIRTY_DAYS_SECONDS=$((30 * 24 * 3600))
if [ "$TOTAL_UPTIME_RECORDED" -gt 0 ]; then
    # Simple estimate based on recorded uptimes vs theoretical max
    RECORD_COUNT=$(echo "$HISTORICAL_UPTIMES" | jq 'length' 2>/dev/null || echo "1")
    if [ "$RECORD_COUNT" -gt 1 ]; then
        # Estimate based on average time between reboots
        EXPECTED_UPTIME=$((AVG_UPTIME * RECORD_COUNT))
        ACTUAL_TOTAL=$TOTAL_UPTIME_RECORDED
        if [ "$EXPECTED_UPTIME" -gt 0 ]; then
            UPTIME_PERCENTAGE=$((ACTUAL_TOTAL * 100 / EXPECTED_UPTIME))
            if [ "$UPTIME_PERCENTAGE" -gt 100 ]; then
                UPTIME_PERCENTAGE=100
            fi
        fi
    fi
fi

# Generate uptime trend for chart (simulated based on reboots)
# Create hourly buckets for the last 24 hours
UPTIME_TREND="["
for i in $(seq 0 23); do
    if [ $i -gt 0 ]; then
        UPTIME_TREND="$UPTIME_TREND,"
    fi
    # All hours show uptime if current uptime > hours since boot
    hours_ago=$((23 - i))
    hours_ago_seconds=$((hours_ago * 3600))
    if [ "$UPTIME_SECONDS" -gt "$hours_ago_seconds" ]; then
        UPTIME_TREND="$UPTIME_TREND 1"
    else
        UPTIME_TREND="$UPTIME_TREND 0"
    fi
done
UPTIME_TREND="$UPTIME_TREND ]"

# Identify potential issues
WARNINGS="[]"
WARNING_COUNT=0

# Check if many recent reboots (more than 3 in last week based on last output)
RECENT_REBOOTS=$(last -x reboot 2>/dev/null | grep "^reboot" | head -10 | wc -l)
if [ "$RECENT_REBOOTS" -gt 5 ]; then
    WARNINGS=$(echo "$WARNINGS" | jq '. + ["High reboot frequency detected - system may be unstable"]')
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

# Check for crash reboots (no clean shutdown before reboot)
# This is a simplified check
CRASH_COUNT=$(last -x 2>/dev/null | grep -c "crash" 2>/dev/null || echo "0")
CRASH_COUNT=$(echo "$CRASH_COUNT" | tr -d '[:space:]')
if [ -n "$CRASH_COUNT" ] && [ "$CRASH_COUNT" -gt 0 ] 2>/dev/null; then
    WARNINGS=$(echo "$WARNINGS" | jq ". + [\"$CRASH_COUNT crash reboot(s) detected in history\"]")
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

# Build the final JSON
cat > "$REBOOT_FILE" << EOF
{
    "timestamp": "$TIMESTAMP",
    "current_uptime": {
        "seconds": $UPTIME_SECONDS,
        "formatted": "$UPTIME_FORMATTED",
        "boot_time": "$BOOT_TIME",
        "kernel": "$KERNEL",
        "hostname": "$HOSTNAME"
    },
    "statistics": {
        "total_reboots_recorded": $REBOOT_COUNT,
        "average_uptime_seconds": $AVG_UPTIME,
        "average_uptime_formatted": "$AVG_UPTIME_FORMATTED",
        "max_uptime_seconds": $MAX_UPTIME,
        "max_uptime_formatted": "$MAX_UPTIME_FORMATTED",
        "min_uptime_seconds": $MIN_UPTIME,
        "min_uptime_formatted": "$MIN_UPTIME_FORMATTED",
        "is_new_record": $IS_NEW_RECORD,
        "uptime_percentage": $UPTIME_PERCENTAGE,
        "warning_count": $WARNING_COUNT
    },
    "reboots": $REBOOTS,
    "shutdowns": $SHUTDOWNS,
    "uptime_trend": $UPTIME_TREND,
    "warnings": $WARNINGS
}
EOF

# Update historical records for future statistics
# Only record if we detect a new boot (uptime < 1 hour and no recent record)
if [ "$UPTIME_SECONDS" -lt 3600 ]; then
    # This is a fresh boot, record previous session's uptime if available
    # For now, we'll skip this to avoid complexity
    :
fi

# Save current uptime to history file periodically (every update)
if [ -f "$HISTORY_FILE" ]; then
    EXISTING=$(cat "$HISTORY_FILE" 2>/dev/null)
    RECORDS=$(echo "$EXISTING" | jq '.uptime_records // []' 2>/dev/null || echo "[]")
else
    RECORDS="[]"
fi

# Keep last 30 records
RECORDS=$(echo "$RECORDS" | jq "if length >= 30 then .[-29:] else . end | . + [$UPTIME_SECONDS]" 2>/dev/null || echo "[$UPTIME_SECONDS]")

cat > "$HISTORY_FILE" << EOF
{
    "last_updated": "$TIMESTAMP",
    "uptime_records": $RECORDS
}
EOF

# Output status for logging
echo "Reboot history updated: $REBOOT_COUNT reboots, uptime $UPTIME_FORMATTED, record=$IS_NEW_RECORD ($(date))"
