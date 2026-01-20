#!/bin/bash
# update-workflow.sh - Extracts task lifecycle metrics and SLA tracking from git history
# Output: JSON data for workflow.html dashboard

set -e

REPO_DIR="/home/novakj"
TASKS_FILE="$REPO_DIR/tasks.md"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/workflow.json"

# SLA definitions (in hours)
SLA_HIGH=24
SLA_MEDIUM=48
SLA_LOW=168  # 7 days

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

cd "$REPO_DIR"

# Create temporary file for building JSON
TMP_FILE=$(mktemp)

# Parse tasks.md for current task states
parse_current_tasks() {
    local status_counts_todo=0
    local status_counts_in_progress=0
    local status_counts_done=0
    local status_counts_verified=0
    local priority_high=0
    local priority_medium=0
    local priority_low=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^\#\#\#[[:space:]]+(TASK-[0-9]+) ]]; then
            current_task="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \*\*Status\*\*:[[:space:]]*(TODO|IN_PROGRESS|DONE|VERIFIED) ]]; then
            status="${BASH_REMATCH[1]}"
            case "$status" in
                TODO) ((status_counts_todo++)) ;;
                IN_PROGRESS) ((status_counts_in_progress++)) ;;
                DONE) ((status_counts_done++)) ;;
                VERIFIED) ((status_counts_verified++)) ;;
            esac
        elif [[ "$line" =~ \*\*Priority\*\*:[[:space:]]*(HIGH|MEDIUM|LOW) ]]; then
            priority="${BASH_REMATCH[1]}"
            case "$priority" in
                HIGH) ((priority_high++)) ;;
                MEDIUM) ((priority_medium++)) ;;
                LOW) ((priority_low++)) ;;
            esac
        fi
    done < "$TASKS_FILE"

    echo "$status_counts_todo $status_counts_in_progress $status_counts_done $status_counts_verified $priority_high $priority_medium $priority_low"
}

# Get task status changes from git history
get_task_history() {
    # Get commits that modified tasks.md, extract task status changes
    git log --oneline --follow -p -- tasks.md 2>/dev/null | \
        grep -E "^(\+|\-).*(TASK-[0-9]+|Status.*:)" | head -1000
}

