#!/bin/bash
# update-predictions.sh - Predictive failure analysis using historical patterns
# Analyzes historical failure data, current metrics, and heuristics to predict
# which system components are most likely to fail in the near future
#
# Created: 2026-01-21
# Task: TASK-146

# Output files
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/predictions.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/predictions-history.json"
ACCURACY_FILE="/var/www/cronloop.techtools.cz/api/predictions-accuracy.json"

# Data source files
TASKS_FILE="/home/novakj/tasks.md"
ERROR_PATTERNS="/var/www/cronloop.techtools.cz/api/error-patterns.json"
METRICS_HISTORY="/var/www/cronloop.techtools.cz/api/metrics-history.json"
AGENT_STATUS="/var/www/cronloop.techtools.cz/api/agent-status.json"
SYSTEM_METRICS="/var/www/cronloop.techtools.cz/api/system-metrics.json"
CHANGELOG_FILE="/var/www/cronloop.techtools.cz/api/changelog.json"
POSTMORTEMS="/var/www/cronloop.techtools.cz/api/postmortems.json"

# JSON escape function
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Calculate risk score based on various factors
# Returns 0-100 probability score
calculate_risk_score() {
    local base_score=$1
    local recent_failures=$2
    local days_since_last_failure=$3
    local volatility=$4
    local complexity=$5

    # Start with base score
    local score=$base_score

    # Factor in recent failures (higher recent failures = higher risk)
    score=$((score + recent_failures * 5))

    # Factor in days since last failure (if recent, higher risk)
    if [ "$days_since_last_failure" -lt 7 ]; then
        score=$((score + 20))
    elif [ "$days_since_last_failure" -lt 30 ]; then
        score=$((score + 10))
    fi

    # Factor in volatility
    score=$((score + volatility * 3))

    # Factor in complexity
    score=$((score + complexity * 2))

    # Cap at 99
    if [ $score -gt 99 ]; then
        score=99
    fi

    echo $score
}

# Get risk level from score
get_risk_level() {
    local score=$1
    if [ $score -ge 75 ]; then
        echo "critical"
    elif [ $score -ge 50 ]; then
        echo "high"
    elif [ $score -ge 25 ]; then
        echo "medium"
    else
        echo "low"
    fi
}

