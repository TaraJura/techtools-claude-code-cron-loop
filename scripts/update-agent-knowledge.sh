#!/bin/bash
# Update agent knowledge JSON for the dashboard
# Parses prompt.md files to extract LEARNED entries

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/agent-knowledge.json"
ACTORS_DIR="/home/novakj/actors"

# Function to extract lessons from a prompt file
extract_lessons() {
    local agent="$1"
    local prompt_file="$ACTORS_DIR/$agent/prompt.md"

    if [[ ! -f "$prompt_file" ]]; then
        echo "[]"
        return
    fi

    # Extract LEARNED entries with date and text
    local lessons=$(grep -n "\*\*LEARNED" "$prompt_file" 2>/dev/null | while read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        content=$(echo "$line" | cut -d: -f2-)

        # Parse date from [date] pattern
        date=$(echo "$content" | grep -oP '\[\K[^\]]+' | head -1 || echo "unknown")

        # Parse lesson text after the date bracket
        text=$(echo "$content" | sed 's/.*\*\*LEARNED[^:]*\*\*:\s*//' | sed 's/"/\\"/g')

        # Determine category
        category="behavior"
        lower_text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
        if echo "$lower_text" | grep -qE '(always|never|must)'; then
            category="rule"
        elif echo "$lower_text" | grep -qE '(warning|danger|critical)'; then
            category="warning"
        fi

        echo "{\"date\":\"$date\",\"text\":\"$text\",\"agent\":\"$agent\",\"category\":\"$category\",\"line\":$line_num}"
    done | paste -sd ',' -)

    if [[ -z "$lessons" ]]; then
        echo "[]"
    else
        echo "[$lessons]"
    fi
}

# Build JSON
echo "Generating agent knowledge JSON..."

# Get all agents
agents=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Start building JSON
{
    echo "{"
    echo "  \"generated\": \"$(date -Iseconds)\","
    echo "  \"lessons\": ["

    all_lessons=""
    by_agent="{"

    for agent in "${agents[@]}"; do
        lessons_json=$(extract_lessons "$agent")

        # Add to byAgent
        by_agent="$by_agent\"$agent\":$lessons_json,"

        # Add to all lessons (strip brackets and add)
        stripped=$(echo "$lessons_json" | sed 's/^\[//' | sed 's/\]$//')
        if [[ -n "$stripped" && "$stripped" != "" ]]; then
            if [[ -n "$all_lessons" ]]; then
                all_lessons="$all_lessons,$stripped"
            else
                all_lessons="$stripped"
            fi
        fi
    done

    # Close byAgent (remove trailing comma)
    by_agent=$(echo "$by_agent" | sed 's/,$//')
    by_agent="$by_agent}"

    echo "    $all_lessons"
    echo "  ],"
    echo "  \"byAgent\": $by_agent,"

    # Add timeline (same as lessons, sorted would be done client-side)
    echo "  \"timeline\": [$all_lessons],"

    # Add growth data (prompt file sizes over time from git)
    echo "  \"growth\": {"

    # Get growth data from git log
    growth_data=""
    for agent in "${agents[@]}"; do
        prompt_file="actors/$agent/prompt.md"
        if [[ -f "/home/novakj/$prompt_file" ]]; then
            # Get line count from current file
            lines=$(wc -l < "/home/novakj/$prompt_file" 2>/dev/null || echo "0")
            if [[ -n "$growth_data" ]]; then
                growth_data="$growth_data,"
            fi
            growth_data="$growth_data\"$agent\":$lines"
        fi
    done

    echo "    $growth_data"
    echo "  }"
    echo "}"
} > "$OUTPUT_FILE"

echo "Agent knowledge data written to $OUTPUT_FILE"
