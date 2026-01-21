#!/bin/bash
# Generate weather-themed health forecast data
# Predicts system health using weather metaphors

set -euo pipefail

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/forecast-health.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/forecast-health-history.json"
METRICS_HISTORY="/var/www/cronloop.techtools.cz/api/metrics-history.json"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"

# Initialize history file if it doesn't exist
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"forecasts":[],"accuracy":{"total_predictions":0,"correct":0,"accuracy_percent":0}}' > "$HISTORY_FILE"
fi

# Get current metrics
DISK_USED=$(df / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')

MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
CPU_CORES=$(nproc)

# Calculate disk growth rate (GB per day) from metrics history
DISK_GROWTH_RATE="0.1"
if [[ -f "$METRICS_HISTORY" ]]; then
    # Get first and last disk readings
    FIRST_DISK=$(jq -r '.snapshots[0].disk.used_gb // 3' "$METRICS_HISTORY" 2>/dev/null || echo "3")
    LAST_DISK=$(jq -r '.snapshots[-1].disk.used_gb // 3' "$METRICS_HISTORY" 2>/dev/null || echo "3")
    SNAPSHOT_COUNT=$(jq -r '.snapshots | length' "$METRICS_HISTORY" 2>/dev/null || echo "1")

    if [[ "$SNAPSHOT_COUNT" -gt 1 ]]; then
        # Rough estimate: snapshots every ~30 min, so growth per day
        HOURS_SPAN=$((SNAPSHOT_COUNT / 2))
        if [[ "$HOURS_SPAN" -gt 0 ]]; then
            DISK_DIFF=$((LAST_DISK - FIRST_DISK))
            # GB per day = (disk_diff / hours) * 24
            DISK_GROWTH_RATE=$(echo "scale=2; ($DISK_DIFF / $HOURS_SPAN) * 24" | bc 2>/dev/null || echo "0.1")
        fi
    fi
fi

# Get cost data
DAILY_COST=0
DAILY_BUDGET=10
if [[ -f "$COSTS_FILE" ]]; then
    DAILY_COST=$(jq -r '.aggregate.total_cost_usd // 0' "$COSTS_FILE" 2>/dev/null || echo "0")
    DAILY_BUDGET=$(jq -r '.summary.daily_budget // 10' "$COSTS_FILE" 2>/dev/null || echo "10")
fi

# Calculate days until disk full
DISK_FREE_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,""); print $4}')
if [[ $(echo "$DISK_GROWTH_RATE > 0" | bc 2>/dev/null) == "1" ]]; then
    DAYS_UNTIL_DISK_FULL=$(echo "scale=0; $DISK_FREE_GB / $DISK_GROWTH_RATE" | bc 2>/dev/null || echo "999")
else
    DAYS_UNTIL_DISK_FULL=999
fi

