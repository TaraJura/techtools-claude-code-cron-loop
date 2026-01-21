#!/bin/bash
# update-workload.sh - Generate agent workload distribution and bottleneck analysis data
# Analyzes task flow through the agent pipeline and identifies capacity issues

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/workload.json"
TASKS_FILE="/home/novakj/tasks.md"
ACTORS_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Agents in pipeline order
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Initialize associative arrays
declare -A queue_depth
declare -A throughput_7d
declare -A throughput_30d
declare -A avg_duration
declare -A utilization
declare -A wait_times
declare -A runs_today
declare -A runs_7d
declare -A runs_30d

# Calculate date ranges
now=$(date +%s)
today_start=$(date -d "today 00:00" +%s)
seven_days_ago=$((now - 7*24*60*60))
thirty_days_ago=$((now - 30*24*60*60))

# Helper function to get clean integer value
clean_int() {
    local val="$1"
    val=$(echo "$val" | tr -d '[:space:]')
    val=${val:-0}
    # Convert to integer to remove leading zeros
    echo $((val + 0))
}

# Count tasks in backlog (TODO, unassigned)
backlog_count=0
if [[ -f "$TASKS_FILE" ]]; then
    backlog_count=$(clean_int "$(grep -c "Status: TODO" "$TASKS_FILE" 2>/dev/null || echo "0")")
fi

# Count tasks per status for queue depth
todo_count=$(clean_int "$(grep -c "Status: TODO" "$TASKS_FILE" 2>/dev/null || echo "0")")
in_progress_count=$(clean_int "$(grep -c "Status: IN_PROGRESS" "$TASKS_FILE" 2>/dev/null || echo "0")")
done_count=$(clean_int "$(grep -c "Status: DONE" "$TASKS_FILE" 2>/dev/null || echo "0")")

# Count tasks assigned to each agent (queue depth)
for agent in "${AGENTS[@]}"; do
    # Count how many tasks are assigned to this agent (waiting to be worked on)
    # Use explicit pattern to avoid partial matches (e.g., developer vs developer2)
    if [[ "$agent" == "developer" ]]; then
        assigned=$(grep -E "^\- \*\*Assigned\*\*: developer$" "$TASKS_FILE" 2>/dev/null | wc -l)
    else
        assigned=$(grep -c "Assigned: $agent" "$TASKS_FILE" 2>/dev/null || echo "0")
    fi
    queue_depth[$agent]=$(clean_int "$assigned")
done

