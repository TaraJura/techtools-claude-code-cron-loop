#!/bin/bash
# update-uptime.sh - Collects service uptime data and stores it for the web dashboard
# This script should be run every minute via cron to build uptime history
#
# Services monitored:
# - nginx: Web server
# - cron: Task scheduler
# - ssh: SSH daemon
# - systemd-timesyncd: Time synchronization
#
# Data is stored in /var/www/cronloop.techtools.cz/api/uptime-history.json

set -e

# Configuration
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/uptime-history.json"
MAX_ENTRIES=43200  # Keep last 30 days at 1-minute intervals (30*24*60)

# Services to monitor (must match systemd service names)
SERVICES=("nginx" "cron" "ssh" "systemd-timesyncd")

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

# Check each service status
check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "up"
    else
        echo "down"
    fi
}

# Build status object for this check
build_status() {
    local first=true
    echo -n "{"
    echo -n "\"timestamp\":\"$TIMESTAMP\","
    echo -n "\"epoch\":$EPOCH,"
    echo -n "\"services\":{"

    for service in "${SERVICES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo -n ","
        fi
        local status=$(check_service "$service")
        echo -n "\"$service\":\"$status\""
    done

    echo -n "}}"
}

# Initialize empty history file if it doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    echo '{"history":[],"summary":{},"last_updated":""}' > "$OUTPUT_FILE"
fi

# Read existing data (handle empty or invalid JSON)
EXISTING=$(cat "$OUTPUT_FILE" 2>/dev/null || echo '{"history":[],"summary":{},"last_updated":""}')

# Validate JSON structure
if ! echo "$EXISTING" | jq -e '.history' > /dev/null 2>&1; then
    EXISTING='{"history":[],"summary":{},"last_updated":""}'
fi

# Get current status
CURRENT_STATUS=$(build_status)

# Add new entry and trim old entries
# Keep only the last MAX_ENTRIES
NEW_HISTORY=$(echo "$EXISTING" | jq --argjson entry "$CURRENT_STATUS" --argjson max "$MAX_ENTRIES" '
    .history = ([$entry] + .history) | .history = .history[:$max]
')

# Calculate summary statistics
calc_uptime_percent() {
    local service="$1"
    local period_seconds="$2"
    local cutoff_epoch=$((EPOCH - period_seconds))

    echo "$NEW_HISTORY" | jq --arg service "$service" --argjson cutoff "$cutoff_epoch" '
        [.history[] | select(.epoch >= $cutoff) | .services[$service]] |
        if length == 0 then 100
        else
            (map(select(. == "up")) | length) / length * 100 | . * 100 | floor / 100
        end
    '
}

# Get current streak (how long each service has been up continuously)
calc_streak() {
    local service="$1"
    echo "$NEW_HISTORY" | jq --arg service "$service" '
        .history |
        reduce .[] as $item (
            {streak: 0, counting: true};
            if .counting and $item.services[$service] == "up" then
                {streak: (.streak + 60), counting: true}
            else
                {streak: .streak, counting: false}
            end
        ) | .streak
    '
}

# Calculate last downtime for each service
calc_last_downtime() {
    local service="$1"
    echo "$NEW_HISTORY" | jq --arg service "$service" '
        [.history[] | select(.services[$service] == "down")] |
        if length > 0 then .[0].timestamp else null end
    '
}

# Count total checks and failures in period
calc_stats() {
    local service="$1"
    local period_seconds="$2"
    local cutoff_epoch=$((EPOCH - period_seconds))

    echo "$NEW_HISTORY" | jq --arg service "$service" --argjson cutoff "$cutoff_epoch" '
        [.history[] | select(.epoch >= $cutoff)] |
        {
            total_checks: length,
            up_checks: [.[] | select(.services[$service] == "up")] | length,
            down_checks: [.[] | select(.services[$service] == "down")] | length
        }
    '
}

# Build summary for each service
SUMMARY="{"
first_service=true

for service in "${SERVICES[@]}"; do
    if [ "$first_service" = true ]; then
        first_service=false
    else
        SUMMARY="$SUMMARY,"
    fi

    # Calculate uptime percentages for different periods
    UPTIME_1H=$(calc_uptime_percent "$service" 3600)
    UPTIME_24H=$(calc_uptime_percent "$service" 86400)
    UPTIME_7D=$(calc_uptime_percent "$service" 604800)
    UPTIME_30D=$(calc_uptime_percent "$service" 2592000)

    # Get current streak
    STREAK=$(calc_streak "$service")

    # Get last downtime
    LAST_DOWN=$(calc_last_downtime "$service")

    # Get stats for 24h
    STATS_24H=$(calc_stats "$service" 86400)

    # Current status
    CURRENT=$(check_service "$service")

    SUMMARY="$SUMMARY\"$service\":{"
    SUMMARY="$SUMMARY\"current\":\"$CURRENT\","
    SUMMARY="$SUMMARY\"uptime_1h\":$UPTIME_1H,"
    SUMMARY="$SUMMARY\"uptime_24h\":$UPTIME_24H,"
    SUMMARY="$SUMMARY\"uptime_7d\":$UPTIME_7D,"
    SUMMARY="$SUMMARY\"uptime_30d\":$UPTIME_30D,"
    SUMMARY="$SUMMARY\"current_streak_seconds\":$STREAK,"
    SUMMARY="$SUMMARY\"last_downtime\":$LAST_DOWN,"
    SUMMARY="$SUMMARY\"stats_24h\":$STATS_24H"
    SUMMARY="$SUMMARY}"
done

SUMMARY="$SUMMARY}"

# Build final output
FINAL_OUTPUT=$(echo "$NEW_HISTORY" | jq --argjson summary "$SUMMARY" --arg timestamp "$TIMESTAMP" '
    .summary = $summary |
    .last_updated = $timestamp
')

# Write atomically using temp file
TEMP_FILE=$(mktemp)
echo "$FINAL_OUTPUT" > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Uptime data updated at $TIMESTAMP"
