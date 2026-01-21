#!/bin/bash
# Analyze log files across the system and report on their sizes and growth rates
# This script creates /api/log-analysis.json for the Log Analysis Dashboard

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/log-analysis.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/log-analysis-history.json"

# Get current timestamp
TIMESTAMP=$(date -Iseconds)
TIMESTAMP_EPOCH=$(date +%s)

echo "Analyzing log files across the system..."

# Directories to scan for logs
LOG_DIRS=(
    "/var/log"
    "/home/novakj/logs"
    "/home/novakj/actors/idea-maker/logs"
    "/home/novakj/actors/project-manager/logs"
    "/home/novakj/actors/developer/logs"
    "/home/novakj/actors/developer2/logs"
    "/home/novakj/actors/tester/logs"
    "/home/novakj/actors/security/logs"
    "/home/novakj/actors/supervisor/logs"
)

# Arrays to hold log file data
declare -a LOG_FILES_JSON
TOTAL_SIZE=0
TOTAL_COUNT=0
LARGE_COUNT=0
OLD_COUNT=0
UNROTATED_COUNT=0

# Size thresholds
LARGE_THRESHOLD=$((10 * 1024 * 1024))  # 10 MB
UNROTATED_THRESHOLD=$((100 * 1024 * 1024))  # 100 MB

