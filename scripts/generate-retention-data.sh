#!/bin/bash
# Generate retention data for the Data Retention Dashboard
# This script scans data directories and creates /api/retention.json

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/retention.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/retention-history.json"

# Data directories to scan
API_DIR="/var/www/cronloop.techtools.cz/api"
ACTOR_LOGS_DIR="/home/novakj/actors"
SYSTEM_LOGS_DIR="/home/novakj/logs"
WEB_LOGS_DIR="/var/www/cronloop.techtools.cz/logs"

# Initialize JSON structure
echo "Generating retention data..."

# Get disk info
DISK_TOTAL=$(df -B1 / | awk 'NR==2 {print $2}')
DISK_USED=$(df -B1 / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -B1 / | awk 'NR==2 {print $4}')
DISK_PERCENT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')

# Build file list and categories
declare -A CATEGORIES
TOTAL_SIZE=0
TOTAL_FILES=0
CLEANUP_POTENTIAL=0
DATA_HOARDERS=0
OLDEST_AGE=0

# Temp file for JSON array
FILES_JSON=$(mktemp)
echo "[" > "$FILES_JSON"
FIRST=true

# Function to get entry count from JSON file
get_json_entries() {
    local file="$1"
    if [[ "$file" == *.json ]]; then
        # Try to count array elements at root level
        python3 -c "
import json
import sys
try:
    with open('$file', 'r') as f:
        data = json.load(f)
    if isinstance(data, list):
        print(len(data))
    elif isinstance(data, dict):
        # Count items in largest array within dict
        max_count = 0
        for v in data.values():
            if isinstance(v, list):
                max_count = max(max_count, len(v))
        print(max_count if max_count > 0 else len(data))
    else:
        print(0)
except:
    print(0)
" 2>/dev/null || echo "0"
    else
        # For log files, count lines
        wc -l < "$file" 2>/dev/null || echo "0"
    fi
}

