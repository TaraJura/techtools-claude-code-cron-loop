#!/bin/bash
# update-token-optimizer.sh - Real-time token budget monitoring with per-agent caps and spending alerts
# Output: JSON data for the token-optimizer.html dashboard

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/token-optimizer.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
CONFIG_FILE="/var/www/cronloop.techtools.cz/api/token-budgets-config.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/token-optimizer-history.json"
LOG_DIR="/home/novakj/actors"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
HOUR=$(date +%H)
EPOCH=$(date +%s)

# Claude Opus 4.5 pricing (per million tokens)
INPUT_PRICE=15.00
OUTPUT_PRICE=75.00
CACHE_READ_PRICE=1.50
CACHE_WRITE_PRICE=18.75

# Default budget configuration (can be overridden by config file)
GLOBAL_DAILY_BUDGET_TOKENS=2000000  # 2M tokens/day global
GLOBAL_WEEKLY_BUDGET_TOKENS=10000000  # 10M tokens/week

# Default per-agent budgets (tokens/day)
declare -A DEFAULT_AGENT_BUDGETS=(
    ["developer"]=500000
    ["developer2"]=500000
    ["idea-maker"]=200000
    ["project-manager"]=200000
    ["tester"]=300000
    ["security"]=200000
    ["supervisor"]=100000
)

# Load custom config if exists
if [ -f "$CONFIG_FILE" ]; then
    GLOBAL_DAILY_BUDGET_TOKENS=$(jq -r '.global.daily_tokens // 2000000' "$CONFIG_FILE")
    GLOBAL_WEEKLY_BUDGET_TOKENS=$(jq -r '.global.weekly_tokens // 10000000' "$CONFIG_FILE")
fi

# Initialize output
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "date": "$TODAY",
  "hour": $HOUR,
  "epoch": $EPOCH,
EOF

# Get real-time token usage from costs.json
if [ -f "$COSTS_FILE" ]; then
    TOTAL_TOKENS=$(jq -r '.aggregate.total_tokens // 0' "$COSTS_FILE")
    DAILY_TOKENS=$(jq -r '.aggregate.daily_tokens // 0' "$COSTS_FILE")
    TOTAL_COST=$(jq -r '.aggregate.total_cost_usd // 0' "$COSTS_FILE")
else
    TOTAL_TOKENS=0
    DAILY_TOKENS=0
    TOTAL_COST=0
fi

# Calculate global budget status
GLOBAL_DAILY_PCT=$(echo "scale=2; ($DAILY_TOKENS * 100) / $GLOBAL_DAILY_BUDGET_TOKENS" | bc 2>/dev/null || echo "0")
if [ -z "$GLOBAL_DAILY_PCT" ] || [ "$GLOBAL_DAILY_PCT" = "" ]; then GLOBAL_DAILY_PCT=0; fi

# Determine global budget status
if (( $(echo "$GLOBAL_DAILY_PCT >= 100" | bc -l) )); then
    GLOBAL_STATUS="exceeded"
    GLOBAL_STATUS_MSG="Budget exceeded! Pause operations recommended."
elif (( $(echo "$GLOBAL_DAILY_PCT >= 90" | bc -l) )); then
    GLOBAL_STATUS="critical"
    GLOBAL_STATUS_MSG="Critical: 90%+ of daily budget consumed"
elif (( $(echo "$GLOBAL_DAILY_PCT >= 75" | bc -l) )); then
    GLOBAL_STATUS="warning"
    GLOBAL_STATUS_MSG="Warning: 75%+ of daily budget consumed"
elif (( $(echo "$GLOBAL_DAILY_PCT >= 50" | bc -l) )); then
    GLOBAL_STATUS="caution"
    GLOBAL_STATUS_MSG="Caution: 50%+ of daily budget consumed"
else
    GLOBAL_STATUS="healthy"
    GLOBAL_STATUS_MSG="Budget healthy"
fi

# Calculate spending velocity (tokens per hour based on current hour)
HOURS_ELAPSED=$((HOUR + 1))
if [ "$HOURS_ELAPSED" -gt 0 ]; then
    VELOCITY_PER_HOUR=$(echo "scale=0; $DAILY_TOKENS / $HOURS_ELAPSED" | bc 2>/dev/null || echo "0")
    PROJECTED_DAILY=$(echo "scale=0; $VELOCITY_PER_HOUR * 24" | bc 2>/dev/null || echo "0")