# Build JSON for each log file
process_log_file() {
    local filepath="$1"
    local size
    local mtime_epoch
    local age_days
    local category
    local basename_file

    # Skip if not a regular file
    [[ ! -f "$filepath" ]] && return

    # Get file size
    size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
    [[ $size -eq 0 ]] && return

    # Get modification time
    mtime_epoch=$(stat -c%Y "$filepath" 2>/dev/null || echo 0)
    age_days=$(( (TIMESTAMP_EPOCH - mtime_epoch) / 86400 ))

    # Determine category based on path
    if [[ "$filepath" == /var/log/* ]]; then
        category="system"
    elif [[ "$filepath" == */actors/*/logs/* ]]; then
        category="agent"
    elif [[ "$filepath" == /home/*/logs/* ]]; then
        category="application"
    else
        category="other"
    fi

    # Get basename
    basename_file=$(basename "$filepath")

    # Determine severity
    local severity="info"
    if [[ $size -gt $UNROTATED_THRESHOLD ]]; then
        severity="critical"
        ((UNROTATED_COUNT++))
    elif [[ $size -gt $LARGE_THRESHOLD ]]; then
        severity="warning"
        ((LARGE_COUNT++))
    fi

    # Check if file is old (no updates in 7+ days)
    if [[ $age_days -gt 7 ]]; then
        ((OLD_COUNT++))
    fi

    # Add to totals
    TOTAL_SIZE=$((TOTAL_SIZE + size))
    ((TOTAL_COUNT++))

    # Escape filepath for JSON
    local filepath_escaped
    filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')

    # Add to array
    LOG_FILES_JSON+=("{\"path\":\"$filepath_escaped\",\"name\":\"$basename_file\",\"size\":$size,\"category\":\"$category\",\"modifiedEpoch\":$mtime_epoch,\"ageDays\":$age_days,\"severity\":\"$severity\"}")
}

# Scan each directory
for dir in "${LOG_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        # Find log files (common log extensions and patterns)
        while IFS= read -r -d '' file; do
            process_log_file "$file"
        done < <(find "$dir" -maxdepth 2 -type f \( -name "*.log" -o -name "*.log.*" -o -name "syslog" -o -name "syslog.*" -o -name "messages" -o -name "auth.log" -o -name "auth.log.*" -o -name "kern.log" -o -name "*.err" -o -name "error.log" -o -name "access.log" -o -name "*.out" \) -print0 2>/dev/null)
    fi
done

# Sort by size (descending) and take top 50
# We need to sort the JSON objects by size
IFS=$'\n' SORTED_FILES=($(for f in "${LOG_FILES_JSON[@]}"; do echo "$f"; done | while read -r line; do
    size=$(echo "$line" | grep -o '"size":[0-9]*' | cut -d: -f2)
    echo "$size|$line"
done | sort -t'|' -k1 -nr | head -50 | cut -d'|' -f2-))
unset IFS

# Build top files JSON array
TOP_FILES_JSON="["
FIRST=true
for f in "${SORTED_FILES[@]}"; do
    [[ -z "$f" ]] && continue
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        TOP_FILES_JSON+=","
    fi
    TOP_FILES_JSON+="$f"
done
TOP_FILES_JSON+="]"

# Calculate category breakdown
SYSTEM_SIZE=0
AGENT_SIZE=0
APP_SIZE=0
OTHER_SIZE=0
SYSTEM_COUNT=0
AGENT_COUNT=0
APP_COUNT=0
OTHER_COUNT=0

for f in "${LOG_FILES_JSON[@]}"; do
    size=$(echo "$f" | grep -o '"size":[0-9]*' | cut -d: -f2)
    category=$(echo "$f" | grep -o '"category":"[^"]*"' | cut -d'"' -f4)

    case "$category" in
        "system")
            SYSTEM_SIZE=$((SYSTEM_SIZE + size))
            ((SYSTEM_COUNT++))
            ;;
        "agent")
            AGENT_SIZE=$((AGENT_SIZE + size))
            ((AGENT_COUNT++))
            ;;
        "application")
            APP_SIZE=$((APP_SIZE + size))
            ((APP_COUNT++))
            ;;
        *)
            OTHER_SIZE=$((OTHER_SIZE + size))
            ((OTHER_COUNT++))
            ;;
    esac
done

# Calculate growth rate from history
GROWTH_RATE=0
GROWTH_PERCENT=0
if [[ -f "$HISTORY_FILE" ]]; then
    # Get size from 24 hours ago
    YESTERDAY_EPOCH=$((TIMESTAMP_EPOCH - 86400))
    PREV_SIZE=$(jq -r --argjson target "$YESTERDAY_EPOCH" '.history | map(select(.timestamp_epoch < $target)) | last | .total_size // 0' "$HISTORY_FILE" 2>/dev/null || echo 0)

    if [[ $PREV_SIZE -gt 0 ]]; then
        GROWTH_RATE=$((TOTAL_SIZE - PREV_SIZE))
        GROWTH_PERCENT=$(echo "scale=2; ($GROWTH_RATE * 100) / $PREV_SIZE" | bc 2>/dev/null || echo 0)
    fi
fi

# Determine overall status
OVERALL_STATUS="healthy"
if [[ $UNROTATED_COUNT -gt 0 ]]; then
    OVERALL_STATUS="critical"
elif [[ $LARGE_COUNT -gt 5 ]]; then
    OVERALL_STATUS="warning"
fi

# Calculate health score
HEALTH_SCORE=100
[[ $UNROTATED_COUNT -gt 0 ]] && HEALTH_SCORE=$((HEALTH_SCORE - UNROTATED_COUNT * 20))
[[ $LARGE_COUNT -gt 0 ]] && HEALTH_SCORE=$((HEALTH_SCORE - LARGE_COUNT * 5))
[[ $HEALTH_SCORE -lt 0 ]] && HEALTH_SCORE=0

# Generate recommendations
RECOMMENDATIONS_JSON="["
FIRST_REC=true

add_recommendation() {
    local priority="$1"
    local title="$2"
    local desc="$3"

    if [[ "$FIRST_REC" == "true" ]]; then
        FIRST_REC=false
    else
        RECOMMENDATIONS_JSON+=","
    fi
    RECOMMENDATIONS_JSON+="{\"priority\":\"$priority\",\"title\":\"$title\",\"description\":\"$desc\"}"
}

if [[ $UNROTATED_COUNT -gt 0 ]]; then
    add_recommendation "high" "Configure Log Rotation" "$UNROTATED_COUNT files exceed 100MB. Configure logrotate for these files."
fi

if [[ $LARGE_COUNT -gt 5 ]]; then
    add_recommendation "medium" "Review Large Logs" "$LARGE_COUNT files exceed 10MB. Consider compression or cleanup."
fi

if [[ $OLD_COUNT -gt 10 ]]; then
    add_recommendation "low" "Archive Old Logs" "$OLD_COUNT log files haven't been updated in 7+ days. Consider archiving."
fi

if [[ $GROWTH_RATE -gt $((100 * 1024 * 1024)) ]]; then
    add_recommendation "high" "Rapid Growth Detected" "Log files grew by $(numfmt --to=iec $GROWTH_RATE) in 24 hours. Investigate cause."
fi

RECOMMENDATIONS_JSON+="]"

# Build final JSON output
cat > "$OUTPUT_FILE" << EOF
{
    "generated": "$TIMESTAMP",
    "summary": {
        "total_size": $TOTAL_SIZE,
        "total_count": $TOTAL_COUNT,
        "large_count": $LARGE_COUNT,
        "unrotated_count": $UNROTATED_COUNT,
        "old_count": $OLD_COUNT,
        "growth_rate_24h": $GROWTH_RATE,
        "growth_percent_24h": $GROWTH_PERCENT,
        "health_score": $HEALTH_SCORE,
        "status": "$OVERALL_STATUS"
    },
    "categories": {
        "system": {"size": $SYSTEM_SIZE, "count": $SYSTEM_COUNT},
        "agent": {"size": $AGENT_SIZE, "count": $AGENT_COUNT},
        "application": {"size": $APP_SIZE, "count": $APP_COUNT},
        "other": {"size": $OTHER_SIZE, "count": $OTHER_COUNT}
    },
    "files": $TOP_FILES_JSON,
    "recommendations": $RECOMMENDATIONS_JSON
}
EOF

# Update history file
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"history":[]}' > "$HISTORY_FILE"
fi

# Add current data point to history (keep last 168 entries = 7 days at hourly updates)
jq --argjson ts "$TIMESTAMP_EPOCH" \
   --argjson size "$TOTAL_SIZE" \
   --argjson count "$TOTAL_COUNT" \
   '.history = ([{timestamp_epoch: $ts, total_size: $size, total_count: $count}] + .history) | .history = .history[:168]' \
   "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

echo "Log analysis complete: $OUTPUT_FILE"
echo "Total: $(numfmt --to=iec $TOTAL_SIZE) across $TOTAL_COUNT files"
echo "Health Score: $HEALTH_SCORE ($OVERALL_STATUS)"
