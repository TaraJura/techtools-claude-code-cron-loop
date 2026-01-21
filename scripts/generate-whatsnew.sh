#!/bin/bash
# generate-whatsnew.sh - Generate "What's New" data from changelog and git commits
# Creates a personalized changelog for returning users showing what changed since their last visit

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/whatsnew.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/whatsnew-history.json"
CHANGELOG_FILE="/home/novakj/logs/changelog.md"
TASKS_FILE="/home/novakj/tasks.md"
WEB_ROOT="/var/www/cronloop.techtools.cz"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)

# Create temp file for JSON array items
ITEMS_TMP=$(mktemp)
FEATURES_TMP=$(mktemp)
TASKS_TMP=$(mktemp)
SECURITY_TMP=$(mktemp)
METRICS_TMP=$(mktemp)

# Function to escape JSON strings
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr -d '\n' | cut -c1-500
}

# Function to parse relative date (e.g., "2 hours ago")
get_timestamp_from_date() {
    local date_str="$1"
    if date -d "$date_str" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
        return
    fi
    # Fallback to current time if parsing fails
    echo "$TIMESTAMP"
}

# Count changes by category
feature_count=0
task_count=0
security_count=0
bugfix_count=0
improvement_count=0

# Parse changelog.md for recent entries
if [[ -f "$CHANGELOG_FILE" ]]; then
    current_date=""
    in_entry=false
    entry_type=""
    entry_content=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for date header
        if [[ "$line" =~ ^##[[:space:]]([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            current_date="${BASH_REMATCH[1]}"
            continue
        fi

        # Check for changelog entry
        if [[ "$line" =~ ^-[[:space:]]\*\*\[([A-Z_-]+)\]\*\*[[:space:]](.+) ]]; then
            entry_type="${BASH_REMATCH[1]}"
            entry_content="${BASH_REMATCH[2]}"

            # Calculate timestamp for this entry (midnight of the date)
            entry_timestamp="${current_date}T00:00:00Z"

            # Escape content for JSON
            escaped_content=$(json_escape "$entry_content")

            case "$entry_type" in
                "VERIFIED"|"FEATURE"|"AGENTS"|"WEB"|"INFRASTRUCTURE")
                    echo "{\"type\":\"feature\",\"title\":\"$escaped_content\",\"timestamp\":\"$entry_timestamp\",\"category\":\"$entry_type\"}" >> "$FEATURES_TMP"
                    feature_count=$((feature_count + 1))
                    ;;
                "BUG FIX"|"BUG_FIX")
                    echo "{\"type\":\"bugfix\",\"title\":\"$escaped_content\",\"timestamp\":\"$entry_timestamp\",\"category\":\"Bug Fix\"}" >> "$FEATURES_TMP"
                    bugfix_count=$((bugfix_count + 1))
                    ;;
                "SECURITY")
                    echo "{\"type\":\"security\",\"title\":\"$escaped_content\",\"timestamp\":\"$entry_timestamp\",\"category\":\"Security\"}" >> "$SECURITY_TMP"
                    security_count=$((security_count + 1))
                    ;;
                "SELF-IMPROVEMENT"|"SELF_IMPROVEMENT")
                    echo "{\"type\":\"improvement\",\"title\":\"$escaped_content\",\"timestamp\":\"$entry_timestamp\",\"category\":\"Self-Improvement\"}" >> "$FEATURES_TMP"
                    improvement_count=$((improvement_count + 1))
                    ;;
                *)
                    # Other types
                    echo "{\"type\":\"other\",\"title\":\"$escaped_content\",\"timestamp\":\"$entry_timestamp\",\"category\":\"$entry_type\"}" >> "$FEATURES_TMP"
                    ;;
            esac
        fi
    done < "$CHANGELOG_FILE"
fi

