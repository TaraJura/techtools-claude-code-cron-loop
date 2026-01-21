#!/bin/bash
# update-schedule.sh - Collects cron and systemd timer schedule data for the web dashboard
# Creates /api/schedule.json with all scheduled jobs and their timing information

set -eo pipefail

API_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$API_DIR/schedule.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Helper function to convert cron expression to human-readable format
cron_to_human() {
    local expr="$1"
    local min="${expr%% *}"
    local rest="${expr#* }"
    local hour="${rest%% *}"
    rest="${rest#* }"
    local dom="${rest%% *}"
    rest="${rest#* }"
    local mon="${rest%% *}"
    local dow="${rest##* }"

    # Common patterns
    if [[ "$min" == "*" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every minute"
    elif [[ "$min" == "*/5" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every 5 minutes"
    elif [[ "$min" == "*/10" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every 10 minutes"
    elif [[ "$min" == "*/15" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every 15 minutes"
    elif [[ "$min" == "*/30" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every 30 minutes"
    elif [[ "$min" == "0" && "$hour" == "*" && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Every hour"
    elif [[ "$min" =~ ^[0-9]+$ && "$hour" =~ ^[0-9]+$ && "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Daily at $(printf '%02d:%02d' "$hour" "$min")"
    elif [[ "$min" =~ ^[0-9]+$ && "$hour" =~ ^[0-9]+$ && "$dom" == "*" && "$mon" == "*" && "$dow" =~ ^[0-9]+$ ]]; then
        local days=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
        echo "Weekly on ${days[$dow]} at $(printf '%02d:%02d' "$hour" "$min")"
    elif [[ "$min" =~ ^[0-9]+$ && "$hour" =~ ^[0-9]+$ && "$dom" =~ ^[0-9]+$ && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "Monthly on day $dom at $(printf '%02d:%02d' "$hour" "$min")"
    else
        echo "$expr"
    fi
}

# Function to calculate next run times for a cron expression (next 24 hours)
get_cron_next_runs() {
    local expr="$1"
    local min="${expr%% *}"
    local rest="${expr#* }"
    local hour="${rest%% *}"

    local now_ts=$(date +%s)
    local end_ts=$((now_ts + 86400))  # 24 hours from now
    local runs=()

    # For simplicity, handle common patterns
    if [[ "$min" == "*" && "$hour" == "*" ]]; then
        # Every minute - just list next few
        for i in {0..5}; do
            runs+=("$(date -d "@$((now_ts + i*60))" +"%Y-%m-%dT%H:%M:00Z")")
        done
    elif [[ "$min" == "*/5" && "$hour" == "*" ]]; then
        local curr_min=$(date +%M)
        local next_min=$(( (curr_min / 5 + 1) * 5 ))
        local base=$(date +"%Y-%m-%d %H"):00
        for i in {0..11}; do
            local run_time=$(date -d "$base +$((next_min + i*5)) minutes" +"%Y-%m-%dT%H:%M:00Z" 2>/dev/null || echo "")
            [[ -n "$run_time" ]] && runs+=("$run_time")
        done
    elif [[ "$min" == "*/10" && "$hour" == "*" ]]; then
        local curr_min=$(date +%M)
        local next_min=$(( (curr_min / 10 + 1) * 10 ))
        local base=$(date +"%Y-%m-%d %H"):00
        for i in {0..6}; do
            local run_time=$(date -d "$base +$((next_min + i*10)) minutes" +"%Y-%m-%dT%H:%M:00Z" 2>/dev/null || echo "")
            [[ -n "$run_time" ]] && runs+=("$run_time")
        done
    elif [[ "$min" == "*/30" && "$hour" == "*" ]]; then
        local curr_min=$(date +%M)
        local next_min=$(( (curr_min / 30 + 1) * 30 ))
        local base=$(date +"%Y-%m-%d %H"):00
        for i in {0..48}; do
            local run_time=$(date -d "$base +$((next_min + i*30)) minutes" +"%Y-%m-%dT%H:%M:00Z" 2>/dev/null || echo "")
            [[ -n "$run_time" ]] && runs+=("$run_time")
        done
    elif [[ "$min" == "0" && "$hour" == "*" ]]; then
        # Hourly
        local base=$(date +"%Y-%m-%d %H"):00
        for i in {1..24}; do
            local run_time=$(date -d "$base +$i hours" +"%Y-%m-%dT%H:00:00Z" 2>/dev/null || echo "")
            [[ -n "$run_time" ]] && runs+=("$run_time")
        done
    elif [[ "$min" =~ ^[0-9]+$ && "$hour" =~ ^[0-9]+$ ]]; then
        # Specific time
        local today=$(date +"%Y-%m-%d")
        local tomorrow=$(date -d "tomorrow" +"%Y-%m-%d")
        local run_time="${today}T$(printf '%02d:%02d' "$hour" "$min"):00Z"
        if [[ $(date -d "$run_time" +%s 2>/dev/null || echo 0) -gt $now_ts ]]; then
            runs+=("$run_time")
        fi
        runs+=("${tomorrow}T$(printf '%02d:%02d' "$hour" "$min"):00Z")
    fi

    # Return as JSON array
    printf '%s\n' "${runs[@]}" | head -10 | jq -R . | jq -s .
}

# Initialize JSON structure
echo "{" > "$OUTPUT_FILE.tmp"
echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$OUTPUT_FILE.tmp"
echo "  \"jobs\": [" >> "$OUTPUT_FILE.tmp"

FIRST_JOB=true

# Parse user crontab
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Parse cron line: min hour dom mon dow command
    if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        min="${BASH_REMATCH[1]}"
        hour="${BASH_REMATCH[2]}"
        dom="${BASH_REMATCH[3]}"
        mon="${BASH_REMATCH[4]}"
        dow="${BASH_REMATCH[5]}"
        cmd="${BASH_REMATCH[6]}"

        expr="$min $hour $dom $mon $dow"
        human=$(cron_to_human "$expr")
        next_runs=$(get_cron_next_runs "$expr")

        # Detect if it's the orchestrator
        if [[ "$cmd" == *"cron-orchestrator"* ]]; then
            type="orchestrator"
        else
            type="cron"
        fi

        # Short name from command
        short_name=$(basename "${cmd%% *}" | sed 's/\.sh$//')

        [[ "$FIRST_JOB" == "false" ]] && echo "," >> "$OUTPUT_FILE.tmp"
        FIRST_JOB=false

        cat >> "$OUTPUT_FILE.tmp" << JOBEOF
    {
      "id": "cron-user-$short_name",
      "name": "$short_name",
      "type": "$type",
      "source": "user-crontab",
      "schedule": "$expr",
      "schedule_human": "$human",
      "command": $(echo "$cmd" | jq -R .),
      "next_runs": $next_runs
    }
JOBEOF
    fi
done < <(crontab -l 2>/dev/null || echo "")

# Parse system crontab
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^# ]] && continue
    [[ -z "${line// }" ]] && continue

    # System crontab has user field: min hour dom mon dow user command
    if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        min="${BASH_REMATCH[1]}"
        hour="${BASH_REMATCH[2]}"
        dom="${BASH_REMATCH[3]}"
        mon="${BASH_REMATCH[4]}"
        dow="${BASH_REMATCH[5]}"
        user="${BASH_REMATCH[6]}"
        cmd="${BASH_REMATCH[7]}"

        expr="$min $hour $dom $mon $dow"
        human=$(cron_to_human "$expr")
        next_runs=$(get_cron_next_runs "$expr")

        short_name=$(echo "$cmd" | sed 's/.*run-parts.*--report //' | sed 's|/etc/||')

        [[ "$FIRST_JOB" == "false" ]] && echo "," >> "$OUTPUT_FILE.tmp"
        FIRST_JOB=false

        cat >> "$OUTPUT_FILE.tmp" << JOBEOF
    {
      "id": "cron-system-$short_name",
      "name": "$short_name",
      "type": "cron",
      "source": "system-crontab",
      "schedule": "$expr",
      "schedule_human": "$human",
      "user": "$user",
      "command": $(echo "$cmd" | jq -R .),
      "next_runs": $next_runs
    }
JOBEOF
    fi
done < <(grep -v '^#' /etc/crontab 2>/dev/null | grep -v '^[[:space:]]*$' | grep -v '^SHELL' | grep -v '^PATH' || echo "")

# Parse /etc/cron.d/* files (system cron jobs)
if [[ -d "/etc/cron.d" ]]; then
    for cronfile in /etc/cron.d/*; do
        [[ -f "$cronfile" ]] || continue
        cronfile_name=$(basename "$cronfile")

        while IFS= read -r line; do
            # Skip comments, empty lines, and variable definitions
            [[ "$line" =~ ^# ]] && continue
            [[ -z "${line// }" ]] && continue
            [[ "$line" =~ ^[A-Z_]+= ]] && continue

            # System cron.d files have user field: min hour dom mon dow user command
            if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
                min="${BASH_REMATCH[1]}"
                hour="${BASH_REMATCH[2]}"
                dom="${BASH_REMATCH[3]}"
                mon="${BASH_REMATCH[4]}"
                dow="${BASH_REMATCH[5]}"
                user="${BASH_REMATCH[6]}"
                cmd="${BASH_REMATCH[7]}"

                expr="$min $hour $dom $mon $dow"
                human=$(cron_to_human "$expr")
                next_runs=$(get_cron_next_runs "$expr")

                # Create unique ID from file and command
                short_name=$(echo "$cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "job")

                [[ "$FIRST_JOB" == "false" ]] && echo "," >> "$OUTPUT_FILE.tmp"
                FIRST_JOB=false

                cat >> "$OUTPUT_FILE.tmp" << JOBEOF
    {
      "id": "cron-d-$cronfile_name-$short_name",
      "name": "$cronfile_name: $short_name",
      "type": "cron",
      "source": "/etc/cron.d/$cronfile_name",
      "schedule": "$expr",
      "schedule_human": "$human",
      "user": "$user",
      "command": $(echo "$cmd" | jq -R .),
      "next_runs": $next_runs
    }
JOBEOF
            fi
        done < "$cronfile"
    done
fi

# Parse systemd timers
while IFS= read -r line; do
    # Skip header line
    [[ "$line" =~ ^NEXT ]] && continue
    [[ -z "${line// }" ]] && continue

    # Parse: NEXT LEFT LAST PASSED UNIT ACTIVATES
    next_time=$(echo "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
    unit=$(echo "$line" | awk '{print $(NF-1)}')
    service=$(echo "$line" | awk '{print $NF}')

    # Skip if no next time
    [[ "$next_time" == "-" ]] && continue
    [[ "$unit" == "-" ]] && continue

    # Convert next time to ISO format
    if [[ "$next_time" != "-" ]]; then
        next_iso=$(date -d "$next_time" +"%Y-%m-%dT%H:%M:00Z" 2>/dev/null || echo "")
    else
        next_iso=""
    fi

    timer_name="${unit%.timer}"

    [[ "$FIRST_JOB" == "false" ]] && echo "," >> "$OUTPUT_FILE.tmp"
    FIRST_JOB=false

    cat >> "$OUTPUT_FILE.tmp" << JOBEOF
    {
      "id": "systemd-$timer_name",
      "name": "$timer_name",
      "type": "systemd",
      "source": "systemd-timer",
      "unit": "$unit",
      "service": "$service",
      "schedule_human": "Systemd timer",
      "next_runs": $(if [[ -n "$next_iso" ]]; then echo "[\"$next_iso\"]"; else echo "[]"; fi)
    }
JOBEOF
done < <(systemctl list-timers --all 2>/dev/null | head -30)

# Parse cron directories
for dir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    if [[ -d "$dir" ]]; then
        freq=$(basename "$dir" | sed 's/cron\.//')
        case "$freq" in
            hourly) schedule="0 * * * *"; human="Hourly" ;;
            daily) schedule="25 6 * * *"; human="Daily at 6:25" ;;
            weekly) schedule="47 6 * * 0"; human="Weekly on Sunday at 6:47" ;;
            monthly) schedule="52 6 1 * *"; human="Monthly on 1st at 6:52" ;;
        esac

        for script in "$dir"/*; do
            [[ -x "$script" ]] || continue
            script_name=$(basename "$script")

            [[ "$FIRST_JOB" == "false" ]] && echo "," >> "$OUTPUT_FILE.tmp"
            FIRST_JOB=false

            cat >> "$OUTPUT_FILE.tmp" << JOBEOF
    {
      "id": "cron-$freq-$script_name",
      "name": "$script_name",
      "type": "cron",
      "source": "$dir",
      "schedule": "$schedule",
      "schedule_human": "$human",
      "command": "$script"
    }
JOBEOF
        done
    fi
done

# Close jobs array
echo "" >> "$OUTPUT_FILE.tmp"
echo "  ]," >> "$OUTPUT_FILE.tmp"

# Calculate hourly activity for heatmap (based on scheduled jobs)
echo "  \"hourly_activity\": {" >> "$OUTPUT_FILE.tmp"
for h in {0..23}; do
    count=0
    # Count jobs that run at this hour
    # Every minute jobs count as 60
    # Every 5 min = 12, every 10 min = 6, every 30 min = 2, hourly = 1
    count=$((count + 1))  # Placeholder - real calculation would parse all jobs
    [[ $h -lt 23 ]] && echo "    \"$h\": $count," >> "$OUTPUT_FILE.tmp" || echo "    \"$h\": $count" >> "$OUTPUT_FILE.tmp"
done
echo "  }," >> "$OUTPUT_FILE.tmp"

# Add orchestrator info prominently
echo "  \"orchestrator\": {" >> "$OUTPUT_FILE.tmp"
echo "    \"schedule\": \"*/30 * * * *\"," >> "$OUTPUT_FILE.tmp"
echo "    \"schedule_human\": \"Every 30 minutes\"," >> "$OUTPUT_FILE.tmp"
echo "    \"agents\": [\"idea-maker\", \"project-manager\", \"developer\", \"tester\", \"security\"]," >> "$OUTPUT_FILE.tmp"
echo "    \"script\": \"/home/novakj/scripts/cron-orchestrator.sh\"" >> "$OUTPUT_FILE.tmp"
echo "  }" >> "$OUTPUT_FILE.tmp"

echo "}" >> "$OUTPUT_FILE.tmp"

# Validate and move
if jq . "$OUTPUT_FILE.tmp" > /dev/null 2>&1; then
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "[$(date)] Schedule data updated successfully"
else
    echo "[$(date)] ERROR: Invalid JSON generated"
    cat "$OUTPUT_FILE.tmp"
    rm -f "$OUTPUT_FILE.tmp"
    exit 1
fi
