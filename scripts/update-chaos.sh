#!/bin/bash
# update-chaos.sh - Generate chaos engineering data and resilience scores
# Part of the CronLoop autonomous AI system

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$API_DIR/chaos-results.json"
METRICS_FILE="$API_DIR/system-metrics.json"
AGENT_STATUS_FILE="$API_DIR/agent-status.json"
ERROR_PATTERNS_FILE="$API_DIR/error-patterns.json"

# Ensure API directory exists
mkdir -p "$API_DIR"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Read system metrics for resilience calculation
if [[ -f "$METRICS_FILE" ]]; then
    DISK_PERCENT=$(jq -r '.disk[0].percent // 5' "$METRICS_FILE")
    MEMORY_PERCENT=$(jq -r '.memory.percent // 12' "$METRICS_FILE")
    CPU_LOAD=$(jq -r '.cpu.load_1m // 0.1' "$METRICS_FILE")
    CPU_CORES=$(jq -r '.cpu.cores // 4' "$METRICS_FILE")
else
    DISK_PERCENT=5
    MEMORY_PERCENT=12
    CPU_LOAD=0.1
    CPU_CORES=4
fi

# Calculate CPU percentage (load / cores * 100)
CPU_PERCENT=$(echo "scale=0; ($CPU_LOAD / $CPU_CORES) * 100" | bc 2>/dev/null || echo "5")

# Read error patterns for agent resilience
if [[ -f "$ERROR_PATTERNS_FILE" ]]; then
    TOTAL_ERRORS=$(jq -r '.total_errors // 0' "$ERROR_PATTERNS_FILE")
    TOTAL_LOGS=$(jq -r '.total_logs_scanned // 1' "$ERROR_PATTERNS_FILE")
else
    TOTAL_ERRORS=0
    TOTAL_LOGS=1
fi

# Calculate resilience scores (higher is better)
# Disk resilience: based on free space (95 - usage gives room to handle growth)
DISK_RESILIENCE=$((95 - DISK_PERCENT))
[[ $DISK_RESILIENCE -gt 95 ]] && DISK_RESILIENCE=95
[[ $DISK_RESILIENCE -lt 10 ]] && DISK_RESILIENCE=10

# CPU resilience: based on available headroom
CPU_RESILIENCE=$((95 - CPU_PERCENT))
[[ $CPU_RESILIENCE -gt 95 ]] && CPU_RESILIENCE=95
[[ $CPU_RESILIENCE -lt 10 ]] && CPU_RESILIENCE=10

# Memory resilience: based on available memory
MEMORY_RESILIENCE=$((95 - MEMORY_PERCENT))
[[ $MEMORY_RESILIENCE -gt 95 ]] && MEMORY_RESILIENCE=95
[[ $MEMORY_RESILIENCE -lt 10 ]] && MEMORY_RESILIENCE=10

# Network resilience: assume good unless we have evidence otherwise
NETWORK_RESILIENCE=88

# Agent resilience: based on error rate
if [[ $TOTAL_LOGS -gt 0 ]]; then
    ERROR_RATE=$(echo "scale=2; ($TOTAL_ERRORS / $TOTAL_LOGS) * 100" | bc 2>/dev/null || echo "5")
    AGENT_RESILIENCE=$(echo "scale=0; 95 - $ERROR_RATE" | bc 2>/dev/null || echo "85")
else
    AGENT_RESILIENCE=90
fi
[[ $AGENT_RESILIENCE -gt 95 ]] && AGENT_RESILIENCE=95
[[ $AGENT_RESILIENCE -lt 10 ]] && AGENT_RESILIENCE=10

# Calculate overall resilience (weighted average)
OVERALL_RESILIENCE=$(echo "scale=0; ($DISK_RESILIENCE * 20 + $CPU_RESILIENCE * 25 + $MEMORY_RESILIENCE * 25 + $NETWORK_RESILIENCE * 15 + $AGENT_RESILIENCE * 15) / 100" | bc 2>/dev/null || echo "85")

# Load existing experiments or start fresh
if [[ -f "$OUTPUT_FILE" ]]; then
    EXISTING_EXPERIMENTS=$(jq -c '.experiments // []' "$OUTPUT_FILE" 2>/dev/null || echo "[]")
else
    EXISTING_EXPERIMENTS="[]"
fi

# Generate the chaos results JSON
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "resilience": {
    "overall": $OVERALL_RESILIENCE,
    "disk": $DISK_RESILIENCE,
    "cpu": $CPU_RESILIENCE,
    "memory": $MEMORY_RESILIENCE,
    "network": $NETWORK_RESILIENCE,
    "agent": $AGENT_RESILIENCE
  },
  "experiments": $EXISTING_EXPERIMENTS,
  "system_state": {
    "disk_percent": $DISK_PERCENT,
    "memory_percent": $MEMORY_PERCENT,
    "cpu_percent": ${CPU_PERCENT:-5},
    "total_errors": $TOTAL_ERRORS,
    "total_logs": $TOTAL_LOGS
  },
  "thresholds": {
    "disk_warning": 80,
    "disk_critical": 90,
    "memory_warning": 80,
    "memory_critical": 90,
    "cpu_warning": 70,
    "cpu_critical": 90
  },
  "last_updated": "$TIMESTAMP"
}
EOF

# Validate JSON output
if jq empty "$OUTPUT_FILE" 2>/dev/null; then
    echo "Chaos data updated successfully at $TIMESTAMP"
    echo "Overall Resilience Score: $OVERALL_RESILIENCE%"
else
    echo "Error: Invalid JSON generated"
    exit 1
fi
