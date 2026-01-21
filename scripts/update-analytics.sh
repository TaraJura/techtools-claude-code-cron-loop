#!/bin/bash
# update-analytics.sh - Generate agent performance analytics data
# Parses agent logs to extract execution metrics and success rates

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/analytics.json"
ACTORS_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Initialize counters
declare -A agent_runs
declare -A agent_success
declare -A agent_errors
declare -A agent_duration_sum
declare -A agent_duration_count
declare -A hourly_runs

total_runs=0
total_success=0
total_errors=0
total_duration=0
duration_count=0

# Calculate date ranges
now=$(date +%s)
seven_days_ago=$((now - 7*24*60*60))
thirty_days_ago=$((now - 30*24*60*60))

# Process each agent's logs
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    agent_runs[$agent]=0
    agent_success[$agent]=0
    agent_errors[$agent]=0
    agent_duration_sum[$agent]=0
    agent_duration_count[$agent]=0

    # Process each log file
    for log_file in "$log_dir"/*.log; do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        # Extract timestamps from log file name (format: YYYYMMDD_HHMMSS.log)
        filename=$(basename "$log_file")
        if [[ $filename =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.log$ ]]; then
            year=${BASH_REMATCH[1]}
            month=${BASH_REMATCH[2]}
            day=${BASH_REMATCH[3]}
            hour=${BASH_REMATCH[4]}
            minute=${BASH_REMATCH[5]}
            second=${BASH_REMATCH[6]}

            file_timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null || echo "0")

            # Skip if older than 30 days
            if [[ $file_timestamp -lt $thirty_days_ago ]]; then
                continue
            fi

            agent_runs[$agent]=$((${agent_runs[$agent]} + 1))
            total_runs=$((total_runs + 1))

            # Track hourly distribution
            hourly_runs[$hour]=$((${hourly_runs[$hour]:-0} + 1))

            # Check for errors in log content
            if grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                agent_errors[$agent]=$((${agent_errors[$agent]} + 1))
                total_errors=$((total_errors + 1))
            else
                agent_success[$agent]=$((${agent_success[$agent]} + 1))
                total_success=$((total_success + 1))
            fi

            # Extract duration from log (look for "Started:" and "Completed:" lines)
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
                    agent_duration_sum[$agent]=$((${agent_duration_sum[$agent]} + duration))
                    agent_duration_count[$agent]=$((${agent_duration_count[$agent]} + 1))
                    total_duration=$((total_duration + duration))
                    duration_count=$((duration_count + 1))
                fi
            fi
        fi
    done
done

# Find most productive hour
max_hour_runs=0
most_productive_hour=0
for hour in "${!hourly_runs[@]}"; do
    if [[ ${hourly_runs[$hour]} -gt $max_hour_runs ]]; then
        max_hour_runs=${hourly_runs[$hour]}
        most_productive_hour=$hour
    fi
done

# Calculate averages
avg_duration=0
if [[ $duration_count -gt 0 ]]; then
    avg_duration=$((total_duration / duration_count))
fi

# Calculate health score (0-100)
health_score=100
if [[ $total_runs -gt 0 ]]; then
    health_score=$((total_success * 100 / total_runs))
fi

# Calculate 7-day trends
runs_7d=0
success_7d=0

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
            file_timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null || echo "0")

            if [[ $file_timestamp -ge $seven_days_ago ]]; then
                runs_7d=$((runs_7d + 1))

                if ! grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                    success_7d=$((success_7d + 1))
                fi
            fi
        fi
    done
done

success_rate_7d=0
if [[ $runs_7d -gt 0 ]]; then
    success_rate_7d=$((success_7d * 100 / runs_7d))
fi
runs_per_day_7d=$((runs_7d / 7))

# Build JSON output
{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"agents\": {"

    first_agent=true
    for agent in "${AGENTS[@]}"; do
        runs=${agent_runs[$agent]:-0}
        if [[ $runs -eq 0 ]]; then
            continue
        fi

        if [[ $first_agent == false ]]; then
            echo ","
        fi
        first_agent=false

        success=${agent_success[$agent]:-0}
        errors=${agent_errors[$agent]:-0}
        duration_sum=${agent_duration_sum[$agent]:-0}
        duration_cnt=${agent_duration_count[$agent]:-0}

        success_rate=0
        avg_dur=0
        if [[ $runs -gt 0 ]]; then
            success_rate=$((success * 100 / runs))
        fi
        if [[ $duration_cnt -gt 0 ]]; then
            avg_dur=$((duration_sum / duration_cnt))
        fi

        echo -n "    \"$agent\": {"
        echo -n "\"runs\": $runs, "
        echo -n "\"success\": $success, "
        echo -n "\"errors\": $errors, "
        echo -n "\"success_rate\": $success_rate, "
        echo -n "\"avg_duration_seconds\": $avg_dur"
        echo -n "}"
    done

    echo ""
    echo "  },"

    echo "  \"summary\": {"
    echo "    \"total_runs\": $total_runs,"
    echo "    \"total_success\": $total_success,"
    echo "    \"total_errors\": $total_errors,"
    echo "    \"avg_duration_seconds\": $avg_duration,"
    echo "    \"most_productive_hour\": $((10#$most_productive_hour)),"
    echo "    \"health_score\": $health_score"
    echo "  },"

    echo "  \"hourly_distribution\": {"
    first_hour=true
    for hour in $(echo "${!hourly_runs[@]}" | tr ' ' '\n' | sort -n); do
        if [[ $first_hour == false ]]; then
            echo ","
        fi
        first_hour=false
        echo -n "    \"$hour\": ${hourly_runs[$hour]}"
    done
    echo ""
    echo "  },"

    echo "  \"trends\": {"
    echo "    \"success_rate_7d\": $success_rate_7d,"
    echo "    \"avg_duration_7d\": $avg_duration,"
    echo "    \"runs_per_day_7d\": $runs_per_day_7d"
    echo "  }"
    echo "}"
} > "$OUTPUT_FILE"

echo "Analytics data updated: $OUTPUT_FILE"
