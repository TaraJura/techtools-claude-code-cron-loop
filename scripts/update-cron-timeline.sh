#!/bin/bash
# update-cron-timeline.sh - Generate cron orchestrator execution timeline from cron.log
# Used by cron-timeline.html to display historical pipeline runs with success/failure indicators

API_DIR="/var/www/cronloop.techtools.cz/api"
CRON_LOG="/home/novakj/actors/cron.log"
OUTPUT_FILE="$API_DIR/cron-timeline.json"

# Create API directory if needed
mkdir -p "$API_DIR"

# Parse the cron.log to extract runs
parse_cron_log() {
    local temp_file=$(mktemp)
    local runs_file=$(mktemp)

    # Extract Start and Completed timestamps
    grep -n "=== Agent Orchestrator" "$CRON_LOG" 2>/dev/null > "$temp_file"

    # Process the log to build run objects
    local current_run_start=""
    local current_run_start_line=""
    local runs_json="["
    local first_run=true
    local run_count=0
    local success_count=0
    local failure_count=0
    local total_duration=0

    # We'll build an array of runs
    declare -A agents_in_run

    while IFS=: read -r line_num content; do
        if [[ "$content" =~ "Started:" ]]; then
            # Start of a new run
            current_run_start=$(echo "$content" | sed 's/.*Started: //' | sed 's/ ===//')
            current_run_start_line=$line_num
        elif [[ "$content" =~ "Completed:" ]]; then
            # End of a run
            local completed_time=$(echo "$content" | sed 's/.*Completed: //' | sed 's/ ===//')
            local completed_line=$line_num

            if [[ -n "$current_run_start" ]]; then
                # Calculate duration
                local start_epoch=$(date -d "$current_run_start" +%s 2>/dev/null)
                local end_epoch=$(date -d "$completed_time" +%s 2>/dev/null)
                local duration=0
                if [[ -n "$start_epoch" ]] && [[ -n "$end_epoch" ]]; then
                    duration=$((end_epoch - start_epoch))
                    total_duration=$((total_duration + duration))
                fi

                # Extract agents that ran between these lines
                local agents_ran=""
                local agent_details=""
                local has_error=false

                # Get the content between start and completed lines
                local section=$(sed -n "${current_run_start_line},${completed_line}p" "$CRON_LOG")

                # Find all >>> Running <agent> Agent... patterns
                while IFS= read -r agent_line; do
                    # Extract agent name - handle multi-word names like "Idea Maker", "Project Manager"
                    local agent_name=$(echo "$agent_line" | sed -n 's/.*>>> Running \(.*\) Agent.*/\1/p')
                    if [[ -n "$agent_name" ]]; then
                        # Convert to lowercase and replace spaces with hyphens
                        local agent=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

                        if [[ -z "$agents_ran" ]]; then
                            agents_ran="\"$agent\""
                        else
                            agents_ran="$agents_ran,\"$agent\""
                        fi
                    fi
                done <<< "$(echo "$section" | grep ">>> Running")"

                # Check for real orchestrator errors
                # Real errors: actual python/bash exceptions, agent script failures
                # Exclude: task status mentions, SSH attack reports, log summaries
                local error_found=false

                # Check for actual crash indicators
                if echo "$section" | grep -qE "^Traceback|^Exception:|RuntimeError|SyntaxError|ImportError|ModuleNotFoundError"; then
                    error_found=true
                fi

                # Check for orchestrator script errors (but not git pull)
                if echo "$section" | grep -qE "^bash: |command not found|No such file or directory"; then
                    error_found=true
                fi

                # A run is considered successful if it completed without actual errors
                # The "=== Agent Orchestrator Completed" line itself indicates the run finished
                if [[ "$error_found" == "true" ]]; then
                    has_error=true
                    ((failure_count++))
                else
                    ((success_count++))
                fi

                # Check for git pull errors specifically (informational, not a failure)
                local git_error=false
                if echo "$section" | grep -q "error: cannot pull"; then
                    git_error=true
                fi

                # Format timestamps to ISO format
                local iso_start=$(date -d "$current_run_start" --iso-8601=seconds 2>/dev/null)
                local iso_end=$(date -d "$completed_time" --iso-8601=seconds 2>/dev/null)

                if [[ -n "$iso_start" ]] && [[ -n "$iso_end" ]]; then
                    # Build JSON for this run
                    if [[ "$first_run" == "true" ]]; then
                        first_run=false
                    else
                        runs_json="$runs_json,"
                    fi

                    runs_json="$runs_json{\"id\":$run_count,\"start\":\"$iso_start\",\"end\":\"$iso_end\",\"duration\":$duration,\"agents\":[$agents_ran],\"success\":$([[ "$has_error" == "false" ]] && echo "true" || echo "false"),\"gitError\":$git_error}"
                    ((run_count++))
                fi
            fi

            # Reset for next run
            current_run_start=""
            current_run_start_line=""
        fi
    done < "$temp_file"

    runs_json="$runs_json]"

    # Calculate stats
    local avg_duration=0
    if [[ $run_count -gt 0 ]]; then
        avg_duration=$((total_duration / run_count))
    fi

    local success_rate=0
    if [[ $run_count -gt 0 ]]; then
        success_rate=$(echo "scale=1; $success_count * 100 / $run_count" | bc)
    fi

    # Get last 24 hours stats
    local now=$(date +%s)
    local cutoff_24h=$((now - 86400))
    local runs_24h=0
    local success_24h=0

    # Reparse for 24h stats (simpler approach)
    while read -r line; do
        if [[ "$line" =~ "Completed:" ]]; then
            local completed_time=$(echo "$line" | sed 's/.*Completed: //' | sed 's/ ===//')
            local completed_epoch=$(date -d "$completed_time" +%s 2>/dev/null)
            if [[ -n "$completed_epoch" ]] && [[ $completed_epoch -gt $cutoff_24h ]]; then
                ((runs_24h++))
            fi
        fi
    done < <(grep "Agent Orchestrator Completed" "$CRON_LOG")

    # Generate the final JSON
    cat > "$OUTPUT_FILE" <<EOF
{
  "generated": "$(date --iso-8601=seconds)",
  "stats": {
    "totalRuns": $run_count,
    "successfulRuns": $success_count,
    "failedRuns": $failure_count,
    "successRate": $success_rate,
    "avgDurationSeconds": $avg_duration,
    "runs24h": $runs_24h
  },
  "runs": $runs_json
}
EOF

    rm -f "$temp_file" "$runs_file"
}

# Main execution
main() {
    if [[ ! -f "$CRON_LOG" ]]; then
        # Create empty data if no log exists
        cat > "$OUTPUT_FILE" <<EOF
{
  "generated": "$(date --iso-8601=seconds)",
  "stats": {
    "totalRuns": 0,
    "successfulRuns": 0,
    "failedRuns": 0,
    "successRate": 0,
    "avgDurationSeconds": 0,
    "runs24h": 0
  },
  "runs": []
}
EOF
        echo "No cron.log found, created empty timeline data"
        exit 0
    fi

    parse_cron_log
    echo "Cron timeline data updated: $OUTPUT_FILE"
}

main "$@"