# Function to calculate growth rate (requires history)
get_growth_rate() {
    local file="$1"
    local current_size="$2"
    # Simple heuristic: larger files are assumed to grow faster
    # In production, we'd compare to historical snapshots
    if [[ -f "$HISTORY_FILE" ]]; then
        # Look up previous size from history
        prev_size=$(python3 -c "
import json
try:
    with open('$HISTORY_FILE', 'r') as f:
        data = json.load(f)
    history = data.get('history', [])
    if len(history) > 1:
        for entry in history[-2].get('files', []):
            if entry.get('path') == '$file':
                print(entry.get('size', $current_size))
                break
        else:
            print($current_size)
    else:
        print($current_size)
except:
    print($current_size)
" 2>/dev/null)
        echo $(( (current_size - prev_size) ))
    else
        echo "0"
    fi
}

# Scan API JSON files
for file in "$API_DIR"/*.json; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" == "retention.json" ]] && continue
    [[ "$(basename "$file")" == "retention-history.json" ]] && continue

    filename=$(basename "$file")
    filesize=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fileage=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || echo $(date +%s))) / 86400 ))
    entries=$(get_json_entries "$file")
    growth=$(get_growth_rate "$file" "$filesize")

    TOTAL_SIZE=$((TOTAL_SIZE + filesize))
    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Track data hoarders (files > 50KB)
    if [[ $filesize -gt 51200 ]]; then
        DATA_HOARDERS=$((DATA_HOARDERS + 1))
    fi

    # Track cleanup potential (entries > 30 days old in large files)
    if [[ $filesize -gt 102400 ]]; then
        CLEANUP_POTENTIAL=$((CLEANUP_POTENTIAL + filesize / 2))
    fi

    # Track oldest
    [[ $fileage -gt $OLDEST_AGE ]] && OLDEST_AGE=$fileage

    # Update category (handled later via du)

    # Add to JSON
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        echo "," >> "$FILES_JSON"
    fi

    cat >> "$FILES_JSON" << EOF
    {
        "name": "$filename",
        "path": "${file#/var/www/cronloop.techtools.cz/}",
        "size": $filesize,
        "entries": $entries,
        "growth": $growth,
        "age": $fileage,
        "policy": "None"
    }
EOF
done

# Scan agent logs
for agent_dir in "$ACTOR_LOGS_DIR"/*/logs; do
    [[ -d "$agent_dir" ]] || continue
    agent_name=$(basename "$(dirname "$agent_dir")")

    for file in "$agent_dir"/*.log; do
        [[ -f "$file" ]] || continue

        filename=$(basename "$file")
        filesize=$(stat -c%s "$file" 2>/dev/null || echo 0)
        fileage=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || echo $(date +%s))) / 86400 ))
        entries=$(wc -l < "$file" 2>/dev/null || echo 0)

        TOTAL_SIZE=$((TOTAL_SIZE + filesize))
        TOTAL_FILES=$((TOTAL_FILES + 1))

        [[ $fileage -gt $OLDEST_AGE ]] && OLDEST_AGE=$fileage

        if [[ "$FIRST" == "true" ]]; then
            FIRST=false
        else
            echo "," >> "$FILES_JSON"
        fi

        cat >> "$FILES_JSON" << EOF
    {
        "name": "$agent_name/$filename",
        "path": "actors/$agent_name/logs/$filename",
        "size": $filesize,
        "entries": $entries,
        "growth": 0,
        "age": $fileage,
        "policy": "7 days"
    }
EOF
    done
done

# Scan system logs
for file in "$SYSTEM_LOGS_DIR"/*.log "$SYSTEM_LOGS_DIR"/*.md; do
    [[ -f "$file" ]] || continue

    filename=$(basename "$file")
    filesize=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fileage=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || echo $(date +%s))) / 86400 ))
    entries=$(wc -l < "$file" 2>/dev/null || echo 0)

    TOTAL_SIZE=$((TOTAL_SIZE + filesize))
    TOTAL_FILES=$((TOTAL_FILES + 1))

    [[ $fileage -gt $OLDEST_AGE ]] && OLDEST_AGE=$fileage

    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        echo "," >> "$FILES_JSON"
    fi

    cat >> "$FILES_JSON" << EOF
    {
        "name": "$filename",
        "path": "logs/$filename",
        "size": $filesize,
        "entries": $entries,
        "growth": 0,
        "age": $fileage,
        "policy": "30 days"
    }
EOF
done

echo "]" >> "$FILES_JSON"

# Calculate daily growth from disk changes
DAILY_GROWTH=$((TOTAL_SIZE / 30))  # Rough estimate

# Calculate days until disk full
if [[ $DAILY_GROWTH -gt 0 && $DISK_AVAIL -gt 0 ]]; then
    DAYS_UNTIL_FULL=$((DISK_AVAIL / DAILY_GROWTH))
else
    DAYS_UNTIL_FULL=9999
fi

# Calculate category totals
API_SIZE=$(du -sb "$API_DIR" 2>/dev/null | cut -f1 || echo 0)
API_COUNT=$(find "$API_DIR" -maxdepth 1 -name "*.json" | wc -l)

AGENT_LOGS_SIZE=$(du -sb "$ACTOR_LOGS_DIR"/*/logs 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
AGENT_LOGS_COUNT=$(find "$ACTOR_LOGS_DIR"/*/logs -name "*.log" 2>/dev/null | wc -l)

SYSTEM_LOGS_SIZE=$(du -sb "$SYSTEM_LOGS_DIR" 2>/dev/null | cut -f1 || echo 0)
SYSTEM_LOGS_COUNT=$(find "$SYSTEM_LOGS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)

# Generate recommendations
RECOMMENDATIONS="["
REC_FIRST=true

# Check for large JSON files
LARGE_JSON=$(find "$API_DIR" -name "*.json" -size +100k 2>/dev/null | head -5)
if [[ -n "$LARGE_JSON" ]]; then
    for lf in $LARGE_JSON; do
        lfsize=$(stat -c%s "$lf" 2>/dev/null || echo 0)
        lfname=$(basename "$lf")
        savings=$((lfsize / 2))

        if [[ "$REC_FIRST" == "true" ]]; then
            REC_FIRST=false
        else
            RECOMMENDATIONS+=","
        fi

        RECOMMENDATIONS+=$(cat << EOF

        {
            "id": "archive-$lfname",
            "title": "Archive old entries in $lfname",
            "description": "This file is $(numfmt --to=iec $lfsize). Consider archiving entries older than 30 days.",
            "savings": $savings,
            "severity": "warning"
        }
EOF
)
    done
fi

# Check for old log files
OLD_LOGS=$(find "$ACTOR_LOGS_DIR"/*/logs -name "*.log" -mtime +7 2>/dev/null | wc -l)
if [[ $OLD_LOGS -gt 10 ]]; then
    old_size=$(find "$ACTOR_LOGS_DIR"/*/logs -name "*.log" -mtime +7 -exec stat -c%s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    if [[ "$REC_FIRST" == "true" ]]; then
        REC_FIRST=false
    else
        RECOMMENDATIONS+=","
    fi
    RECOMMENDATIONS+=$(cat << EOF

        {
            "id": "cleanup-old-logs",
            "title": "Remove agent logs older than 7 days",
            "description": "$OLD_LOGS log files are older than 7 days and can be safely archived.",
            "savings": $old_size,
            "severity": ""
        }
EOF
)
fi

RECOMMENDATIONS+="]"

# Generate history entry for today
TODAY=$(date +%Y-%m-%d)

# Build final JSON
cat > "$OUTPUT_FILE" << EOF
{
    "generated": "$(date -Iseconds)",
    "totalSize": $TOTAL_SIZE,
    "totalFiles": $TOTAL_FILES,
    "dailyGrowth": $DAILY_GROWTH,
    "oldestAge": $OLDEST_AGE,
    "dataHoarders": $DATA_HOARDERS,
    "cleanupPotential": $CLEANUP_POTENTIAL,
    "disk": {
        "total": $DISK_TOTAL,
        "used": $DISK_USED,
        "available": $DISK_AVAIL,
        "usagePercent": $DISK_PERCENT,
        "dailyGrowth": $DAILY_GROWTH,
        "daysUntilFull": $DAYS_UNTIL_FULL
    },
    "categories": {
        "API Data": {"size": $API_SIZE, "count": $API_COUNT},
        "Agent Logs": {"size": $AGENT_LOGS_SIZE, "count": $AGENT_LOGS_COUNT},
        "System Logs": {"size": $SYSTEM_LOGS_SIZE, "count": $SYSTEM_LOGS_COUNT}
    },
    "files": $(cat "$FILES_JSON"),
    "recommendations": $RECOMMENDATIONS,
    "history": []
}
EOF

# Update history file
if [[ -f "$HISTORY_FILE" ]]; then
    # Append today's snapshot to history (keep last 30 days)
    python3 << PYEOF
import json
from datetime import datetime

try:
    with open('$HISTORY_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {"history": []}

history = data.get("history", [])

# Add today's entry
today_entry = {
    "date": "$TODAY",
    "size": $TOTAL_SIZE,
    "files": $TOTAL_FILES
}

# Remove duplicates for today
history = [h for h in history if h.get("date") != "$TODAY"]
history.append(today_entry)

# Keep only last 30 entries
history = history[-30:]

data["history"] = history

with open('$HISTORY_FILE', 'w') as f:
    json.dump(data, f, indent=2)

# Also update the main file's history section
with open('$OUTPUT_FILE', 'r') as f:
    main_data = json.load(f)

main_data["history"] = history

with open('$OUTPUT_FILE', 'w') as f:
    json.dump(main_data, f, indent=2)

print("History updated with {} entries".format(len(history)))
PYEOF
else
    # Create initial history file
    cat > "$HISTORY_FILE" << EOF
{
    "history": [
        {"date": "$TODAY", "size": $TOTAL_SIZE, "files": $TOTAL_FILES}
    ]
}
EOF
fi

rm -f "$FILES_JSON"

echo "Retention data generated at $OUTPUT_FILE"
echo "Total size: $(numfmt --to=iec $TOTAL_SIZE)"
echo "Total files: $TOTAL_FILES"