else
    VELOCITY_PER_HOUR=0
    PROJECTED_DAILY=0
fi

# Project whether we'll exceed budget
if [ "$PROJECTED_DAILY" -gt "$GLOBAL_DAILY_BUDGET_TOKENS" ]; then
    ON_PACE_EXCEED="true"
else
    ON_PACE_EXCEED="false"
fi

# Write global budget section
cat >> "$OUTPUT_FILE" << EOF
  "global_budget": {
    "daily_limit_tokens": $GLOBAL_DAILY_BUDGET_TOKENS,
    "weekly_limit_tokens": $GLOBAL_WEEKLY_BUDGET_TOKENS,
    "current_daily_tokens": $DAILY_TOKENS,
    "current_daily_pct": $GLOBAL_DAILY_PCT,
    "status": "$GLOBAL_STATUS",
    "status_message": "$GLOBAL_STATUS_MSG",
    "velocity_per_hour": $VELOCITY_PER_HOUR,
    "projected_daily": $PROJECTED_DAILY,
    "on_pace_to_exceed": $ON_PACE_EXCEED,
    "hours_elapsed": $HOURS_ELAPSED
  },
EOF

# Per-agent budget tracking
echo '  "agent_budgets": {' >> "$OUTPUT_FILE"
FIRST_AGENT=true
declare -A AGENT_ALERTS

for agent in developer developer2 idea-maker project-manager tester security supervisor; do
    agent_dir="$LOG_DIR/$agent"

    # Get agent budget (from config or default)
    if [ -f "$CONFIG_FILE" ]; then
        AGENT_BUDGET=$(jq -r ".agents[\"$agent\"].daily_tokens // ${DEFAULT_AGENT_BUDGETS[$agent]}" "$CONFIG_FILE")
    else
        AGENT_BUDGET=${DEFAULT_AGENT_BUDGETS[$agent]}
    fi

    # Estimate today's token usage from log sizes
    TODAYS_TOKENS=0
    TODAY_COST=0
    RUN_COUNT=0
    LAST_RUN=""
    LAST_RUN_SIZE=0

    if [ -d "$agent_dir/logs" ]; then
        # Find today's logs
        while IFS= read -r log_file; do
            if [ -f "$log_file" ]; then
                RUN_COUNT=$((RUN_COUNT + 1))
                LOG_SIZE=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
                # Estimate tokens: roughly 1 token per 4 characters in log
                EST_TOKENS=$((LOG_SIZE / 4))
                TODAYS_TOKENS=$((TODAYS_TOKENS + EST_TOKENS))
                LAST_RUN=$(basename "$log_file" .log)
                LAST_RUN_SIZE=$LOG_SIZE
            fi
        done < <(find "$agent_dir/logs" -name "${TODAY//-/}*.log" -type f 2>/dev/null)

        # Estimate cost based on token distribution (80% input, 20% output estimate)
        INPUT_EST=$((TODAYS_TOKENS * 80 / 100))
        OUTPUT_EST=$((TODAYS_TOKENS * 20 / 100))
        TODAY_COST=$(echo "scale=4; ($INPUT_EST * $INPUT_PRICE / 1000000) + ($OUTPUT_EST * $OUTPUT_PRICE / 1000000)" | bc 2>/dev/null || echo "0")
    fi

    # Calculate percentage of budget used
    if [ "$AGENT_BUDGET" -gt 0 ]; then
        AGENT_PCT=$(echo "scale=2; ($TODAYS_TOKENS * 100) / $AGENT_BUDGET" | bc 2>/dev/null || echo "0")
    else
        AGENT_PCT=0
    fi
    if [ -z "$AGENT_PCT" ] || [ "$AGENT_PCT" = "" ]; then AGENT_PCT=0; fi

    # Determine agent status
    if (( $(echo "$AGENT_PCT >= 100" | bc -l 2>/dev/null || echo "0") )); then
        AGENT_STATUS="exceeded"
        AGENT_ALERTS[$agent]="exceeded"
    elif (( $(echo "$AGENT_PCT >= 90" | bc -l 2>/dev/null || echo "0") )); then
        AGENT_STATUS="critical"
        AGENT_ALERTS[$agent]="critical"
    elif (( $(echo "$AGENT_PCT >= 75" | bc -l 2>/dev/null || echo "0") )); then
        AGENT_STATUS="warning"
        AGENT_ALERTS[$agent]="warning"
    elif (( $(echo "$AGENT_PCT >= 50" | bc -l 2>/dev/null || echo "0") )); then
        AGENT_STATUS="caution"
    else
        AGENT_STATUS="healthy"
    fi

    # Calculate tokens remaining
    TOKENS_REMAINING=$((AGENT_BUDGET - TODAYS_TOKENS))
    if [ "$TOKENS_REMAINING" -lt 0 ]; then TOKENS_REMAINING=0; fi

    # Estimate runs remaining based on average
    if [ "$RUN_COUNT" -gt 0 ]; then
        AVG_TOKENS_PER_RUN=$((TODAYS_TOKENS / RUN_COUNT))
        if [ "$AVG_TOKENS_PER_RUN" -gt 0 ]; then
            RUNS_REMAINING=$((TOKENS_REMAINING / AVG_TOKENS_PER_RUN))
        else
            RUNS_REMAINING=0
        fi
    else
        AVG_TOKENS_PER_RUN=0
        RUNS_REMAINING=0
    fi

    # Write agent entry
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" << EOF
    "$agent": {
      "daily_budget_tokens": $AGENT_BUDGET,
      "tokens_used_today": $TODAYS_TOKENS,
      "tokens_remaining": $TOKENS_REMAINING,
      "budget_pct": $AGENT_PCT,
      "status": "$AGENT_STATUS",
      "today_cost_usd": $TODAY_COST,
      "runs_today": $RUN_COUNT,
      "avg_tokens_per_run": $AVG_TOKENS_PER_RUN,
      "estimated_runs_remaining": $RUNS_REMAINING,
      "last_run": "$LAST_RUN"
    }
