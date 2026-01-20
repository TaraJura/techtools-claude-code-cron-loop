#!/bin/bash
# update-learning.sh - Tracks agent learning and improvement over time
# Output: JSON data for the learning.html dashboard
# Analyzes: success rate trends, task type performance, improvement velocity

set -e

TASKS_FILE="/home/novakj/tasks.md"
ARCHIVE_DIR="/home/novakj/logs/tasks-archive"
LOG_DIR="/home/novakj/actors"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/learning.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/learning-history.json"
QUALITY_FILE="/var/www/cronloop.techtools.cz/api/quality.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Initialize history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"history":[]}' > "$HISTORY_FILE"
fi

# Agents to track
AGENTS=("developer" "developer2" "idea-maker" "project-manager" "tester" "security")

# Task categories for classification
classify_task_type() {
    local desc="$1"
    local lower_desc=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

    # Web features
    if echo "$lower_desc" | grep -qE "web app|html|dashboard|page|widget|frontend|css|javascript"; then
        echo "web-feature"
    # Scripts/Backend
    elif echo "$lower_desc" | grep -qE "script|bash|backend|api|endpoint|json"; then
        echo "script"
    # Security
    elif echo "$lower_desc" | grep -qE "security|ssh|audit|vulnerability|attack"; then
        echo "security"
    # Documentation
    elif echo "$lower_desc" | grep -qE "doc|readme|comment|help|guide"; then
        echo "docs"
    # Configuration
    elif echo "$lower_desc" | grep -qE "config|setting|cron|schedule|setup"; then
        echo "config"
    # Testing
    elif echo "$lower_desc" | grep -qE "test|verify|check|validate"; then
        echo "testing"
    else
        echo "other"
    fi
}

