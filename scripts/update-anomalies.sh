#!/bin/bash
# update-anomalies.sh - System anomaly detection using statistical analysis
# Detects unusual patterns by comparing current metrics against learned baselines
#
# Created: 2026-01-20
# Task: TASK-081

# Output files
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/anomalies.json"
BASELINE_FILE="/var/www/cronloop.techtools.cz/api/anomaly-baselines.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/anomaly-history.json"

# Data source files
METRICS_HISTORY="/var/www/cronloop.techtools.cz/api/metrics-history.json"
SECURITY_METRICS="/var/www/cronloop.techtools.cz/api/security-metrics.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
ERROR_PATTERNS="/var/www/cronloop.techtools.cz/api/error-patterns.json"

# Configuration
SENSITIVITY=${ANOMALY_SENSITIVITY:-2.0}
MIN_DATAPOINTS=5

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

# Calculate mean of values (using awk for reliability)
calc_mean() {
    echo "$@" | tr ' ' '\n' | awk 'BEGIN{s=0;c=0} /^[0-9.]+$/{s+=$1;c++} END{if(c>0)printf "%.4f",s/c; else print "0"}'
}

# Calculate standard deviation (using awk)
calc_stddev() {
    local mean=$1
    shift
    echo "$@" | tr ' ' '\n' | awk -v m="$mean" 'BEGIN{s=0;c=0} /^[0-9.]+$/{d=$1-m;s+=d*d;c++} END{if(c>1)printf "%.4f",sqrt(s/(c-1)); else print "0"}'
}

# Check if value is anomalous
is_anomaly() {
    local value=$1
    local mean=$2
    local stddev=$3
    local sensitivity=$4

    awk -v v="$value" -v m="$mean" -v s="$stddev" -v sens="$sensitivity" 'BEGIN {
        if (s < 0.001) {
            threshold = m * 0.1
            if (threshold < 1) threshold = 1
            diff = v - m
            if (diff < 0) diff = -diff
            if (diff > threshold) print "1"; else print "0"
        } else {
            lower = m - sens * s
            upper = m + sens * s
            if (v < lower || v > upper) print "1"; else print "0"
        }
    }'
}

# Calculate deviation amount
calc_deviation() {
    local value=$1
    local mean=$2
    local stddev=$3

    awk -v v="$value" -v m="$mean" -v s="$stddev" 'BEGIN {
        if (s < 0.001) { print "0" }
        else { printf "%.2f", (v - m) / s }
    }'
}

# Get severity based on deviation
get_severity() {
    local deviation=$1
    deviation=${deviation#-}

    awk -v d="$deviation" 'BEGIN {
        if (d >= 4) print "critical"
        else if (d >= 3) print "high"
        else if (d >= 2) print "medium"
        else print "low"
    }'
}