# Get error count from recent agent logs
ERROR_COUNT=$(grep -ri "error\|fail\|exception" /home/novakj/actors/*/logs/*.log 2>/dev/null | wc -l || echo "0")

# Get agent success rate from recent activity
AGENT_RUNS=$(find /home/novakj/actors -name "*.log" -mtime -1 2>/dev/null | wc -l || echo "0")

# Determine weather conditions based on metrics
determine_condition() {
    local metric=$1
    local thresholds=$2  # "good,warning,bad"
    local value=$3

    IFS=',' read -r good warning bad <<< "$thresholds"

    if (( $(echo "$value < $good" | bc -l 2>/dev/null || echo "0") )); then
        echo "sunny"
    elif (( $(echo "$value < $warning" | bc -l 2>/dev/null || echo "0") )); then
        echo "cloudy"
    elif (( $(echo "$value < $bad" | bc -l 2>/dev/null || echo "0") )); then
        echo "rainy"
    else
        echo "stormy"
    fi
}

# Determine overall weather
DISK_WEATHER=$(determine_condition "disk" "50,70,90" "$DISK_PERCENT")
MEM_WEATHER=$(determine_condition "memory" "60,80,95" "$MEM_PERCENT")

# Cost weather based on percentage of budget used
COST_PERCENT=$(echo "scale=0; ($DAILY_COST / $DAILY_BUDGET) * 100" | bc 2>/dev/null || echo "0")
COST_WEATHER=$(determine_condition "cost" "50,80,100" "$COST_PERCENT")

# Determine overall conditions
get_overall_weather() {
    local worst="sunny"
    for cond in "$@"; do
        case $cond in
            stormy) worst="stormy"; break ;;
            rainy) [[ "$worst" != "stormy" ]] && worst="rainy" ;;
            cloudy) [[ "$worst" == "sunny" ]] && worst="cloudy" ;;
        esac
    done
    echo "$worst"
}

OVERALL_WEATHER=$(get_overall_weather "$DISK_WEATHER" "$MEM_WEATHER" "$COST_WEATHER")

# Weather icon mapping
get_weather_icon() {
    case $1 in
        sunny) echo "sunny" ;;
        cloudy) echo "partly_cloudy" ;;
        rainy) echo "rainy" ;;
        stormy) echo "stormy" ;;
        *) echo "sunny" ;;
    esac
}

# Generate weather descriptions
get_weather_desc() {
    case $1 in
        sunny) echo "Clear skies ahead - all systems healthy" ;;
        cloudy) echo "Minor concerns on the horizon - monitoring recommended" ;;
        rainy) echo "Issues developing - attention required" ;;
        stormy) echo "Critical conditions - immediate action needed" ;;
        *) echo "Conditions unknown" ;;
    esac
}

# Calculate precipitation chance (chance of errors)
PRECIP_CHANCE=5
if [[ "$ERROR_COUNT" -gt 10 ]]; then
    PRECIP_CHANCE=$((ERROR_COUNT * 2))
    [[ "$PRECIP_CHANCE" -gt 95 ]] && PRECIP_CHANCE=95
fi

# Barometric pressure (system load trend)
PRESSURE="stable"
CURRENT_LOAD=$(echo "$CPU_LOAD" | cut -d. -f1)
if [[ "$CURRENT_LOAD" -gt 2 ]]; then
    PRESSURE="falling"
elif [[ "$CURRENT_LOAD" -lt 1 ]]; then
    PRESSURE="rising"
fi

# Generate 24-hour forecast
generate_hourly_forecast() {
    local hours=()
    local now=$(date +%H)

    for i in {0..23}; do
        local hour=$(( (now + i) % 24 ))
        local hour_str=$(printf "%02d:00" "$hour")

        # Vary conditions slightly based on typical patterns
        local condition="$OVERALL_WEATHER"
        local temp=$((60 + RANDOM % 20))  # "Temperature" as system health score

        # Agent runs every 30 min, so activity peaks
        if [[ $((hour % 2)) -eq 0 ]]; then
            temp=$((temp - 5))  # Slightly more load during agent runs
        fi

        # Night hours (2-6 AM) typically quieter
        if [[ "$hour" -ge 2 && "$hour" -le 6 ]]; then
            condition="sunny"
            temp=$((temp + 10))
        fi

        hours+=("{\"hour\":\"$hour_str\",\"condition\":\"$condition\",\"health_score\":$temp}")
    done

    echo "[$(IFS=,; echo "${hours[*]}")]"
}

# Generate 7-day extended forecast
generate_daily_forecast() {
    local days=()

    for i in {0..6}; do
        local date=$(date -d "+$i days" +%Y-%m-%d)
        local day_name=$(date -d "+$i days" +%a)

        # Project disk usage
        local projected_disk=$((DISK_PERCENT + (i * 1)))  # Assume ~1% growth per day
        [[ "$projected_disk" -gt 100 ]] && projected_disk=99

        local condition="sunny"
        if [[ "$projected_disk" -gt 80 ]]; then
            condition="stormy"
        elif [[ "$projected_disk" -gt 70 ]]; then
            condition="rainy"
        elif [[ "$projected_disk" -gt 60 ]]; then
            condition="cloudy"
        fi

        # Trend based on condition progression
        local trend="stable"
        if [[ "$i" -gt 0 ]]; then
            local prev_disk=$((DISK_PERCENT + ((i-1) * 1)))
            if [[ "$projected_disk" -gt "$prev_disk" ]]; then
                trend="degrading"
            elif [[ "$projected_disk" -lt "$prev_disk" ]]; then
                trend="improving"
            fi
        fi

        local health_score=$((100 - projected_disk))

        days+=("{\"date\":\"$date\",\"day\":\"$day_name\",\"condition\":\"$condition\",\"trend\":\"$trend\",\"projected_disk_percent\":$projected_disk,\"health_score\":$health_score}")
    done

    echo "[$(IFS=,; echo "${days[*]}")]"
}

# Generate alerts
generate_alerts() {
    local alerts=()

    # Disk alerts
    if [[ "$DAYS_UNTIL_DISK_FULL" -lt 7 ]]; then
        alerts+=("{\"type\":\"storm_warning\",\"severity\":\"critical\",\"message\":\"Disk full in approximately $DAYS_UNTIL_DISK_FULL days at current growth rate\",\"metric\":\"disk\",\"recommendation\":\"Run cleanup scripts or expand storage\"}")
    elif [[ "$DAYS_UNTIL_DISK_FULL" -lt 30 ]]; then
        alerts+=("{\"type\":\"rain_watch\",\"severity\":\"warning\",\"message\":\"Disk approaching capacity in $DAYS_UNTIL_DISK_FULL days\",\"metric\":\"disk\",\"recommendation\":\"Plan storage maintenance soon\"}")
    fi

    # Memory alerts
    if [[ "$MEM_PERCENT" -gt 90 ]]; then
        alerts+=("{\"type\":\"heat_advisory\",\"severity\":\"critical\",\"message\":\"Memory usage critically high at ${MEM_PERCENT}%\",\"metric\":\"memory\",\"recommendation\":\"Identify and restart memory-hungry processes\"}")
    elif [[ "$MEM_PERCENT" -gt 80 ]]; then
        alerts+=("{\"type\":\"heat_warning\",\"severity\":\"warning\",\"message\":\"Memory usage elevated at ${MEM_PERCENT}%\",\"metric\":\"memory\",\"recommendation\":\"Monitor for memory leaks\"}")
    fi

    # Cost alerts
    if [[ $(echo "$DAILY_COST > $DAILY_BUDGET" | bc 2>/dev/null) == "1" ]]; then
        alerts+=("{\"type\":\"budget_drought\",\"severity\":\"warning\",\"message\":\"Daily spending (\$$(printf "%.2f" "$DAILY_COST")) exceeds budget (\$$DAILY_BUDGET)\",\"metric\":\"cost\",\"recommendation\":\"Review agent activity and token usage\"}")
    fi

    if [[ ${#alerts[@]} -eq 0 ]]; then
        echo "[]"
    else
        echo "[$(IFS=,; echo "${alerts[*]}")]"
    fi
}

# Generate "feels like" summary
generate_feels_like() {
    local factors=()
    local score=100

    # Disk impact
    if [[ "$DISK_PERCENT" -gt 70 ]]; then
        score=$((score - 20))
        factors+=("\"high disk usage\"")
    fi

    # Memory impact
    if [[ "$MEM_PERCENT" -gt 80 ]]; then
        score=$((score - 25))
        factors+=("\"elevated memory\"")
    fi

    # Cost impact
    if [[ $(echo "$DAILY_COST > $DAILY_BUDGET" | bc 2>/dev/null) == "1" ]]; then
        score=$((score - 15))
        factors+=("\"budget overrun\"")
    fi

    # Error impact
    if [[ "$ERROR_COUNT" -gt 5 ]]; then
        score=$((score - 10))
        factors+=("\"recent errors\"")
    fi

    [[ "$score" -lt 0 ]] && score=0

    local desc="Healthy conditions"
    if [[ "$score" -lt 40 ]]; then
        desc="Heavy load - multiple concerns"
    elif [[ "$score" -lt 60 ]]; then
        desc="Moderate pressure"
    elif [[ "$score" -lt 80 ]]; then
        desc="Mostly comfortable"
    fi

    local factors_json="[]"
    if [[ ${#factors[@]} -gt 0 ]]; then
        factors_json="[$(IFS=,; echo "${factors[*]}")]"
    fi

    echo "{\"score\":$score,\"description\":\"$desc\",\"factors\":$factors_json}"
}

# Get accuracy from history
get_accuracy() {
    if [[ -f "$HISTORY_FILE" ]]; then
        jq -r '.accuracy // {"total_predictions":0,"correct":0,"accuracy_percent":0}' "$HISTORY_FILE" 2>/dev/null || echo '{"total_predictions":0,"correct":0,"accuracy_percent":0}'
    else
        echo '{"total_predictions":0,"correct":0,"accuracy_percent":0}'
    fi
}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build the JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "current_conditions": {
    "overall": "$OVERALL_WEATHER",
    "icon": "$(get_weather_icon "$OVERALL_WEATHER")",
    "description": "$(get_weather_desc "$OVERALL_WEATHER")",
    "precipitation_chance": $PRECIP_CHANCE,
    "barometric_pressure": "$PRESSURE"
  },
  "metrics": {
    "disk": {
      "condition": "$DISK_WEATHER",
      "current_percent": $DISK_PERCENT,
      "days_until_full": $DAYS_UNTIL_DISK_FULL,
      "growth_rate_gb_day": $DISK_GROWTH_RATE,
      "forecast": "$(if [[ "$DISK_WEATHER" == "sunny" ]]; then echo "Clear skies - plenty of storage"; elif [[ "$DISK_WEATHER" == "cloudy" ]]; then echo "Light clouds - storage filling gradually"; elif [[ "$DISK_WEATHER" == "rainy" ]]; then echo "Rain approaching - storage becoming tight"; else echo "Storm warning - storage critical"; fi)"
    },
    "memory": {
      "condition": "$MEM_WEATHER",
      "current_percent": $MEM_PERCENT,
      "used_mb": $MEM_USED,
      "total_mb": $MEM_TOTAL,
      "forecast": "$(if [[ "$MEM_WEATHER" == "sunny" ]]; then echo "Cool temperatures - memory comfortable"; elif [[ "$MEM_WEATHER" == "cloudy" ]]; then echo "Warming up - memory usage moderate"; elif [[ "$MEM_WEATHER" == "rainy" ]]; then echo "Heat building - memory pressure"; else echo "Heat wave - memory critical"; fi)"
    },
    "cost": {
      "condition": "$COST_WEATHER",
      "current_usd": $DAILY_COST,
      "budget_usd": $DAILY_BUDGET,
      "percent_of_budget": $COST_PERCENT,
      "forecast": "$(if [[ "$COST_WEATHER" == "sunny" ]]; then echo "Abundant resources - budget healthy"; elif [[ "$COST_WEATHER" == "cloudy" ]]; then echo "Resources moderate - budget on track"; elif [[ "$COST_WEATHER" == "rainy" ]]; then echo "Drought approaching - budget tight"; else echo "Severe drought - budget exceeded"; fi)"
    },
    "cpu": {
      "load_average": $CPU_LOAD,
      "cores": $CPU_CORES,
      "pressure": "$PRESSURE"
    }
  },
  "hourly_forecast": $(generate_hourly_forecast),
  "daily_forecast": $(generate_daily_forecast),
  "alerts": $(generate_alerts),
  "feels_like": $(generate_feels_like),
  "accuracy": $(get_accuracy)
}
EOF

echo "Weather forecast generated at $OUTPUT_FILE"