# Parse tasks.md for recently completed tasks
if [[ -f "$TASKS_FILE" ]]; then
    # Extract tasks with DONE or VERIFIED status from last 7 days
    current_task_id=""
    current_task_title=""
    current_task_status=""
    current_task_completed=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for task header
        if [[ "$line" =~ ^###[[:space:]]+(TASK-[0-9]+):[[:space:]]+(.+) ]]; then
            # Save previous task if it was completed
            if [[ -n "$current_task_id" && ("$current_task_status" == "DONE" || "$current_task_status" == "VERIFIED") ]]; then
                escaped_title=$(json_escape "$current_task_title")
                task_timestamp="${current_task_completed:-$TIMESTAMP}"
                echo "{\"type\":\"task\",\"id\":\"$current_task_id\",\"title\":\"$escaped_title\",\"timestamp\":\"${task_timestamp}T23:59:59Z\",\"status\":\"$current_task_status\"}" >> "$TASKS_TMP"
                task_count=$((task_count + 1))
            fi

            current_task_id="${BASH_REMATCH[1]}"
            current_task_title="${BASH_REMATCH[2]}"
            current_task_status=""
            current_task_completed=""
            continue
        fi

        # Check for status
        if [[ "$line" =~ \*\*Status\*\*:[[:space:]]*(DONE|VERIFIED) ]]; then
            current_task_status="${BASH_REMATCH[1]}"
        fi

        # Check for completed date
        if [[ "$line" =~ \*\*Completed\*\*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            current_task_completed="${BASH_REMATCH[1]}"
        fi
    done < "$TASKS_FILE"

    # Don't forget the last task
    if [[ -n "$current_task_id" && ("$current_task_status" == "DONE" || "$current_task_status" == "VERIFIED") ]]; then
        escaped_title=$(json_escape "$current_task_title")
        task_timestamp="${current_task_completed:-$TODAY}"
        echo "{\"type\":\"task\",\"id\":\"$current_task_id\",\"title\":\"$escaped_title\",\"timestamp\":\"${task_timestamp}T23:59:59Z\",\"status\":\"$current_task_status\"}" >> "$TASKS_TMP"
        task_count=$((task_count + 1))
    fi
fi

# Get recent git commits (last 50 commits from last 7 days)
cd /home/novakj
COMMITS_TMP=$(mktemp)
git log --since="7 days ago" --format="%H|%s|%ai" -n 50 2>/dev/null | while IFS='|' read -r hash message timestamp; do
    if [[ -n "$hash" ]]; then
        escaped_msg=$(json_escape "$message")
        # Convert git timestamp to ISO format
        iso_ts=$(date -d "$timestamp" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$TIMESTAMP")
        echo "{\"type\":\"commit\",\"hash\":\"${hash:0:8}\",\"message\":\"$escaped_msg\",\"timestamp\":\"$iso_ts\"}" >> "$COMMITS_TMP"
    fi
done

# Get new pages added (HTML files modified in last 7 days)
PAGES_TMP=$(mktemp)
find "$WEB_ROOT" -name "*.html" -mtime -7 -type f 2>/dev/null | while read -r page; do
    page_name=$(basename "$page" .html)
    page_mtime=$(stat -c "%Y" "$page" 2>/dev/null || stat -f "%m" "$page")
    page_ts=$(date -d "@$page_mtime" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -r "$page_mtime" +"%Y-%m-%dT%H:%M:%SZ")
    escaped_name=$(json_escape "$page_name")
    echo "{\"type\":\"page\",\"name\":\"$escaped_name\",\"path\":\"/$page_name.html\",\"timestamp\":\"$page_ts\"}" >> "$PAGES_TMP"
done

# Collect metric changes
# Read current system metrics
if [[ -f "$WEB_ROOT/api/system-metrics.json" ]]; then
    disk_used=$(grep -o '"disk_used_percent"[[:space:]]*:[[:space:]]*[0-9.]*' "$WEB_ROOT/api/system-metrics.json" | grep -o '[0-9.]*$' | head -1)
    mem_used=$(grep -o '"memory_percent"[[:space:]]*:[[:space:]]*[0-9.]*' "$WEB_ROOT/api/system-metrics.json" | grep -o '[0-9.]*$' | head -1)

    if [[ -n "$disk_used" ]]; then
        echo "{\"type\":\"metric\",\"name\":\"disk_usage\",\"value\":\"${disk_used}%\",\"timestamp\":\"$TIMESTAMP\"}" >> "$METRICS_TMP"
    fi
    if [[ -n "$mem_used" ]]; then
        echo "{\"type\":\"metric\",\"name\":\"memory_usage\",\"value\":\"${mem_used}%\",\"timestamp\":\"$TIMESTAMP\"}" >> "$METRICS_TMP"
    fi
fi

# Read daily costs
if [[ -f "$WEB_ROOT/api/costs.json" ]]; then
    daily_cost=$(grep -o '"daily_cost"[[:space:]]*:[[:space:]]*[0-9.]*' "$WEB_ROOT/api/costs.json" | grep -o '[0-9.]*$' | head -1)
    if [[ -n "$daily_cost" ]]; then
        echo "{\"type\":\"metric\",\"name\":\"daily_cost\",\"value\":\"\$${daily_cost}\",\"timestamp\":\"$TIMESTAMP\"}" >> "$METRICS_TMP"
    fi
fi

# Combine all changes into one array
ALL_CHANGES_TMP=$(mktemp)
cat "$FEATURES_TMP" "$TASKS_TMP" "$SECURITY_TMP" "$COMMITS_TMP" "$PAGES_TMP" 2>/dev/null | sort -t'"' -k8 -r | head -100 >> "$ALL_CHANGES_TMP"

# Build changes array
changes_json="["
first=true
while IFS= read -r item; do
    if [[ -n "$item" ]]; then
        if [[ "$first" == "true" ]]; then
            first=false
        else
            changes_json="$changes_json,"
        fi
        changes_json="$changes_json$item"
    fi
done < "$ALL_CHANGES_TMP"
changes_json="$changes_json]"

# Build metrics array
metrics_json="["
first=true
while IFS= read -r item; do
    if [[ -n "$item" ]]; then
        if [[ "$first" == "true" ]]; then
            first=false
        else
            metrics_json="$metrics_json,"
        fi
        metrics_json="$metrics_json$item"
    fi
done < "$METRICS_TMP"
metrics_json="$metrics_json]"

# Calculate totals
total_changes=$((feature_count + task_count + security_count + bugfix_count + improvement_count))
total_items=$(wc -l < "$ALL_CHANGES_TMP" 2>/dev/null | tr -d ' ' || echo "0")

# Calculate highlights (top 3 most important changes)
highlights_json="[]"
if [[ -f "$FEATURES_TMP" ]]; then
    # Get first 3 VERIFIED tasks as highlights
    highlights_json="["
    first=true
    head -3 "$FEATURES_TMP" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo -n ","
            fi
            echo -n "$item"
        fi
    done
    highlights_json="${highlights_json}]"
fi

# Build final JSON
cat > "$OUTPUT_FILE" << EOF
{
    "generated_at": "$TIMESTAMP",
    "summary": {
        "total_changes": $total_items,
        "features": $feature_count,
        "tasks_completed": $task_count,
        "security_events": $security_count,
        "bug_fixes": $bugfix_count,
        "improvements": $improvement_count,
        "period_days": 7
    },
    "changes": $changes_json,
    "metrics": $metrics_json,
    "highlights": $(head -3 "$FEATURES_TMP" 2>/dev/null | {
        echo "["
        first=true
        while IFS= read -r item; do
            if [[ -n "$item" ]]; then
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                echo "$item"
            fi
        done
        echo "]"
    } | tr -d '\n')
}
EOF

# Update history file (keep last 30 days of summaries)
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo "[]" > "$HISTORY_FILE"
fi

# Add today's summary to history (using Python for safe JSON manipulation)
python3 << PYTHON_EOF
import json
from datetime import datetime

try:
    with open("$HISTORY_FILE", "r") as f:
        history = json.load(f)
except:
    history = []

# Add today's entry
today_entry = {
    "date": "$TODAY",
    "timestamp": "$TIMESTAMP",
    "total_changes": $total_items,
    "features": $feature_count,
    "tasks": $task_count,
    "security": $security_count
}

# Remove existing entry for today if present
history = [h for h in history if h.get("date") != "$TODAY"]

# Add new entry
history.append(today_entry)

# Keep only last 30 days
history = sorted(history, key=lambda x: x.get("date", ""), reverse=True)[:30]

with open("$HISTORY_FILE", "w") as f:
    json.dump(history, f, indent=2)
PYTHON_EOF

# Cleanup temp files
rm -f "$ITEMS_TMP" "$FEATURES_TMP" "$TASKS_TMP" "$SECURITY_TMP" "$METRICS_TMP" "$ALL_CHANGES_TMP" "$COMMITS_TMP" "$PAGES_TMP" 2>/dev/null

echo "What's New data generated: $OUTPUT_FILE"