# Calculate baselines from historical data
calculate_baselines() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Use jq to build the entire baselines JSON properly
    local metrics_json='{'
    local first=true

    # Memory baseline
    if [[ -f "$METRICS_HISTORY" ]]; then
        local mem_values=$(jq -r '.snapshots[-48:] | .[].memory.percent // empty' "$METRICS_HISTORY" 2>/dev/null | tr '\n' ' ')
        if [ -n "$mem_values" ]; then
            local mem_array=($mem_values)
            if [ ${#mem_array[@]} -ge $MIN_DATAPOINTS ]; then
                local mem_mean=$(calc_mean "${mem_array[@]}")
                local mem_stddev=$(calc_stddev "$mem_mean" "${mem_array[@]}")
                [ "$first" = false ] && metrics_json+=','
                first=false
                metrics_json+="\"memory_percent\":{\"mean\":$mem_mean,\"stddev\":$mem_stddev,\"samples\":${#mem_array[@]},\"category\":\"resource\"}"
            fi
        fi

        # CPU baseline
        local cpu_values=$(jq -r '.snapshots[-48:] | .[].cpu.load_ratio // empty' "$METRICS_HISTORY" 2>/dev/null | tr '\n' ' ')
        if [ -n "$cpu_values" ]; then
            local cpu_array=($cpu_values)
            if [ ${#cpu_array[@]} -ge $MIN_DATAPOINTS ]; then
                local cpu_mean=$(calc_mean "${cpu_array[@]}")
                local cpu_stddev=$(calc_stddev "$cpu_mean" "${cpu_array[@]}")
                [ "$first" = false ] && metrics_json+=','
                first=false
                metrics_json+="\"cpu_load_ratio\":{\"mean\":$cpu_mean,\"stddev\":$cpu_stddev,\"samples\":${#cpu_array[@]},\"category\":\"resource\"}"
            fi
        fi

        # Disk baseline
        local disk_values=$(jq -r '.snapshots[-48:] | .[].disk.percent // empty' "$METRICS_HISTORY" 2>/dev/null | tr '\n' ' ')
        if [ -n "$disk_values" ]; then
            local disk_array=($disk_values)
            if [ ${#disk_array[@]} -ge $MIN_DATAPOINTS ]; then
                local disk_mean=$(calc_mean "${disk_array[@]}")
                local disk_stddev=$(calc_stddev "$disk_mean" "${disk_array[@]}")
                [ "$first" = false ] && metrics_json+=','
                first=false
                metrics_json+="\"disk_percent\":{\"mean\":$disk_mean,\"stddev\":$disk_stddev,\"samples\":${#disk_array[@]},\"category\":\"resource\"}"
            fi
        fi
    fi

    # Security metrics
    if [[ -f "$SECURITY_METRICS" ]]; then
        local ssh_attempts=$(jq -r '.ssh_attacks.total_attempts // 0' "$SECURITY_METRICS" 2>/dev/null)
        local unique_ips=$(jq -r '.ssh_attacks.unique_ips // 0' "$SECURITY_METRICS" 2>/dev/null)

        [ "$first" = false ] && metrics_json+=','
        first=false
        local ssh_stddev=$(awk -v x="$ssh_attempts" 'BEGIN{printf "%.4f", x * 0.2}')
        metrics_json+="\"ssh_attempts\":{\"mean\":$ssh_attempts,\"stddev\":$ssh_stddev,\"samples\":1,\"category\":\"security\"}"

        metrics_json+=','
        local ip_stddev=$(awk -v x="$unique_ips" 'BEGIN{printf "%.4f", x * 0.2}')
        metrics_json+="\"unique_attackers\":{\"mean\":$unique_ips,\"stddev\":$ip_stddev,\"samples\":1,\"category\":\"security\"}"
    fi

    # Cost metrics
    if [[ -f "$COSTS_FILE" ]]; then
        local total_tokens=$(jq -r '.aggregate.total_tokens // 0' "$COSTS_FILE" 2>/dev/null)
        local total_cost=$(jq -r '.aggregate.total_cost_usd // 0' "$COSTS_FILE" 2>/dev/null)

        [ "$first" = false ] && metrics_json+=','
        first=false
        local token_stddev=$(awk -v x="$total_tokens" 'BEGIN{printf "%.4f", x * 0.3}')
        metrics_json+="\"token_usage\":{\"mean\":$total_tokens,\"stddev\":$token_stddev,\"samples\":1,\"category\":\"cost\"}"

        metrics_json+=','
        local cost_stddev=$(awk -v x="$total_cost" 'BEGIN{printf "%.6f", x * 0.3}')
        metrics_json+="\"cost_usd\":{\"mean\":$total_cost,\"stddev\":$cost_stddev,\"samples\":1,\"category\":\"cost\"}"
    fi

    # Error metrics
    if [[ -f "$ERROR_PATTERNS" ]]; then
        local error_count=$(jq -r '.summary.total_errors // 0' "$ERROR_PATTERNS" 2>/dev/null)
        local health_score=$(jq -r '.summary.health_score // 100' "$ERROR_PATTERNS" 2>/dev/null)

        [ "$first" = false ] && metrics_json+=','
        first=false
        local error_stddev=$(awk -v x="$error_count" 'BEGIN{printf "%.4f", x * 0.5 + 1}')
        metrics_json+="\"error_count\":{\"mean\":$error_count,\"stddev\":$error_stddev,\"samples\":1,\"category\":\"agent\"}"

        metrics_json+=','
        metrics_json+="\"error_health_score\":{\"mean\":$health_score,\"stddev\":10,\"samples\":1,\"category\":\"agent\"}"
    fi

    metrics_json+='}'

    echo "{\"timestamp\":\"$timestamp\",\"sensitivity\":$SENSITIVITY,\"metrics\":$metrics_json}"
}

# Detect anomalies
detect_anomalies() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create baselines if not exists
    if [[ ! -f "$BASELINE_FILE" ]]; then
        echo "Creating initial baselines..."
        calculate_baselines > "$BASELINE_FILE"
    fi

    # Read baselines
    local baselines=$(cat "$BASELINE_FILE" 2>/dev/null)

    # Arrays to collect anomalies
    local anomalies_json='['
    local first_anomaly=true
    local anomaly_count=0
    local critical_count=0
    local high_count=0
    local medium_count=0

    # Check memory
    if [[ -f "$METRICS_HISTORY" ]]; then
        local current_mem=$(jq -r '.snapshots[-1].memory.percent // 0' "$METRICS_HISTORY" 2>/dev/null)
        local mem_mean=$(echo "$baselines" | jq -r '.metrics.memory_percent.mean // 0' 2>/dev/null)
        local mem_stddev=$(echo "$baselines" | jq -r '.metrics.memory_percent.stddev // 0' 2>/dev/null)

        if [[ "$mem_mean" != "null" && "$mem_mean" != "0" && -n "$mem_mean" ]]; then
            local is_mem_anom=$(is_anomaly "$current_mem" "$mem_mean" "$mem_stddev" "$SENSITIVITY")
            if [ "$is_mem_anom" = "1" ]; then
                local deviation=$(calc_deviation "$current_mem" "$mem_mean" "$mem_stddev")
                local severity=$(get_severity "$deviation")
                [ "$first_anomaly" = false ] && anomalies_json+=','
                first_anomaly=false
                anomalies_json+="{\"metric\":\"memory_percent\",\"category\":\"resource\",\"current\":$current_mem,\"baseline\":$mem_mean,\"stddev\":$mem_stddev,\"deviation\":$deviation,\"severity\":\"$severity\",\"timestamp\":\"$timestamp\",\"message\":\"Memory usage is $deviation standard deviations from baseline\"}"
                ((anomaly_count++))
                case $severity in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; esac
            fi
        fi

        # Check CPU
        local current_cpu=$(jq -r '.snapshots[-1].cpu.load_ratio // 0' "$METRICS_HISTORY" 2>/dev/null)
        local cpu_mean=$(echo "$baselines" | jq -r '.metrics.cpu_load_ratio.mean // 0' 2>/dev/null)
        local cpu_stddev=$(echo "$baselines" | jq -r '.metrics.cpu_load_ratio.stddev // 0' 2>/dev/null)

        if [[ "$cpu_mean" != "null" && "$cpu_mean" != "0" && -n "$cpu_mean" ]]; then
            local is_cpu_anom=$(is_anomaly "$current_cpu" "$cpu_mean" "$cpu_stddev" "$SENSITIVITY")
            if [ "$is_cpu_anom" = "1" ]; then
                local deviation=$(calc_deviation "$current_cpu" "$cpu_mean" "$cpu_stddev")
                local severity=$(get_severity "$deviation")
                [ "$first_anomaly" = false ] && anomalies_json+=','
                first_anomaly=false
                anomalies_json+="{\"metric\":\"cpu_load_ratio\",\"category\":\"resource\",\"current\":$current_cpu,\"baseline\":$cpu_mean,\"stddev\":$cpu_stddev,\"deviation\":$deviation,\"severity\":\"$severity\",\"timestamp\":\"$timestamp\",\"message\":\"CPU load is $deviation standard deviations from baseline\"}"
                ((anomaly_count++))
                case $severity in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; esac
            fi
        fi

        # Check disk
        local current_disk=$(jq -r '.snapshots[-1].disk.percent // 0' "$METRICS_HISTORY" 2>/dev/null)
        local disk_mean=$(echo "$baselines" | jq -r '.metrics.disk_percent.mean // 0' 2>/dev/null)
        local disk_stddev=$(echo "$baselines" | jq -r '.metrics.disk_percent.stddev // 0' 2>/dev/null)

        if [[ "$disk_mean" != "null" && "$disk_mean" != "0" && -n "$disk_mean" ]]; then
            local is_disk_anom=$(is_anomaly "$current_disk" "$disk_mean" "$disk_stddev" "$SENSITIVITY")
            if [ "$is_disk_anom" = "1" ]; then
                local deviation=$(calc_deviation "$current_disk" "$disk_mean" "$disk_stddev")
                local severity=$(get_severity "$deviation")
                [ "$first_anomaly" = false ] && anomalies_json+=','
                first_anomaly=false
                anomalies_json+="{\"metric\":\"disk_percent\",\"category\":\"resource\",\"current\":$current_disk,\"baseline\":$disk_mean,\"stddev\":$disk_stddev,\"deviation\":$deviation,\"severity\":\"$severity\",\"timestamp\":\"$timestamp\",\"message\":\"Disk usage is $deviation standard deviations from baseline\"}"
                ((anomaly_count++))
                case $severity in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; esac
            fi
        fi
    fi

    # Check error count
    if [[ -f "$ERROR_PATTERNS" ]]; then
        local current_errors=$(jq -r '.summary.total_errors // 0' "$ERROR_PATTERNS" 2>/dev/null)
        local error_mean=$(echo "$baselines" | jq -r '.metrics.error_count.mean // 0' 2>/dev/null)
        local error_stddev=$(echo "$baselines" | jq -r '.metrics.error_count.stddev // 1' 2>/dev/null)

        if [[ "$error_mean" != "null" && "$current_errors" != "0" && -n "$error_mean" ]]; then
            local is_error_anom=$(is_anomaly "$current_errors" "$error_mean" "$error_stddev" "$SENSITIVITY")
            if [ "$is_error_anom" = "1" ]; then
                local deviation=$(calc_deviation "$current_errors" "$error_mean" "$error_stddev")
                local severity=$(get_severity "$deviation")
                [ "$first_anomaly" = false ] && anomalies_json+=','
                first_anomaly=false
                anomalies_json+="{\"metric\":\"error_count\",\"category\":\"agent\",\"current\":$current_errors,\"baseline\":$error_mean,\"stddev\":$error_stddev,\"deviation\":$deviation,\"severity\":\"$severity\",\"timestamp\":\"$timestamp\",\"message\":\"Agent error count is $deviation standard deviations from baseline\"}"
                ((anomaly_count++))
                case $severity in critical) ((critical_count++));; high) ((high_count++));; medium) ((medium_count++));; esac
            fi
        fi
    fi

    anomalies_json+=']'

    # Determine status
    local status="ok"
    if [ $critical_count -gt 0 ]; then
        status="critical"
    elif [ $high_count -gt 0 ]; then
        status="warning"
    elif [ $medium_count -gt 0 ] || [ $anomaly_count -gt 0 ]; then
        status="info"
    fi

    # Get baseline info
    local baseline_timestamp=$(echo "$baselines" | jq -r '.timestamp // ""' 2>/dev/null)
    local metrics_count=$(echo "$baselines" | jq -r '.metrics | keys | length' 2>/dev/null)

    # Build output
    cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "summary": {
    "total_anomalies": $anomaly_count,
    "critical": $critical_count,
    "high": $high_count,
    "medium": $medium_count,
    "metrics_monitored": ${metrics_count:-0}
  },
  "baseline": {
    "last_updated": "$baseline_timestamp",
    "sensitivity": $SENSITIVITY,
    "description": "Anomalies detected when values exceed $SENSITIVITY standard deviations from baseline"
  },
  "anomalies": $anomalies_json,
  "baselines": $(echo "$baselines" | jq '.metrics' 2>/dev/null || echo '{}')
}
EOF

    # Update history
    local history_entry="{\"timestamp\":\"$timestamp\",\"status\":\"$status\",\"total\":$anomaly_count,\"critical\":$critical_count,\"high\":$high_count,\"medium\":$medium_count}"

    if [[ -f "$HISTORY_FILE" ]]; then
        local updated_history=$(jq --argjson entry "$history_entry" '. + [$entry] | .[-100:]' "$HISTORY_FILE" 2>/dev/null || echo "[$history_entry]")
        echo "$updated_history" > "$HISTORY_FILE"
    else
        echo "[$history_entry]" > "$HISTORY_FILE"
    fi

    echo "Anomaly detection completed: $anomaly_count anomalies ($critical_count critical, $high_count high, $medium_count medium)"
}

# Update baselines
update_baselines() {
    echo "Updating baselines..."
    calculate_baselines > "$BASELINE_FILE"
    echo "Baselines updated at $BASELINE_FILE"
}

# Main
case "${1:-detect}" in
    init|update)
        update_baselines
        ;;
    detect|*)
        detect_anomalies
        ;;
esac
