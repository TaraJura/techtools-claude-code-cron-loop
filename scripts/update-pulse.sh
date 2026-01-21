#!/bin/bash
# Pulse API Generator - Creates lightweight aggregated metrics for mobile pulse page
# Part of the CronLoop autonomous system

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/pulse.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Source data files
SYSTEM_METRICS="/var/www/cronloop.techtools.cz/api/system-metrics.json"
AGENT_STATUS="/var/www/cronloop.techtools.cz/api/agent-status.json"
ERROR_PATTERNS="/var/www/cronloop.techtools.cz/api/error-patterns.json"
COSTS="/var/www/cronloop.techtools.cz/api/costs.json"

# Initialize with defaults
SYSTEM_STATUS="unknown"
SYSTEM_STATUS_LABEL="Unknown"
MEMORY_PERCENT=0
DISK_PERCENT=0
CPU_LOAD=0
RESOURCE_STATUS="ok"
RESOURCE_WORST="cpu"
RESOURCE_WORST_VALUE=0

LAST_AGENT_RUN=""
LAST_AGENT_NAME=""
LAST_AGENT_SUCCESS=true
AGENT_STATUS_TEXT="Unknown"

ERROR_COUNT=0
ERROR_CRITICAL=0
ERROR_HIGH=0
ERROR_STATUS="ok"

COST_TODAY=0.00
COST_STATUS="ok"

# Read system metrics
if [[ -f "$SYSTEM_METRICS" ]]; then
    MEMORY_PERCENT=$(jq -r '.memory.percent // 0' "$SYSTEM_METRICS")

    # Get root disk percent
    DISK_PERCENT=$(jq -r '.disk[] | select(.mount == "/") | .percent // 0' "$SYSTEM_METRICS")

    # Get CPU load (1 min avg, normalized to percentage of cores)
    CPU_CORES=$(jq -r '.cpu.cores // 1' "$SYSTEM_METRICS")
    CPU_LOAD_RAW=$(jq -r '.cpu.load_1m // 0' "$SYSTEM_METRICS")
    CPU_LOAD=$(echo "scale=0; ($CPU_LOAD_RAW * 100 / $CPU_CORES)" | bc 2>/dev/null || echo "0")

    # Determine worst resource
    if (( MEMORY_PERCENT >= DISK_PERCENT && MEMORY_PERCENT >= CPU_LOAD )); then
        RESOURCE_WORST="memory"
        RESOURCE_WORST_VALUE=$MEMORY_PERCENT
    elif (( DISK_PERCENT >= MEMORY_PERCENT && DISK_PERCENT >= CPU_LOAD )); then
        RESOURCE_WORST="disk"
        RESOURCE_WORST_VALUE=$DISK_PERCENT
    else
        RESOURCE_WORST="cpu"
        RESOURCE_WORST_VALUE=$CPU_LOAD
    fi

    # Determine resource status (traffic light)
    if (( RESOURCE_WORST_VALUE >= 90 )); then
        RESOURCE_STATUS="critical"
    elif (( RESOURCE_WORST_VALUE >= 70 )); then
        RESOURCE_STATUS="warning"
    else
        RESOURCE_STATUS="ok"
    fi
fi

