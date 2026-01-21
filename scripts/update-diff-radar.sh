#!/bin/bash
# update-diff-radar.sh - Generate diff radar data showing system changes
# Aggregates changes from multiple sources: git commits, config drift, task states, security events, and metrics

API_DIR="/var/www/cronloop.techtools.cz/api"
HOME_DIR="/home/novakj"
OUTPUT_FILE="$API_DIR/diff-radar.json"
HISTORY_FILE="$API_DIR/diff-radar-history.json"

# Time ranges in seconds
HOUR_1=$((60 * 60))
HOURS_6=$((6 * 60 * 60))
HOURS_24=$((24 * 60 * 60))
DAYS_7=$((7 * 24 * 60 * 60))

NOW=$(date +%s)
NOW_ISO=$(date --iso-8601=seconds)

# Initialize arrays for each category
declare -a FILE_CHANGES
declare -a CONFIG_CHANGES
declare -a METRIC_CHANGES
declare -a SECURITY_EVENTS
declare -a TASK_CHANGES

# Get file changes from git commits in the last 7 days
get_file_changes() {
    local since_date=$(date -d "@$((NOW - DAYS_7))" --iso-8601=seconds)
    local temp_file=$(mktemp)

    cd "$HOME_DIR" 2>/dev/null || return

    # Get commits with their timestamps and changed files
    git log --since="$since_date" --pretty=format:'%H|%ct|%an|%s' --name-status 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" =~ ^[a-f0-9]{40}\| ]]; then
            # This is a commit line
            commit_hash=$(echo "$line" | cut -d'|' -f1)
            commit_time=$(echo "$line" | cut -d'|' -f2)
            author=$(echo "$line" | cut -d'|' -f3)
            message=$(echo "$line" | cut -d'|' -f4)

            # Determine agent from commit message
            agent=""
            if [[ "$message" =~ \[(.*)\] ]]; then
                agent="${BASH_REMATCH[1]}"
            fi

            # Store current commit context
            echo "COMMIT|$commit_hash|$commit_time|$author|$agent|$message" >> "$temp_file"
        elif [[ "$line" =~ ^[AMD]$'\t' ]]; then
            # This is a file change line
            status=$(echo "$line" | cut -c1)
            filepath=$(echo "$line" | cut -f2-)
            echo "FILE|$status|$filepath" >> "$temp_file"
        fi
    done

    # Process the temp file to build JSON
    local current_commit=""
    local current_time=""
    local current_author=""
    local current_agent=""
    local current_message=""
    local first=true

    echo -n "["
    while IFS='|' read -r type f1 f2 f3 f4 f5; do
        if [[ "$type" == "COMMIT" ]]; then
            current_commit="$f1"
            current_time="$f2"
            current_author="$f3"
            current_agent="$f4"
            current_message="$f5"
        elif [[ "$type" == "FILE" ]]; then
            [[ -z "$current_commit" ]] && continue

            local status="$f1"
            local filepath="$f2"

            # Determine file type
            local extension="${filepath##*.}"
            [[ "$extension" == "$filepath" ]] && extension="none"

            # Calculate age in seconds
            local age=$((NOW - current_time))

            # Skip if file doesn't exist and status is not D
            if [[ "$status" != "D" ]] && [[ ! -f "$HOME_DIR/$filepath" ]]; then
                continue
            fi

            # Escape special characters for JSON
            local safe_path=$(echo "$filepath" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
            local safe_message=$(echo "$current_message" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')

            [[ "$first" == "false" ]] && echo -n ","
            first=false

            cat <<EOF
{"type":"file","path":"$safe_path","status":"$status","extension":"$extension","timestamp":$current_time,"age":$age,"commit":"${current_commit:0:7}","author":"$current_author","agent":"$current_agent","message":"$safe_message"}
EOF
        fi
    done < "$temp_file"
    echo "]"

    rm -f "$temp_file"
}

# Get config drift changes
get_config_changes() {
    local drift_file="$API_DIR/config-drift.json"

    if [[ ! -f "$drift_file" ]]; then
        echo "[]"
        return
    fi

    # Parse config-drift.json for any changes
    if command -v jq &> /dev/null; then
        jq '[.files[]? | select(.status != "unchanged") | {
            type: "config",
            path: .path,
            status: .status,
            category: .category,
            alert_level: .alert_level,
            timestamp: (if .modified then (.modified | fromdateiso8601) else now end),
            age: (now - (if .modified then (.modified | fromdateiso8601) else now end)),
            current_hash: .current_hash,
            baseline_hash: .baseline_hash
        }]' "$drift_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Get metric changes (significant changes in system metrics)
get_metric_changes() {
    local metrics_file="$API_DIR/system-metrics.json"
    local history_file="$API_DIR/metrics-history.json"

    if [[ ! -f "$metrics_file" ]] || [[ ! -f "$history_file" ]]; then
        echo "[]"
        return
    fi

    if command -v jq &> /dev/null; then
        # Look for significant metric changes in history
        jq --arg now "$NOW" '[
            .history[-24:]? // [] | .[] |
            select(.disk_percent > 80 or .memory_percent > 80) |
            {
                type: "metric",
                metric: (if .disk_percent > 80 then "disk" else "memory" end),
                value: (if .disk_percent > 80 then .disk_percent else .memory_percent end),
                threshold: 80,
                timestamp: (if .timestamp then (.timestamp | fromdateiso8601) else ($now | tonumber) end),
                age: (($now | tonumber) - (if .timestamp then (.timestamp | fromdateiso8601) else ($now | tonumber) end)),
                status: "warning"
            }
        ]' "$history_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Get security events
get_security_events() {
    local security_file="$API_DIR/security-metrics.json"
    local auth_log="/var/log/auth.log"
    local temp_file=$(mktemp)

    echo -n "["
    local first=true

    # Get SSH attacks from security-metrics.json
    if [[ -f "$security_file" ]] && command -v jq &> /dev/null; then
        local total_attacks=$(jq -r '.ssh_attacks.total_attempts // 0' "$security_file" 2>/dev/null)
        local timestamp=$(jq -r '.timestamp // empty' "$security_file" 2>/dev/null)

        if [[ -n "$timestamp" ]] && [[ "$total_attacks" -gt 0 ]]; then
            local event_time=$(date -d "$timestamp" +%s 2>/dev/null || echo "$NOW")
            local age=$((NOW - event_time))

            [[ "$first" == "false" ]] && echo -n ","
            first=false
            echo -n "{\"type\":\"security\",\"event\":\"ssh_attacks\",\"count\":$total_attacks,\"timestamp\":$event_time,\"age\":$age,\"severity\":\"warning\",\"description\":\"SSH brute force attempts detected\"}"
        fi

        # Get top attackers
        jq -r '.ssh_attacks.top_attackers[]? | "\(.ip)|\(.count)"' "$security_file" 2>/dev/null | head -5 | while IFS='|' read -r ip count; do
            [[ -z "$ip" ]] && continue
            [[ "$first" == "false" ]] && echo -n ","
            first=false
            echo -n "{\"type\":\"security\",\"event\":\"attacker\",\"ip\":\"$ip\",\"count\":$count,\"timestamp\":$NOW,\"age\":0,\"severity\":\"high\",\"description\":\"Top attacker: $ip ($count attempts)\"}"
        done
    fi

    echo "]"
    rm -f "$temp_file"
}

# Get task state changes from workflow.json
get_task_changes() {
    local workflow_file="$API_DIR/workflow.json"
    local tasks_file="$HOME_DIR/tasks.md"

    if [[ ! -f "$workflow_file" ]]; then
        echo "[]"
        return
    fi

    if command -v jq &> /dev/null; then
        # Extract recent task completions
        local temp_changes=$(jq '[
            .daily_completions[-7:]? // [] | .[] |
            select(.completed > 0) |
            {
                type: "task",
                event: "completion",
                date: .date,
                count: .completed,
                timestamp: (.date | strptime("%Y-%m-%d") | mktime),
                age: (now - (.date | strptime("%Y-%m-%d") | mktime)),
                status: "completed"
            }
        ]' "$workflow_file" 2>/dev/null || echo "[]")

        echo "$temp_changes"
    else
        echo "[]"
    fi
}

# Calculate changes per hour rate
calculate_velocity() {
    local changes="$1"
    local period_hours="$2"

    if command -v jq &> /dev/null; then
        local period_seconds=$((period_hours * 3600))
        local count=$(echo "$changes" | jq --arg period "$period_seconds" '[.[] | select(.age < ($period | tonumber))] | length' 2>/dev/null || echo "0")
        echo "scale=2; $count / $period_hours" | bc 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Main execution
main() {
    mkdir -p "$API_DIR"

    # Collect all changes
    local file_changes=$(get_file_changes)
    local config_changes=$(get_config_changes)
    local metric_changes=$(get_metric_changes)
    local security_events=$(get_security_events)
    local task_changes=$(get_task_changes)

    # Merge all changes into a single array
    local all_changes="[]"
    if command -v jq &> /dev/null; then
        all_changes=$(jq -s 'add | sort_by(-.timestamp)' <<< "$file_changes $config_changes $metric_changes $security_events $task_changes" 2>/dev/null || echo "[]")
    fi

    # Calculate statistics
    local total_changes=$(echo "$all_changes" | jq 'length' 2>/dev/null || echo "0")
    local changes_1h=$(echo "$all_changes" | jq --arg age "$HOUR_1" '[.[] | select(.age < ($age | tonumber))] | length' 2>/dev/null || echo "0")
    local changes_6h=$(echo "$all_changes" | jq --arg age "$HOURS_6" '[.[] | select(.age < ($age | tonumber))] | length' 2>/dev/null || echo "0")
    local changes_24h=$(echo "$all_changes" | jq --arg age "$HOURS_24" '[.[] | select(.age < ($age | tonumber))] | length' 2>/dev/null || echo "0")
    local changes_7d=$(echo "$all_changes" | jq --arg age "$DAYS_7" '[.[] | select(.age < ($age | tonumber))] | length' 2>/dev/null || echo "0")

    # Calculate velocity (changes per hour)
    local velocity_1h=$(echo "scale=2; $changes_1h / 1" | bc 2>/dev/null || echo "0")
    local velocity_6h=$(echo "scale=2; $changes_6h / 6" | bc 2>/dev/null || echo "0")
    local velocity_24h=$(echo "scale=2; $changes_24h / 24" | bc 2>/dev/null || echo "0")

    # Count by category
    local file_count=$(echo "$all_changes" | jq '[.[] | select(.type == "file")] | length' 2>/dev/null || echo "0")
    local config_count=$(echo "$all_changes" | jq '[.[] | select(.type == "config")] | length' 2>/dev/null || echo "0")
    local metric_count=$(echo "$all_changes" | jq '[.[] | select(.type == "metric")] | length' 2>/dev/null || echo "0")
    local security_count=$(echo "$all_changes" | jq '[.[] | select(.type == "security")] | length' 2>/dev/null || echo "0")
    local task_count=$(echo "$all_changes" | jq '[.[] | select(.type == "task")] | length' 2>/dev/null || echo "0")

    # Get recent changes (last 100 for display)
    local recent_changes=$(echo "$all_changes" | jq '.[0:100]' 2>/dev/null || echo "[]")

    # Generate output JSON
    cat > "$OUTPUT_FILE" <<EOF
{
  "generated": "$NOW_ISO",
  "timestamp": $NOW,
  "summary": {
    "total_changes": $total_changes,
    "changes_1h": $changes_1h,
    "changes_6h": $changes_6h,
    "changes_24h": $changes_24h,
    "changes_7d": $changes_7d,
    "velocity_1h": $velocity_1h,
    "velocity_6h": $velocity_6h,
    "velocity_24h": $velocity_24h
  },
  "by_category": {
    "file": $file_count,
    "config": $config_count,
    "metric": $metric_count,
    "security": $security_count,
    "task": $task_count
  },
  "changes": $recent_changes
}
EOF

    # Update history file (keep last 7 days of hourly snapshots)
    if [[ -f "$HISTORY_FILE" ]] && command -v jq &> /dev/null; then
        local cutoff=$((NOW - DAYS_7))
        local new_entry="{\"timestamp\":$NOW,\"total\":$total_changes,\"changes_1h\":$changes_1h,\"velocity\":$velocity_1h}"
        jq --arg cutoff "$cutoff" --argjson entry "$new_entry" '
            .history = ([.history[]? | select(.timestamp > ($cutoff | tonumber))] + [$entry])
        ' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    else
        echo "{\"history\":[{\"timestamp\":$NOW,\"total\":$total_changes,\"changes_1h\":$changes_1h,\"velocity\":$velocity_1h}]}" > "$HISTORY_FILE"
    fi

    echo "Diff radar data updated: $OUTPUT_FILE"
}

main "$@"