# Process each agent's logs for throughput metrics
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    runs_today[$agent]=0
    runs_7d[$agent]=0
    runs_30d[$agent]=0

    total_duration=0
    duration_count=0

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    for log_file in "$log_dir"/*.log; do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        filename=$(basename "$log_file")
        if [[ $filename =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.log$ ]]; then
            year=${BASH_REMATCH[1]}
            month=${BASH_REMATCH[2]}
            day=${BASH_REMATCH[3]}
            hour=${BASH_REMATCH[4]}
            minute=${BASH_REMATCH[5]}
            second=${BASH_REMATCH[6]}

            file_timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null || echo "0")

            if [[ $file_timestamp -ge $today_start ]]; then
                runs_today[$agent]=$((${runs_today[$agent]} + 1))
            fi

            if [[ $file_timestamp -ge $seven_days_ago ]]; then
                runs_7d[$agent]=$((${runs_7d[$agent]} + 1))
            fi

            if [[ $file_timestamp -ge $thirty_days_ago ]]; then
                runs_30d[$agent]=$((${runs_30d[$agent]} + 1))

                # Extract duration
                start_time=""
                end_time=""
                while IFS= read -r line; do
                    if [[ $line =~ ^Started:\ (.+)$ ]]; then
                        start_time="${BASH_REMATCH[1]}"
                    elif [[ $line =~ ^Completed:\ (.+)$ ]]; then
                        end_time="${BASH_REMATCH[1]}"
                    fi
                done < "$log_file"

                if [[ -n "$start_time" && -n "$end_time" ]]; then
                    start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
                    end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")

                    if [[ $start_epoch -gt 0 && $end_epoch -gt 0 && $end_epoch -gt $start_epoch ]]; then
                        duration=$((end_epoch - start_epoch))
                        total_duration=$((total_duration + duration))
                        duration_count=$((duration_count + 1))
                    fi
                fi
            fi
        fi
    done

    # Calculate averages
    throughput_7d[$agent]=${runs_7d[$agent]}
    throughput_30d[$agent]=${runs_30d[$agent]}

    if [[ $duration_count -gt 0 ]]; then
        avg_duration[$agent]=$((total_duration / duration_count))
    else
        avg_duration[$agent]=0
    fi

    # Calculate utilization (runs per day vs expected)
    # Expected: 48 runs/day (every 30 min = 2/hour * 24 hours)
    expected_runs=$((48 * 7))
    actual_runs=${runs_7d[$agent]}
    if [[ $expected_runs -gt 0 ]]; then
        utilization[$agent]=$((actual_runs * 100 / expected_runs))
    else
        utilization[$agent]=0
    fi
done

# Identify bottlenecks (agent with largest queue or slowest throughput)
max_queue=0
bottleneck_agent=""
for agent in "${AGENTS[@]}"; do
    q=${queue_depth[$agent]:-0}
    if [[ $q -gt $max_queue ]]; then
        max_queue=$q
        bottleneck_agent=$agent
    fi
done

# Calculate pipeline health (0-100)
# Based on: queue sizes, throughput balance, error-free flow
total_queue=0
for agent in "${AGENTS[@]}"; do
    total_queue=$((total_queue + ${queue_depth[$agent]:-0}))
done

pipeline_health=100
if [[ $total_queue -gt 50 ]]; then
    pipeline_health=$((100 - (total_queue - 50)))
    if [[ $pipeline_health -lt 0 ]]; then
        pipeline_health=0
    fi
fi

# Calculate total system throughput
total_throughput_7d=0
total_throughput_30d=0
for agent in "${AGENTS[@]}"; do
    total_throughput_7d=$((total_throughput_7d + ${throughput_7d[$agent]:-0}))
    total_throughput_30d=$((total_throughput_30d + ${throughput_30d[$agent]:-0}))
done

# Calculate hourly distribution for today
declare -A hourly_runs_today
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"
    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    for log_file in "$log_dir"/*.log; do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        filename=$(basename "$log_file")
        if [[ $filename =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.log$ ]]; then
            year=${BASH_REMATCH[1]}
            month=${BASH_REMATCH[2]}
            day=${BASH_REMATCH[3]}
            hour=${BASH_REMATCH[4]}

            file_timestamp=$(date -d "$year-$month-$day" +%s 2>/dev/null || echo "0")

            if [[ $file_timestamp -ge $today_start ]]; then
                hourly_runs_today[$hour]=$((${hourly_runs_today[$hour]:-0} + 1))
            fi
        fi
    done
done

# Build JSON output
{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"summary\": {"
    echo "    \"backlog_count\": $backlog_count,"
    echo "    \"todo_count\": $todo_count,"
    echo "    \"in_progress_count\": $in_progress_count,"
    echo "    \"done_count\": $done_count,"
    echo "    \"total_throughput_7d\": $total_throughput_7d,"
    echo "    \"total_throughput_30d\": $total_throughput_30d,"
    echo "    \"pipeline_health\": $pipeline_health,"
    echo "    \"bottleneck_agent\": \"$bottleneck_agent\""
    echo "  },"

    # Agents section
    echo "  \"agents\": {"
    first_agent=true
    for agent in "${AGENTS[@]}"; do
        if [[ $first_agent == false ]]; then
            echo ","
        fi
        first_agent=false

        echo -n "    \"$agent\": {"
        echo -n "\"queue_depth\": ${queue_depth[$agent]:-0}, "
        echo -n "\"runs_today\": ${runs_today[$agent]:-0}, "
        echo -n "\"runs_7d\": ${runs_7d[$agent]:-0}, "
        echo -n "\"runs_30d\": ${runs_30d[$agent]:-0}, "
        echo -n "\"avg_duration_sec\": ${avg_duration[$agent]:-0}, "
        echo -n "\"utilization_pct\": ${utilization[$agent]:-0}"
        echo -n "}"
    done
    echo ""
    echo "  },"

    # Pipeline flow (funnel visualization data)
    echo "  \"pipeline_flow\": ["
    echo "    {\"stage\": \"Ideas\", \"agent\": \"idea-maker\", \"queue\": ${queue_depth[idea-maker]:-0}, \"throughput_7d\": ${throughput_7d[idea-maker]:-0}},"
    echo "    {\"stage\": \"Assignment\", \"agent\": \"project-manager\", \"queue\": ${queue_depth[project-manager]:-0}, \"throughput_7d\": ${throughput_7d[project-manager]:-0}},"
    echo "    {\"stage\": \"Development\", \"agent\": \"developer\", \"queue\": ${queue_depth[developer]:-0}, \"throughput_7d\": ${throughput_7d[developer]:-0}},"
    echo "    {\"stage\": \"Development 2\", \"agent\": \"developer2\", \"queue\": ${queue_depth[developer2]:-0}, \"throughput_7d\": ${throughput_7d[developer2]:-0}},"
    echo "    {\"stage\": \"Testing\", \"agent\": \"tester\", \"queue\": ${queue_depth[tester]:-0}, \"throughput_7d\": ${throughput_7d[tester]:-0}},"
    echo "    {\"stage\": \"Security\", \"agent\": \"security\", \"queue\": ${queue_depth[security]:-0}, \"throughput_7d\": ${throughput_7d[security]:-0}}"
    echo "  ],"

    # Hourly distribution
    echo "  \"hourly_distribution\": {"
    first_hour=true
    for hour in $(echo "${!hourly_runs_today[@]}" | tr ' ' '\n' | sort -n); do
        if [[ $first_hour == false ]]; then
            echo ","
        fi
        first_hour=false
        echo -n "    \"$hour\": ${hourly_runs_today[$hour]}"
    done
    echo ""
    echo "  },"

    # Recommendations based on analysis
    echo "  \"recommendations\": ["
    rec_count=0

    # Check for bottlenecks
    if [[ -n "$bottleneck_agent" && $max_queue -gt 5 ]]; then
        if [[ $rec_count -gt 0 ]]; then echo ","; fi
        echo -n "    {\"type\": \"bottleneck\", \"agent\": \"$bottleneck_agent\", \"message\": \"Agent $bottleneck_agent has $max_queue tasks queued - consider rebalancing or increasing throughput\"}"
        rec_count=$((rec_count + 1))
    fi

    # Check for idle agents
    for agent in "${AGENTS[@]}"; do
        rt=${runs_today[$agent]:-0}
        qd=${queue_depth[$agent]:-0}
        if [[ $rt -eq 0 && $qd -eq 0 ]]; then
            if [[ $rec_count -gt 0 ]]; then echo ","; fi
            echo -n "    {\"type\": \"idle\", \"agent\": \"$agent\", \"message\": \"Agent $agent has no activity today and no queued tasks\"}"
            rec_count=$((rec_count + 1))
        fi
    done

    # Check for high backlog
    if [[ $backlog_count -gt 30 ]]; then
        if [[ $rec_count -gt 0 ]]; then echo ","; fi
        echo -n "    {\"type\": \"backlog\", \"message\": \"Backlog contains $backlog_count ideas - consider slowing idea generation or speeding up development\"}"
        rec_count=$((rec_count + 1))
    fi

    # Check for low pipeline health
    if [[ $pipeline_health -lt 50 ]]; then
        if [[ $rec_count -gt 0 ]]; then echo ","; fi
        echo -n "    {\"type\": \"health\", \"message\": \"Pipeline health is low ($pipeline_health%) - review task flow and agent capacity\"}"
        rec_count=$((rec_count + 1))
    fi

    echo ""
    echo "  ]"
    echo "}"
} > "$OUTPUT_FILE"

echo "Workload data updated: $OUTPUT_FILE"