EOF
done

echo '  },' >> "$OUTPUT_FILE"

# Generate alerts array
echo '  "alerts": [' >> "$OUTPUT_FILE"
FIRST_ALERT=true
for agent in "${!AGENT_ALERTS[@]}"; do
    level="${AGENT_ALERTS[$agent]}"
    if [ "$FIRST_ALERT" = true ]; then
        FIRST_ALERT=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi

    case $level in
        exceeded)
            MSG="$agent has EXCEEDED daily token budget - pause recommended"
            SEVERITY="critical"
            ;;
        critical)
            MSG="$agent at 90%+ of daily token budget"
            SEVERITY="high"
            ;;
        warning)
            MSG="$agent at 75%+ of daily token budget"
            SEVERITY="medium"
            ;;
        *)
            MSG="$agent budget alert"
            SEVERITY="low"
            ;;
    esac

    echo "    {\"agent\": \"$agent\", \"level\": \"$level\", \"severity\": \"$SEVERITY\", \"message\": \"$MSG\", \"timestamp\": \"$TIMESTAMP\"}" >> "$OUTPUT_FILE"
done

# Check global budget alerts
if [ "$GLOBAL_STATUS" = "exceeded" ] || [ "$GLOBAL_STATUS" = "critical" ]; then
    if [ "$FIRST_ALERT" = false ]; then
        echo ',' >> "$OUTPUT_FILE"
    fi
    echo "    {\"agent\": \"global\", \"level\": \"$GLOBAL_STATUS\", \"severity\": \"critical\", \"message\": \"$GLOBAL_STATUS_MSG\", \"timestamp\": \"$TIMESTAMP\"}" >> "$OUTPUT_FILE"
fi

echo '  ],' >> "$OUTPUT_FILE"

# Cost efficiency metrics
echo '  "efficiency": {' >> "$OUTPUT_FILE"

# Calculate efficiency leaderboard
declare -A AGENT_EFFICIENCY
for agent in developer developer2 idea-maker project-manager tester security supervisor; do
    # Get agent data from costs.json
    if [ -f "$COSTS_FILE" ]; then
        RUN_COUNT=$(jq -r ".by_agent[\"$agent\"].run_count // 0" "$COSTS_FILE")
        EST_COST=$(jq -r ".by_agent[\"$agent\"].estimated_cost_usd // 0" "$COSTS_FILE")
        if [ "$RUN_COUNT" -gt 0 ]; then
            # Cost per run
            COST_PER_RUN=$(echo "scale=4; $EST_COST / $RUN_COUNT" | bc 2>/dev/null || echo "0")
        else
            COST_PER_RUN=0
        fi
        AGENT_EFFICIENCY[$agent]=$COST_PER_RUN
    fi
