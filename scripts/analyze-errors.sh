#!/bin/bash
# analyze-errors.sh - Analyzes agent logs for error patterns
# Output: JSON data for the error-patterns.html dashboard

set -e

LOG_DIR="/home/novakj/actors"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/error-patterns.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

# Define error patterns to search for
declare -A ERROR_PATTERNS
ERROR_PATTERNS=(
    ["timeout"]="timeout|timed out"
    ["permission_denied"]="permission denied|access denied|forbidden"
    ["file_not_found"]="file not found|no such file|not found"
    ["connection_error"]="connection refused|connection reset|connection failed|network error"
    ["syntax_error"]="syntax error|parse error|invalid syntax"
    ["memory_error"]="out of memory|memory allocation|segmentation fault"
    ["test_failed"]="FAILED|FAIL\]|\[FAIL|failed verification|test.*fail"
    ["missing_integration"]="missing.*integration|not linked|cannot discover|not accessible"
    ["general_error"]="error:|ERROR|exception"
)

# Initialize JSON structure
echo "{" > "$OUTPUT_FILE"
echo '  "timestamp": "'"$TIMESTAMP"'",' >> "$OUTPUT_FILE"
echo '  "epoch": '"$EPOCH"',' >> "$OUTPUT_FILE"

# Collect all log files
ALL_LOGS=$(find "$LOG_DIR"/*/logs -name "*.log" -type f 2>/dev/null | sort)
TOTAL_LOGS=$(echo "$ALL_LOGS" | wc -l)

echo '  "total_logs_scanned": '"$TOTAL_LOGS"',' >> "$OUTPUT_FILE"

# Count errors by pattern
echo '  "patterns": {' >> "$OUTPUT_FILE"
FIRST_PATTERN=true

for pattern_name in "${!ERROR_PATTERNS[@]}"; do
    regex="${ERROR_PATTERNS[$pattern_name]}"

    # Count total occurrences
    COUNT=$(grep -riEc "$regex" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')

    # Get affected files count
    FILES=$(grep -rlE -i "$regex" $LOG_DIR/*/logs/*.log 2>/dev/null | wc -l)

    # Get most recent occurrence
    RECENT_FILE=""
    RECENT_MATCH=""
    if [ "$COUNT" -gt 0 ]; then
        RECENT_FILE=$(grep -rlE -i "$regex" $LOG_DIR/*/logs/*.log 2>/dev/null | sort -r | head -1)
        if [ -n "$RECENT_FILE" ]; then
            RECENT_MATCH=$(grep -iE "$regex" "$RECENT_FILE" 2>/dev/null | head -1 | sed 's/"/\\"/g' | cut -c1-200)
        fi
    fi

    if [ "$FIRST_PATTERN" = true ]; then
        FIRST_PATTERN=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi

    echo -n '    "'"$pattern_name"'": {"count": '"$COUNT"', "files_affected": '"$FILES"', "last_match": "'"$RECENT_MATCH"'"' >> "$OUTPUT_FILE"
    if [ -n "$RECENT_FILE" ]; then
        FILENAME=$(basename "$RECENT_FILE")
        AGENT=$(echo "$RECENT_FILE" | sed 's|.*/actors/||' | cut -d'/' -f1)
        echo -n ', "last_file": "'"$FILENAME"'", "last_agent": "'"$AGENT"'"' >> "$OUTPUT_FILE"
    fi
    echo -n '}' >> "$OUTPUT_FILE"
done

echo '' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Errors by agent
echo '  "by_agent": {' >> "$OUTPUT_FILE"
FIRST_AGENT=true

for agent_dir in "$LOG_DIR"/*/; do
    agent=$(basename "$agent_dir")
    if [ -d "$agent_dir/logs" ]; then
        ERROR_COUNT=0
        for pattern_name in "${!ERROR_PATTERNS[@]}"; do
            regex="${ERROR_PATTERNS[$pattern_name]}"
            C=$(grep -riEc "$regex" "$agent_dir"/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
            ERROR_COUNT=$((ERROR_COUNT + C))
        done

        LOG_COUNT=$(find "$agent_dir/logs" -name "*.log" -type f 2>/dev/null | wc -l)

        if [ "$FIRST_AGENT" = true ]; then
            FIRST_AGENT=false
        else
            echo ',' >> "$OUTPUT_FILE"
        fi

        echo -n '    "'"$agent"'": {"error_count": '"$ERROR_COUNT"', "log_count": '"$LOG_COUNT"'}' >> "$OUTPUT_FILE"
    fi
done

echo '' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Recent errors (last 20)
echo '  "recent_errors": [' >> "$OUTPUT_FILE"

# Collect recent errors with timestamps
RECENT_ERRORS=$(
    for log_file in $(find "$LOG_DIR"/*/logs -name "*.log" -type f -mtime -7 2>/dev/null | sort -r | head -100); do
        agent=$(echo "$log_file" | sed 's|.*/actors/||' | cut -d'/' -f1)
        filename=$(basename "$log_file")
        # Extract date from filename (format: YYYYMMDD_HHMMSS.log)
        log_date=$(echo "$filename" | sed 's/\.log$//' | sed 's/_/T/' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)T\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3T\4:\5:\6Z/')

        for pattern_name in "${!ERROR_PATTERNS[@]}"; do
            regex="${ERROR_PATTERNS[$pattern_name]}"
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # Escape and truncate the line
                    escaped_line=$(echo "$line" | sed 's/"/\\"/g' | cut -c1-200)
                    echo "$log_date|$agent|$pattern_name|$escaped_line|$filename"
                fi
            done < <(grep -iE "$regex" "$log_file" 2>/dev/null | head -3)
        done
    done | sort -t'|' -k1 -r | head -20
)

