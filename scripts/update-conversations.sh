#!/bin/bash
# Conversation data extractor for agent logs
# Parses agent log files and extracts conversation-like data
# Output: /var/www/cronloop.techtools.cz/api/conversations.json

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/conversations.json"
ACTORS_DIR="/home/novakj/actors"
DAYS_TO_INCLUDE=7

# Create temp file for JSON entries
TEMP_ENTRIES=$(mktemp)

# Process each actor's logs
for actor_dir in "$ACTORS_DIR"/*/; do
    actor_name=$(basename "$actor_dir")
    logs_dir="$actor_dir/logs"

    # Skip if no logs directory
    [ -d "$logs_dir" ] || continue

    # Find log files from last N days
    for log_file in $(find "$logs_dir" -name "*.log" -mtime -$DAYS_TO_INCLUDE -type f 2>/dev/null | sort -r); do
        # Extract filename for ID
        filename=$(basename "$log_file" .log)

        # Read log content
        content=$(cat "$log_file" 2>/dev/null || echo "")
        [ -z "$content" ] && continue

        # Extract timestamps from log headers
        started=$(echo "$content" | grep -oP 'Started: \K.*' | head -1)
        completed=$(echo "$content" | grep -oP 'Completed: \K.*' | head -1)

        # Calculate duration if possible
        duration_seconds=0
        if [ -n "$started" ] && [ -n "$completed" ]; then
            start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
            end_epoch=$(date -d "$completed" +%s 2>/dev/null || echo "0")
            if [ "$start_epoch" != "0" ] && [ "$end_epoch" != "0" ] && [ "$start_epoch" -gt 0 ] && [ "$end_epoch" -gt 0 ]; then
                duration_seconds=$((end_epoch - start_epoch))
            fi
        fi

        # Extract the main conversation content (between headers)
        conversation_text=$(echo "$content" | sed -n '/Running .* agent.../,/========================================/{/========================================/d;p}' | head -c 50000)

        # Detect if there were errors
        has_error="false"
        if echo "$content" | grep -qiE '(error|exception|failed|fatal)'; then
            has_error="true"
        fi

        # Extract task ID if mentioned
        task_id=$(echo "$content" | grep -oP 'TASK-\d+' | head -1 || echo "")

        # Count approximate sections/messages - use tr to trim whitespace
        message_count=$(echo "$conversation_text" | grep -cE '^(#{1,3} |[*-] \*\*|\d+\. |```|I |Let me |Here|Now |The )' 2>/dev/null | tr -d ' ' || echo "1")
        if [ -z "$message_count" ] || [ "$message_count" = "0" ]; then
            message_count=1
        fi

        # Get file size and line count - use tr to trim whitespace
        file_size=$(wc -c < "$log_file" 2>/dev/null | tr -d ' ')
        line_count=$(wc -l < "$log_file" 2>/dev/null | tr -d ' ')

        # Ensure numeric values
        file_size=${file_size:-0}
        line_count=${line_count:-0}

        # Build JSON entry using jq for proper escaping (compact mode)
        jq -c -n \
            --arg id "${actor_name}_${filename}" \
            --arg agent "$actor_name" \
            --arg filename "$filename" \
            --arg log_file "$log_file" \
            --arg started "$started" \
            --arg completed "$completed" \
            --argjson duration "$duration_seconds" \
            --argjson has_error "$has_error" \
            --arg task_id "$task_id" \
            --argjson message_count "$message_count" \
            --argjson file_size "$file_size" \
            --argjson line_count "$line_count" \
            --arg content "$conversation_text" \
            '{
                id: $id,
                agent: $agent,
                filename: $filename,
                log_file: $log_file,
                started: $started,
                completed: $completed,
                duration_seconds: $duration,
                has_error: $has_error,
                task_id: $task_id,
                message_count: $message_count,
                file_size_bytes: $file_size,
                line_count: $line_count,
                content: $content
            }' >> "$TEMP_ENTRIES"
    done
done

# Count total entries - trim whitespace
total_count=$(wc -l < "$TEMP_ENTRIES" 2>/dev/null | tr -d ' ')
total_count=${total_count:-0}

# Build final JSON
{
    echo '{"updated":"'$(date -Iseconds)'","total_conversations":'$total_count',"conversations":['
    # Join entries with commas
    if [ -s "$TEMP_ENTRIES" ]; then
        cat "$TEMP_ENTRIES" | paste -sd ',' -
    fi
    echo ']}'
} > "$OUTPUT_FILE.tmp"

# Validate JSON and move to final location
if jq empty "$OUTPUT_FILE.tmp" 2>/dev/null; then
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "Conversations data updated: $OUTPUT_FILE ($total_count conversations)"
else
    echo "ERROR: Generated invalid JSON"
    head -20 "$OUTPUT_FILE.tmp"
    rm -f "$OUTPUT_FILE.tmp"
    rm -f "$TEMP_ENTRIES"
    exit 1
fi

rm -f "$TEMP_ENTRIES"
