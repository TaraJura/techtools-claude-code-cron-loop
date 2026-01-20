#!/bin/bash
# update-quality.sh - Tracks and scores agent output quality over time
# Output: JSON data for the quality.html dashboard
# Measures: tester pass rates, rework rates, code complexity, first-time pass rate

set -e

TASKS_FILE="/home/novakj/tasks.md"
ARCHIVE_DIR="/home/novakj/logs/tasks-archive"
LOG_DIR="/home/novakj/actors"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/quality.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/quality-history.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Initialize history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"history":[]}' > "$HISTORY_FILE"
fi

# Count tasks by status and assigned agent from tasks.md and archives
count_tasks() {
    local pattern="$1"
    local file="$2"
    grep -c "$pattern" "$file" 2>/dev/null || echo "0"
}

# Parse task archives for quality metrics
get_task_metrics() {
    local agent="$1"

    # Count tasks assigned to agent that were VERIFIED (passed first time)
    local passed=0
    local failed=0
    local total=0
    local rework=0

    # Check current tasks.md (using **Assigned**: format with markdown bold)
    if [ -f "$TASKS_FILE" ]; then
        # Count DONE tasks by agent
        local done_count=$(grep -B5 "Status.*DONE" "$TASKS_FILE" 2>/dev/null | grep -c "Assigned.*: $agent" 2>/dev/null || true)
        passed=$((passed + ${done_count:-0}))
        # Count VERIFIED tasks by agent
        local verified_count=$(grep -B5 "Status.*VERIFIED" "$TASKS_FILE" 2>/dev/null | grep -c "Assigned.*: $agent" 2>/dev/null || true)
        passed=$((passed + ${verified_count:-0}))
        # Count FAILED tasks by agent
        local failed_count=$(grep -B5 "Status.*FAILED" "$TASKS_FILE" 2>/dev/null | grep -c "Assigned.*: $agent" 2>/dev/null || true)
        failed=$((failed + ${failed_count:-0}))
    fi

    # Check archives (using **Assigned**: format with markdown bold)
    for archive in "$ARCHIVE_DIR"/*.md; do
        if [ -f "$archive" ]; then
            # Use word boundaries to avoid matching developer when looking for developer2
            local archive_verified=$(grep -B5 "Status.*VERIFIED" "$archive" 2>/dev/null | grep -cE "Assigned.*: ${agent}\$" 2>/dev/null || true)
            passed=$((passed + ${archive_verified:-0}))
            # Count reworks - tasks with "FIX REQUIRED" or multiple test rounds
            local archive_rework=$(grep -B10 -E "Assigned.*: ${agent}\$" "$archive" 2>/dev/null | grep -c "FIX REQUIRED\|Re-tested\|Bug Fix" 2>/dev/null || true)
            rework=$((rework + ${archive_rework:-0}))
        fi
    done

    total=$((passed + failed))
    echo "$passed $failed $total $rework"
}

# Analyze git commits for code quality signals
analyze_git_quality() {
    local agent="$1"
    local days="${2:-7}"

    cd /home/novakj

    # Count commits by agent in last N days
    local commits=$(git log --since="${days} days ago" --oneline --author="" --grep="\[$agent\]" 2>/dev/null | wc -l || echo "0")

    # Average files changed per commit
    local files_changed=$(git log --since="${days} days ago" --shortstat --grep="\[$agent\]" 2>/dev/null | grep "files\? changed" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}' || echo "0")

    # Average lines changed per commit
    local lines_changed=$(git log --since="${days} days ago" --shortstat --grep="\[$agent\]" 2>/dev/null | grep "files\? changed" | awk '{
        ins=0; del=0;
        for(i=1;i<=NF;i++) {
            if($i ~ /insertion/) ins=$(i-1);
            if($i ~ /deletion/) del=$(i-1);
        }
        sum+=ins+del; count++
    } END {if(count>0) print int(sum/count); else print 0}' || echo "0")

    echo "$commits $files_changed $lines_changed"
}

# Count errors from agent logs
count_agent_errors() {
    local agent="$1"
    local log_dir="$LOG_DIR/$agent/logs"

    if [ -d "$log_dir" ]; then
        # Count error patterns in recent logs
        local errors=$(find "$log_dir" -name "*.log" -mtime -7 -exec grep -l "error\|Error\|ERROR\|failed\|Failed\|FAILED" {} \; 2>/dev/null | wc -l || echo "0")
        local total_logs=$(find "$log_dir" -name "*.log" -mtime -7 2>/dev/null | wc -l || echo "1")
        echo "$errors $total_logs"
    else
        echo "0 0"
    fi
}

# Calculate quality score (0-100)
calculate_quality_score() {
    local pass_rate="$1"    # Weight: 40%
    local rework_rate="$2"  # Weight: 25% (lower is better)
    local error_rate="$3"   # Weight: 20% (lower is better)
    local complexity="$4"   # Weight: 15% (moderate is best)

    # Pass rate component (0-40)
    local pass_score=$(echo "scale=2; $pass_rate * 40 / 100" | bc)

    # Rework rate component (0-25, inverse - low rework = high score)
    local rework_score=$(echo "scale=2; (100 - $rework_rate) * 25 / 100" | bc)

    # Error rate component (0-20, inverse)
    local error_score=$(echo "scale=2; (100 - $error_rate) * 20 / 100" | bc)

    # Complexity component (0-15, bell curve - moderate is best)
    # Ideal is 10-50 lines per commit, score decreases for extremes
    if [ "$complexity" -le 0 ]; then
        local complexity_score=7
    elif [ "$complexity" -le 50 ]; then
        local complexity_score=15
    elif [ "$complexity" -le 100 ]; then
        local complexity_score=12
    elif [ "$complexity" -le 200 ]; then
        local complexity_score=8
    else
        local complexity_score=5
    fi

    # Total score
    local total=$(echo "scale=0; ($pass_score + $rework_score + $error_score + $complexity_score) / 1" | bc)

    # Ensure score is in range 0-100
    if [ "$total" -lt 0 ]; then total=0; fi
    if [ "$total" -gt 100 ]; then total=100; fi

    echo "$total"
}

# Get cost data for correlation
get_agent_cost() {
    local agent="$1"
    if [ -f "$COSTS_FILE" ]; then
        jq -r ".by_agent.\"$agent\".estimated_cost_usd // 0" "$COSTS_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Build JSON output
echo "{" > "$OUTPUT_FILE"
echo '  "timestamp": "'"$TIMESTAMP"'",' >> "$OUTPUT_FILE"
echo '  "epoch": '"$EPOCH"',' >> "$OUTPUT_FILE"
echo '  "date": "'"$TODAY"'",' >> "$OUTPUT_FILE"

# Process each agent
echo '  "agents": {' >> "$OUTPUT_FILE"

AGENTS=("developer" "developer2" "idea-maker" "project-manager" "tester" "security")
FIRST_AGENT=true

for agent in "${AGENTS[@]}"; do
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    # Get task metrics
    read passed failed total rework <<< $(get_task_metrics "$agent")
    passed=${passed:-0}
    failed=${failed:-0}
    total=${total:-0}
    rework=${rework:-0}

    # Calculate pass rate
    if [ "$total" -gt 0 ] 2>/dev/null; then
        pass_rate=$(echo "scale=2; $passed * 100 / $total" | bc)
    else
        pass_rate=100
    fi

    # Calculate rework rate
    if [ "$passed" -gt 0 ] 2>/dev/null; then
        rework_rate=$(echo "scale=2; $rework * 100 / $passed" | bc)
    else
        rework_rate=0
    fi

    # Get git metrics
    read commits files_per_commit lines_per_commit <<< $(analyze_git_quality "$agent")
    commits=${commits:-0}
    files_per_commit=${files_per_commit:-0}
    lines_per_commit=${lines_per_commit:-0}

    # Get error metrics
    read error_logs total_logs <<< $(count_agent_errors "$agent")
    error_logs=${error_logs:-0}
    total_logs=${total_logs:-0}
    if [ "$total_logs" -gt 0 ] 2>/dev/null; then
        error_rate=$(echo "scale=2; $error_logs * 100 / $total_logs" | bc)
    else
        error_rate=0
    fi

    # Get cost data
    cost=$(get_agent_cost "$agent")
    cost=${cost:-0}

    # Calculate overall quality score
    quality_score=$(calculate_quality_score "$pass_rate" "$rework_rate" "$error_rate" "$lines_per_commit")
    quality_score=${quality_score:-75}

    # Determine trend (compare to previous day if available)
    prev_score=$(jq -r ".history[-1].agents.\"$agent\".quality_score // $quality_score" "$HISTORY_FILE" 2>/dev/null || echo "$quality_score")
    if [ "$(echo "$quality_score > $prev_score" | bc)" -eq 1 ]; then
        trend="improving"
    elif [ "$(echo "$quality_score < $prev_score" | bc)" -eq 1 ]; then
        trend="declining"
    else
        trend="stable"
    fi

    # Determine if problem child (declining + low score)
    problem_child=false
    if [ "$trend" = "declining" ] && [ "$(echo "$quality_score < 70" | bc)" -eq 1 ]; then
        problem_child=true
    fi

    # Output agent data
    echo -n '    "'"$agent"'": {' >> "$OUTPUT_FILE"
    echo -n '"quality_score": '"$quality_score"',' >> "$OUTPUT_FILE"
    echo -n '"pass_rate": '"$pass_rate"',' >> "$OUTPUT_FILE"
    echo -n '"rework_rate": '"$rework_rate"',' >> "$OUTPUT_FILE"
    echo -n '"error_rate": '"$error_rate"',' >> "$OUTPUT_FILE"
    echo -n '"tasks_passed": '"$passed"',' >> "$OUTPUT_FILE"
    echo -n '"tasks_failed": '"$failed"',' >> "$OUTPUT_FILE"
    echo -n '"tasks_total": '"$total"',' >> "$OUTPUT_FILE"
    echo -n '"rework_count": '"$rework"',' >> "$OUTPUT_FILE"
    echo -n '"commits_7d": '"$commits"',' >> "$OUTPUT_FILE"
    echo -n '"avg_files_per_commit": '"$files_per_commit"',' >> "$OUTPUT_FILE"
    echo -n '"avg_lines_per_commit": '"$lines_per_commit"',' >> "$OUTPUT_FILE"
    echo -n '"error_logs_7d": '"$error_logs"',' >> "$OUTPUT_FILE"
    echo -n '"total_logs_7d": '"$total_logs"',' >> "$OUTPUT_FILE"
    echo -n '"estimated_cost_usd": '"$cost"',' >> "$OUTPUT_FILE"
    echo -n '"trend": "'"$trend"'",' >> "$OUTPUT_FILE"
    echo -n '"problem_child": '"$problem_child"'' >> "$OUTPUT_FILE"
    echo -n "}" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Calculate aggregate metrics
total_passed=0
total_failed=0
total_tasks=0
total_rework=0

for agent in "${AGENTS[@]}"; do
    read passed failed total rework <<< $(get_task_metrics "$agent")
    total_passed=$((total_passed + passed))
    total_failed=$((total_failed + failed))
    total_tasks=$((total_tasks + total))
    total_rework=$((total_rework + rework))
done

if [ "$total_tasks" -gt 0 ]; then
    overall_pass_rate=$(echo "scale=2; $total_passed * 100 / $total_tasks" | bc)
else
    overall_pass_rate=100
fi

if [ "$total_passed" -gt 0 ]; then
    overall_rework_rate=$(echo "scale=2; $total_rework * 100 / $total_passed" | bc)
    first_time_pass_rate=$(echo "scale=2; ($total_passed - $total_rework) * 100 / $total_passed" | bc)
else
    overall_rework_rate=0
    first_time_pass_rate=100
fi

# Overall system quality score (average of all agents)
system_score=$(jq -r '[.agents[].quality_score] | add / length | floor' "$OUTPUT_FILE" 2>/dev/null || echo "75")

echo '  "summary": {' >> "$OUTPUT_FILE"
echo '    "system_quality_score": '"${system_score:-75}"',' >> "$OUTPUT_FILE"
echo '    "overall_pass_rate": '"$overall_pass_rate"',' >> "$OUTPUT_FILE"
echo '    "overall_rework_rate": '"$overall_rework_rate"',' >> "$OUTPUT_FILE"
echo '    "first_time_pass_rate": '"$first_time_pass_rate"',' >> "$OUTPUT_FILE"
echo '    "total_tasks_passed": '"$total_passed"',' >> "$OUTPUT_FILE"
echo '    "total_tasks_failed": '"$total_failed"',' >> "$OUTPUT_FILE"
echo '    "total_tasks": '"$total_tasks"',' >> "$OUTPUT_FILE"
echo '    "total_rework": '"$total_rework"'' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Leaderboard (sorted by quality score)
echo '  "leaderboard": [' >> "$OUTPUT_FILE"
# Use jq to sort and format leaderboard
if command -v jq &> /dev/null; then
    # Extract agents and sort by quality_score
    leaderboard=$(cat "$OUTPUT_FILE" | jq -r '.agents | to_entries | sort_by(-.value.quality_score) | .[:6] | to_entries | map({rank: (.key + 1), agent: .value.key, quality_score: .value.value.quality_score, pass_rate: .value.value.pass_rate, trend: .value.value.trend})' 2>/dev/null || echo "[]")
    echo "$leaderboard" | jq -c '.[]' 2>/dev/null | while read -r entry; do
        rank=$(echo "$entry" | jq -r '.rank')
        agent=$(echo "$entry" | jq -r '.agent')
        score=$(echo "$entry" | jq -r '.quality_score')
        pass=$(echo "$entry" | jq -r '.pass_rate')
        trend=$(echo "$entry" | jq -r '.trend')

        if [ "$rank" -gt 1 ]; then echo "," >> "$OUTPUT_FILE"; fi
        echo -n '    {"rank": '"$rank"', "agent": "'"$agent"'", "quality_score": '"$score"', "pass_rate": '"$pass"', "trend": "'"$trend"'"}' >> "$OUTPUT_FILE"
    done
fi
echo "" >> "$OUTPUT_FILE"
echo '  ],' >> "$OUTPUT_FILE"

# Problem children (agents with declining quality)
echo '  "problem_children": [' >> "$OUTPUT_FILE"
FIRST=true
for agent in "${AGENTS[@]}"; do
    is_problem=$(jq -r ".agents.\"$agent\".problem_child" "$OUTPUT_FILE" 2>/dev/null || echo "false")
    if [ "$is_problem" = "true" ]; then
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi
        score=$(jq -r ".agents.\"$agent\".quality_score" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo -n '    {"agent": "'"$agent"'", "quality_score": '"$score"', "recommendation": "Review prompt and recent failures"}' >> "$OUTPUT_FILE"
    fi
done
echo "" >> "$OUTPUT_FILE"
echo '  ],' >> "$OUTPUT_FILE"

# Quality trend (daily history)
echo '  "daily_trend": [' >> "$OUTPUT_FILE"
# Get last 7 days from history
if [ -f "$HISTORY_FILE" ]; then
    jq -r '.history[-7:] | .[] | @json' "$HISTORY_FILE" 2>/dev/null | while read -r entry; do
        date=$(echo "$entry" | jq -r '.date')
        score=$(echo "$entry" | jq -r '.system_score')
        pass=$(echo "$entry" | jq -r '.pass_rate')
        echo '    {"date": "'"$date"'", "system_score": '"${score:-75}"', "pass_rate": '"${pass:-100}"'},'
    done >> "$OUTPUT_FILE"
fi
# Add today's entry
echo '    {"date": "'"$TODAY"'", "system_score": '"${system_score:-75}"', "pass_rate": '"$overall_pass_rate"'}' >> "$OUTPUT_FILE"
echo '  ]' >> "$OUTPUT_FILE"

echo "}" >> "$OUTPUT_FILE"

# Update history file
TODAY_ENTRY=$(jq -n \
    --arg date "$TODAY" \
    --argjson score "${system_score:-75}" \
    --argjson pass "$overall_pass_rate" \
    '{date: $date, system_score: $score, pass_rate: $pass}')

# Check if today's entry exists, update or append
if jq -e ".history[-1].date == \"$TODAY\"" "$HISTORY_FILE" >/dev/null 2>&1; then
    # Update existing entry
    jq ".history[-1] = $TODAY_ENTRY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
else
    # Append new entry
    jq ".history += [$TODAY_ENTRY]" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
fi

# Keep only last 30 days of history
jq '.history = .history[-30:]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

echo "Quality metrics updated: $OUTPUT_FILE"
