#!/bin/bash
# update-benchmarks.sh - Generate agent execution speed benchmarks and regression detection
# Parses agent logs to extract execution times, calculate percentiles, detect regressions

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/benchmarks.json"
ACTORS_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Temp file for storing all durations
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Calculate date ranges
now=$(date +%s)
seven_days_ago=$((now - 7*24*60*60))
thirty_days_ago=$((now - 30*24*60*60))

# Track global stats
total_runs=0
total_duration=0
fastest_run=""
fastest_duration=999999
slowest_run=""
slowest_duration=0

# Initialize JSON arrays
declare -A agent_durations_7d
declare -A agent_durations_30d
declare -A agent_durations_all
declare -A agent_runs_7d
declare -A agent_runs_30d
declare -A agent_runs_all
declare -A agent_personal_best
declare -A agent_current_avg
declare -A agent_7d_avg
declare -A agent_30d_avg
declare -A agent_errors
declare -A hourly_duration_sum
declare -A hourly_duration_count

# Process each agent's logs
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    # Initialize agent-specific counters
    agent_runs_7d[$agent]=0
    agent_runs_30d[$agent]=0
    agent_runs_all[$agent]=0
    agent_errors[$agent]=0
    agent_personal_best[$agent]=999999

    duration_sum_7d=0
    duration_sum_30d=0
    duration_sum_all=0
    count_7d=0
    count_30d=0
    count_all=0

    # Create temp file for this agent's durations
    > "$TEMP_DIR/${agent}_durations_7d.txt"
    > "$TEMP_DIR/${agent}_durations_30d.txt"
    > "$TEMP_DIR/${agent}_durations_all.txt"

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

            if [[ $file_timestamp -eq 0 ]]; then
                continue
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

                    # Track personal best
                    if [[ $duration -lt ${agent_personal_best[$agent]} ]]; then
                        agent_personal_best[$agent]=$duration
                    fi

                    # Track global fastest/slowest
                    if [[ $duration -lt $fastest_duration ]]; then
                        fastest_duration=$duration
                        fastest_run="${agent}:${filename}"
                    fi
                    if [[ $duration -gt $slowest_duration ]]; then
                        slowest_duration=$duration
                        slowest_run="${agent}:${filename}"
                    fi

                    # All-time stats
                    agent_runs_all[$agent]=$((${agent_runs_all[$agent]} + 1))
                    echo "$duration" >> "$TEMP_DIR/${agent}_durations_all.txt"
                    duration_sum_all=$((duration_sum_all + duration))
                    count_all=$((count_all + 1))
                    total_runs=$((total_runs + 1))
                    total_duration=$((total_duration + duration))

                    # Hourly tracking
                    hourly_duration_sum[$hour]=$((${hourly_duration_sum[$hour]:-0} + duration))
                    hourly_duration_count[$hour]=$((${hourly_duration_count[$hour]:-0} + 1))

                    # Check errors
                    if grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                        agent_errors[$agent]=$((${agent_errors[$agent]} + 1))
                    fi

                    # 30-day stats
                    if [[ $file_timestamp -ge $thirty_days_ago ]]; then
                        agent_runs_30d[$agent]=$((${agent_runs_30d[$agent]} + 1))
                        echo "$duration" >> "$TEMP_DIR/${agent}_durations_30d.txt"
                        duration_sum_30d=$((duration_sum_30d + duration))
                        count_30d=$((count_30d + 1))
                    fi

                    # 7-day stats
                    if [[ $file_timestamp -ge $seven_days_ago ]]; then
                        agent_runs_7d[$agent]=$((${agent_runs_7d[$agent]} + 1))
                        echo "$duration" >> "$TEMP_DIR/${agent}_durations_7d.txt"
                        duration_sum_7d=$((duration_sum_7d + duration))
                        count_7d=$((count_7d + 1))
                    fi
                fi
            fi
        fi
    done

    # Calculate averages
    if [[ $count_7d -gt 0 ]]; then
        agent_7d_avg[$agent]=$((duration_sum_7d / count_7d))
        agent_current_avg[$agent]=${agent_7d_avg[$agent]}
    else
        agent_7d_avg[$agent]=0
        agent_current_avg[$agent]=0
    fi

    if [[ $count_30d -gt 0 ]]; then
        agent_30d_avg[$agent]=$((duration_sum_30d / count_30d))
    else
        agent_30d_avg[$agent]=0
    fi

    if [[ $count_all -gt 0 ]]; then
        # All-time average stored in a variable for percentile calculation
        :
    fi
