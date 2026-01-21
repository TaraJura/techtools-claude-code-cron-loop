#!/bin/bash
# update-activity.sh - Generate activity data including live agent status, presence, and annotations
# Used by activity.html for real-time collaboration awareness

API_DIR="/var/www/cronloop.techtools.cz/api"
ACTORS_DIR="/home/novakj/actors"
LOG_DIR="/home/novakj"

# Initialize activity.json if it doesn't exist
ACTIVITY_FILE="$API_DIR/activity.json"
VIEWERS_FILE="$API_DIR/viewers.json"
ANNOTATIONS_FILE="$API_DIR/annotations.json"

# Check if cron-orchestrator is running
check_orchestrator_running() {
    local pid_file="$LOG_DIR/actors/cron.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "true"
            return
        fi
    fi

    # Fallback: check by process name
    if pgrep -f "cron-orchestrator.sh" > /dev/null 2>&1; then
        echo "true"
        return
    fi

    echo "false"
}

# Detect currently running agent
detect_running_agent() {
    # Check for running claude-code processes
    local running_agent=""
    local start_time=""

    # Check each agent's log directory for recent activity
    for agent in idea-maker project-manager developer developer2 tester security supervisor; do
        local latest_log=$(ls -t "$ACTORS_DIR/$agent/logs/"*.log 2>/dev/null | head -1)
        if [[ -f "$latest_log" ]]; then
            # Check if log file was modified in the last 60 seconds (likely active)
            local mod_time=$(stat -c %Y "$latest_log" 2>/dev/null || echo "0")
            local now=$(date +%s)
            local age=$((now - mod_time))

            if [[ $age -lt 60 ]]; then
                running_agent="$agent"
                # Extract start time from log filename
                local log_name=$(basename "$latest_log")
                local timestamp="${log_name%.log}"
                start_time=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" +%s 2>/dev/null || echo "$mod_time")
                break
            fi
        fi
    done

    if [[ -n "$running_agent" ]]; then
        echo "$running_agent|$start_time"
    else
        echo "|"
    fi
}

# Get recent agent runs from logs
get_recent_runs() {
    local max_runs=20
    local temp_file=$(mktemp)
    local output_file=$(mktemp)

    # Collect recent logs from all agents
    for agent in idea-maker project-manager developer developer2 tester security supervisor; do
        local logs=$(ls -t "$ACTORS_DIR/$agent/logs/"*.log 2>/dev/null | head -5)
        for log in $logs; do
            if [[ -f "$log" ]]; then
                local mod_time=$(stat -c %Y "$log" 2>/dev/null)
                echo "$mod_time|$agent|$log" >> "$temp_file"
            fi
        done
    done

    # Sort by modification time and take most recent, build JSON array
    local count=0
    sort -t'|' -k1 -rn "$temp_file" | head -$max_runs | while IFS='|' read -r mod_time agent log; do
        [[ -z "$log" ]] && continue

        local log_name=$(basename "$log")
        local timestamp="${log_name%.log}"
        local iso_time=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" --iso-8601=seconds 2>/dev/null || echo "")

        # Check if log contains errors
        local has_error="false"
        if grep -q "error\|Error\|ERROR\|failed\|Failed\|FAILED" "$log" 2>/dev/null; then
            has_error="true"
        fi

        # Get file size
        local size=$(stat -c %s "$log" 2>/dev/null || echo "0")

        echo "{\"agent\":\"$agent\",\"timestamp\":\"$iso_time\",\"logFile\":\"$log_name\",\"hasError\":$has_error,\"size\":$size}" >> "$output_file"
    done

    # Build the JSON array
    if [[ -s "$output_file" ]]; then
        echo -n "["
        local first=true
        while read -r line; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo -n ","
            fi
            echo -n "$line"
        done < "$output_file"
        echo "]"
    else
        echo "[]"
    fi

    rm -f "$temp_file" "$output_file"
}

# Clean up stale viewers (older than 5 minutes)
cleanup_viewers() {
    if [[ -f "$VIEWERS_FILE" ]]; then
        local now=$(date +%s)
        local cutoff=$((now - 300))  # 5 minutes

        # Use jq if available, otherwise manual cleanup
        if command -v jq &> /dev/null; then
            local temp_file=$(mktemp)
            jq --arg cutoff "$cutoff" '[.viewers[] | select((.last_seen | tonumber) > ($cutoff | tonumber))]' "$VIEWERS_FILE" > "$temp_file" 2>/dev/null
            if [[ $? -eq 0 ]] && [[ -s "$temp_file" ]]; then
                echo "{\"viewers\": $(cat "$temp_file"), \"updated\": \"$(date --iso-8601=seconds)\"}" > "$VIEWERS_FILE"
            fi
            rm -f "$temp_file"
        fi
    fi
}

# Main execution
main() {
    # Create API directory if needed
    mkdir -p "$API_DIR"

    # Initialize viewers file if it doesn't exist
    if [[ ! -f "$VIEWERS_FILE" ]]; then
        echo '{"viewers": [], "updated": "'$(date --iso-8601=seconds)'"}' > "$VIEWERS_FILE"
    fi

    # Initialize annotations file if it doesn't exist
    if [[ ! -f "$ANNOTATIONS_FILE" ]]; then
        echo '{"annotations": [], "updated": "'$(date --iso-8601=seconds)'"}' > "$ANNOTATIONS_FILE"
    fi

    # Clean up stale viewers
    cleanup_viewers

    # Check orchestrator status
    local orchestrator_running=$(check_orchestrator_running)

    # Detect running agent
    local agent_info=$(detect_running_agent)
    local running_agent=$(echo "$agent_info" | cut -d'|' -f1)
    local agent_start=$(echo "$agent_info" | cut -d'|' -f2)

    # Get viewer count
    local viewer_count=0
    if [[ -f "$VIEWERS_FILE" ]] && command -v jq &> /dev/null; then
        viewer_count=$(jq '.viewers | length' "$VIEWERS_FILE" 2>/dev/null || echo "0")
    fi

    # Get annotation count (last 24h)
    local annotation_count=0
    if [[ -f "$ANNOTATIONS_FILE" ]] && command -v jq &> /dev/null; then
        local yesterday=$(date -d "24 hours ago" --iso-8601=seconds)
        annotation_count=$(jq --arg cutoff "$yesterday" '[.annotations[] | select(.timestamp > $cutoff)] | length' "$ANNOTATIONS_FILE" 2>/dev/null || echo "0")
    fi

    # Get recent activity
    local recent_runs=$(get_recent_runs)

    # Generate activity.json
    cat > "$ACTIVITY_FILE" <<EOF
{
  "generated": "$(date --iso-8601=seconds)",
  "orchestrator": {
    "running": $orchestrator_running,
    "lastCheck": "$(date --iso-8601=seconds)"
  },
  "currentAgent": {
    "name": "$running_agent",
    "startTime": ${agent_start:-null},
    "running": $([ -n "$running_agent" ] && echo "true" || echo "false")
  },
  "viewers": {
    "count": $viewer_count,
    "file": "/api/viewers.json"
  },
  "annotations": {
    "count24h": $annotation_count,
    "file": "/api/annotations.json"
  },
  "recentRuns": $recent_runs
}
EOF

    echo "Activity data updated: $ACTIVITY_FILE"
}

main "$@"
