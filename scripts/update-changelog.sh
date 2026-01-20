#!/bin/bash
# update-changelog.sh - Extracts git history and produces JSON for changelog.html
# Output: JSON data for the system changelog/audit trail

set -e

REPO_DIR="/home/novakj"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/changelog.json"
MAX_COMMITS=200

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

cd "$REPO_DIR"

# Create temporary file for building JSON
TMP_FILE=$(mktemp)

# Start JSON structure
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
EOF

# Get total commits
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
echo "  \"total_commits\": $TOTAL_COMMITS," >> "$TMP_FILE"

# Initialize arrays for tracking
declare -A AGENT_COMMITS
declare -A FILE_CHANGES
declare -A HOURLY_ACTIVITY
declare -A DAILY_ACTIVITY

# Initialize hourly activity
for h in $(seq 0 23); do
    HOURLY_ACTIVITY[$h]=0
done

# Start commits array
echo '  "commits": [' >> "$TMP_FILE"

FIRST_COMMIT=true

# Get git log
git log --pretty=format:'COMMIT_START%H|%an|%aI|%s' -n "$MAX_COMMITS" 2>/dev/null | while IFS='|' read -r hash author date subject; do
    # Skip empty lines or incomplete records
    [[ ! "$hash" =~ ^COMMIT_START ]] && continue
    hash="${hash#COMMIT_START}"
    [ -z "$hash" ] && continue

    # Extract agent name from commit message (format: [agent-name] message)
    AGENT=""
    if [[ "$subject" =~ ^\[([a-zA-Z-]+)\] ]]; then
        AGENT="${BASH_REMATCH[1]}"
    elif [[ "$author" == "Claude"* ]]; then
        AGENT="claude-code"
    fi

    # Extract task references (TASK-XXX)
    TASKS=$(echo "$subject" | grep -oE 'TASK-[0-9]+' | sort -u | tr '\n' ',' | sed 's/,$//' || echo "")

    # Get changed files for this commit
    FILES_CHANGED=$(git show --stat --name-only --format="" "$hash" 2>/dev/null | grep -v '^$' | head -20)
    FILES_COUNT=$(echo "$FILES_CHANGED" | grep -c -v '^$' || echo "0")

    # Categorize change type
    CHANGE_TYPE="other"
    if echo "$FILES_CHANGED" | grep -qE "\.html$|\.css$|\.js$"; then
        CHANGE_TYPE="web"
    elif echo "$FILES_CHANGED" | grep -qE "\.sh$"; then
        CHANGE_TYPE="script"
    elif echo "$FILES_CHANGED" | grep -qE "\.md$"; then
        CHANGE_TYPE="docs"
    elif echo "$FILES_CHANGED" | grep -qE "\.json$"; then
        CHANGE_TYPE="config"
    fi

    # Get insertions/deletions
    STATS=$(git show --stat --format="" "$hash" 2>/dev/null | tail -1)
    INSERTIONS=$(echo "$STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' | head -1 || echo "0")
    DELETIONS=$(echo "$STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' | head -1 || echo "0")
    [ -z "$INSERTIONS" ] && INSERTIONS="0"
    [ -z "$DELETIONS" ] && DELETIONS="0"

    # Escape special characters in subject
    SUBJECT_ESCAPED=$(echo "$subject" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/ /g' | tr -d '\r\n')

    # Get list of changed files as JSON array
    FILES_JSON="["
    FIRST_FILE=true
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if [ "$FIRST_FILE" = true ]; then
            FIRST_FILE=false
        else
            FILES_JSON+=","
        fi
        FILES_JSON+="\"$f\""
    done <<< "$FILES_CHANGED"
    FILES_JSON+="]"

    # Add comma separator
    if [ "$FIRST_COMMIT" = true ]; then
        FIRST_COMMIT=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    # Write commit entry
    cat >> "$TMP_FILE" << COMMIT_EOF
    {
      "hash": "$hash",
      "short_hash": "${hash:0:7}",
      "author": "$author",
      "date": "$date",
      "subject": "$SUBJECT_ESCAPED",
      "agent": "$AGENT",
      "tasks": "$TASKS",
      "change_type": "$CHANGE_TYPE",
      "files_count": $FILES_COUNT,
      "insertions": $INSERTIONS,
      "deletions": $DELETIONS,
      "files": $FILES_JSON
    }
COMMIT_EOF
done

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Now compute statistics in a separate pass
echo '  "by_agent": {' >> "$TMP_FILE"

# Get agent statistics
AGENT_STATS=$(git log --pretty=format:'%s' -n "$MAX_COMMITS" 2>/dev/null | \
    grep -oE '^\[[a-zA-Z-]+\]' | sed 's/\[//;s/\]//' | sort | uniq -c | sort -rn)

FIRST_AGENT=true
while read -r count agent; do
    [ -z "$agent" ] && continue
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo ',' >> "$TMP_FILE"
    fi
    echo -n "    \"$agent\": $count" >> "$TMP_FILE"
done <<< "$AGENT_STATS"
echo '' >> "$TMP_FILE"
echo '  },' >> "$TMP_FILE"

# Get most changed files (top 10)
echo '  "most_changed_files": [' >> "$TMP_FILE"

MOST_CHANGED=$(git log --pretty=format: --name-only -n "$MAX_COMMITS" 2>/dev/null | \
    grep -v '^$' | sort | uniq -c | sort -rn | head -10)

FIRST_FILE=true
while read -r count file; do
    [ -z "$file" ] && continue
    if [ "$FIRST_FILE" = true ]; then
        FIRST_FILE=false
    else
        echo ',' >> "$TMP_FILE"
    fi
    echo -n "    {\"file\": \"$file\", \"count\": $count}" >> "$TMP_FILE"
done <<< "$MOST_CHANGED"
echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Get hourly activity
echo '  "hourly_activity": {' >> "$TMP_FILE"

HOURLY=$(git log --pretty=format:'%aI' -n "$MAX_COMMITS" 2>/dev/null | \
    sed 's/.*T\([0-9][0-9]\).*/\1/' | sort | uniq -c)

FIRST_HOUR=true
for h in $(seq -w 0 23); do
    count=$(echo "$HOURLY" | grep " $h$" | awk '{print $1}' || echo "0")
    [ -z "$count" ] && count=0
    if [ "$FIRST_HOUR" = true ]; then
        FIRST_HOUR=false
    else
        echo ',' >> "$TMP_FILE"
    fi
    echo -n "    \"$h\": $count" >> "$TMP_FILE"
done
echo '' >> "$TMP_FILE"
echo '  },' >> "$TMP_FILE"

# Get daily activity (last 30 days)
echo '  "daily_activity": [' >> "$TMP_FILE"

DAILY=$(git log --pretty=format:'%aI' -n "$MAX_COMMITS" 2>/dev/null | \
    cut -dT -f1 | sort | uniq -c | sort -t' ' -k2 -r | head -30)

FIRST_DAY=true
while read -r count day; do
    [ -z "$day" ] && continue
    if [ "$FIRST_DAY" = true ]; then
        FIRST_DAY=false
    else
        echo ',' >> "$TMP_FILE"
    fi
    echo -n "    {\"date\": \"$day\", \"count\": $count}" >> "$TMP_FILE"
done <<< "$DAILY"
echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Calculate summary statistics
UNIQUE_AGENTS=$(git log --pretty=format:'%s' -n "$MAX_COMMITS" 2>/dev/null | \
    grep -oE '^\[[a-zA-Z-]+\]' | sed 's/\[//;s/\]//' | sort -u | wc -l)
UNIQUE_FILES=$(git log --pretty=format: --name-only -n "$MAX_COMMITS" 2>/dev/null | \
    grep -v '^$' | sort -u | wc -l)

# Find busiest hour
BUSIEST=$(echo "$HOURLY" | sort -rn | head -1)
BUSIEST_COUNT=$(echo "$BUSIEST" | awk '{print $1}')
BUSIEST_HOUR=$(echo "$BUSIEST" | awk '{print $2}')
[ -z "$BUSIEST_COUNT" ] && BUSIEST_COUNT=0
[ -z "$BUSIEST_HOUR" ] && BUSIEST_HOUR="00"

cat >> "$TMP_FILE" << EOF
  "summary": {
    "unique_agents": $UNIQUE_AGENTS,
    "unique_files": $UNIQUE_FILES,
    "busiest_hour": "$BUSIEST_HOUR",
    "busiest_hour_count": $BUSIEST_COUNT
  }
}
EOF

# Move temp file to output (atomic operation)
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Changelog data updated: $OUTPUT_FILE"
