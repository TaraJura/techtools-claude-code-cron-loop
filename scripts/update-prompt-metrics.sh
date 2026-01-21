#!/bin/bash
# update-prompt-metrics.sh - Correlates agent runs with prompt versions for A/B testing metrics
# Output: JSON data for prompt versioning A/B testing page

set -e

REPO_DIR="/home/novakj"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/prompt-metrics.json"
ACTORS_DIR="$REPO_DIR/actors"
TASKS_FILE="$REPO_DIR/tasks.md"
TASKS_ARCHIVE_DIR="$REPO_DIR/logs/tasks-archive"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

cd "$REPO_DIR"

# Agent list
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Create temporary file for building JSON
TMP_FILE=$(mktemp)

# Function to get prompt version hash active at a given timestamp
get_prompt_version_at_time() {
    local agent="$1"
    local timestamp="$2"  # ISO format
    local prompt_file="actors/$agent/prompt.md"

    git log -1 --until="$timestamp" --format="%H" -- "$prompt_file" 2>/dev/null || echo ""
}

# Function to calculate task status from tasks.md
get_task_status() {
    local task_id="$1"

    # Check active tasks file first
    local status=$(grep -A5 "### $task_id:" "$TASKS_FILE" 2>/dev/null | grep -oP '\*\*Status\*\*: \K\w+' | head -1 || echo "")

    # If not found, check archive
    if [ -z "$status" ] && [ -d "$TASKS_ARCHIVE_DIR" ]; then
        for archive in "$TASKS_ARCHIVE_DIR"/tasks-*.md; do
            [ -f "$archive" ] || continue
            status=$(grep -A5 "### $task_id:" "$archive" 2>/dev/null | grep -oP '\*\*Status\*\*: \K\w+' | head -1 || echo "")
            [ -n "$status" ] && break
        done
    fi

    echo "${status:-UNKNOWN}"
}