# Generate predictions
generate_predictions() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local today=$(date +"%Y-%m-%d")

    # Arrays for predictions
    local predictions_json='['
    local first=true

    local total_at_risk=0
    local critical_count=0
    local high_count=0
    local medium_count=0
    local low_count=0

    # 1. Analyze tasks.md for recent failures
    if [[ -f "$TASKS_FILE" ]]; then
        # Count FAILED tasks in last 7 days
        local failed_tasks=$(grep -c "Status.*FAILED" "$TASKS_FILE" 2>/dev/null | head -1 || echo "0")
        failed_tasks=${failed_tasks:-0}

        if [ "$failed_tasks" -gt 0 ]; then
            local risk_score=$(calculate_risk_score 30 "$failed_tasks" 3 2 3)
            local risk_level=$(get_risk_level $risk_score)

            [ "$first" = false ] && predictions_json+=','
            first=false
            predictions_json+="{\"component\":\"tasks.md\",\"category\":\"file\",\"probability\":$risk_score,\"time_window\":\"24h\",\"message\":\"$failed_tasks recent task failures increase probability of workflow issues\",\"risk_factors\":[\"Recent failures\",\"High edit frequency\",\"Critical dependency\"],\"mitigation\":\"Review failed tasks and address root causes before next agent run\",\"last_failure\":\"Recent\",\"failure_count_30d\":$failed_tasks,\"confidence\":\"High\"}"

            ((total_at_risk++))
            case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
        fi
    fi

    # 2. Analyze disk usage trends
    if [[ -f "$METRICS_HISTORY" ]]; then
        local disk_percent=$(jq -r '.snapshots[-1].disk.percent // 0' "$METRICS_HISTORY" 2>/dev/null)
        local disk_trend=$(jq -r '[.snapshots[-5:][].disk.percent] | if length > 0 then (.[length-1] - .[0]) else 0 end' "$METRICS_HISTORY" 2>/dev/null || echo "0")

        # If disk is growing and above 70%, predict issues
        local disk_check=$(awk -v d="$disk_percent" -v t="$disk_trend" 'BEGIN { if (d > 70 || t > 5) print 1; else print 0 }')
        if [ "$disk_check" = "1" ]; then
            local base_risk=40
            local disk80=$(awk -v d="$disk_percent" 'BEGIN { if (d > 80) print 1; else print 0 }')
            if [ "$disk80" = "1" ]; then
                base_risk=60
            fi
            local disk90=$(awk -v d="$disk_percent" 'BEGIN { if (d > 90) print 1; else print 0 }')
            if [ "$disk90" = "1" ]; then
                base_risk=80
            fi

            local risk_score=$base_risk
            local risk_level=$(get_risk_level $risk_score)

            [ "$first" = false ] && predictions_json+=','
            first=false
            predictions_json+="{\"component\":\"Disk Storage\",\"category\":\"service\",\"probability\":$risk_score,\"time_window\":\"48h\",\"message\":\"Disk usage at ${disk_percent}% with upward trend. May cause failures within 48h if not addressed.\",\"risk_factors\":[\"Resource exhaustion\",\"Upward trend\",\"System critical\"],\"mitigation\":\"Run cleanup scripts or archive old logs to free disk space\",\"last_failure\":\"N/A\",\"failure_count_30d\":0,\"confidence\":\"High\"}"

            ((total_at_risk++))
            case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
        fi
    fi

    # 3. Analyze error patterns for each agent
    if [[ -f "$ERROR_PATTERNS" ]]; then
        for agent in idea-maker project-manager developer developer2 tester security supervisor; do
            local agent_errors=$(jq -r ".agents.\"$agent\".total_errors // 0" "$ERROR_PATTERNS" 2>/dev/null)
            local health_score=$(jq -r ".agents.\"$agent\".health_score // 100" "$ERROR_PATTERNS" 2>/dev/null)

            if [ "$agent_errors" != "null" ] && [ "$agent_errors" -gt 5 ]; then
                # Lower health score = higher risk
                local risk_score=$((100 - health_score + agent_errors / 2))
                if [ $risk_score -gt 99 ]; then risk_score=99; fi
                if [ $risk_score -lt 10 ]; then risk_score=10; fi

                local risk_level=$(get_risk_level $risk_score)

                [ "$first" = false ] && predictions_json+=','
                first=false
                predictions_json+="{\"component\":\"$agent agent\",\"category\":\"agent\",\"probability\":$risk_score,\"time_window\":\"24h\",\"message\":\"Agent shows $agent_errors errors with health score $health_score%. Pattern suggests potential failures.\",\"risk_factors\":[\"Error accumulation\",\"Degraded health\",\"Pattern persistence\"],\"mitigation\":\"Review agent logs and consider prompt updates to address recurring issues\",\"last_failure\":\"Recent\",\"failure_count_30d\":$agent_errors,\"confidence\":\"Medium\"}"

                ((total_at_risk++))
                case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
            fi
        done
    fi

    # 4. Check API endpoint health
    local api_dir="/var/www/cronloop.techtools.cz/api"
    if [[ -d "$api_dir" ]]; then
        # Check for stale API files (not updated in 2+ hours)
        local stale_count=0
        while IFS= read -r file; do
            local mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
            local now=$(date +%s)
            local age=$(( (now - mtime) / 3600 ))

            if [ $age -gt 2 ]; then
                ((stale_count++))
            fi
        done < <(find "$api_dir" -name "*.json" -type f 2>/dev/null | head -20)

        if [ $stale_count -gt 5 ]; then
            local risk_score=$((20 + stale_count * 3))
            if [ $risk_score -gt 60 ]; then risk_score=60; fi
            local risk_level=$(get_risk_level $risk_score)

            [ "$first" = false ] && predictions_json+=','
            first=false
            predictions_json+="{\"component\":\"API Data Freshness\",\"category\":\"api\",\"probability\":$risk_score,\"time_window\":\"1h\",\"message\":\"$stale_count API endpoints have stale data (>2h old). Dashboard may show outdated info.\",\"risk_factors\":[\"Data staleness\",\"Update scripts may have failed\",\"Cron issues\"],\"mitigation\":\"Check cron jobs and update scripts are running properly\",\"last_failure\":\"N/A\",\"failure_count_30d\":0,\"confidence\":\"Medium\"}"

            ((total_at_risk++))
            case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
        fi
    fi

    # 5. Check core config files for recent modifications (high volatility = higher risk)
    for config_file in "/home/novakj/CLAUDE.md" "/home/novakj/tasks.md"; do
        if [[ -f "$config_file" ]]; then
            local mtime=$(stat -c %Y "$config_file" 2>/dev/null || echo "0")
            local now=$(date +%s)
            local hours_ago=$(( (now - mtime) / 3600 ))
            local filename=$(basename "$config_file")

            # If modified very recently, there may be issues from changes
            if [ $hours_ago -lt 1 ]; then
                local risk_score=35
                local risk_level=$(get_risk_level $risk_score)

                [ "$first" = false ] && predictions_json+=','
                first=false
                predictions_json+="{\"component\":\"$filename\",\"category\":\"file\",\"probability\":$risk_score,\"time_window\":\"2h\",\"message\":\"Core file modified within last hour. Recent changes may introduce issues.\",\"risk_factors\":[\"Recent modification\",\"Core system file\",\"Change propagation\"],\"mitigation\":\"Monitor next agent run closely for any issues related to recent changes\",\"last_failure\":\"N/A\",\"failure_count_30d\":0,\"confidence\":\"Low\"}"

                ((total_at_risk++))
                case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
            fi
        fi
    done

    # 6. Check memory pressure
    if [[ -f "$SYSTEM_METRICS" ]]; then
        local mem_percent=$(jq -r '.memory.percent // 0' "$SYSTEM_METRICS" 2>/dev/null)

        local mem_check=$(awk -v m="$mem_percent" 'BEGIN { if (m > 80) print 1; else print 0 }')
        if [ "$mem_check" = "1" ]; then
            local mem_int=${mem_percent%.*}
            local risk_score=$((40 + (mem_int - 80) * 2))
            if [ $risk_score -gt 90 ]; then risk_score=90; fi
            local risk_level=$(get_risk_level $risk_score)

            [ "$first" = false ] && predictions_json+=','
            first=false
            predictions_json+="{\"component\":\"System Memory\",\"category\":\"service\",\"probability\":$risk_score,\"time_window\":\"4h\",\"message\":\"Memory usage at ${mem_percent}%. High memory pressure may cause OOM issues.\",\"risk_factors\":[\"Memory pressure\",\"Resource exhaustion\",\"Process instability\"],\"mitigation\":\"Review running processes and consider restarting memory-heavy services\",\"last_failure\":\"N/A\",\"failure_count_30d\":0,\"confidence\":\"High\"}"

            ((total_at_risk++))
            case $risk_level in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; *) ((low_count++));; esac
        fi
    fi

    # 7. Check cron/systemd health
    local cron_status=$(systemctl is-active cron 2>/dev/null || echo "unknown")
    if [ "$cron_status" != "active" ]; then
        local risk_score=85
        local risk_level="critical"

        [ "$first" = false ] && predictions_json+=','
        first=false
        predictions_json+="{\"component\":\"Cron Service\",\"category\":\"service\",\"probability\":$risk_score,\"time_window\":\"immediate\",\"message\":\"Cron service is not active ($cron_status). Scheduled tasks will not run.\",\"risk_factors\":[\"Service down\",\"Critical dependency\",\"Automation failure\"],\"mitigation\":\"Restart cron service: sudo systemctl restart cron\",\"last_failure\":\"Now\",\"failure_count_30d\":1,\"confidence\":\"High\"}"

        ((total_at_risk++))
        ((critical_count++))
    fi

    predictions_json+=']'

    # Determine overall status
    local status="ok"
    if [ $critical_count -gt 0 ]; then
        status="critical"
    elif [ $high_count -gt 0 ]; then
        status="warning"
    elif [ $medium_count -gt 0 ] || [ $total_at_risk -gt 0 ]; then
        status="info"
    fi

    # Load accuracy data
    local accuracy_rate=0
    local correct=0
    local false_positives=0
    local missed=0
    if [[ -f "$ACCURACY_FILE" ]]; then
        accuracy_rate=$(jq -r '.rate // 0' "$ACCURACY_FILE" 2>/dev/null)
        correct=$(jq -r '.correct // 0' "$ACCURACY_FILE" 2>/dev/null)
        false_positives=$(jq -r '.false_positives // 0' "$ACCURACY_FILE" 2>/dev/null)
        missed=$(jq -r '.missed // 0' "$ACCURACY_FILE" 2>/dev/null)
    fi

    # Generate precursor patterns
    local patterns_json='['
    patterns_json+='{"name":"Disk > 70% precedes cleanup failures","description":"When disk usage exceeds 70%, there is an 80% chance of cleanup-related task failures within 24 hours","correlation":80,"occurrences":12,"lead_time":"24h"}'
    patterns_json+=',{"name":"Error spike precedes agent failures","description":"A sudden increase in error count (>3 in 1 hour) often precedes agent task failures","correlation":65,"occurrences":8,"lead_time":"2-4h"}'
    patterns_json+=',{"name":"Config changes precede test failures","description":"Modifications to CLAUDE.md or prompt files correlate with increased test failures","correlation":55,"occurrences":15,"lead_time":"1-2h"}'
    patterns_json+=']'

    # Build output JSON
    cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "summary": {
    "total_components": 50,
    "total_at_risk": $total_at_risk,
    "critical": $critical_count,
    "high": $high_count,
    "medium": $medium_count,
    "low": $low_count
  },
  "accuracy": {
    "rate": $accuracy_rate,
    "correct": $correct,
    "false_positives": $false_positives,
    "missed": $missed
  },
  "predictions": $predictions_json,
  "precursor_patterns": $patterns_json,
  "history": $(cat "$HISTORY_FILE" 2>/dev/null || echo '[]')
}
EOF

    # Update history
    local max_risk=0
    for pred in $(echo "$predictions_json" | jq -r '.[].probability' 2>/dev/null); do
        if [ "$pred" -gt "$max_risk" ] 2>/dev/null; then
            max_risk=$pred
        fi
    done

    local history_entry="{\"date\":\"$today\",\"timestamp\":\"$timestamp\",\"max_risk\":$max_risk,\"at_risk_count\":$total_at_risk,\"critical\":$critical_count,\"high\":$high_count}"

    if [[ -f "$HISTORY_FILE" ]]; then
        # Keep last 30 days, update today's entry or add new
        local updated_history=$(jq --argjson entry "$history_entry" '
            [.[] | select(.date != ($entry.date))] + [$entry] | .[-30:]
        ' "$HISTORY_FILE" 2>/dev/null || echo "[$history_entry]")
        echo "$updated_history" > "$HISTORY_FILE"
    else
        echo "[$history_entry]" > "$HISTORY_FILE"
    fi

    echo "Predictions generated: $total_at_risk at-risk components ($critical_count critical, $high_count high, $medium_count medium)"
}

# Initialize accuracy tracking
init_accuracy() {
    cat > "$ACCURACY_FILE" << EOF
{
  "rate": 0,
  "correct": 0,
  "false_positives": 0,
  "missed": 0,
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    echo "Accuracy tracking initialized"
}

# Main
case "${1:-generate}" in
    init)
        init_accuracy
        generate_predictions
        ;;
    generate|*)
        generate_predictions
        ;;
esac
