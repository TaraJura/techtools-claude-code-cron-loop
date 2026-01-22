#!/bin/bash
# update-timers.sh - Collects detailed systemd timer data for the web dashboard
# Creates /api/timers.json with all systemd timers, their schedules, last/next runs

set -eo pipefail

API_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$API_DIR/timers.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Convert microseconds timestamp to ISO format
us_to_iso() {
    local us="$1"
    if [[ -z "$us" || "$us" == "null" || "$us" == "0" ]]; then
        echo "null"
    else
        # Convert microseconds to seconds
        local sec=$((us / 1000000))
        local result=$(date -d "@$sec" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "\"$result\""
        else
            echo "null"
        fi
    fi
}

# Convert microseconds to human-readable duration
us_to_human() {
    local us="$1"
    if [[ -z "$us" || "$us" == "null" || "$us" == "0" ]]; then
        echo ""
    else
        local sec=$((us / 1000000))
        local min=$((sec / 60))
        local hr=$((min / 60))
        local day=$((hr / 24))

        if [[ $day -gt 0 ]]; then
            echo "${day}d $((hr % 24))h"
        elif [[ $hr -gt 0 ]]; then
            echo "${hr}h $((min % 60))m"
        elif [[ $min -gt 0 ]]; then
            echo "${min}m $((sec % 60))s"
        else
            echo "${sec}s"
        fi
    fi
}

# Parse OnCalendar specification to human-readable format
parse_oncalendar() {
    local spec="$1"

    # Common patterns
    case "$spec" in
        "daily") echo "Daily" ;;
        "weekly") echo "Weekly" ;;
        "monthly") echo "Monthly" ;;
        "yearly") echo "Yearly" ;;
        "hourly") echo "Hourly" ;;
        "minutely") echo "Every minute" ;;
        "*-*-* *:00:00") echo "Hourly" ;;
        "*-*-* 00:00:00") echo "Daily at midnight" ;;
        *) echo "$spec" ;;
    esac
}

# Get timer unit file schedule info
get_timer_schedule() {
    local unit="$1"
    local schedule=""

    # Try to get OnCalendar from unit file
    local oncal=$(systemctl show "$unit" -p OnCalendar 2>/dev/null | cut -d= -f2-)
    if [[ -n "$oncal" && "$oncal" != "n/a" ]]; then
        schedule="$oncal"
    else
        # Try OnBootSec, OnUnitActiveSec, etc.
        local onboot=$(systemctl show "$unit" -p OnBootSec 2>/dev/null | cut -d= -f2-)
        local onactive=$(systemctl show "$unit" -p OnUnitActiveSec 2>/dev/null | cut -d= -f2-)

        if [[ -n "$onboot" && "$onboot" != "infinity" && "$onboot" != "0" ]]; then
            schedule="$onboot after boot"
        elif [[ -n "$onactive" && "$onactive" != "infinity" && "$onactive" != "0" ]]; then
            schedule="Every $onactive"
        fi
    fi

    echo "$schedule"
}

# Get service description
get_description() {
    local unit="$1"
    systemctl show "$unit" -p Description 2>/dev/null | cut -d= -f2- || echo ""
}

# Check if service is failed
is_service_failed() {
    local service="$1"
    local state=$(systemctl is-failed "$service" 2>/dev/null || echo "unknown")
    [[ "$state" == "failed" ]] && echo "true" || echo "false"
}

# Get last service result
get_service_result() {
    local service="$1"
    systemctl show "$service" -p Result 2>/dev/null | cut -d= -f2- || echo "unknown"
}

# Main: Collect timer data
echo "Collecting systemd timer data..."

# Get JSON data from systemctl
timer_json=$(systemctl list-timers --all --no-pager --output=json 2>/dev/null || echo "[]")

# Build the output JSON
{
    echo "{"
    echo "  \"timestamp\": \"$TIMESTAMP\","
    echo "  \"timers\": ["

    first=true

    # Parse the JSON output
    echo "$timer_json" | jq -c '.[]' 2>/dev/null | while read -r timer; do
        unit=$(echo "$timer" | jq -r '.unit // empty')
        activates=$(echo "$timer" | jq -r '.activates // empty')
        next_us=$(echo "$timer" | jq -r '.next // 0')
        last_us=$(echo "$timer" | jq -r '.last // 0')
        left_us=$(echo "$timer" | jq -r '.left // 0')
        passed_us=$(echo "$timer" | jq -r '.passed // 0')

        if [[ -z "$unit" ]]; then
            continue
        fi

        # Extract timer name (remove .timer suffix)
        name="${unit%.timer}"
        service="${activates:-${name}.service}"

        # Get additional info
        schedule=$(get_timer_schedule "$unit")
        schedule_human=$(parse_oncalendar "$schedule")
        description=$(get_description "$unit")
        failed=$(is_service_failed "$service")
        result=$(get_service_result "$service")

        # Convert timestamps
        next_run=$(us_to_iso "$next_us")
        last_run=$(us_to_iso "$last_us")
        left=$(us_to_human "$left_us")
        passed=$(us_to_human "$passed_us")

        # Check if timer is active
        is_active=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
        active="true"
        [[ "$is_active" != "active" ]] && active="false"

        # Output JSON for this timer
        if [[ "$first" != "true" ]]; then
            echo ","
        fi
        first=false

        cat << EOF
    {
      "name": "$name",
      "unit": "$unit",
      "service": "$service",
      "schedule": "$schedule",
      "schedule_human": "$schedule_human",
      "description": "$description",
      "next_run": $next_run,
      "last_run": $last_run,
      "left": "$left",
      "passed": "$passed",
      "active": $active,
      "failed": $failed,
      "result": "$result"
    }
EOF
    done

    echo ""
    echo "  ],"

    # Add summary statistics
    total=$(echo "$timer_json" | jq 'length')
    active_count=$(systemctl list-timers --state=active --no-pager --output=json 2>/dev/null | jq 'length' || echo "0")

    # Count failed services
    failed_count=0
    while read -r timer; do
        activates=$(echo "$timer" | jq -r '.activates // empty')
        if [[ -n "$activates" ]]; then
            state=$(systemctl is-failed "$activates" 2>/dev/null || echo "")
            [[ "$state" == "failed" ]] && ((failed_count++)) || true
        fi
    done < <(echo "$timer_json" | jq -c '.[]' 2>/dev/null)

    # Find next timer to trigger
    next_timer=$(echo "$timer_json" | jq -r '[.[] | select(.next != null and .next > 0)] | sort_by(.next) | .[0] // empty')
    next_unit=$(echo "$next_timer" | jq -r '.unit // ""')
    next_time_us=$(echo "$next_timer" | jq -r '.next // 0')
    next_time_iso=$(us_to_iso "$next_time_us")

    echo "  \"summary\": {"
    echo "    \"total\": $total,"
    echo "    \"active\": $active_count,"
    echo "    \"failed\": $failed_count,"
    echo "    \"next_timer\": \"$next_unit\","
    echo "    \"next_time\": $next_time_iso"
    echo "  }"

    echo "}"
} > "$OUTPUT_FILE"

echo "Timer data saved to $OUTPUT_FILE"