# Start JSON structure
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "agents": [
EOF

FIRST_AGENT=true

for AGENT in "${AGENTS[@]}"; do
    PROMPT_FILE="actors/$AGENT/prompt.md"
    AGENT_LOGS_DIR="$ACTORS_DIR/$AGENT/logs"

    # Skip if prompt file doesn't exist
    [ ! -f "$PROMPT_FILE" ] && continue

    # Add comma separator
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    # Get all prompt version hashes for this agent into a file for easy lookup
    VERSION_DATA_FILE=$(mktemp)
    git log --pretty=format:'%H|%aI|%s' -n 50 -- "$PROMPT_FILE" 2>/dev/null > "$VERSION_DATA_FILE" || true

    # Create files to track metrics for each version
    METRICS_DIR=$(mktemp -d)

    # Initialize version tracking
    while IFS='|' read -r hash date subject; do
        [ -z "$hash" ] && continue
        mkdir -p "$METRICS_DIR/$hash"
        echo "0" > "$METRICS_DIR/$hash/runs"
        echo "0" > "$METRICS_DIR/$hash/success"
        echo "0" > "$METRICS_DIR/$hash/errors"
        echo "0" > "$METRICS_DIR/$hash/duration"
        echo "0" > "$METRICS_DIR/$hash/tasks_done"
        echo "0" > "$METRICS_DIR/$hash/tasks_failed"
        echo "0" > "$METRICS_DIR/$hash/lines_changed"
        echo "" > "$METRICS_DIR/$hash/first_run"
        echo "" > "$METRICS_DIR/$hash/last_run"
    done < "$VERSION_DATA_FILE"

    # Parse log files to correlate runs with prompt versions
    if [ -d "$AGENT_LOGS_DIR" ]; then
        for log_file in "$AGENT_LOGS_DIR"/*.log; do
            [ -f "$log_file" ] || continue

            # Extract timestamp from filename (format: YYYYMMDD_HHMMSS.log)
            filename=$(basename "$log_file")
            if [[ "$filename" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.log$ ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
                day="${BASH_REMATCH[3]}"
                hour="${BASH_REMATCH[4]}"
                min="${BASH_REMATCH[5]}"
                sec="${BASH_REMATCH[6]}"
                log_timestamp="${year}-${month}-${day}T${hour}:${min}:${sec}Z"
            else
                continue
            fi

            # Get prompt version active at this time
            version_hash=$(get_prompt_version_at_time "$AGENT" "$log_timestamp")
            [ -z "$version_hash" ] && continue

            # Only count if we have this version tracked
            if [ -d "$METRICS_DIR/$version_hash" ]; then
                # Increment run count
                runs=$(cat "$METRICS_DIR/$version_hash/runs")
                echo "$((runs + 1))" > "$METRICS_DIR/$version_hash/runs"

                # Check for errors in log
                if grep -qiE '(error|failed|exception|traceback)' "$log_file" 2>/dev/null; then
                    errors=$(cat "$METRICS_DIR/$version_hash/errors")
                    echo "$((errors + 1))" > "$METRICS_DIR/$version_hash/errors"
                else
                    success=$(cat "$METRICS_DIR/$version_hash/success")
                    echo "$((success + 1))" > "$METRICS_DIR/$version_hash/success"
                fi

                # Track time range
                first_run=$(cat "$METRICS_DIR/$version_hash/first_run")
                if [ -z "$first_run" ]; then
                    echo "$log_timestamp" > "$METRICS_DIR/$version_hash/first_run"
                fi
                echo "$log_timestamp" > "$METRICS_DIR/$version_hash/last_run"

                # Try to extract task ID from log
                task_id=$(grep -oE 'TASK-[0-9]+' "$log_file" 2>/dev/null | head -1 || echo "")
                if [ -n "$task_id" ]; then
                    status=$(get_task_status "$task_id")
                    case "$status" in
                        DONE|VERIFIED)
                            tasks_done=$(cat "$METRICS_DIR/$version_hash/tasks_done")
                            echo "$((tasks_done + 1))" > "$METRICS_DIR/$version_hash/tasks_done"
                            ;;
                        FAILED)
                            tasks_failed=$(cat "$METRICS_DIR/$version_hash/tasks_failed")
                            echo "$((tasks_failed + 1))" > "$METRICS_DIR/$version_hash/tasks_failed"
                            ;;
                    esac
                fi
            fi
        done
    fi

    # Start agent object
    cat >> "$TMP_FILE" << AGENT_START
    {
      "id": "$AGENT",
      "prompt_path": "$PROMPT_FILE",
      "versions": [
AGENT_START

    FIRST_VERSION=true

    # Output version metrics
    while IFS='|' read -r hash date subject; do
        [ -z "$hash" ] && continue

        # Get metrics from files
        runs=$(cat "$METRICS_DIR/$hash/runs" 2>/dev/null || echo "0")
        success=$(cat "$METRICS_DIR/$hash/success" 2>/dev/null || echo "0")
        errors=$(cat "$METRICS_DIR/$hash/errors" 2>/dev/null || echo "0")
        tasks_done=$(cat "$METRICS_DIR/$hash/tasks_done" 2>/dev/null || echo "0")
        tasks_failed=$(cat "$METRICS_DIR/$hash/tasks_failed" 2>/dev/null || echo "0")
        first_run=$(cat "$METRICS_DIR/$hash/first_run" 2>/dev/null || echo "$date")
        last_run=$(cat "$METRICS_DIR/$hash/last_run" 2>/dev/null || echo "$date")

        # Calculate success rate
        if [ "$runs" -gt 0 ]; then
            success_rate=$(echo "scale=1; $success * 100 / $runs" | bc 2>/dev/null || echo "0")
        else
            success_rate="0"
        fi

        # Escape subject for JSON
        SUBJECT_ESCAPED=$(echo "$subject" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/ /g' | tr -d '\r\n')

        # Get file stats at this commit
        FILE_SIZE=$(git show "$hash:$PROMPT_FILE" 2>/dev/null | wc -c || echo "0")
        FILE_LINES=$(git show "$hash:$PROMPT_FILE" 2>/dev/null | wc -l || echo "0")

        # Use empty string if date variables are empty
        [ -z "$first_run" ] && first_run=""
        [ -z "$last_run" ] && last_run=""

        # Add comma separator
        if [ "$FIRST_VERSION" = true ]; then
            FIRST_VERSION=false
        else
            echo ',' >> "$TMP_FILE"
        fi

        cat >> "$TMP_FILE" << VERSION_EOF
        {
          "hash": "$hash",
          "short_hash": "${hash:0:7}",
          "date": "$date",
          "subject": "$SUBJECT_ESCAPED",
          "prompt_size": $FILE_SIZE,
          "prompt_lines": $FILE_LINES,
          "metrics": {
            "total_runs": $runs,
            "successful_runs": $success,
            "error_runs": $errors,
            "success_rate": $success_rate,
            "tasks_completed": $tasks_done,
            "tasks_failed": $tasks_failed,
            "first_run": "$first_run",
            "last_run": "$last_run"
          }
        }
VERSION_EOF
    done < "$VERSION_DATA_FILE"

    echo '' >> "$TMP_FILE"
    echo '      ]' >> "$TMP_FILE"
    echo '    }' >> "$TMP_FILE"

    # Cleanup
    rm -rf "$METRICS_DIR" "$VERSION_DATA_FILE"
done

# Calculate aggregate stats
TOTAL_VERSIONS=$(git log --oneline -- 'actors/*/prompt.md' 2>/dev/null | wc -l || echo "0")
TOTAL_LOG_FILES=$(find "$ACTORS_DIR" -path "*/logs/*.log" 2>/dev/null | wc -l || echo "0")

cat >> "$TMP_FILE" << EOF

  ],
  "summary": {
    "total_agents": ${#AGENTS[@]},
    "total_prompt_versions": $TOTAL_VERSIONS,
    "total_runs_analyzed": $TOTAL_LOG_FILES,
    "generated": "$TIMESTAMP"
  },
  "comparison_guide": {
    "success_rate": "Higher is better. Percentage of runs without errors.",
    "tasks_completed": "Higher is better. Number of tasks reaching DONE/VERIFIED status.",
    "tasks_failed": "Lower is better. Number of tasks marked FAILED.",
    "sample_size_warning": "Need at least 5-10 runs per version for statistically meaningful comparison."
  }
}
EOF

# Move temp file to output (atomic operation)
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Prompt metrics data updated: $OUTPUT_FILE"
