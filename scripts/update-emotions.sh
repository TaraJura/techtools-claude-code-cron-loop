#!/bin/bash
# update-emotions.sh - Analyzes agent outputs for emotional/behavioral indicators
# Output: JSON data for the emotions.html dashboard
# Analyzes: frustration patterns, confidence markers, struggle behaviors

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/emotions.json"
LOG_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)

# Agent colors for UI
declare -A AGENT_COLORS
AGENT_COLORS["idea-maker"]="#eab308"
AGENT_COLORS["project-manager"]="#a855f7"
AGENT_COLORS["developer"]="#3b82f6"
AGENT_COLORS["developer2"]="#06b6d4"
AGENT_COLORS["tester"]="#22c55e"
AGENT_COLORS["security"]="#ef4444"

# Frustration indicators (phrases that suggest difficulty)
FRUSTRATION_PATTERNS=(
    "let me try again"
    "that didn't work"
    "try a different"
    "failed to"
    "error occurred"
    "unable to"
    "cannot find"
    "not found"
    "doesn't exist"
    "retry"
    "attempt again"
    "still not working"
    "issue persists"
)

# Confidence markers (positive)
CONFIDENCE_POSITIVE=(
    "successfully"
    "completed"
    "this will"
    "correctly"
    "working as expected"
    "verified"
    "confirmed"
    "done"
    "finished"
)

# Uncertainty markers (suggests lower confidence)
UNCERTAINTY_MARKERS=(
    "I think"
    "probably"
    "might"
    "should work"
    "hopefully"
    "I believe"
    "perhaps"
    "possibly"
    "may need"
)

# Analyze a single log file and return emotional indicators
analyze_log() {
    local log_file="$1"
    local agent="$2"

    if [ ! -f "$log_file" ]; then
        echo "null"
        return
    fi

    local content=$(cat "$log_file" 2>/dev/null || echo "")
    local content_lower=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    # Count frustration indicators
    local frustration_count=0
    for pattern in "${FRUSTRATION_PATTERNS[@]}"; do
        local count=$(echo "$content_lower" | grep -o "$pattern" | wc -l)
        frustration_count=$((frustration_count + count))
    done

    # Count confidence positive markers
    local confidence_positive=0
    for pattern in "${CONFIDENCE_POSITIVE[@]}"; do
        local count=$(echo "$content_lower" | grep -o "$pattern" | wc -l)
        confidence_positive=$((confidence_positive + count))
    done

    # Count uncertainty markers
    local uncertainty_count=0
    for pattern in "${UNCERTAINTY_MARKERS[@]}"; do
        local count=$(echo "$content_lower" | grep -o "$pattern" | wc -l)
        uncertainty_count=$((uncertainty_count + count))
    done

    # Count tool call retries (same tool called multiple times)
    local read_calls=$(echo "$content" | grep -c "Read" || echo 0)
    local edit_calls=$(echo "$content" | grep -c "Edit" || echo 0)
    local bash_calls=$(echo "$content" | grep -c "Bash" || echo 0)

    # Calculate confidence score (0-100)
    local total_markers=$((confidence_positive + uncertainty_count))
    local confidence_score=70
    if [ $total_markers -gt 0 ]; then
        confidence_score=$(( (confidence_positive * 100) / total_markers ))
        if [ $confidence_score -gt 100 ]; then confidence_score=100; fi
        if [ $confidence_score -lt 0 ]; then confidence_score=0; fi
    fi

    # Calculate frustration level (0-100)
    local frustration_level=0
    if [ $frustration_count -gt 0 ]; then
        frustration_level=$((frustration_count * 15))
        if [ $frustration_level -gt 100 ]; then frustration_level=100; fi
    fi

    # Determine mood based on metrics
    local mood="calm"
    if [ $frustration_level -gt 50 ]; then
        mood="frustrated"
    elif [ $frustration_level -gt 25 ]; then
        mood="struggling"
    elif [ $confidence_score -lt 50 ]; then
        mood="uncertain"
    elif [ $confidence_score -gt 80 ] && [ $frustration_level -lt 10 ]; then
        mood="confident"
    fi

    # Get log timestamp
    local log_time=$(basename "$log_file" .log | sed 's/_/T/' | sed 's/\(....\)\(..\)\(..\)T\(..\)\(..\)\(..\)/\1-\2-\3T\4:\5:\6Z/')

    echo "{\"timestamp\":\"$log_time\",\"frustration\":$frustration_level,\"confidence\":$confidence_score,\"mood\":\"$mood\",\"frustration_count\":$frustration_count,\"uncertainty_count\":$uncertainty_count,\"positive_count\":$confidence_positive}"
}

