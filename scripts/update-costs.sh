#!/bin/bash
# update-costs.sh - Tracks and analyzes Claude API token consumption and costs
# Output: JSON data for the costs.html dashboard

set -e

CLAUDE_STATS="/home/novakj/.claude/stats-cache.json"
LOG_DIR="/home/novakj/actors"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/costs-history.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Claude Opus 4.5 pricing (per million tokens)
INPUT_PRICE=15.00      # $15 per 1M input tokens
OUTPUT_PRICE=75.00     # $75 per 1M output tokens
CACHE_READ_PRICE=1.50  # $1.50 per 1M cache read tokens
CACHE_WRITE_PRICE=18.75 # $18.75 per 1M cache write tokens

# Initialize output
echo "{" > "$OUTPUT_FILE"
echo '  "timestamp": "'"$TIMESTAMP"'",' >> "$OUTPUT_FILE"
echo '  "epoch": '"$EPOCH"',' >> "$OUTPUT_FILE"
echo '  "date": "'"$TODAY"'",' >> "$OUTPUT_FILE"

# Read Claude stats if available
if [ -f "$CLAUDE_STATS" ]; then
    INPUT_TOKENS=$(jq -r '.modelUsage["claude-opus-4-5-20251101"].inputTokens // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    OUTPUT_TOKENS=$(jq -r '.modelUsage["claude-opus-4-5-20251101"].outputTokens // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    CACHE_READ=$(jq -r '.modelUsage["claude-opus-4-5-20251101"].cacheReadInputTokens // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    CACHE_WRITE=$(jq -r '.modelUsage["claude-opus-4-5-20251101"].cacheCreationInputTokens // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    TOTAL_SESSIONS=$(jq -r '.totalSessions // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    TOTAL_MESSAGES=$(jq -r '.totalMessages // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
    DAILY_TOKENS=$(jq -r '.dailyModelTokens[0].tokensByModel["claude-opus-4-5-20251101"] // 0' "$CLAUDE_STATS" 2>/dev/null || echo "0")
else
    INPUT_TOKENS=0
    OUTPUT_TOKENS=0
    CACHE_READ=0
    CACHE_WRITE=0
    TOTAL_SESSIONS=0
    TOTAL_MESSAGES=0
    DAILY_TOKENS=0
fi

# Calculate costs (in USD)
# Note: Use printf to ensure leading zeros (bc outputs .xxx for values <1)
INPUT_COST_RAW=$(echo "scale=6; $INPUT_TOKENS * $INPUT_PRICE / 1000000" | bc)
INPUT_COST=$(printf "%.6f" "$INPUT_COST_RAW" 2>/dev/null || echo "0.000000")
OUTPUT_COST_RAW=$(echo "scale=6; $OUTPUT_TOKENS * $OUTPUT_PRICE / 1000000" | bc)
OUTPUT_COST=$(printf "%.6f" "$OUTPUT_COST_RAW" 2>/dev/null || echo "0.000000")
CACHE_READ_COST_RAW=$(echo "scale=6; $CACHE_READ * $CACHE_READ_PRICE / 1000000" | bc)
CACHE_READ_COST=$(printf "%.6f" "$CACHE_READ_COST_RAW" 2>/dev/null || echo "0.000000")
CACHE_WRITE_COST_RAW=$(echo "scale=6; $CACHE_WRITE * $CACHE_WRITE_PRICE / 1000000" | bc)
CACHE_WRITE_COST=$(printf "%.6f" "$CACHE_WRITE_COST_RAW" 2>/dev/null || echo "0.000000")
TOTAL_COST_RAW=$(echo "scale=6; $INPUT_COST + $OUTPUT_COST + $CACHE_READ_COST + $CACHE_WRITE_COST" | bc)
TOTAL_COST=$(printf "%.6f" "$TOTAL_COST_RAW" 2>/dev/null || echo "0.000000")

# Output aggregate stats
echo '  "aggregate": {' >> "$OUTPUT_FILE"
echo '    "input_tokens": '"$INPUT_TOKENS"',' >> "$OUTPUT_FILE"
echo '    "output_tokens": '"$OUTPUT_TOKENS"',' >> "$OUTPUT_FILE"
echo '    "cache_read_tokens": '"$CACHE_READ"',' >> "$OUTPUT_FILE"
echo '    "cache_write_tokens": '"$CACHE_WRITE"',' >> "$OUTPUT_FILE"
echo '    "total_tokens": '"$(echo "$INPUT_TOKENS + $OUTPUT_TOKENS" | bc)"',' >> "$OUTPUT_FILE"
echo '    "input_cost_usd": '"$INPUT_COST"',' >> "$OUTPUT_FILE"
echo '    "output_cost_usd": '"$OUTPUT_COST"',' >> "$OUTPUT_FILE"
echo '    "cache_read_cost_usd": '"$CACHE_READ_COST"',' >> "$OUTPUT_FILE"
echo '    "cache_write_cost_usd": '"$CACHE_WRITE_COST"',' >> "$OUTPUT_FILE"
echo '    "total_cost_usd": '"$TOTAL_COST"',' >> "$OUTPUT_FILE"
echo '    "total_sessions": '"$TOTAL_SESSIONS"',' >> "$OUTPUT_FILE"
echo '    "total_messages": '"$TOTAL_MESSAGES"',' >> "$OUTPUT_FILE"
echo '    "daily_tokens": '"$DAILY_TOKENS"'' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Pricing info
echo '  "pricing": {' >> "$OUTPUT_FILE"
echo '    "model": "claude-opus-4-5-20251101",' >> "$OUTPUT_FILE"
echo '    "input_per_million": '"$INPUT_PRICE"',' >> "$OUTPUT_FILE"
echo '    "output_per_million": '"$OUTPUT_PRICE"',' >> "$OUTPUT_FILE"
echo '    "cache_read_per_million": '"$CACHE_READ_PRICE"',' >> "$OUTPUT_FILE"
echo '    "cache_write_per_million": '"$CACHE_WRITE_PRICE"'' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Estimate per-agent usage based on run counts and log sizes
echo '  "by_agent": {' >> "$OUTPUT_FILE"
FIRST_AGENT=true
TOTAL_RUNS=0
TOTAL_LOG_SIZE=0

# First pass: count total runs and log sizes
for agent_dir in "$LOG_DIR"/*/; do
    agent=$(basename "$agent_dir")
    if [ -d "$agent_dir/logs" ]; then
        RUN_COUNT=$(find "$agent_dir/logs" -name "*.log" -type f 2>/dev/null | wc -l)
        LOG_SIZE=$(du -sb "$agent_dir/logs" 2>/dev/null | cut -f1 || echo "0")
        TOTAL_RUNS=$((TOTAL_RUNS + RUN_COUNT))
        TOTAL_LOG_SIZE=$((TOTAL_LOG_SIZE + LOG_SIZE))
    fi
done

# Second pass: calculate per-agent estimates
for agent_dir in "$LOG_DIR"/*/; do
    agent=$(basename "$agent_dir")
    if [ -d "$agent_dir/logs" ]; then
        RUN_COUNT=$(find "$agent_dir/logs" -name "*.log" -type f 2>/dev/null | wc -l)
        LOG_SIZE=$(du -sb "$agent_dir/logs" 2>/dev/null | cut -f1 || echo "0")

        # Get recent log info
        RECENT_LOG=$(find "$agent_dir/logs" -name "*.log" -type f 2>/dev/null | sort -r | head -1)
        RECENT_DATE=""
        RECENT_SIZE=0
        if [ -n "$RECENT_LOG" ] && [ -f "$RECENT_LOG" ]; then
            RECENT_DATE=$(stat -c %Y "$RECENT_LOG" 2>/dev/null | xargs -I{} date -d @{} -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            RECENT_SIZE=$(stat -c %s "$RECENT_LOG" 2>/dev/null || echo "0")
        fi

        # Estimate tokens and cost based on proportional share
        if [ "$TOTAL_RUNS" -gt 0 ]; then
            # Weight by both run count and log size for better estimation
            RUN_WEIGHT=$(echo "scale=6; $RUN_COUNT / $TOTAL_RUNS" | bc)
            if [ "$TOTAL_LOG_SIZE" -gt 0 ]; then
                SIZE_WEIGHT=$(echo "scale=6; $LOG_SIZE / $TOTAL_LOG_SIZE" | bc)
                # Average of run weight and size weight
                WEIGHT=$(echo "scale=6; ($RUN_WEIGHT + $SIZE_WEIGHT) / 2" | bc)
            else
                WEIGHT=$RUN_WEIGHT
            fi

            EST_INPUT=$(echo "scale=0; $INPUT_TOKENS * $WEIGHT / 1" | bc)
            EST_OUTPUT=$(echo "scale=0; $OUTPUT_TOKENS * $WEIGHT / 1" | bc)
            EST_COST_RAW=$(echo "scale=6; $TOTAL_COST * $WEIGHT" | bc)
            EST_COST=$(printf "%.6f" "$EST_COST_RAW" 2>/dev/null || echo "0.000000")
            AVG_TOKENS=$(echo "scale=0; ($EST_INPUT + $EST_OUTPUT) / $RUN_COUNT" | bc 2>/dev/null || echo "0")
        else
            WEIGHT=0
            EST_INPUT=0
            EST_OUTPUT=0
            EST_COST="0.000000"
            AVG_TOKENS=0
        fi

        if [ "$FIRST_AGENT" = true ]; then
            FIRST_AGENT=false
        else
            echo ',' >> "$OUTPUT_FILE"
        fi

        echo -n '    "'"$agent"'": {' >> "$OUTPUT_FILE"
        echo -n '"run_count": '"$RUN_COUNT"', ' >> "$OUTPUT_FILE"
        echo -n '"log_size_bytes": '"$LOG_SIZE"', ' >> "$OUTPUT_FILE"
        echo -n '"estimated_input_tokens": '"$EST_INPUT"', ' >> "$OUTPUT_FILE"
        echo -n '"estimated_output_tokens": '"$EST_OUTPUT"', ' >> "$OUTPUT_FILE"
        echo -n '"estimated_cost_usd": '"$EST_COST"', ' >> "$OUTPUT_FILE"
        echo -n '"avg_tokens_per_run": '"$AVG_TOKENS"', ' >> "$OUTPUT_FILE"
        echo -n '"last_run": "'"$RECENT_DATE"'", ' >> "$OUTPUT_FILE"
        echo -n '"last_log_size": '"$RECENT_SIZE"'' >> "$OUTPUT_FILE"
        echo -n '}' >> "$OUTPUT_FILE"
    fi
done

echo '' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Calculate daily trend from history
echo '  "daily_trend": [' >> "$OUTPUT_FILE"

if [ -f "$HISTORY_FILE" ]; then
    # Read last 7 entries from history
    jq -r '.entries | .[-7:] | .[] | @json' "$HISTORY_FILE" 2>/dev/null | head -7 | while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        echo "    $entry,"
    done | sed '$ s/,$//' >> "$OUTPUT_FILE"
fi

echo '  ],' >> "$OUTPUT_FILE"

# Efficiency metrics
# Note: Use printf to ensure leading zeros (bc outputs .xxx for values <1)
if [ "$TOTAL_SESSIONS" -gt 0 ]; then
    TOKENS_PER_SESSION_RAW=$(echo "scale=2; ($INPUT_TOKENS + $OUTPUT_TOKENS) / $TOTAL_SESSIONS" | bc)
    TOKENS_PER_SESSION=$(printf "%.2f" "$TOKENS_PER_SESSION_RAW" 2>/dev/null || echo "0.00")
    COST_PER_SESSION_RAW=$(echo "scale=6; $TOTAL_COST / $TOTAL_SESSIONS" | bc)
    COST_PER_SESSION=$(printf "%.6f" "$COST_PER_SESSION_RAW" 2>/dev/null || echo "0.000000")
else
    TOKENS_PER_SESSION="0.00"
    COST_PER_SESSION="0.000000"
fi

if [ "$TOTAL_MESSAGES" -gt 0 ]; then
    TOKENS_PER_MESSAGE_RAW=$(echo "scale=2; ($INPUT_TOKENS + $OUTPUT_TOKENS) / $TOTAL_MESSAGES" | bc)
    TOKENS_PER_MESSAGE=$(printf "%.2f" "$TOKENS_PER_MESSAGE_RAW" 2>/dev/null || echo "0.00")
    COST_PER_MESSAGE_RAW=$(echo "scale=6; $TOTAL_COST / $TOTAL_MESSAGES" | bc)
    COST_PER_MESSAGE=$(printf "%.6f" "$COST_PER_MESSAGE_RAW" 2>/dev/null || echo "0.000000")
else
    TOKENS_PER_MESSAGE="0.00"
    COST_PER_MESSAGE="0.000000"
fi

echo '  "efficiency": {' >> "$OUTPUT_FILE"
echo '    "tokens_per_session": '"$TOKENS_PER_SESSION"',' >> "$OUTPUT_FILE"
echo '    "tokens_per_message": '"$TOKENS_PER_MESSAGE"',' >> "$OUTPUT_FILE"
echo '    "cost_per_session": '"$COST_PER_SESSION"',' >> "$OUTPUT_FILE"
echo '    "cost_per_message": '"$COST_PER_MESSAGE"'' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Summary with budget alerts
DAILY_BUDGET=10.00  # $10/day budget threshold for warning
WEEKLY_BUDGET=50.00 # $50/week budget threshold for warning

BUDGET_STATUS="healthy"
BUDGET_MESSAGE="Token usage within normal limits"

if [ "$(echo "$TOTAL_COST > $DAILY_BUDGET" | bc)" -eq 1 ]; then
    BUDGET_STATUS="warning"
    BUDGET_MESSAGE="Daily cost exceeds \$$DAILY_BUDGET budget threshold"
fi

echo '  "summary": {' >> "$OUTPUT_FILE"
echo '    "total_tokens": '"$(echo "$INPUT_TOKENS + $OUTPUT_TOKENS" | bc)"',' >> "$OUTPUT_FILE"
echo '    "total_cost_usd": '"$TOTAL_COST"',' >> "$OUTPUT_FILE"
echo '    "budget_status": "'"$BUDGET_STATUS"'",' >> "$OUTPUT_FILE"
echo '    "budget_message": "'"$BUDGET_MESSAGE"'",' >> "$OUTPUT_FILE"
echo '    "daily_budget": '"$DAILY_BUDGET"',' >> "$OUTPUT_FILE"
echo '    "weekly_budget": '"$WEEKLY_BUDGET"'' >> "$OUTPUT_FILE"
echo '  }' >> "$OUTPUT_FILE"

echo "}" >> "$OUTPUT_FILE"

# Update history file
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"entries": []}' > "$HISTORY_FILE"
fi

# Add today's entry to history (deduplicate by date)
ENTRY='{"date": "'"$TODAY"'", "tokens": '"$(echo "$INPUT_TOKENS + $OUTPUT_TOKENS" | bc)"', "cost": '"$TOTAL_COST"', "sessions": '"$TOTAL_SESSIONS"'}'

# Read current history, filter out today's entry, add new entry, keep last 30 days
TEMP_HISTORY=$(mktemp)
jq --argjson entry "$ENTRY" --arg today "$TODAY" '
    .entries = ([.entries[] | select(.date != $today)] + [$entry]) | .entries = .entries[-30:]
' "$HISTORY_FILE" > "$TEMP_HISTORY" 2>/dev/null || echo "$ENTRY" > "$TEMP_HISTORY"

if [ -s "$TEMP_HISTORY" ]; then
    mv "$TEMP_HISTORY" "$HISTORY_FILE"
else
    rm -f "$TEMP_HISTORY"
fi

echo "Cost analysis updated: $OUTPUT_FILE"