# Calculate task velocity (tasks completed per day in last 7 days)
calculate_velocity() {
    local completed=0
    local days_counted=0

    for i in $(seq 0 6); do
        day_date=$(date -d "-$i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)
        day_commits=$(git log --since="$day_date 00:00:00" --until="$day_date 23:59:59" --oneline -- tasks.md 2>/dev/null | wc -l)
        # Estimate: count status changes to DONE or VERIFIED
        day_completed=$(git log --since="$day_date 00:00:00" --until="$day_date 23:59:59" -p -- tasks.md 2>/dev/null | \
            grep -E "^\+.*Status.*:.*DONE|^\+.*Status.*:.*VERIFIED" | wc -l)
        completed=$((completed + day_completed))
        days_counted=$((days_counted + 1))
    done

    if [ $days_counted -gt 0 ]; then
        echo "scale=2; $completed / $days_counted" | bc 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get backlog age distribution
get_backlog_ages() {
    local ages_under_1d=0
    local ages_1_3d=0
    local ages_3_7d=0
    local ages_over_7d=0
    local current_task=""
    local task_found=0
    local now_epoch=$(date +%s)

    # For each TODO task, find when it was first created
    while IFS= read -r line; do
        if [[ "$line" =~ ^\#\#\#[[:space:]]+(TASK-[0-9]+) ]]; then
            current_task="${BASH_REMATCH[1]}"
            task_found=1
        elif [[ $task_found -eq 1 && "$line" =~ \*\*Status\*\*:[[:space:]]*TODO ]]; then
            # Find first commit mentioning this task
            first_commit=$(git log --oneline --all --format="%aI" -S "$current_task" 2>/dev/null | tail -1)
            if [ -n "$first_commit" ]; then
                first_epoch=$(date -d "$first_commit" +%s 2>/dev/null || echo "$now_epoch")
                age_hours=$(( (now_epoch - first_epoch) / 3600 ))

                if [ $age_hours -lt 24 ]; then
                    ((ages_under_1d++))
                elif [ $age_hours -lt 72 ]; then
                    ((ages_1_3d++))
                elif [ $age_hours -lt 168 ]; then
                    ((ages_3_7d++))
                else
                    ((ages_over_7d++))
                fi
            else
                ((ages_under_1d++))  # Default if no history found
            fi
            task_found=0
        fi
    done < "$TASKS_FILE"

    echo "$ages_under_1d $ages_1_3d $ages_3_7d $ages_over_7d"
}

# Get completion metrics by priority
get_priority_metrics() {
    local high_completed=0
    local high_total=0
    local medium_completed=0
    local medium_total=0
    local low_completed=0
    local low_total=0

    local current_status=""
    local current_priority=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^\#\#\#[[:space:]]+(TASK-[0-9]+) ]]; then
            # Process previous task
            if [ -n "$current_priority" ]; then
                case "$current_priority" in
                    HIGH)
                        ((high_total++))
                        [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((high_completed++))
                        ;;
                    MEDIUM)
                        ((medium_total++))
                        [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((medium_completed++))
                        ;;
                    LOW)
                        ((low_total++))
                        [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((low_completed++))
                        ;;
                esac
            fi
            current_status=""
            current_priority=""
        elif [[ "$line" =~ \*\*Status\*\*:[[:space:]]*(TODO|IN_PROGRESS|DONE|VERIFIED) ]]; then
            current_status="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \*\*Priority\*\*:[[:space:]]*(HIGH|MEDIUM|LOW) ]]; then
            current_priority="${BASH_REMATCH[1]}"
        fi
    done < "$TASKS_FILE"

    # Process last task
    if [ -n "$current_priority" ]; then
        case "$current_priority" in
            HIGH)
                ((high_total++))
                [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((high_completed++))
                ;;
            MEDIUM)
                ((medium_total++))
                [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((medium_completed++))
                ;;
            LOW)
                ((low_total++))
                [[ "$current_status" == "DONE" || "$current_status" == "VERIFIED" ]] && ((low_completed++))
                ;;
        esac
    fi

    echo "$high_completed $high_total $medium_completed $medium_total $low_completed $low_total"
}

# Get daily completion trend (last 14 days)
get_daily_completions() {
    local result=""
    for i in $(seq 13 -1 0); do
        day_date=$(date -d "-$i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)
        day_completed=$(git log --since="$day_date 00:00:00" --until="$day_date 23:59:59" -p -- tasks.md 2>/dev/null | \
            grep -c -E "^\+.*Status.*:.*DONE" 2>/dev/null || echo "0")
        # Ensure day_completed is a valid number
        day_completed=$(echo "$day_completed" | tr -d '\n' | grep -oE '^[0-9]+' || echo "0")
        [ -z "$day_completed" ] && day_completed=0
        if [ -n "$result" ]; then
            result="$result,"
        fi
        result="$result{\"date\":\"$day_date\",\"completed\":$day_completed}"
    done
    echo "$result"
}

# Get agent throughput
get_agent_throughput() {
    local result=""
    local first=1

    for agent in idea-maker project-manager developer tester security; do
        # Count commits by this agent in last 7 days
        count=$(git log --since="7 days ago" --oneline -- tasks.md 2>/dev/null | \
            grep -c "\[$agent\]" || echo "0")

        if [ $first -eq 0 ]; then
            result="$result,"
        fi
        first=0
        result="$result\"$agent\":$count"
    done
    echo "{$result}"
}

# Get rejection rate (tasks that went DONE -> IN_PROGRESS)
get_rejection_rate() {
    local rejections=$(git log -p -- tasks.md 2>/dev/null | \
        grep -c "^\+.*Status.*:.*IN_PROGRESS" | head -100 || echo "0")
    local completions=$(git log -p -- tasks.md 2>/dev/null | \
        grep -c "^\+.*Status.*:.*DONE" | head -100 || echo "0")

    if [ "$completions" -gt 0 ]; then
        # Estimate: rejections are roughly 10% of DONE->IN_PROGRESS transitions
        # This is a rough estimate since we can't easily track specific task state changes
        echo "scale=1; ($rejections * 10 / $completions)" | bc 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get bottleneck status (which status has most tasks)
get_bottleneck() {
    read todo in_prog done verified high med low <<< $(parse_current_tasks)

    local max=$todo
    local bottleneck="TODO"

    if [ "$in_prog" -gt "$max" ]; then
        max=$in_prog
        bottleneck="IN_PROGRESS"
    fi

    echo "$bottleneck"
}

# Main execution
echo "Calculating workflow metrics..."

# Get current task distribution
read todo in_prog done verified high med low <<< $(parse_current_tasks)
total=$((todo + in_prog + done + verified))

# Get backlog ages
read age_1d age_3d age_7d age_over <<< $(get_backlog_ages)

# Get priority metrics
read high_done high_total med_done med_total low_done low_total <<< $(get_priority_metrics)

# Calculate completion rates
high_rate=0
med_rate=0
low_rate=0
[ "$high_total" -gt 0 ] && high_rate=$(echo "scale=0; $high_done * 100 / $high_total" | bc 2>/dev/null || echo "0")
[ "$med_total" -gt 0 ] && med_rate=$(echo "scale=0; $med_done * 100 / $med_total" | bc 2>/dev/null || echo "0")
[ "$low_total" -gt 0 ] && low_rate=$(echo "scale=0; $low_done * 100 / $low_total" | bc 2>/dev/null || echo "0")

# Get velocity
velocity=$(calculate_velocity)
[ -z "$velocity" ] && velocity="0"

# Get agent throughput
agent_throughput=$(get_agent_throughput)

# Get daily completions
daily_completions=$(get_daily_completions)

# Get bottleneck
bottleneck=$(get_bottleneck)

# Calculate average completion per day (simple estimate)
avg_completion=$(echo "scale=1; ($done + $verified) / 7" | bc 2>/dev/null || echo "0")

# Estimate days to clear backlog
if [ "$velocity" != "0" ] && [ $(echo "$velocity > 0" | bc 2>/dev/null || echo "0") -eq 1 ]; then
    days_to_clear=$(echo "scale=0; $todo / $velocity" | bc 2>/dev/null || echo "999")
else
    days_to_clear="999"
fi
[ "$days_to_clear" -gt 999 ] && days_to_clear="999"

# Build JSON output
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "status_distribution": {
    "todo": $todo,
    "in_progress": $in_prog,
    "done": $done,
    "verified": $verified,
    "total": $total
  },
  "priority_distribution": {
    "high": $high,
    "medium": $med,
    "low": $low
  },
  "backlog_aging": {
    "under_1_day": $age_1d,
    "1_to_3_days": $age_3d,
    "3_to_7_days": $age_7d,
    "over_7_days": $age_over,
    "stale_count": $age_over
  },
  "velocity": {
    "daily_average": $velocity,
    "weekly_total": $(echo "scale=0; $velocity * 7" | bc 2>/dev/null || echo "0"),
    "days_to_clear_backlog": $days_to_clear
  },
  "sla_compliance": {
    "high": {
      "target_hours": $SLA_HIGH,
      "completed": $high_done,
      "total": $high_total,
      "compliance_rate": $high_rate
    },
    "medium": {
      "target_hours": $SLA_MEDIUM,
      "completed": $med_done,
      "total": $med_total,
      "compliance_rate": $med_rate
    },
    "low": {
      "target_hours": $SLA_LOW,
      "completed": $low_done,
      "total": $low_total,
      "compliance_rate": $low_rate
    }
  },
  "agent_throughput": $agent_throughput,
  "bottleneck": {
    "status": "$bottleneck",
    "count": $([ "$bottleneck" == "TODO" ] && echo "$todo" || echo "$in_prog")
  },
  "daily_completions": [$daily_completions],
  "summary": {
    "total_tasks": $total,
    "backlog_size": $todo,
    "in_flight": $in_prog,
    "completed_total": $((done + verified)),
    "avg_daily_completion": $avg_completion
  }
}
EOF

# Move temp file to output (atomic operation)
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Workflow metrics updated: $OUTPUT_FILE"
