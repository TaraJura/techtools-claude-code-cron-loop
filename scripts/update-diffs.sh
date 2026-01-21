#!/bin/bash
# update-diffs.sh - Extract file diffs from git commits grouped by agent
# Output: JSON data for the diffs.html page showing actual code changes per agent run

set -e

REPO_DIR="/home/novakj"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/diffs.json"
MAX_COMMITS=100  # Number of commits to analyze

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cd "$REPO_DIR"

# Create temporary files
TMP_FILE=$(mktemp)
TMP_COMMITS=$(mktemp)

cleanup() {
    rm -f "$TMP_FILE" "$TMP_COMMITS"
}
trap cleanup EXIT

# Function to escape JSON strings
escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"    # Escape backslashes first
    str="${str//\"/\\\"}"    # Escape double quotes
    str="${str//$'\n'/\\n}"  # Escape newlines
    str="${str//$'\r'/}"     # Remove carriage returns
    str="${str//$'\t'/    }" # Replace tabs with spaces
    printf '%s' "$str"
}

# Start JSON structure
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "repo_path": "$REPO_DIR",
EOF

# ============================================================
# Collect commits by agent
# ============================================================

# Initialize counters
TOTAL_COMMITS=0
TOTAL_FILES_CHANGED=0
TOTAL_ADDITIONS=0
TOTAL_DELETIONS=0

declare -A AGENT_COMMITS
declare -A AGENT_FILES
declare -A AGENT_ADDITIONS
declare -A AGENT_DELETIONS

# Get commit list with agent info
git log --pretty=format:'%H|%an|%aI|%s' -n "$MAX_COMMITS" 2>/dev/null > "$TMP_COMMITS" || true

# Count total commits
TOTAL_COMMITS=$(wc -l < "$TMP_COMMITS" 2>/dev/null | tr -d ' ' || echo "0")

# Start commits array
echo '  "commits": [' >> "$TMP_FILE"

FIRST_COMMIT=true
COMMIT_INDEX=0