# Read agent status
if [[ -f "$AGENT_STATUS" ]]; then
    # Find the most recent agent run
    LAST_AGENT_DATA=$(jq -r '
        .agents | to_entries |
        map(select(.value.last_completed != null)) |
        sort_by(.value.last_completed) |
        last |
        {name: .key, completed: .value.last_completed, status: .value.status}
    ' "$AGENT_STATUS" 2>/dev/null || echo '{}')

    LAST_AGENT_NAME=$(echo "$LAST_AGENT_DATA" | jq -r '.name // "unknown"')
    LAST_AGENT_RUN=$(echo "$LAST_AGENT_DATA" | jq -r '.completed // ""')
    AGENT_RUN_STATUS=$(echo "$LAST_AGENT_DATA" | jq -r '.status // "unknown"')

    if [[ "$AGENT_RUN_STATUS" == "completed" ]]; then
        LAST_AGENT_SUCCESS=true
        AGENT_STATUS_TEXT="completed"
    elif [[ "$AGENT_RUN_STATUS" == "error" || "$AGENT_RUN_STATUS" == "failed" ]]; then
        LAST_AGENT_SUCCESS=false
        AGENT_STATUS_TEXT="failed"
    elif [[ "$AGENT_RUN_STATUS" == "running" ]]; then
        LAST_AGENT_SUCCESS=true
        AGENT_STATUS_TEXT="running"
    else
        AGENT_STATUS_TEXT="$AGENT_RUN_STATUS"
    fi
fi

# Read error patterns
if [[ -f "$ERROR_PATTERNS" ]]; then
    ERROR_COUNT=$(jq -r '.summary.total_errors // 0' "$ERROR_PATTERNS")
    ERROR_STATUS_RAW=$(jq -r '.summary.status // "ok"' "$ERROR_PATTERNS")

    # Count by severity from recommendations
    ERROR_CRITICAL=$(jq -r '[.recommendations[]? | select(.severity == "critical")] | length' "$ERROR_PATTERNS")
    ERROR_HIGH=$(jq -r '[.recommendations[]? | select(.severity == "high")] | length' "$ERROR_PATTERNS")

    # Determine error status
    if [[ "$ERROR_STATUS_RAW" == "critical" ]] || (( ERROR_CRITICAL > 0 )); then
        ERROR_STATUS="critical"
    elif [[ "$ERROR_STATUS_RAW" == "warning" ]] || (( ERROR_HIGH > 0 )); then
        ERROR_STATUS="warning"
    else
        ERROR_STATUS="ok"
    fi
fi

# Read costs
if [[ -f "$COSTS" ]]; then
    # Get today's cost from daily_trend
    TODAY=$(date +"%Y-%m-%d")
    COST_TODAY=$(jq -r --arg today "$TODAY" '.daily_trend[] | select(.date == $today) | .cost // 0' "$COSTS" 2>/dev/null || echo "0")

    # If no entry for today, use aggregate
    if [[ -z "$COST_TODAY" || "$COST_TODAY" == "0" || "$COST_TODAY" == "null" ]]; then
        COST_TODAY=$(jq -r '.aggregate.total_cost_usd // 0' "$COSTS")
    fi

    # Budget status from costs.json
    BUDGET_STATUS=$(jq -r '.summary.budget_status // "ok"' "$COSTS")
    DAILY_BUDGET=$(jq -r '.summary.daily_budget // 10' "$COSTS")

    if [[ "$BUDGET_STATUS" == "over" ]] || (( $(echo "$COST_TODAY > $DAILY_BUDGET" | bc -l 2>/dev/null || echo 0) == 1 )); then
        COST_STATUS="critical"
    elif [[ "$BUDGET_STATUS" == "warning" ]] || (( $(echo "$COST_TODAY > ($DAILY_BUDGET * 0.8)" | bc -l 2>/dev/null || echo 0) == 1 )); then
        COST_STATUS="warning"
    else
        COST_STATUS="ok"
    fi
fi

# Determine overall system status
# Priority: critical > warning > ok
if [[ "$RESOURCE_STATUS" == "critical" ]] || [[ "$ERROR_STATUS" == "critical" ]] || [[ "$COST_STATUS" == "critical" ]] || [[ "$LAST_AGENT_SUCCESS" == "false" ]]; then
    SYSTEM_STATUS="critical"
    SYSTEM_STATUS_LABEL="Critical"
elif [[ "$RESOURCE_STATUS" == "warning" ]] || [[ "$ERROR_STATUS" == "warning" ]] || [[ "$COST_STATUS" == "warning" ]]; then
    SYSTEM_STATUS="warning"
    SYSTEM_STATUS_LABEL="Warning"
else
    SYSTEM_STATUS="ok"
    SYSTEM_STATUS_LABEL="Healthy"
fi

# Format cost with 2 decimal places
COST_TODAY_FORMATTED=$(printf "%.2f" "$COST_TODAY" 2>/dev/null || echo "0.00")

# Generate JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "system": {
    "status": "$SYSTEM_STATUS",
    "label": "$SYSTEM_STATUS_LABEL"
  },
  "last_agent": {
    "name": "$LAST_AGENT_NAME",
    "timestamp": "$LAST_AGENT_RUN",
    "success": $LAST_AGENT_SUCCESS,
    "status": "$AGENT_STATUS_TEXT"
  },
  "errors": {
    "count": $ERROR_COUNT,
    "critical": $ERROR_CRITICAL,
    "high": $ERROR_HIGH,
    "status": "$ERROR_STATUS"
  },
  "resources": {
    "worst": "$RESOURCE_WORST",
    "percent": $RESOURCE_WORST_VALUE,
    "status": "$RESOURCE_STATUS",
    "details": {
      "cpu": $CPU_LOAD,
      "memory": $MEMORY_PERCENT,
      "disk": $DISK_PERCENT
    }
  },
  "cost": {
    "today_usd": $COST_TODAY_FORMATTED,
    "status": "$COST_STATUS"
  }
}
EOF

# Set proper permissions
chmod 644 "$OUTPUT_FILE"

echo "Pulse API updated: $OUTPUT_FILE"
