#!/bin/bash
# update-logs-index.sh - Generate JSON index of agent log files
# This script scans actor log directories and outputs a JSON index
# for the web-based log viewer

set -e

ACTORS_DIR="/home/novakj/actors"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/logs-index.json"
AGENTS=("idea-maker" "project-manager" "developer" "tester" "security")

# Escape JSON strings
json_escape() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Get file preview (first 3 non-header lines of content)
get_preview() {
    local file="$1"
    # Skip header lines (====), get first meaningful content
    local preview=$(grep -v "^====\|^Actor:\|^Started:\|^Completed:\|^Running\|^$" "$file" 2>/dev/null | head -5 | tr '\n' ' ' | cut -c1-200)
    echo "$preview"
}

# Build JSON
echo "{"
echo '  "timestamp": "'$(date -Iseconds)'",'
echo '  "agents": ['

first_agent=true
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [ "$first_agent" = true ]; then
        first_agent=false
    else
        echo ","
    fi

    echo '    {'
    echo "      \"name\": \"$agent\","
    echo '      "logs": ['

    if [ -d "$log_dir" ]; then
        first_log=true
        # Get log files sorted by modification time (newest first), limit to 20
        for log_file in $(ls -t "$log_dir"/*.log 2>/dev/null | head -20); do
            if [ -f "$log_file" ]; then
                filename=$(basename "$log_file")
                # Extract timestamp from filename (YYYYMMDD_HHMMSS.log)
                file_date="${filename:0:8}"  # YYYYMMDD
                file_time="${filename:9:6}"  # HHMMSS

                # Format readable timestamp
                if [[ "$file_date" =~ ^[0-9]{8}$ ]] && [[ "$file_time" =~ ^[0-9]{6}$ ]]; then
                    readable_date="${file_date:0:4}-${file_date:4:2}-${file_date:6:2}"
                    readable_time="${file_time:0:2}:${file_time:2:2}:${file_time:4:2}"
                    timestamp="${readable_date}T${readable_time}Z"
                else
                    timestamp=$(stat -c %y "$log_file" | cut -d'.' -f1 | tr ' ' 'T')
                fi

                # Get file size
                size=$(stat -c %s "$log_file")

                # Get preview
                preview=$(get_preview "$log_file")
                preview_escaped=$(json_escape "$preview")

                if [ "$first_log" = true ]; then
                    first_log=false
                else
                    echo ","
                fi

                echo '        {'
                echo "          \"filename\": \"$filename\","
                echo "          \"path\": \"$agent/logs/$filename\","
                echo "          \"timestamp\": \"$timestamp\","
                echo "          \"size\": $size,"
                echo "          \"preview\": $preview_escaped"
                echo -n '        }'
            fi
        done
    fi

    echo ''
    echo '      ]'
    echo -n '    }'
done

echo ''
echo '  ]'
echo "}"