done

# Function to calculate percentile from sorted file
calculate_percentile() {
    local file=$1
    local percentile=$2

    if [[ ! -s "$file" ]]; then
        echo "0"
        return
    fi

    local count=$(wc -l < "$file")
    if [[ $count -eq 0 ]]; then
        echo "0"
        return
    fi

    local index=$(( (count * percentile + 99) / 100 ))
    if [[ $index -lt 1 ]]; then
        index=1
    fi
    if [[ $index -gt $count ]]; then
        index=$count
    fi

    sort -n "$file" | sed -n "${index}p"
}

# Calculate global average
global_avg=0
if [[ $total_runs -gt 0 ]]; then
    global_avg=$((total_duration / total_runs))
fi

# Build JSON output
{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"summary\": {"
    echo "    \"total_runs\": $total_runs,"
    echo "    \"total_duration_seconds\": $total_duration,"
    echo "    \"global_avg_duration\": $global_avg,"
    echo "    \"fastest_run\": \"$fastest_run\","
    echo "    \"fastest_duration\": $fastest_duration,"
    echo "    \"slowest_run\": \"$slowest_run\","
    echo "    \"slowest_duration\": $slowest_duration"
    echo "  },"

    # Per-agent benchmarks
    echo "  \"agents\": {"
    first_agent=true
    for agent in "${AGENTS[@]}"; do
        runs_all=${agent_runs_all[$agent]:-0}
        if [[ $runs_all -eq 0 ]]; then
            continue
        fi

        if [[ $first_agent == false ]]; then
            echo ","
        fi
        first_agent=false

        runs_7d=${agent_runs_7d[$agent]:-0}
        runs_30d=${agent_runs_30d[$agent]:-0}
        avg_7d=${agent_7d_avg[$agent]:-0}
        avg_30d=${agent_30d_avg[$agent]:-0}
        personal_best=${agent_personal_best[$agent]:-0}
        errors=${agent_errors[$agent]:-0}

        # Calculate percentiles from 7d data
        p50=$(calculate_percentile "$TEMP_DIR/${agent}_durations_7d.txt" 50)
        p90=$(calculate_percentile "$TEMP_DIR/${agent}_durations_7d.txt" 90)
        p99=$(calculate_percentile "$TEMP_DIR/${agent}_durations_7d.txt" 99)

        # Detect regression (7d avg vs 30d avg)
        regression_pct=0
        regression_status="stable"
        if [[ $avg_30d -gt 0 && $avg_7d -gt 0 ]]; then
            regression_pct=$(( (avg_7d - avg_30d) * 100 / avg_30d ))
            if [[ $regression_pct -gt 20 ]]; then
                regression_status="regressed"
            elif [[ $regression_pct -lt -20 ]]; then
                regression_status="improved"
            fi
        fi

        # Speed vs personal best
        speed_vs_best=0
        if [[ $personal_best -gt 0 && $avg_7d -gt 0 ]]; then
            speed_vs_best=$(( (avg_7d - personal_best) * 100 / personal_best ))
        fi

        echo -n "    \"$agent\": {"
        echo -n "\"runs_7d\": $runs_7d, "
        echo -n "\"runs_30d\": $runs_30d, "
        echo -n "\"runs_all\": $runs_all, "
        echo -n "\"avg_duration_7d\": $avg_7d, "
        echo -n "\"avg_duration_30d\": $avg_30d, "
        echo -n "\"personal_best\": $personal_best, "
        echo -n "\"p50\": ${p50:-0}, "
        echo -n "\"p90\": ${p90:-0}, "
        echo -n "\"p99\": ${p99:-0}, "
        echo -n "\"errors\": $errors, "
        echo -n "\"regression_pct\": $regression_pct, "
        echo -n "\"regression_status\": \"$regression_status\", "
        echo -n "\"speed_vs_best_pct\": $speed_vs_best"
        echo -n "}"
    done
    echo ""
    echo "  },"

    # Speed leaderboard (sorted by 7d average, fastest first)
    echo "  \"leaderboard\": ["
    first_entry=true
    for agent in $(for a in "${AGENTS[@]}"; do
        avg=${agent_7d_avg[$a]:-999999}
        if [[ ${agent_runs_7d[$a]:-0} -gt 0 ]]; then
            echo "$avg $a"
        fi
    done | sort -n | awk '{print $2}'); do
        if [[ $first_entry == false ]]; then
            echo ","
        fi
        first_entry=false
        avg=${agent_7d_avg[$agent]:-0}
        echo -n "    {\"agent\": \"$agent\", \"avg_duration_7d\": $avg}"
    done
    echo ""
    echo "  ],"

    # Hourly performance patterns
    echo "  \"hourly_performance\": {"
    first_hour=true
    for hour in $(echo "${!hourly_duration_count[@]}" | tr ' ' '\n' | sort -n); do
        if [[ $first_hour == false ]]; then
            echo ","
        fi
        first_hour=false

        sum=${hourly_duration_sum[$hour]:-0}
        count=${hourly_duration_count[$hour]:-0}
        avg=0
        if [[ $count -gt 0 ]]; then
            avg=$((sum / count))
        fi

        echo -n "    \"$hour\": {\"runs\": $count, \"avg_duration\": $avg}"
    done
    echo ""
    echo "  },"

    # Regressions list (agents with >20% slowdown)
    echo "  \"regressions\": ["
    first_reg=true
    for agent in "${AGENTS[@]}"; do
        avg_7d=${agent_7d_avg[$agent]:-0}
        avg_30d=${agent_30d_avg[$agent]:-0}

        if [[ $avg_30d -gt 0 && $avg_7d -gt 0 ]]; then
            regression_pct=$(( (avg_7d - avg_30d) * 100 / avg_30d ))
            if [[ $regression_pct -gt 20 ]]; then
                if [[ $first_reg == false ]]; then
                    echo ","
                fi
                first_reg=false
                echo -n "    {\"agent\": \"$agent\", \"7d_avg\": $avg_7d, \"30d_avg\": $avg_30d, \"slowdown_pct\": $regression_pct}"
            fi
        fi
    done
    echo ""
    echo "  ],"

    # Speed budget compliance
    echo "  \"speed_budgets\": {"
    echo "    \"target_seconds\": 120,"
    compliant=0
    total_with_budget=0
    for agent in "${AGENTS[@]}"; do
        avg=${agent_7d_avg[$agent]:-0}
        if [[ ${agent_runs_7d[$agent]:-0} -gt 0 ]]; then
            total_with_budget=$((total_with_budget + 1))
            if [[ $avg -le 120 ]]; then
                compliant=$((compliant + 1))
            fi
        fi
    done
    compliance_pct=0
    if [[ $total_with_budget -gt 0 ]]; then
        compliance_pct=$((compliant * 100 / total_with_budget))
    fi
    echo "    \"compliant_agents\": $compliant,"
    echo "    \"total_agents\": $total_with_budget,"
    echo "    \"compliance_pct\": $compliance_pct"
    echo "  }"

    echo "}"
} > "$OUTPUT_FILE"

echo "Benchmarks data updated: $OUTPUT_FILE"