FIRST_ERROR=true
while IFS='|' read -r date agent pattern message file; do
    if [ -n "$date" ]; then
        if [ "$FIRST_ERROR" = true ]; then
            FIRST_ERROR=false
        else
            echo ',' >> "$OUTPUT_FILE"
        fi
        echo -n '    {"timestamp": "'"$date"'", "agent": "'"$agent"'", "pattern": "'"$pattern"'", "message": "'"$message"'", "file": "'"$file"'"}' >> "$OUTPUT_FILE"
    fi
done <<< "$RECENT_ERRORS"

echo '' >> "$OUTPUT_FILE"
echo '  ],' >> "$OUTPUT_FILE"

# Daily error trend (last 7 days)
echo '  "daily_trend": [' >> "$OUTPUT_FILE"
FIRST_DAY=true

for i in {6..0}; do
    day=$(date -d "$i days ago" +%Y%m%d)
    day_display=$(date -d "$i days ago" +%Y-%m-%d)

    DAY_ERRORS=0
    for pattern_name in "${!ERROR_PATTERNS[@]}"; do
        regex="${ERROR_PATTERNS[$pattern_name]}"
        C=$(grep -riEc "$regex" "$LOG_DIR"/*/logs/"$day"*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
        DAY_ERRORS=$((DAY_ERRORS + C))
    done

    if [ "$FIRST_DAY" = true ]; then
        FIRST_DAY=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi

    echo -n '    {"date": "'"$day_display"'", "count": '"$DAY_ERRORS"'}' >> "$OUTPUT_FILE"
done

echo '' >> "$OUTPUT_FILE"
echo '  ],' >> "$OUTPUT_FILE"

# Calculate overall health score (0-100, higher is better)
TOTAL_ERRORS=0
for pattern_name in "${!ERROR_PATTERNS[@]}"; do
    regex="${ERROR_PATTERNS[$pattern_name]}"
    C=$(grep -riEc "$regex" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
    TOTAL_ERRORS=$((TOTAL_ERRORS + C))
done

# Calculate score based on error density
if [ "$TOTAL_LOGS" -gt 0 ]; then
    ERROR_RATIO=$((TOTAL_ERRORS * 100 / TOTAL_LOGS))
    if [ "$ERROR_RATIO" -eq 0 ]; then
        HEALTH_SCORE=100
    elif [ "$ERROR_RATIO" -lt 10 ]; then
        HEALTH_SCORE=90
    elif [ "$ERROR_RATIO" -lt 25 ]; then
        HEALTH_SCORE=70
    elif [ "$ERROR_RATIO" -lt 50 ]; then
        HEALTH_SCORE=50
    else
        HEALTH_SCORE=30
    fi
else
    HEALTH_SCORE=100
fi

echo '  "summary": {' >> "$OUTPUT_FILE"
echo '    "total_errors": '"$TOTAL_ERRORS"',' >> "$OUTPUT_FILE"
echo '    "total_logs": '"$TOTAL_LOGS"',' >> "$OUTPUT_FILE"
echo '    "health_score": '"$HEALTH_SCORE"',' >> "$OUTPUT_FILE"

# Determine status
if [ "$HEALTH_SCORE" -ge 80 ]; then
    STATUS="healthy"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    STATUS="warning"
else
    STATUS="critical"
fi

echo '    "status": "'"$STATUS"'"' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Generate recommendations based on patterns
echo '  "recommendations": [' >> "$OUTPUT_FILE"
FIRST_REC=true

# Check for test failures
TEST_FAILURES=$(grep -riEc "FAILED|failed verification" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
if [ "$TEST_FAILURES" -gt 0 ]; then
    if [ "$FIRST_REC" = true ]; then FIRST_REC=false; else echo ',' >> "$OUTPUT_FILE"; fi
    echo -n '    {"severity": "high", "title": "Test Failures Detected", "description": "'"$TEST_FAILURES"' test failures found. Review failed tests and fix issues before they impact production."}' >> "$OUTPUT_FILE"
fi

# Check for missing integration issues
MISSING_INTEGRATION=$(grep -riEc "missing.*integration|not linked|cannot discover" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
if [ "$MISSING_INTEGRATION" -gt 0 ]; then
    if [ "$FIRST_REC" = true ]; then FIRST_REC=false; else echo ',' >> "$OUTPUT_FILE"; fi
    echo -n '    {"severity": "medium", "title": "Dashboard Integration Issues", "description": "'"$MISSING_INTEGRATION"' cases of missing dashboard integration. Ensure all features are discoverable through the web UI."}' >> "$OUTPUT_FILE"
fi

# Check for permission errors
PERM_ERRORS=$(grep -riEc "permission denied|access denied" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
if [ "$PERM_ERRORS" -gt 0 ]; then
    if [ "$FIRST_REC" = true ]; then FIRST_REC=false; else echo ',' >> "$OUTPUT_FILE"; fi
    echo -n '    {"severity": "high", "title": "Permission Issues", "description": "'"$PERM_ERRORS"' permission denied errors. Check file ownership and permissions in the system."}' >> "$OUTPUT_FILE"
fi

# Check for connection errors
CONN_ERRORS=$(grep -riEc "connection refused|connection reset|connection failed" $LOG_DIR/*/logs/*.log 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
if [ "$CONN_ERRORS" -gt 0 ]; then
    if [ "$FIRST_REC" = true ]; then FIRST_REC=false; else echo ',' >> "$OUTPUT_FILE"; fi
    echo -n '    {"severity": "medium", "title": "Connection Issues", "description": "'"$CONN_ERRORS"' connection errors detected. Verify network connectivity and service availability."}' >> "$OUTPUT_FILE"
fi

# If no issues, add a positive recommendation
if [ "$FIRST_REC" = true ]; then
    echo -n '    {"severity": "info", "title": "System Healthy", "description": "No significant error patterns detected. Continue monitoring for emerging issues."}' >> "$OUTPUT_FILE"
fi

echo '' >> "$OUTPUT_FILE"
echo '  ]' >> "$OUTPUT_FILE"

echo '}' >> "$OUTPUT_FILE"

echo "Error patterns analysis updated: $OUTPUT_FILE"