# Extract task data from tasks.md and archives
extract_tasks() {
    local temp_file=$(mktemp)

    # Parse current tasks.md
    if [ -f "$TASKS_FILE" ]; then
        # Extract task blocks
        awk '/^### TASK-[0-9]+:/{p=1; task=$0} p{if(/^### TASK-[0-9]+:/ && NR>1){p=1; task=$0} else if(/^---/ || /^## /){p=0} else {print task; print; task=""}}' "$TASKS_FILE" >> "$temp_file"
    fi

    # Parse archives
    for archive in "$ARCHIVE_DIR"/*.md; do
        if [ -f "$archive" ]; then
            awk '/^### TASK-[0-9]+:/{p=1; task=$0} p{if(/^### TASK-[0-9]+:/ && NR>1){p=1; task=$0} else if(/^---/ || /^## /){p=0} else {print task; print; task=""}}' "$archive" >> "$temp_file"
        fi
    done

    echo "$temp_file"
}

# Get task statistics per agent by type
get_agent_task_stats() {
    local agent="$1"
    local tasks_data="$2"

    local passed_web=0
    local failed_web=0
    local passed_script=0
    local failed_script=0
    local passed_security=0
    local failed_security=0
    local passed_docs=0
    local failed_docs=0
    local passed_config=0
    local failed_config=0
    local passed_other=0
    local failed_other=0
    local total_rework=0

    # Read tasks file and process
    local current_task=""
    local current_status=""
    local current_assigned=""
    local current_desc=""
    local had_rework="false"

    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ TASK-([0-9]+): ]]; then
            # Process previous task if any
            if [ -n "$current_task" ] && [ "$current_assigned" = "$agent" ]; then
                local task_type=$(classify_task_type "$current_desc")

                if [ "$current_status" = "VERIFIED" ] || [ "$current_status" = "DONE" ]; then
                    case "$task_type" in
                        web-feature) passed_web=$((passed_web + 1)) ;;
                        script) passed_script=$((passed_script + 1)) ;;
                        security) passed_security=$((passed_security + 1)) ;;
                        docs) passed_docs=$((passed_docs + 1)) ;;
                        config) passed_config=$((passed_config + 1)) ;;
                        *) passed_other=$((passed_other + 1)) ;;
                    esac
                elif [ "$current_status" = "FAILED" ]; then
                    case "$task_type" in
                        web-feature) failed_web=$((failed_web + 1)) ;;
                        script) failed_script=$((failed_script + 1)) ;;
                        security) failed_security=$((failed_security + 1)) ;;
                        docs) failed_docs=$((failed_docs + 1)) ;;
                        config) failed_config=$((failed_config + 1)) ;;
                        *) failed_other=$((failed_other + 1)) ;;
                    esac
                fi

                if [ "$had_rework" = "true" ]; then
                    total_rework=$((total_rework + 1))
                fi
            fi

            # Start new task
            current_task="$line"
            current_status=""
            current_assigned=""
            current_desc=""
            had_rework="false"
        elif [[ "$line" =~ Status.*:\ *(TODO|IN_PROGRESS|DONE|VERIFIED|FAILED) ]]; then
            current_status="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ Assigned.*:\ *([a-z0-9-]+) ]]; then
            current_assigned="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ Description.*:\ *(.+) ]]; then
            current_desc="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ (FIX\ REQUIRED|Re-tested|rework|Bug\ Fix) ]]; then
            had_rework="true"
        fi
    done < "$tasks_data"

    # Process last task
    if [ -n "$current_task" ] && [ "$current_assigned" = "$agent" ]; then
        local task_type=$(classify_task_type "$current_desc")

        if [ "$current_status" = "VERIFIED" ] || [ "$current_status" = "DONE" ]; then
            case "$task_type" in
                web-feature) passed_web=$((passed_web + 1)) ;;
                script) passed_script=$((passed_script + 1)) ;;
                security) passed_security=$((passed_security + 1)) ;;
                docs) passed_docs=$((passed_docs + 1)) ;;
                config) passed_config=$((passed_config + 1)) ;;
                *) passed_other=$((passed_other + 1)) ;;
            esac
        elif [ "$current_status" = "FAILED" ]; then
            case "$task_type" in
                web-feature) failed_web=$((failed_web + 1)) ;;
                script) failed_script=$((failed_script + 1)) ;;
                security) failed_security=$((failed_security + 1)) ;;
                docs) failed_docs=$((failed_docs + 1)) ;;
                config) failed_config=$((failed_config + 1)) ;;
                *) failed_other=$((failed_other + 1)) ;;
            esac
        fi

        if [ "$had_rework" = "true" ]; then
            total_rework=$((total_rework + 1))
        fi
    fi

    echo "$passed_web $failed_web $passed_script $failed_script $passed_security $failed_security $passed_docs $failed_docs $passed_config $failed_config $passed_other $failed_other $total_rework"
}

# Calculate success rate safely
calc_rate() {
    local passed="$1"
    local failed="$2"
    local total=$((passed + failed))

    if [ "$total" -gt 0 ]; then
        echo "scale=1; $passed * 100 / $total" | bc
    else
        echo "100"
    fi
}

# Get historical success rates from learning-history.json for trends
get_historical_rate() {
    local agent="$1"
    local days_ago="$2"

    if [ -f "$HISTORY_FILE" ]; then
        jq -r ".history[-(${days_ago}+1)].agents.\"$agent\".overall_success_rate // 0" "$HISTORY_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Extract lessons learned from prompt files
get_lessons_learned() {
    local agent="$1"
    local prompt_file="$LOG_DIR/$agent/prompt.md"
    local lessons=""

    if [ -f "$prompt_file" ]; then
        # Extract lines containing LEARNED or from Lessons Learned section
        lessons=$(grep -i "LEARNED\|lesson" "$prompt_file" 2>/dev/null | head -5 | sed 's/.*LEARNED.*: //' | tr '\n' '|' || echo "")
    fi

    echo "$lessons"
}

# Extract feedback from tester on failed tasks
get_tester_feedback() {
    local temp_file=$(mktemp)

    # Look for FAILED tasks and their feedback
    if [ -f "$TASKS_FILE" ]; then
        grep -A20 "Status.*FAILED" "$TASKS_FILE" 2>/dev/null | grep -i "feedback\|reason\|issue" | head -5 >> "$temp_file"
    fi

    for archive in "$ARCHIVE_DIR"/*.md; do
        if [ -f "$archive" ]; then
            grep -A20 "Status.*FAILED" "$archive" 2>/dev/null | grep -i "feedback\|reason\|issue" | head -3 >> "$temp_file"
        fi
    done

    cat "$temp_file" | head -10 | sed 's/.*: //' | tr '\n' '|'
    rm -f "$temp_file"
}

# Count recent commits by agent
count_recent_commits() {
    local agent="$1"
    local days="$2"

    cd /home/novakj
    git log --since="${days} days ago" --oneline --grep="\[$agent\]" 2>/dev/null | wc -l || echo "0"
}

# Main execution

# Extract all tasks to temp file
TASKS_DATA=$(extract_tasks)

# Build JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "generated": "$TIMESTAMP",
  "epoch": $EPOCH,
  "date": "$TODAY",
  "agents": {
EOF

# Process each agent
FIRST_AGENT=true
declare -A agent_data

for agent in "${AGENTS[@]}"; do
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    # Get task stats by type
    read pw fw ps fs pse fse pd fd pc fc po fo rework <<< $(get_agent_task_stats "$agent" "$TASKS_DATA")

    # Ensure values are numeric
    pw=${pw:-0}; fw=${fw:-0}
    ps=${ps:-0}; fs=${fs:-0}
    pse=${pse:-0}; fse=${fse:-0}
    pd=${pd:-0}; fd=${fd:-0}
    pc=${pc:-0}; fc=${fc:-0}
    po=${po:-0}; fo=${fo:-0}
    rework=${rework:-0}

    # Calculate per-type success rates
    web_rate=$(calc_rate $pw $fw)
    script_rate=$(calc_rate $ps $fs)
    security_rate=$(calc_rate $pse $fse)
    docs_rate=$(calc_rate $pd $fd)
    config_rate=$(calc_rate $pc $fc)
    other_rate=$(calc_rate $po $fo)

    # Overall success rate
    total_passed=$((pw + ps + pse + pd + pc + po))
    total_failed=$((fw + fs + fse + fd + fc + fo))
    overall_rate=$(calc_rate $total_passed $total_failed)
    total_tasks=$((total_passed + total_failed))

    # Rework rate
    if [ "$total_passed" -gt 0 ]; then
        rework_rate=$(echo "scale=1; $rework * 100 / $total_passed" | bc)
    else
        rework_rate="0"
    fi

    # Get historical data for trend calculation
    rate_7d_ago=$(get_historical_rate "$agent" 7)
    rate_30d_ago=$(get_historical_rate "$agent" 30)

    # Calculate improvement velocity (change in success rate)
    if [ "$rate_7d_ago" != "0" ] && [ "$rate_7d_ago" != "" ]; then
        improvement_7d=$(echo "scale=1; $overall_rate - $rate_7d_ago" | bc)
    else
        improvement_7d="0"
    fi

    if [ "$rate_30d_ago" != "0" ] && [ "$rate_30d_ago" != "" ]; then
        improvement_30d=$(echo "scale=1; $overall_rate - $rate_30d_ago" | bc)
    else
        improvement_30d="0"
    fi

    # Determine trend
    if [ "$(echo "$improvement_7d > 2" | bc)" -eq 1 ]; then
        trend="improving"
    elif [ "$(echo "$improvement_7d < -2" | bc)" -eq 1 ]; then
        trend="declining"
    else
        trend="stable"
    fi

    # Get commit activity
    commits_7d=$(count_recent_commits "$agent" 7)
    commits_30d=$(count_recent_commits "$agent" 30)

    # Identify strengths (highest success rate categories with enough tasks)
    declare -A type_rates
    type_rates["web-feature"]=$web_rate
    type_rates["script"]=$script_rate
    type_rates["security"]=$security_rate
    type_rates["docs"]=$docs_rate
    type_rates["config"]=$config_rate

    # Find best category
    best_type=""
    best_rate=0
    for type in "${!type_rates[@]}"; do
        rate="${type_rates[$type]}"
        if [ "$(echo "$rate > $best_rate" | bc)" -eq 1 ]; then
            best_rate="$rate"
            best_type="$type"
        fi
    done

    # Find worst category (with tasks)
    worst_type=""
    worst_rate=100
    declare -A type_totals
    type_totals["web-feature"]=$((pw + fw))
    type_totals["script"]=$((ps + fs))
    type_totals["security"]=$((pse + fse))
    type_totals["docs"]=$((pd + fd))
    type_totals["config"]=$((pc + fc))

    for type in "${!type_rates[@]}"; do
        total="${type_totals[$type]}"
        if [ "$total" -gt 0 ]; then
            rate="${type_rates[$type]}"
            if [ "$(echo "$rate < $worst_rate" | bc)" -eq 1 ]; then
                worst_rate="$rate"
                worst_type="$type"
            fi
        fi
    done

    # Get lessons learned
    lessons=$(get_lessons_learned "$agent")

    # Output agent data
    cat >> "$OUTPUT_FILE" << AGENT_EOF
    "$agent": {
      "overall_success_rate": $overall_rate,
      "total_tasks": $total_tasks,
      "total_passed": $total_passed,
      "total_failed": $total_failed,
      "rework_count": $rework,
      "rework_rate": $rework_rate,
      "by_type": {
        "web-feature": {"passed": $pw, "failed": $fw, "rate": $web_rate},
        "script": {"passed": $ps, "failed": $fs, "rate": $script_rate},
        "security": {"passed": $pse, "failed": $fse, "rate": $security_rate},
        "docs": {"passed": $pd, "failed": $fd, "rate": $docs_rate},
        "config": {"passed": $pc, "failed": $fc, "rate": $config_rate},
        "other": {"passed": $po, "failed": $fo, "rate": $other_rate}
      },
      "strengths": ["$best_type"],
      "struggles": ["$worst_type"],
      "trend": "$trend",
      "improvement_7d": $improvement_7d,
      "improvement_30d": $improvement_30d,
      "commits_7d": $commits_7d,
      "commits_30d": $commits_30d
    }
AGENT_EOF
done

echo "" >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Summary statistics
total_all_passed=0
total_all_failed=0
total_all_rework=0

for agent in "${AGENTS[@]}"; do
    agent_passed=$(jq -r ".agents.\"$agent\".total_passed // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    agent_failed=$(jq -r ".agents.\"$agent\".total_failed // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    agent_rework=$(jq -r ".agents.\"$agent\".rework_count // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")

    total_all_passed=$((total_all_passed + agent_passed))
    total_all_failed=$((total_all_failed + agent_failed))
    total_all_rework=$((total_all_rework + agent_rework))
done

total_all=$((total_all_passed + total_all_failed))
if [ "$total_all" -gt 0 ]; then
    system_success_rate=$(echo "scale=1; $total_all_passed * 100 / $total_all" | bc)
else
    system_success_rate="100"
fi

if [ "$total_all_passed" -gt 0 ]; then
    system_rework_rate=$(echo "scale=1; $total_all_rework * 100 / $total_all_passed" | bc)
else
    system_rework_rate="0"
fi

# Get historical system rates
system_rate_7d_ago=$(jq -r '.history[-8].summary.system_success_rate // 0' "$HISTORY_FILE" 2>/dev/null || echo "0")
system_rate_30d_ago=$(jq -r '.history[-31].summary.system_success_rate // 0' "$HISTORY_FILE" 2>/dev/null || echo "0")

if [ "$system_rate_7d_ago" != "0" ] && [ "$system_rate_7d_ago" != "" ]; then
    system_improvement=$(echo "scale=1; $system_success_rate - $system_rate_7d_ago" | bc)
else
    system_improvement="0"
fi

# Get feedback summary
feedback_summary=$(get_tester_feedback | head -c 500)

cat >> "$OUTPUT_FILE" << EOF
  "summary": {
    "system_success_rate": $system_success_rate,
    "total_tasks": $total_all,
    "total_passed": $total_all_passed,
    "total_failed": $total_all_failed,
    "total_rework": $total_all_rework,
    "rework_rate": $system_rework_rate,
    "improvement_velocity": $system_improvement,
    "is_improving": $([ "$(echo "$system_improvement > 0" | bc)" -eq 1 ] && echo "true" || echo "false")
  },
  "weekly_trend": [
EOF

# Add weekly trend data
for i in 6 5 4 3 2 1 0; do
    date_str=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)
    rate=$(jq -r ".history[] | select(.date == \"$date_str\") | .summary.system_success_rate // 0" "$HISTORY_FILE" 2>/dev/null || echo "0")

    if [ "$i" -lt 6 ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    echo "    {\"date\": \"$date_str\", \"rate\": ${rate:-0}}" >> "$OUTPUT_FILE"
done

cat >> "$OUTPUT_FILE" << EOF
  ],
  "improvement_opportunities": [
EOF

# Find agents/types needing improvement (low success rate with enough tasks)
FIRST_OPP=true
for agent in "${AGENTS[@]}"; do
    for type in "web-feature" "script" "security" "docs" "config"; do
        rate=$(jq -r ".agents.\"$agent\".by_type.\"$type\".rate // 100" "$OUTPUT_FILE" 2>/dev/null || echo "100")
        passed=$(jq -r ".agents.\"$agent\".by_type.\"$type\".passed // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        failed=$(jq -r ".agents.\"$agent\".by_type.\"$type\".failed // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        total=$((passed + failed))

        # Flag if success rate < 80% and has at least 2 tasks
        if [ "$total" -ge 2 ] && [ "$(echo "$rate < 80" | bc)" -eq 1 ]; then
            if [ "$FIRST_OPP" = true ]; then
                FIRST_OPP=false
            else
                echo "," >> "$OUTPUT_FILE"
            fi
            echo "    {\"agent\": \"$agent\", \"type\": \"$type\", \"rate\": $rate, \"suggestion\": \"Review prompt for $type task handling\"}" >> "$OUTPUT_FILE"
        fi
    done
done

cat >> "$OUTPUT_FILE" << EOF

  ]
}
EOF

# Clean up temp file
rm -f "$TASKS_DATA"

# Update history
TODAY_ENTRY=$(jq -n \
    --arg date "$TODAY" \
    --argjson rate "$system_success_rate" \
    --argjson total "$total_all" \
    --argjson passed "$total_all_passed" \
    --argjson rework "$total_all_rework" \
    '{date: $date, summary: {system_success_rate: $rate, total_tasks: $total, total_passed: $passed, total_rework: $rework}}')

# Add agent data to history entry
for agent in "${AGENTS[@]}"; do
    agent_rate=$(jq -r ".agents.\"$agent\".overall_success_rate // 0" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    TODAY_ENTRY=$(echo "$TODAY_ENTRY" | jq --arg agent "$agent" --argjson rate "$agent_rate" '.agents[$agent] = {overall_success_rate: $rate}')
done

# Append or update today's entry
if jq -e ".history[-1].date == \"$TODAY\"" "$HISTORY_FILE" >/dev/null 2>&1; then
    jq ".history[-1] = $TODAY_ENTRY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
else
    jq ".history += [$TODAY_ENTRY]" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
fi

# Keep only last 60 days of history
jq '.history = .history[-60:]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

echo "Learning metrics updated: $OUTPUT_FILE"
