#!/bin/bash
# update-budget.sh - Manages cost budgets and spending alerts for the multi-agent system
# Output: JSON data for the budget.html dashboard

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/budget.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
COSTS_HISTORY="/var/www/cronloop.techtools.cz/api/costs-history.json"
BUDGET_CONFIG_FILE="/var/www/cronloop.techtools.cz/api/budget-config.json"
BUDGET_HISTORY_FILE="/var/www/cronloop.techtools.cz/api/budget-history.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Day of week (1=Monday, 7=Sunday)
DAY_OF_WEEK=$(date +%u)
# Day of month
DAY_OF_MONTH=$(date +%d)
# Days remaining in month
DAYS_IN_MONTH=$(date -d "$TODAY +1 month -$(date +%d) days" +%d 2>/dev/null || echo "30")
DAYS_REMAINING_MONTH=$((DAYS_IN_MONTH - ${DAY_OF_MONTH#0} + 1))
# Days remaining in week (until Sunday)
DAYS_REMAINING_WEEK=$((7 - DAY_OF_WEEK + 1))

# Default budget settings (can be overridden by budget-config.json)
DEFAULT_DAILY_BUDGET=10.00
DEFAULT_WEEKLY_BUDGET=50.00
DEFAULT_MONTHLY_BUDGET=200.00
ALERT_THRESHOLDS="50,75,90,100"

# Per-agent default budgets
AGENT_BUDGETS='{"idea-maker":2.00,"project-manager":2.00,"developer":5.00,"tester":3.00,"security":2.00}'

# Load config if exists
if [ -f "$BUDGET_CONFIG_FILE" ]; then
    CONFIG_DAILY=$(jq -r '.daily_budget // empty' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_WEEKLY=$(jq -r '.weekly_budget // empty' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_MONTHLY=$(jq -r '.monthly_budget // empty' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_THRESHOLDS=$(jq -r '.alert_thresholds // empty' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_AGENT_BUDGETS=$(jq -r '.agent_budgets // empty' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_ROLLOVER=$(jq -r '.rollover_enabled // false' "$BUDGET_CONFIG_FILE" 2>/dev/null)
    CONFIG_PAUSE_ON_EXCEED=$(jq -r '.pause_on_exceed // {}' "$BUDGET_CONFIG_FILE" 2>/dev/null)

    [ -n "$CONFIG_DAILY" ] && DEFAULT_DAILY_BUDGET=$CONFIG_DAILY
    [ -n "$CONFIG_WEEKLY" ] && DEFAULT_WEEKLY_BUDGET=$CONFIG_WEEKLY
    [ -n "$CONFIG_MONTHLY" ] && DEFAULT_MONTHLY_BUDGET=$CONFIG_MONTHLY
    [ -n "$CONFIG_THRESHOLDS" ] && ALERT_THRESHOLDS=$CONFIG_THRESHOLDS
    [ -n "$CONFIG_AGENT_BUDGETS" ] && AGENT_BUDGETS=$CONFIG_AGENT_BUDGETS
    [ -n "$CONFIG_ROLLOVER" ] && ROLLOVER_ENABLED=$CONFIG_ROLLOVER
    [ -n "$CONFIG_PAUSE_ON_EXCEED" ] && PAUSE_ON_EXCEED=$CONFIG_PAUSE_ON_EXCEED
else
    ROLLOVER_ENABLED="false"
    PAUSE_ON_EXCEED='{}'
fi

# Read current costs
TOTAL_COST_TODAY=0
if [ -f "$COSTS_FILE" ]; then
    TOTAL_COST_TODAY=$(jq -r '.aggregate.total_cost_usd // 0' "$COSTS_FILE" 2>/dev/null || echo "0")
fi

# Read costs history for weekly and monthly totals
WEEKLY_COST=0
MONTHLY_COST=0
if [ -f "$COSTS_HISTORY" ]; then
    # Weekly cost (last 7 days)
    WEEK_START=$(date -d "$TODAY -$((DAY_OF_WEEK - 1)) days" +%Y-%m-%d)
    WEEKLY_COST=$(jq -r --arg start "$WEEK_START" '
        [.history[] | select(.date >= $start) | .cost] | add // 0
    ' "$COSTS_HISTORY" 2>/dev/null || echo "0")

    # Monthly cost (current month)
    MONTH_START=$(date +%Y-%m-01)
    MONTHLY_COST=$(jq -r --arg start "$MONTH_START" '
        [.history[] | select(.date >= $start) | .cost] | add // 0
    ' "$COSTS_HISTORY" 2>/dev/null || echo "0")
fi

# Calculate budget usage percentages
calc_percentage() {
    local spent=$1
    local budget=$2
    echo "scale=2; if ($budget > 0) $spent * 100 / $budget else 0" | bc
}

DAILY_USAGE_PCT=$(calc_percentage "$TOTAL_COST_TODAY" "$DEFAULT_DAILY_BUDGET")
WEEKLY_USAGE_PCT=$(calc_percentage "$WEEKLY_COST" "$DEFAULT_WEEKLY_BUDGET")
MONTHLY_USAGE_PCT=$(calc_percentage "$MONTHLY_COST" "$DEFAULT_MONTHLY_BUDGET")

# Determine status (green <70%, yellow 70-90%, red >90%)
get_status() {
    local pct=$1
    local pct_int=$(echo "$pct" | cut -d. -f1)
    if [ "$pct_int" -ge 100 ]; then
        echo "exceeded"
    elif [ "$pct_int" -ge 90 ]; then
        echo "critical"
    elif [ "$pct_int" -ge 70 ]; then
        echo "warning"
    else
        echo "healthy"
    fi
}

DAILY_STATUS=$(get_status "$DAILY_USAGE_PCT")
WEEKLY_STATUS=$(get_status "$WEEKLY_USAGE_PCT")
MONTHLY_STATUS=$(get_status "$MONTHLY_USAGE_PCT")

# Calculate burn rate and projections
# Daily burn rate (average per day from monthly data)
DAYS_ELAPSED=$((${DAY_OF_MONTH#0}))
if [ "$DAYS_ELAPSED" -gt 0 ]; then
    DAILY_BURN_RATE=$(echo "scale=4; $MONTHLY_COST / $DAYS_ELAPSED" | bc)
else
    DAILY_BURN_RATE=$TOTAL_COST_TODAY
fi

# Projected end-of-month spend
PROJECTED_MONTHLY=$(echo "scale=2; $MONTHLY_COST + ($DAILY_BURN_RATE * $DAYS_REMAINING_MONTH)" | bc)

# Projected end-of-week spend
PROJECTED_WEEKLY=$(echo "scale=2; $WEEKLY_COST + ($DAILY_BURN_RATE * $DAYS_REMAINING_WEEK)" | bc)

# Get per-agent spending
get_agent_spending() {
    if [ -f "$COSTS_FILE" ]; then
        jq -r '.by_agent | to_entries[] | "\(.key):\(.value.estimated_cost_usd)"' "$COSTS_FILE" 2>/dev/null
    fi
}

# Check for cost anomalies (single run > 3x average)
check_anomalies() {
    local anomalies="[]"
    if [ -f "$COSTS_FILE" ]; then
        # Calculate overall average cost per run
        local total_runs=$(jq -r '[.by_agent[].run_count] | add // 0' "$COSTS_FILE" 2>/dev/null)
        if [ "$total_runs" -gt 0 ]; then
            local avg_cost=$(echo "scale=4; $TOTAL_COST_TODAY / $total_runs" | bc)
            local threshold=$(echo "scale=4; $avg_cost * 3" | bc)

            # Check each agent's last run
            anomalies=$(jq -r --arg threshold "$threshold" '
                [.by_agent | to_entries[] |
                 select((.value.estimated_cost_usd / (.value.run_count // 1)) > ($threshold | tonumber)) |
                 {agent: .key, cost: (.value.estimated_cost_usd / (.value.run_count // 1)), threshold: ($threshold | tonumber)}
                ] // []
            ' "$COSTS_FILE" 2>/dev/null || echo "[]")
        fi
    fi
    echo "$anomalies"
}

# Generate active alerts
generate_alerts() {
    local alerts="[]"

    # Daily budget alerts
    if [ "$(echo "$DAILY_USAGE_PCT >= 100" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"exceeded","period":"daily","message":"Daily budget exceeded!","severity":"critical","pct":'$DAILY_USAGE_PCT'}]')
    elif [ "$(echo "$DAILY_USAGE_PCT >= 90" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"threshold","period":"daily","message":"Daily budget at 90%","severity":"warning","pct":'$DAILY_USAGE_PCT'}]')
    elif [ "$(echo "$DAILY_USAGE_PCT >= 75" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"threshold","period":"daily","message":"Daily budget at 75%","severity":"info","pct":'$DAILY_USAGE_PCT'}]')
    fi

    # Weekly budget alerts
    if [ "$(echo "$WEEKLY_USAGE_PCT >= 100" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"exceeded","period":"weekly","message":"Weekly budget exceeded!","severity":"critical","pct":'$WEEKLY_USAGE_PCT'}]')
    elif [ "$(echo "$WEEKLY_USAGE_PCT >= 90" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"threshold","period":"weekly","message":"Weekly budget at 90%","severity":"warning","pct":'$WEEKLY_USAGE_PCT'}]')
    fi

    # Monthly budget alerts
    if [ "$(echo "$MONTHLY_USAGE_PCT >= 100" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"exceeded","period":"monthly","message":"Monthly budget exceeded!","severity":"critical","pct":'$MONTHLY_USAGE_PCT'}]')
    elif [ "$(echo "$MONTHLY_USAGE_PCT >= 90" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"threshold","period":"monthly","message":"Monthly budget at 90%","severity":"warning","pct":'$MONTHLY_USAGE_PCT'}]')
    fi

    # Projection alerts
    if [ "$(echo "$PROJECTED_MONTHLY > $DEFAULT_MONTHLY_BUDGET" | bc)" -eq 1 ]; then
        alerts=$(echo "$alerts" | jq '. + [{"type":"projection","period":"monthly","message":"Projected to exceed monthly budget","severity":"warning","projected":'$PROJECTED_MONTHLY'}]')
    fi

    echo "$alerts"
}

ANOMALIES=$(check_anomalies)
ALERTS=$(generate_alerts)

# Build per-agent budget status
build_agent_budgets() {
    if [ -f "$COSTS_FILE" ]; then
        jq -r --argjson budgets "$AGENT_BUDGETS" --argjson pause "$PAUSE_ON_EXCEED" '
            .by_agent | to_entries | map({
                agent: .key,
                spent: .value.estimated_cost_usd,
                budget: ($budgets[.key] // 2.00),
                runs: .value.run_count,
                usage_pct: (if ($budgets[.key] // 2.00) > 0 then (.value.estimated_cost_usd * 100 / ($budgets[.key] // 2.00)) else 0 end),
                status: (if ($budgets[.key] // 2.00) > 0 then
                    (if (.value.estimated_cost_usd * 100 / ($budgets[.key] // 2.00)) >= 100 then "exceeded"
                     elif (.value.estimated_cost_usd * 100 / ($budgets[.key] // 2.00)) >= 90 then "critical"
                     elif (.value.estimated_cost_usd * 100 / ($budgets[.key] // 2.00)) >= 70 then "warning"
                     else "healthy" end)
                else "healthy" end),
                pause_on_exceed: ($pause[.key] // false)
            })
        ' "$COSTS_FILE" 2>/dev/null
    else
        echo "[]"
    fi
}

AGENT_BUDGET_STATUS=$(build_agent_budgets)

# Get spending history for charts (last 30 days)
get_spending_history() {
    if [ -f "$COSTS_HISTORY" ]; then
        local thirty_days_ago=$(date -d "$TODAY -30 days" +%Y-%m-%d)
        local result=$(jq -r --arg start "$thirty_days_ago" --arg daily "$DEFAULT_DAILY_BUDGET" '
            [.history[] | select(.date >= $start) | {
                date: .date,
                cost: .cost,
                tokens: .tokens,
                budget: ($daily | tonumber),
                over_budget: (.cost > ($daily | tonumber))
            }] | sort_by(.date)
        ' "$COSTS_HISTORY" 2>/dev/null)
        if [ -n "$result" ] && [ "$result" != "null" ]; then
            echo "$result"
        else
            echo "[]"
        fi
    else
        echo "[]"
    fi
}

SPENDING_HISTORY=$(get_spending_history)
[ -z "$SPENDING_HISTORY" ] && SPENDING_HISTORY="[]"

# Calculate overall budget health score (0-100)
calc_health_score() {
    # Weight: daily 40%, weekly 30%, monthly 30%
    # Cap usage at 100 for scoring (over-budget is still 0)
    local daily_capped=$(echo "scale=2; if ($DAILY_USAGE_PCT > 100) 100 else $DAILY_USAGE_PCT" | bc)
    local weekly_capped=$(echo "scale=2; if ($WEEKLY_USAGE_PCT > 100) 100 else $WEEKLY_USAGE_PCT" | bc)
    local monthly_capped=$(echo "scale=2; if ($MONTHLY_USAGE_PCT > 100) 100 else $MONTHLY_USAGE_PCT" | bc)

    local daily_score=$(echo "scale=2; 100 - $daily_capped" | bc)
    local weekly_score=$(echo "scale=2; 100 - $weekly_capped" | bc)
    local monthly_score=$(echo "scale=2; 100 - $monthly_capped" | bc)

    local score=$(echo "scale=0; ($daily_score * 0.4 + $weekly_score * 0.3 + $monthly_score * 0.3) / 1" | bc)
    # Ensure non-negative
    [ "$score" -lt 0 ] 2>/dev/null && score=0
    echo "$score"
}

HEALTH_SCORE=$(calc_health_score)
[ -z "$HEALTH_SCORE" ] && HEALTH_SCORE=0

# Build output JSON
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "date": "$TODAY",
  "epoch": $EPOCH,
  "config": {
    "daily_budget": $DEFAULT_DAILY_BUDGET,
    "weekly_budget": $DEFAULT_WEEKLY_BUDGET,
    "monthly_budget": $DEFAULT_MONTHLY_BUDGET,
    "alert_thresholds": [$ALERT_THRESHOLDS],
    "rollover_enabled": $ROLLOVER_ENABLED,
    "agent_budgets": $AGENT_BUDGETS
  },
  "current_spending": {
    "daily": {
      "spent": $TOTAL_COST_TODAY,
      "budget": $DEFAULT_DAILY_BUDGET,
      "remaining": $(echo "scale=2; $DEFAULT_DAILY_BUDGET - $TOTAL_COST_TODAY" | bc),
      "usage_pct": $DAILY_USAGE_PCT,
      "status": "$DAILY_STATUS"
    },
    "weekly": {
      "spent": $WEEKLY_COST,
      "budget": $DEFAULT_WEEKLY_BUDGET,
      "remaining": $(echo "scale=2; $DEFAULT_WEEKLY_BUDGET - $WEEKLY_COST" | bc),
      "usage_pct": $WEEKLY_USAGE_PCT,
      "status": "$WEEKLY_STATUS",
      "days_remaining": $DAYS_REMAINING_WEEK
    },
    "monthly": {
      "spent": $MONTHLY_COST,
      "budget": $DEFAULT_MONTHLY_BUDGET,
      "remaining": $(echo "scale=2; $DEFAULT_MONTHLY_BUDGET - $MONTHLY_COST" | bc),
      "usage_pct": $MONTHLY_USAGE_PCT,
      "status": "$MONTHLY_STATUS",
      "days_remaining": $DAYS_REMAINING_MONTH
    }
  },
  "projections": {
    "daily_burn_rate": $DAILY_BURN_RATE,
    "projected_weekly": $PROJECTED_WEEKLY,
    "projected_monthly": $PROJECTED_MONTHLY,
    "will_exceed_weekly": $([ "$(echo "$PROJECTED_WEEKLY > $DEFAULT_WEEKLY_BUDGET" | bc)" -eq 1 ] && echo "true" || echo "false"),
    "will_exceed_monthly": $([ "$(echo "$PROJECTED_MONTHLY > $DEFAULT_MONTHLY_BUDGET" | bc)" -eq 1 ] && echo "true" || echo "false")
  },
  "by_agent": $AGENT_BUDGET_STATUS,
  "alerts": $ALERTS,
  "anomalies": $ANOMALIES,
  "history": $SPENDING_HISTORY,
  "health_score": $HEALTH_SCORE,
  "summary": {
    "total_alerts": $(echo "$ALERTS" | jq 'length'),
    "critical_alerts": $(echo "$ALERTS" | jq '[.[] | select(.severity == "critical")] | length'),
    "agents_over_budget": $(echo "$AGENT_BUDGET_STATUS" | jq '[.[] | select(.status == "exceeded")] | length'),
    "overall_status": "$([ "$HEALTH_SCORE" -ge 70 ] && echo "healthy" || ([ "$HEALTH_SCORE" -ge 40 ] && echo "warning" || echo "critical"))"
  }
}
EOF

# Update budget history
if [ -f "$BUDGET_HISTORY_FILE" ]; then
    # Append today's snapshot
    jq --arg date "$TODAY" --arg daily "$TOTAL_COST_TODAY" --arg weekly "$WEEKLY_COST" --arg monthly "$MONTHLY_COST" --arg score "$HEALTH_SCORE" '
        .snapshots = [.snapshots[] | select(.date != $date)] + [{
            date: $date,
            daily_spent: ($daily | tonumber),
            weekly_spent: ($weekly | tonumber),
            monthly_spent: ($monthly | tonumber),
            health_score: ($score | tonumber)
        }] | .snapshots = (.snapshots | sort_by(.date) | .[-90:])
    ' "$BUDGET_HISTORY_FILE" > "${BUDGET_HISTORY_FILE}.tmp" && mv "${BUDGET_HISTORY_FILE}.tmp" "$BUDGET_HISTORY_FILE"
else
    # Initialize history file
    cat > "$BUDGET_HISTORY_FILE" << EOF2
{
  "snapshots": [{
    "date": "$TODAY",
    "daily_spent": $TOTAL_COST_TODAY,
    "weekly_spent": $WEEKLY_COST,
    "monthly_spent": $MONTHLY_COST,
    "health_score": $HEALTH_SCORE
  }]
}
EOF2
fi

echo "Budget data updated: $OUTPUT_FILE"
echo "Health Score: $HEALTH_SCORE/100"
echo "Daily: \$$TOTAL_COST_TODAY / \$$DEFAULT_DAILY_BUDGET ($DAILY_STATUS)"
echo "Weekly: \$$WEEKLY_COST / \$$DEFAULT_WEEKLY_BUDGET ($WEEKLY_STATUS)"
echo "Monthly: \$$MONTHLY_COST / \$$DEFAULT_MONTHLY_BUDGET ($MONTHLY_STATUS)"