while IFS='|' read -r hash author date subject; do
    [ -z "$hash" ] && continue

    # Extract agent name from commit message (format: [agent-name] message)
    AGENT="unknown"
    if [[ "$subject" =~ ^\[([a-zA-Z0-9-]+)\] ]]; then
        AGENT="${BASH_REMATCH[1]}"
    elif [[ "$author" == "Claude"* ]]; then
        AGENT="claude-code"
    fi

    # Extract task references (TASK-XXX)
    TASK_ID=$(echo "$subject" | grep -oE 'TASK-[0-9]+' | head -1 || echo "")

    # Get diff statistics
    STATS=$(git show --stat --format="" "$hash" 2>/dev/null | tail -1 || echo "")
    INSERTIONS=$(echo "$STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' | head -1 || echo "0")
    DELETIONS=$(echo "$STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' | head -1 || echo "0")
    [ -z "$INSERTIONS" ] && INSERTIONS=0
    [ -z "$DELETIONS" ] && DELETIONS=0

    # Get list of files changed
    FILES_LIST=$(git show --name-only --format="" "$hash" 2>/dev/null | grep -v '^$' | head -30 || echo "")
    FILES_COUNT=$(echo "$FILES_LIST" | grep -c . 2>/dev/null || echo "0")

    # Update totals
    TOTAL_FILES_CHANGED=$((TOTAL_FILES_CHANGED + FILES_COUNT))
    TOTAL_ADDITIONS=$((TOTAL_ADDITIONS + INSERTIONS))
    TOTAL_DELETIONS=$((TOTAL_DELETIONS + DELETIONS))

    # Track per-agent stats
    AGENT_COMMITS[$AGENT]=$((${AGENT_COMMITS[$AGENT]:-0} + 1))
    AGENT_FILES[$AGENT]=$((${AGENT_FILES[$AGENT]:-0} + FILES_COUNT))
    AGENT_ADDITIONS[$AGENT]=$((${AGENT_ADDITIONS[$AGENT]:-0} + INSERTIONS))
    AGENT_DELETIONS[$AGENT]=$((${AGENT_DELETIONS[$AGENT]:-0} + DELETIONS))

    # Build file diffs for this commit (limit to first 10 files for performance)
    FILE_INDEX=0
    FILE_DIFFS=""

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        [ "$FILE_INDEX" -ge 10 ] && break  # Limit files per commit

        # Get extension for file type
        EXT="${filepath##*.}"

        # Get the actual diff for this file (limit lines for large diffs)
        DIFF_CONTENT=$(git show --format="" -- "$filepath" "$hash" 2>/dev/null | head -200 || echo "")

        # Count additions/deletions in this file
        FILE_ADDS=$(echo "$DIFF_CONTENT" | grep -c "^+" 2>/dev/null || echo "0")
        FILE_DELS=$(echo "$DIFF_CONTENT" | grep -c "^-" 2>/dev/null || echo "0")
        # Subtract the diff header lines
        FILE_ADDS=$((FILE_ADDS > 1 ? FILE_ADDS - 1 : 0))
        FILE_DELS=$((FILE_DELS > 1 ? FILE_DELS - 1 : 0))

        # Escape the diff content for JSON
        ESCAPED_DIFF=$(escape_json "$DIFF_CONTENT")

        [ "$FILE_INDEX" -gt 0 ] && FILE_DIFFS+=","
        FILE_DIFFS+="
        {
          \"path\": \"$filepath\",
          \"extension\": \"$EXT\",
          \"additions\": $FILE_ADDS,
          \"deletions\": $FILE_DELS,
          \"diff\": \"$ESCAPED_DIFF\"
        }"

        FILE_INDEX=$((FILE_INDEX + 1))
    done <<< "$FILES_LIST"

    # Build files array for listing (without diffs)
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
    done <<< "$FILES_LIST"
    FILES_JSON+="]"

    # Escape subject for JSON
    SUBJECT_ESCAPED=$(escape_json "$subject")

    # Add comma separator
    if [ "$FIRST_COMMIT" = true ]; then
        FIRST_COMMIT=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    # Write commit entry with diffs
    cat >> "$TMP_FILE" << COMMIT_EOF
    {
      "hash": "$hash",
      "short_hash": "${hash:0:7}",
      "author": "$author",
      "date": "$date",
      "subject": "$SUBJECT_ESCAPED",
      "agent": "$AGENT",
      "task_id": "$TASK_ID",
      "files_count": $FILES_COUNT,
      "additions": $INSERTIONS,
      "deletions": $DELETIONS,
      "files": $FILES_JSON,
      "file_diffs": [$FILE_DIFFS
      ]
    }
COMMIT_EOF

    COMMIT_INDEX=$((COMMIT_INDEX + 1))

done < "$TMP_COMMITS"

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# ============================================================
# Build agent summary statistics
# ============================================================
echo '  "by_agent": {' >> "$TMP_FILE"

FIRST_AGENT=true
for agent in "${!AGENT_COMMITS[@]}"; do
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo ',' >> "$TMP_FILE"
    fi
    cat >> "$TMP_FILE" << AGENT_EOF
    "$agent": {
      "commits": ${AGENT_COMMITS[$agent]},
      "files_changed": ${AGENT_FILES[$agent]},
      "additions": ${AGENT_ADDITIONS[$agent]},
      "deletions": ${AGENT_DELETIONS[$agent]}
    }
AGENT_EOF
done

echo '  },' >> "$TMP_FILE"

# ============================================================
# Build file type statistics
# ============================================================
echo '  "by_file_type": {' >> "$TMP_FILE"

# Count files by extension
declare -A EXT_COUNT
git log --pretty=format: --name-only -n "$MAX_COMMITS" 2>/dev/null | \
    grep -v '^$' | while read f; do
        ext="${f##*.}"
        echo "$ext"
    done | sort | uniq -c | sort -rn | head -15 | while read count ext; do
    [ -z "$ext" ] && continue
    echo "    \"$ext\": $count,"
done >> "$TMP_FILE"

# Remove trailing comma (use sed)
sed -i '$ s/,$//' "$TMP_FILE"

echo '  },' >> "$TMP_FILE"

# ============================================================
# Build daily summary (last 7 days)
# ============================================================
echo '  "daily_summary": [' >> "$TMP_FILE"

# Get daily stats for last 7 days
FIRST_DAY=true
for i in $(seq 0 6); do
    DATE=$(date -d "$i days ago" +"%Y-%m-%d" 2>/dev/null || date -v-${i}d +"%Y-%m-%d" 2>/dev/null || echo "")
    [ -z "$DATE" ] && continue

    # Count commits, additions, deletions for this day
    DAY_STATS=$(git log --since="$DATE 00:00:00" --until="$DATE 23:59:59" --pretty=format:'%H' 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    DAY_ADDS=$(git log --since="$DATE 00:00:00" --until="$DATE 23:59:59" --stat --format="" 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' | awk '{sum+=$1} END {print sum}' || echo "0")
    DAY_DELS=$(git log --since="$DATE 00:00:00" --until="$DATE 23:59:59" --stat --format="" 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' | awk '{sum+=$1} END {print sum}' || echo "0")
    [ -z "$DAY_ADDS" ] && DAY_ADDS=0
    [ -z "$DAY_DELS" ] && DAY_DELS=0

    if [ "$FIRST_DAY" = true ]; then
        FIRST_DAY=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    cat >> "$TMP_FILE" << DAY_EOF
    {
      "date": "$DATE",
      "commits": $DAY_STATS,
      "additions": $DAY_ADDS,
      "deletions": $DAY_DELS
    }
DAY_EOF
done

echo '  ],' >> "$TMP_FILE"

# ============================================================
# Most changed files (hot spots)
# ============================================================
echo '  "hot_files": [' >> "$TMP_FILE"

FIRST_FILE=true
git log --pretty=format: --name-only -n "$MAX_COMMITS" 2>/dev/null | \
    grep -v '^$' | sort | uniq -c | sort -rn | head -15 | while read count filepath; do
    [ -z "$filepath" ] && continue
    if [ "$FIRST_FILE" = true ]; then
        FIRST_FILE=false
    else
        echo ','
    fi
    cat << HOT_EOF
    {
      "path": "$filepath",
      "change_count": $count
    }
HOT_EOF
done >> "$TMP_FILE"

echo '  ],' >> "$TMP_FILE"

# ============================================================
# Summary statistics
# ============================================================
TODAY=$(date +"%Y-%m-%d")
TODAY_COMMITS=$(git log --since="$TODAY 00:00:00" --pretty=format:'%H' 2>/dev/null | wc -l | tr -d ' ' || echo "0")
TODAY_ADDS=$(git log --since="$TODAY 00:00:00" --stat --format="" 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' | awk '{sum+=$1} END {print sum}' || echo "0")
TODAY_DELS=$(git log --since="$TODAY 00:00:00" --stat --format="" 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' | awk '{sum+=$1} END {print sum}' || echo "0")
[ -z "$TODAY_ADDS" ] && TODAY_ADDS=0
[ -z "$TODAY_DELS" ] && TODAY_DELS=0

cat >> "$TMP_FILE" << EOF
  "summary": {
    "total_commits": $TOTAL_COMMITS,
    "total_files_changed": $TOTAL_FILES_CHANGED,
    "total_additions": $TOTAL_ADDITIONS,
    "total_deletions": $TOTAL_DELETIONS,
    "net_change": $((TOTAL_ADDITIONS - TOTAL_DELETIONS)),
    "today_commits": $TODAY_COMMITS,
    "today_additions": $TODAY_ADDS,
    "today_deletions": $TODAY_DELS,
    "unique_agents": ${#AGENT_COMMITS[@]}
  }
}
EOF

# Move temp file to output (atomic operation)
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Diffs data updated: $OUTPUT_FILE"