# Get emotional state for an agent (last 24 hours)
get_agent_emotions() {
    local agent="$1"
    local agent_log_dir="$LOG_DIR/$agent/logs"

    if [ ! -d "$agent_log_dir" ]; then
        echo "[]"
        return
    fi

    local entries="["
    local first=true
    local cutoff=$(date -d "24 hours ago" +%Y%m%d%H%M%S 2>/dev/null || date +%Y%m%d%H%M%S)

    # Get recent logs (last 24 hours)
    for log_file in "$agent_log_dir"/*.log; do
        if [ -f "$log_file" ]; then
            local log_ts=$(basename "$log_file" .log | tr -d '_')
            if [ "$log_ts" -ge "$cutoff" ] 2>/dev/null; then
                local analysis=$(analyze_log "$log_file" "$agent")
                if [ "$analysis" != "null" ]; then
                    if [ "$first" = true ]; then
                        first=false
                    else
                        entries+=","
                    fi
                    entries+="$analysis"
                fi
            fi
        fi
    done

    entries+="]"
    echo "$entries"
}

# Calculate overall emotional health for an agent
calculate_emotional_health() {
    local agent="$1"
    local emotions="$2"

    # Parse emotional entries
    local total_frustration=0
    local total_confidence=0
    local count=0
    local moods=""

    # Use jq if available, otherwise approximate
    if command -v jq &> /dev/null; then
        count=$(echo "$emotions" | jq '. | length')
        if [ "$count" -gt 0 ]; then
            total_frustration=$(echo "$emotions" | jq '[.[].frustration] | add // 0')
            total_confidence=$(echo "$emotions" | jq '[.[].confidence] | add // 0')
            moods=$(echo "$emotions" | jq -r '.[].mood' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        fi
    else
        # Fallback: basic grep-based extraction
        count=$(echo "$emotions" | grep -o '"timestamp"' | wc -l)
        if [ "$count" -gt 0 ]; then
            total_frustration=$(echo "$emotions" | grep -oP '"frustration":\K[0-9]+' | awk '{s+=$1} END {print s}')
            total_confidence=$(echo "$emotions" | grep -oP '"confidence":\K[0-9]+' | awk '{s+=$1} END {print s}')
            moods=$(echo "$emotions" | grep -oP '"mood":"\K[^"]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        fi
    fi

    # Calculate averages
    local avg_frustration=0
    local avg_confidence=70
    if [ "$count" -gt 0 ]; then
        avg_frustration=$((total_frustration / count))
        avg_confidence=$((total_confidence / count))
    fi

    # Default mood if none found
    if [ -z "$moods" ]; then
        moods="unknown"
    fi

    # Calculate wellness score (0-100)
    local wellness=$((avg_confidence - avg_frustration / 2))
    if [ $wellness -lt 0 ]; then wellness=0; fi
    if [ $wellness -gt 100 ]; then wellness=100; fi

    # Determine emoji based on wellness
    local emoji="😊"
    if [ $wellness -lt 30 ]; then
        emoji="😫"
    elif [ $wellness -lt 50 ]; then
        emoji="😓"
    elif [ $wellness -lt 70 ]; then
        emoji="😐"
    fi

    echo "{\"wellness\":$wellness,\"avg_frustration\":$avg_frustration,\"avg_confidence\":$avg_confidence,\"dominant_mood\":\"$moods\",\"emoji\":\"$emoji\",\"sample_count\":$count}"
}

# Generate recommendations based on emotional state
generate_recommendations() {
    local agent="$1"
    local wellness="$2"
    local avg_frustration="$3"
    local dominant_mood="$4"

    local recs=""

    if [ "$avg_frustration" -gt 40 ]; then
        recs+="\"$agent shows high frustration - consider simplifying task assignments\","
    fi

    if [ "$dominant_mood" = "struggling" ]; then
        recs+="\"$agent is struggling - review prompt for clearer guidance\","
    fi

    if [ "$dominant_mood" = "uncertain" ]; then
        recs+="\"$agent shows uncertainty - add more specific examples to prompt\","
    fi

    if [ "$wellness" -lt 50 ]; then
        recs+="\"$agent wellness is low - monitor closely for errors\","
    fi

    echo "$recs"
}

# Build the complete JSON output
build_json() {
    local agents=("idea-maker" "project-manager" "developer" "developer2" "tester" "security")

    local agent_data="{"
    local first_agent=true
    local total_wellness=0
    local agent_count=0
    local all_recommendations=""

    for agent in "${agents[@]}"; do
        if [ "$first_agent" = true ]; then
            first_agent=false
        else
            agent_data+=","
        fi

        # Get emotional timeline for this agent
        local emotions=$(get_agent_emotions "$agent")

        # Calculate overall emotional health
        local health=$(calculate_emotional_health "$agent" "$emotions")

        # Extract values for recommendations
        local wellness=$(echo "$health" | grep -oP '"wellness":\K[0-9]+' || echo "70")
        local avg_frustration=$(echo "$health" | grep -oP '"avg_frustration":\K[0-9]+' || echo "0")
        local dominant_mood=$(echo "$health" | grep -oP '"dominant_mood":"\K[^"]+' || echo "calm")

        total_wellness=$((total_wellness + wellness))
        agent_count=$((agent_count + 1))

        # Generate recommendations
        local recs=$(generate_recommendations "$agent" "$wellness" "$avg_frustration" "$dominant_mood")
        all_recommendations+="$recs"

        local color="${AGENT_COLORS[$agent]:-#3b82f6}"

        agent_data+="\"$agent\":{\"color\":\"$color\",\"health\":$health,\"timeline\":$emotions}"
    done

    agent_data+="}"

    # Calculate system-wide emotional health
    local system_wellness=$((total_wellness / agent_count))
    local system_emoji="😊"
    local system_status="healthy"

    if [ $system_wellness -lt 30 ]; then
        system_emoji="😫"
        system_status="critical"
    elif [ $system_wellness -lt 50 ]; then
        system_emoji="😓"
        system_status="struggling"
    elif [ $system_wellness -lt 70 ]; then
        system_emoji="😐"
        system_status="okay"
    fi

    # Clean recommendations (remove trailing comma)
    all_recommendations=$(echo "$all_recommendations" | sed 's/,$//')

    # Build final JSON
    cat << EOF
{
    "timestamp": "$TIMESTAMP",
    "system": {
        "wellness": $system_wellness,
        "emoji": "$system_emoji",
        "status": "$system_status"
    },
    "agents": $agent_data,
    "recommendations": [$all_recommendations]
}
EOF
}

# Main execution
echo "Analyzing agent emotional indicators..."

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate and write JSON
build_json > "$OUTPUT_FILE"

echo "Emotional analysis complete: $OUTPUT_FILE"
