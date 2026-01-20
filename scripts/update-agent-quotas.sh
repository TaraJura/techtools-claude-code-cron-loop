#!/bin/bash
# update-agent-quotas.sh - Manages per-agent token quotas with real-time enforcement
# Output: JSON data for the agent-quotas.html dashboard

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/agent-quotas.json"
CONFIG_FILE="/var/www/cronloop.techtools.cz/api/agent-quotas-config.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/agent-quotas-history.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
COSTS_HISTORY="/var/www/cronloop.techtools.cz/api/costs-history.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Day of week (1=Monday, 7=Sunday)
DAY_OF_WEEK=$(date +%u)

# Default quota settings per agent (daily tokens)
declare -A DEFAULT_DAILY_QUOTAS=(
    ["idea-maker"]=50000
    ["project-manager"]=50000
    ["developer"]=150000
    ["developer2"]=150000
    ["tester"]=100000
    ["security"]=75000
    ["supervisor"]=100000
)

declare -A DEFAULT_WEEKLY_QUOTAS=(
    ["idea-maker"]=300000
    ["project-manager"]=300000
    ["developer"]=900000
    ["developer2"]=900000
    ["tester"]=600000
    ["security"]=450000
    ["supervisor"]=600000
)

# Initialize config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
    "enforcement_mode": "warn",
    "rollover_enabled": false,
    "alert_threshold_pct": 80,
    "agent_quotas": {
        "idea-maker": {"daily": 50000, "weekly": 300000, "rollover": false},
        "project-manager": {"daily": 50000, "weekly": 300000, "rollover": false},
        "developer": {"daily": 150000, "weekly": 900000, "rollover": false},
        "developer2": {"daily": 150000, "weekly": 900000, "rollover": false},
        "tester": {"daily": 100000, "weekly": 600000, "rollover": false},
        "security": {"daily": 75000, "weekly": 450000, "rollover": false},
        "supervisor": {"daily": 100000, "weekly": 600000, "rollover": false}
    },
    "paused_agents": []
}
EOF
fi

# Initialize history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"history": []}' > "$HISTORY_FILE"
fi

# Load config
ENFORCEMENT_MODE=$(jq -r '.enforcement_mode // "warn"' "$CONFIG_FILE" 2>/dev/null || echo "warn")
ALERT_THRESHOLD=$(jq -r '.alert_threshold_pct // 80' "$CONFIG_FILE" 2>/dev/null || echo "80")
PAUSED_AGENTS=$(jq -r '.paused_agents // []' "$CONFIG_FILE" 2>/dev/null || echo "[]")

