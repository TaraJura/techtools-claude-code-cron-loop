#!/bin/bash
# update-compare-data.sh - Generate run comparison data from agent logs
# Extracts detailed metrics from each agent run for comparison purposes

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/compare-runs.json"
ACTORS_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Start JSON output
echo "{" > "$OUTPUT_FILE"
echo "  \"generated\": \"$TIMESTAMP\"," >> "$OUTPUT_FILE"
echo "  \"runs\": [" >> "$OUTPUT_FILE"

first_run=true

# Process each agent's logs (last 7 days only for performance)
seven_days_ago=$(date -d "7 days ago" +%Y%m%d)

for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    # Process recent log files (sorted by name = sorted by time)
    for log_file in $(ls -r "$log_dir"/*.log 2>/dev/null | head -100); do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        filename=$(basename "$log_file")

        # Parse filename: YYYYMMDD_HHMMSS.log
        if [[ ! $filename =~ ^([0-9]{8})_([0-9]{6})\.log$ ]]; then
            continue
        fi

        date_part="${BASH_REMATCH[1]}"
        time_part="${BASH_REMATCH[2]}"

        # Skip if older than 7 days
        if [[ "$date_part" < "$seven_days_ago" ]]; then
            continue
        fi

        # Format readable date/time
        year="${date_part:0:4}"
        month="${date_part:4:2}"
        day="${date_part:6:2}"
        hour="${time_part:0:2}"
        minute="${time_part:2:2}"
        second="${time_part:4:2}"

        run_timestamp="$year-$month-${day}T$hour:$minute:${second}Z"
        readable_time="$year-$month-$day $hour:$minute"

        # Extract metrics from log file
        start_time=""
        end_time=""
        duration_seconds=0
        task_id=""
        has_error=false
        files_read=0
        files_modified=0
        tool_calls=0

        # Read log content
        log_content=$(cat "$log_file" 2>/dev/null)

        # Extract start/end times
        start_line=$(echo "$log_content" | grep -m1 "^Started:")
        end_line=$(echo "$log_content" | grep -m1 "^Completed:")

        if [[ $start_line =~ ^Started:\ (.+)$ ]]; then
            start_time="${BASH_REMATCH[1]}"
        fi

        if [[ $end_line =~ ^Completed:\ (.+)$ ]]; then
            end_time="${BASH_REMATCH[1]}"
        fi

        # Calculate duration
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
            end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
            if [[ $start_epoch -gt 0 && $end_epoch -gt 0 && $end_epoch -gt $start_epoch ]]; then
                duration_seconds=$((end_epoch - start_epoch))
            fi
        fi

        # Extract task ID
        task_match=$(echo "$log_content" | grep -oE "TASK-[0-9]+" | head -1)
        if [[ -n "$task_match" ]]; then
            task_id="$task_match"
        fi

        # Check for errors
        if echo "$log_content" | grep -qi "error\|failed\|exception\|traceback"; then
            has_error=true
        fi

        # Count file operations (approximate)
        files_read=$(echo "$log_content" | grep -cE "(Read|read file|reading)" 2>/dev/null | tr -d '[:space:]')
        files_read=${files_read:-0}
        files_modified=$(echo "$log_content" | grep -cE "(Edit|Write|Created|Modified|changed)" 2>/dev/null | tr -d '[:space:]')
        files_modified=${files_modified:-0}

        # Count tool calls mentioned in log
        tool_calls=$(echo "$log_content" | grep -cE "(Read|Edit|Write|Bash|Glob|Grep|WebFetch)" 2>/dev/null | tr -d '[:space:]')
        tool_calls=${tool_calls:-0}

        # Get log file size (proxy for output verbosity)
        file_size=$(wc -c < "$log_file" 2>/dev/null | tr -d '[:space:]')
        file_size=${file_size:-0}

        # Line count in log
        line_count=$(wc -l < "$log_file" 2>/dev/null | tr -d '[:space:]')
        line_count=${line_count:-0}

        # Extract commit info if present
        commit_hash=""
        files_changed=0
        insertions=0
        deletions=0

        commit_line=$(echo "$log_content" | grep -E "^\[main [a-f0-9]+\]" | head -1)
        if [[ $commit_line =~ ^\[main\ ([a-f0-9]+)\] ]]; then
            commit_hash="${BASH_REMATCH[1]}"
        fi

        changes_line=$(echo "$log_content" | grep -E "[0-9]+ files? changed" | head -1)
        if [[ $changes_line =~ ([0-9]+)\ files?\ changed ]]; then
            files_changed="${BASH_REMATCH[1]}"
        fi
        if [[ $changes_line =~ ([0-9]+)\ insertions? ]]; then
            insertions="${BASH_REMATCH[1]}"
        fi
        if [[ $changes_line =~ ([0-9]+)\ deletions? ]]; then
            deletions="${BASH_REMATCH[1]}"
        fi

        # Output JSON entry
        if [[ $first_run == false ]]; then
            echo "," >> "$OUTPUT_FILE"
        fi
        first_run=false

        # Escape task_id for JSON
        task_id_json=""
        if [[ -n "$task_id" ]]; then
            task_id_json="\"$task_id\""
        else
            task_id_json="null"
        fi

        commit_json=""
        if [[ -n "$commit_hash" ]]; then
            commit_json="\"$commit_hash\""
        else
            commit_json="null"
        fi

        cat >> "$OUTPUT_FILE" << EOF
    {
      "id": "${agent}_${date_part}_${time_part}",
      "agent": "$agent",
      "timestamp": "$run_timestamp",
      "readable_time": "$readable_time",
      "filename": "$filename",
      "duration_seconds": $duration_seconds,
      "task_id": $task_id_json,
      "has_error": $has_error,
      "metrics": {
        "files_read": $files_read,
        "files_modified": $files_modified,
        "tool_calls": $tool_calls,
        "log_size_bytes": $file_size,
        "log_lines": $line_count,
        "files_changed": $files_changed,
        "insertions": $insertions,
        "deletions": $deletions,
        "commit": $commit_json
      }
    }
EOF
    done
done

echo "" >> "$OUTPUT_FILE"
echo "  ]" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "Compare data updated: $OUTPUT_FILE"
