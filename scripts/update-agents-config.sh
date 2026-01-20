#!/bin/bash
# Updates the agents configuration JSON for the web dashboard
# Part of CronLoop Agent Configuration Viewer (TASK-044)
#
# This script reads prompt.md files from each actor directory
# and outputs a sanitized JSON for the web app to display.

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/agents-config.json"
ACTORS_DIR="/home/novakj/actors"

# Start JSON output
echo '{' > "$OUTPUT_FILE"
echo '  "updated": "'$(date -Iseconds)'",' >> "$OUTPUT_FILE"
echo '  "agents": [' >> "$OUTPUT_FILE"

# Define agent order (matching execution order)
AGENTS=("idea-maker" "project-manager" "developer" "tester" "security")

# Agent display info
declare -A AGENT_ICONS
AGENT_ICONS["idea-maker"]="lightbulb"
AGENT_ICONS["project-manager"]="clipboard"
AGENT_ICONS["developer"]="code"
AGENT_ICONS["tester"]="flask"
AGENT_ICONS["security"]="shield"

declare -A AGENT_NAMES
AGENT_NAMES["idea-maker"]="Idea Maker"
AGENT_NAMES["project-manager"]="Project Manager"
AGENT_NAMES["developer"]="Developer"
AGENT_NAMES["tester"]="Tester"
AGENT_NAMES["security"]="Security"

declare -A AGENT_ROLES
AGENT_ROLES["idea-maker"]="Generates new feature ideas for the backlog"
AGENT_ROLES["project-manager"]="Assigns tasks and manages priorities"
AGENT_ROLES["developer"]="Implements assigned tasks"
AGENT_ROLES["tester"]="Tests completed work and verifies features"
AGENT_ROLES["security"]="Reviews code and configs for vulnerabilities"

FIRST=true
ORDER=1
for agent in "${AGENTS[@]}"; do
    PROMPT_FILE="$ACTORS_DIR/$agent/prompt.md"

    if [[ -f "$PROMPT_FILE" ]]; then
        # Read the content
        CONTENT=$(cat "$PROMPT_FILE")

        # Escape special characters for JSON
        # Escape backslashes first, then quotes, then newlines
        CONTENT_ESCAPED=$(echo "$CONTENT" | \
            sed 's/\\/\\\\/g' | \
            sed 's/"/\\"/g' | \
            sed ':a;N;$!ba;s/\n/\\n/g' | \
            sed 's/\t/\\t/g')

        # Get file stats
        MODIFIED=$(stat -c "%Y" "$PROMPT_FILE")
        SIZE=$(stat -c "%s" "$PROMPT_FILE")
        LINES=$(wc -l < "$PROMPT_FILE")

        # Add comma separator
        if [[ "$FIRST" != "true" ]]; then
            echo ',' >> "$OUTPUT_FILE"
        fi
        FIRST=false

        # Write agent entry
        cat >> "$OUTPUT_FILE" << ENTRY
    {
      "id": "$agent",
      "name": "${AGENT_NAMES[$agent]}",
      "icon": "${AGENT_ICONS[$agent]}",
      "role": "${AGENT_ROLES[$agent]}",
      "order": $ORDER,
      "prompt": "$CONTENT_ESCAPED",
      "stats": {
        "modified": $MODIFIED,
        "size": $SIZE,
        "lines": $LINES
      }
    }
ENTRY
        ORDER=$((ORDER + 1))
    fi
done

# Close JSON
echo '' >> "$OUTPUT_FILE"
echo '  ]' >> "$OUTPUT_FILE"
echo '}' >> "$OUTPUT_FILE"

echo "Updated agents config: $OUTPUT_FILE"