# Function to get agent token usage from costs.json
get_agent_tokens() {
    local agent=$1
    local period=$2  # "daily" or "weekly"

    if [ ! -f "$COSTS_FILE" ]; then
        echo "0"
        return
    fi

    if [ "$period" = "daily" ]; then
        # Get today's usage
        jq -r --arg agent "$agent" '.by_agent[] | select(.agent == $agent) | .total_tokens // 0' "$COSTS_FILE" 2>/dev/null || echo "0"
    else
        # Get weekly usage from history
        if [ -f "$COSTS_HISTORY" ]; then
            WEEK_START=$(date -d "$TODAY -$((DAY_OF_WEEK - 1)) days" +%Y-%m-%d)
            jq -r --arg agent "$agent" --arg start "$WEEK_START" '
                [.history[] | select(.date >= $start) | .by_agent[]? | select(.agent == $agent) | .tokens // 0] | add // 0
            ' "$COSTS_HISTORY" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    fi
}

# Function to get average tokens per run for an agent
get_avg_tokens_per_run() {
    local agent=$1

    # Parse from costs-history.json if available
    if [ -f "$COSTS_HISTORY" ]; then
        jq -r --arg agent "$agent" '
            [.history[-7:][] | .by_agent[]? | select(.agent == $agent) | .tokens // 0] |
            if length > 0 then (add / length | floor) else 0 end
        ' "$COSTS_HISTORY" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Build agents array
build_agents_json() {
    local first=true
    echo "["

    for agent in "idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor"; do
        # Get quota limits from config
        DAILY_LIMIT=$(jq -r --arg agent "$agent" '.agent_quotas[$agent].daily // 50000' "$CONFIG_FILE" 2>/dev/null || echo "${DEFAULT_DAILY_QUOTAS[$agent]}")
        WEEKLY_LIMIT=$(jq -r --arg agent "$agent" '.agent_quotas[$agent].weekly // 300000' "$CONFIG_FILE" 2>/dev/null || echo "${DEFAULT_WEEKLY_QUOTAS[$agent]}")
        ROLLOVER=$(jq -r --arg agent "$agent" '.agent_quotas[$agent].rollover // false' "$CONFIG_FILE" 2>/dev/null || echo "false")

        # Get actual usage
        DAILY_USED=$(get_agent_tokens "$agent" "daily")
        WEEKLY_USED=$(get_agent_tokens "$agent" "weekly")

        # Ensure numeric values
        DAILY_USED=${DAILY_USED:-0}
        WEEKLY_USED=${WEEKLY_USED:-0}
        DAILY_LIMIT=${DAILY_LIMIT:-50000}
        WEEKLY_LIMIT=${WEEKLY_LIMIT:-300000}

        # Calculate percentages
        if [ "$DAILY_LIMIT" -gt 0 ]; then
            DAILY_PCT=$(echo "scale=2; $DAILY_USED * 100 / $DAILY_LIMIT" | bc)
        else
            DAILY_PCT="0"
        fi

        if [ "$WEEKLY_LIMIT" -gt 0 ]; then
            WEEKLY_PCT=$(echo "scale=2; $WEEKLY_USED * 100 / $WEEKLY_LIMIT" | bc)
        else
            WEEKLY_PCT="0"
        fi

        # Calculate remaining
        DAILY_REMAINING=$((DAILY_LIMIT - DAILY_USED))
        WEEKLY_REMAINING=$((WEEKLY_LIMIT - WEEKLY_USED))
        [ "$DAILY_REMAINING" -lt 0 ] && DAILY_REMAINING=0
        [ "$WEEKLY_REMAINING" -lt 0 ] && WEEKLY_REMAINING=0

        # Get average tokens per run
        AVG_PER_RUN=$(get_avg_tokens_per_run "$agent")
        AVG_PER_RUN=${AVG_PER_RUN:-0}

        # Calculate estimated runs remaining
        if [ "$AVG_PER_RUN" -gt 0 ]; then
            RUNS_REMAINING=$((DAILY_REMAINING / AVG_PER_RUN))
        else
            RUNS_REMAINING=0
        fi

        # Check if agent is paused
        IS_PAUSED=$(echo "$PAUSED_AGENTS" | jq -r --arg agent "$agent" 'if . | index($agent) then "paused" else "active" end')

        # Add comma separator
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        cat << AGENT
        {
            "name": "$agent",
            "status": "$IS_PAUSED",
            "rollover": $ROLLOVER,
            "daily": {
                "used": $DAILY_USED,
                "limit": $DAILY_LIMIT,
                "remaining": $DAILY_REMAINING,
                "usage_pct": $DAILY_PCT
            },
            "weekly": {
                "used": $WEEKLY_USED,
                "limit": $WEEKLY_LIMIT,
                "remaining": $WEEKLY_REMAINING,
                "usage_pct": $WEEKLY_PCT
            },
            "avg_tokens_per_run": $AVG_PER_RUN,
            "estimated_runs_remaining": $RUNS_REMAINING
        }
AGENT
    done

    echo "]"
}

# Build suggestions based on usage patterns
build_suggestions_json() {
    local suggestions="[]"

    # Analyze each agent for suggestions
    for agent in "idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor"; do
        DAILY_LIMIT=$(jq -r --arg agent "$agent" '.agent_quotas[$agent].daily // 50000' "$CONFIG_FILE" 2>/dev/null || echo "50000")
        DAILY_USED=$(get_agent_tokens "$agent" "daily")
        DAILY_USED=${DAILY_USED:-0}
        AVG_PER_RUN=$(get_avg_tokens_per_run "$agent")
        AVG_PER_RUN=${AVG_PER_RUN:-0}

        if [ "$DAILY_LIMIT" -gt 0 ]; then
            DAILY_PCT=$(echo "scale=0; $DAILY_USED * 100 / $DAILY_LIMIT" | bc)
        else
            DAILY_PCT=0
        fi

        # Suggest increase if consistently hitting >90%
        if [ "$DAILY_PCT" -ge 90 ] && [ "$AVG_PER_RUN" -gt 0 ]; then
            SUGGESTED=$((AVG_PER_RUN * 10))  # Suggest 10 runs worth
            suggestions=$(echo "$suggestions" | jq --arg agent "$agent" --argjson suggested "$SUGGESTED" --arg pct "$DAILY_PCT" '. + [{
                "type": "increase",
                "agent": $agent,
                "message": ($agent + " consistently uses >90% of quota"),
                "detail": ("Currently at " + $pct + "%. Suggest increasing daily limit."),
                "suggested_value": $suggested
            }]')
        fi

        # Suggest decrease if consistently under 30%
        if [ "$DAILY_PCT" -le 30 ] && [ "$DAILY_PCT" -gt 0 ] && [ "$AVG_PER_RUN" -gt 0 ]; then
            SUGGESTED=$((AVG_PER_RUN * 5))  # Suggest 5 runs worth
            [ "$SUGGESTED" -lt 10000 ] && SUGGESTED=10000  # Minimum 10K
            suggestions=$(echo "$suggestions" | jq --arg agent "$agent" --argjson suggested "$SUGGESTED" --arg pct "$DAILY_PCT" '. + [{
                "type": "decrease",
                "agent": $agent,
                "message": ($agent + " uses only " + $pct + "% of allocated quota"),
                "detail": "Consider reducing to optimize budget allocation.",
                "suggested_value": $suggested
            }]')
        fi
    done

    echo "$suggestions"
}

# Build history data for chart (last 7 days)
build_history_json() {
    if [ ! -f "$COSTS_HISTORY" ]; then
        echo "[]"
        return
    fi

    jq '
        .history[-7:] | map({
            date: .date,
            "idea-maker": ([.by_agent[]? | select(.agent == "idea-maker") | .tokens] | add // 0),
            "project-manager": ([.by_agent[]? | select(.agent == "project-manager") | .tokens] | add // 0),
            "developer": ([.by_agent[]? | select(.agent == "developer") | .tokens] | add // 0),
            "developer2": ([.by_agent[]? | select(.agent == "developer2") | .tokens] | add // 0),
            "tester": ([.by_agent[]? | select(.agent == "tester") | .tokens] | add // 0),
            "security": ([.by_agent[]? | select(.agent == "security") | .tokens] | add // 0),
            "supervisor": ([.by_agent[]? | select(.agent == "supervisor") | .tokens] | add // 0)
        })
    ' "$COSTS_HISTORY" 2>/dev/null || echo "[]"
}

# Calculate summary statistics
calculate_summary() {
    local agents_json="$1"

    TOTAL_DAILY_USED=$(echo "$agents_json" | jq '[.[].daily.used] | add // 0')
    TOTAL_DAILY_LIMIT=$(echo "$agents_json" | jq '[.[].daily.limit] | add // 0')
    TOTAL_REMAINING=$(echo "$agents_json" | jq '[.[].daily.remaining] | add // 0')

    if [ "$TOTAL_DAILY_LIMIT" -gt 0 ]; then
        TOTAL_PCT=$(echo "scale=2; $TOTAL_DAILY_USED * 100 / $TOTAL_DAILY_LIMIT" | bc)
    else
        TOTAL_PCT="0"
    fi

    OVER_QUOTA=$(echo "$agents_json" | jq '[.[] | select(.daily.usage_pct >= 100)] | length')
    NEAR_LIMIT=$(echo "$agents_json" | jq --argjson threshold "$ALERT_THRESHOLD" '[.[] | select(.daily.usage_pct >= $threshold and .daily.usage_pct < 100)] | length')

    # Estimate total runs remaining based on average
    AVG_REMAINING=$(echo "$agents_json" | jq '[.[].estimated_runs_remaining] | add // 0')

    cat << SUMMARY
{
    "total_tokens_used": $TOTAL_DAILY_USED,
    "total_tokens_limit": $TOTAL_DAILY_LIMIT,
    "total_tokens_remaining": $TOTAL_REMAINING,
    "total_daily_usage_pct": $TOTAL_PCT,
    "agents_over_quota": $OVER_QUOTA,
    "agents_near_limit": $NEAR_LIMIT,
    "estimated_runs_remaining": $AVG_REMAINING
}
SUMMARY
}

# Build the complete JSON output
AGENTS_JSON=$(build_agents_json)
SUGGESTIONS_JSON=$(build_suggestions_json)
HISTORY_JSON=$(build_history_json)
SUMMARY_JSON=$(calculate_summary "$AGENTS_JSON")

# Assemble final output
cat > "$OUTPUT_FILE" << EOF
{
    "generated": "$TIMESTAMP",
    "epoch": $EPOCH,
    "date": "$TODAY",
    "summary": $SUMMARY_JSON,
    "enforcement": {
        "mode": "$ENFORCEMENT_MODE",
        "alert_threshold_pct": $ALERT_THRESHOLD,
        "paused_agents": $PAUSED_AGENTS
    },
    "agents": $AGENTS_JSON,
    "suggestions": $SUGGESTIONS_JSON,
    "history": $HISTORY_JSON,
    "timestamp": "$TIMESTAMP"
}
EOF

# Update history file with today's snapshot
TODAY_SNAPSHOT=$(echo "$AGENTS_JSON" | jq --arg date "$TODAY" '{
    date: $date,
    agents: [.[] | {name: .name, daily_used: .daily.used, daily_limit: .daily.limit}]
}')

jq --argjson snapshot "$TODAY_SNAPSHOT" '
    .history = (.history | if length > 30 then .[-30:] else . end) |
    if (.history | map(.date) | index($snapshot.date)) then
        .history |= map(if .date == $snapshot.date then $snapshot else . end)
    else
        .history += [$snapshot]
    end
' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

echo "Agent quotas updated: $OUTPUT_FILE"