done

# Output efficiency rankings
echo '    "cost_per_run_ranking": [' >> "$OUTPUT_FILE"
FIRST_RANK=true
# Sort by cost per run (ascending - most efficient first)
for agent in $(for key in "${!AGENT_EFFICIENCY[@]}"; do echo "$key ${AGENT_EFFICIENCY[$key]}"; done | sort -k2 -n | cut -d' ' -f1); do
    if [ "$FIRST_RANK" = true ]; then
        FIRST_RANK=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi
    echo "      {\"agent\": \"$agent\", \"cost_per_run\": ${AGENT_EFFICIENCY[$agent]}}" >> "$OUTPUT_FILE"
done
echo '    ]' >> "$OUTPUT_FILE"
echo '  },' >> "$OUTPUT_FILE"

# Optimization suggestions based on current spending patterns
echo '  "recommendations": [' >> "$OUTPUT_FILE"
RECS=()

if [ "$ON_PACE_EXCEED" = "true" ]; then
    RECS+=("{\"priority\": \"high\", \"type\": \"budget\", \"message\": \"On pace to exceed daily budget. Consider pausing non-critical agents.\"}")
fi

for agent in "${!AGENT_ALERTS[@]}"; do
    level="${AGENT_ALERTS[$agent]}"
    if [ "$level" = "exceeded" ]; then
        RECS+=("{\"priority\": \"critical\", \"type\": \"agent\", \"agent\": \"$agent\", \"message\": \"$agent exceeded budget. Recommend pausing until tomorrow.\"}")
    elif [ "$level" = "critical" ]; then
        RECS+=("{\"priority\": \"high\", \"type\": \"agent\", \"agent\": \"$agent\", \"message\": \"$agent at 90%+ budget. Consider limiting to smaller tasks.\"}")
    fi
done

# Output recommendations
FIRST_REC=true
for rec in "${RECS[@]}"; do
    if [ "$FIRST_REC" = true ]; then
        FIRST_REC=false
    else
        echo ',' >> "$OUTPUT_FILE"
    fi
    echo "    $rec" >> "$OUTPUT_FILE"
done
echo '  ],' >> "$OUTPUT_FILE"

# Pricing reference
cat >> "$OUTPUT_FILE" << EOF
  "pricing": {
    "model": "claude-opus-4-5-20251101",
    "input_per_million": $INPUT_PRICE,
    "output_per_million": $OUTPUT_PRICE,
    "cache_read_per_million": $CACHE_READ_PRICE,
    "cache_write_per_million": $CACHE_WRITE_PRICE
  },
  "summary": {
    "total_daily_tokens": $DAILY_TOKENS,
    "daily_budget_tokens": $GLOBAL_DAILY_BUDGET_TOKENS,
    "budget_pct": $GLOBAL_DAILY_PCT,
    "status": "$GLOBAL_STATUS",
    "alert_count": ${#AGENT_ALERTS[@]},
    "velocity_per_hour": $VELOCITY_PER_HOUR,
    "projected_daily": $PROJECTED_DAILY
  }
}
EOF

# Update history file (keep last 7 days of hourly snapshots)
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"snapshots": []}' > "$HISTORY_FILE"
fi

# Add current snapshot to history
SNAPSHOT="{\"timestamp\": \"$TIMESTAMP\", \"daily_tokens\": $DAILY_TOKENS, \"budget_pct\": $GLOBAL_DAILY_PCT, \"status\": \"$GLOBAL_STATUS\", \"alerts\": ${#AGENT_ALERTS[@]}}"

# Keep only last 168 entries (7 days * 24 hours)
TMP_HISTORY=$(mktemp)
jq --argjson snap "$SNAPSHOT" '.snapshots = ([$snap] + .snapshots[0:167])' "$HISTORY_FILE" > "$TMP_HISTORY" 2>/dev/null && mv "$TMP_HISTORY" "$HISTORY_FILE" || rm -f "$TMP_HISTORY"

echo "Token optimizer data updated: $OUTPUT_FILE"
