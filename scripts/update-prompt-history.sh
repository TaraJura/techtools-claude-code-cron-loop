#!/bin/bash
# update-prompt-history.sh - Extracts git history for agent prompt.md files
# Output: JSON data for prompt evolution viewer page

set -e

REPO_DIR="/home/novakj"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/prompt-history.json"
ACTORS_DIR="$REPO_DIR/actors"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

cd "$REPO_DIR"

# Create temporary file for building JSON
TMP_FILE=$(mktemp)

# Agent list
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Start JSON structure
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "agents": [
EOF

FIRST_AGENT=true

for AGENT in "${AGENTS[@]}"; do
    PROMPT_FILE="actors/$AGENT/prompt.md"

    # Skip if prompt file doesn't exist
    [ ! -f "$PROMPT_FILE" ] && continue

    # Add comma separator
    if [ "$FIRST_AGENT" = true ]; then
        FIRST_AGENT=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    # Get current prompt stats
    CURRENT_SIZE=$(wc -c < "$PROMPT_FILE" 2>/dev/null || echo "0")
    CURRENT_LINES=$(wc -l < "$PROMPT_FILE" 2>/dev/null || echo "0")
    CURRENT_MODIFIED=$(stat -c %Y "$PROMPT_FILE" 2>/dev/null || echo "0")

    # Count total commits for this prompt file
    TOTAL_COMMITS=$(git log --oneline -- "$PROMPT_FILE" 2>/dev/null | wc -l || echo "0")

    # Get first and last modified dates from git
    FIRST_COMMIT_DATE=$(git log --follow --format="%aI" -- "$PROMPT_FILE" 2>/dev/null | tail -1 || echo "")
    LAST_COMMIT_DATE=$(git log -1 --format="%aI" -- "$PROMPT_FILE" 2>/dev/null || echo "")

    # Start agent object
    cat >> "$TMP_FILE" << AGENT_START
    {
      "id": "$AGENT",
      "prompt_path": "$PROMPT_FILE",
      "current": {
        "size": $CURRENT_SIZE,
        "lines": $CURRENT_LINES,
        "modified": $CURRENT_MODIFIED
      },
      "total_versions": $TOTAL_COMMITS,
      "first_version": "$FIRST_COMMIT_DATE",
      "last_version": "$LAST_COMMIT_DATE",
      "versions": [
AGENT_START

    # Get git history for this prompt file (last 50 versions max)
    FIRST_VERSION=true
    git log --pretty=format:'%H|%aI|%s' -n 50 -- "$PROMPT_FILE" 2>/dev/null | while IFS='|' read -r hash date subject; do
        [ -z "$hash" ] && continue

        # Get file stats at this commit
        FILE_SIZE=$(git show "$hash:$PROMPT_FILE" 2>/dev/null | wc -c || echo "0")
        FILE_LINES=$(git show "$hash:$PROMPT_FILE" 2>/dev/null | wc -l || echo "0")

        # Get diff stats compared to previous version
        PREV_HASH=$(git log --skip=1 -1 --format="%H" "$hash" -- "$PROMPT_FILE" 2>/dev/null || echo "")
        if [ -n "$PREV_HASH" ]; then
            DIFF_STATS=$(git diff --stat "$PREV_HASH" "$hash" -- "$PROMPT_FILE" 2>/dev/null | tail -1 || echo "")
            INSERTIONS=$(echo "$DIFF_STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' | head -1 || echo "0")
            DELETIONS=$(echo "$DIFF_STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' | head -1 || echo "0")
        else
            INSERTIONS="$FILE_LINES"
            DELETIONS="0"
        fi
        [ -z "$INSERTIONS" ] && INSERTIONS="0"
        [ -z "$DELETIONS" ] && DELETIONS="0"

        # Escape subject for JSON
        SUBJECT_ESCAPED=$(echo "$subject" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/ /g' | tr -d '\r\n')

        # Extract agent that made the change from commit message
        CHANGED_BY=""
        if [[ "$subject" =~ ^\[([a-zA-Z0-9-]+)\] ]]; then
            CHANGED_BY="${BASH_REMATCH[1]}"
        fi

        # Add comma separator
        if [ "$FIRST_VERSION" = true ]; then
            FIRST_VERSION=false
        else
            echo ',' >> "$TMP_FILE"
        fi

        cat >> "$TMP_FILE" << VERSION_EOF
        {
          "hash": "$hash",
          "short_hash": "${hash:0:7}",
          "date": "$date",
          "subject": "$SUBJECT_ESCAPED",
          "changed_by": "$CHANGED_BY",
          "size": $FILE_SIZE,
          "lines": $FILE_LINES,
          "insertions": $INSERTIONS,
          "deletions": $DELETIONS
        }
VERSION_EOF
    done

    echo '' >> "$TMP_FILE"
    echo '      ]' >> "$TMP_FILE"
    echo '    }' >> "$TMP_FILE"
done

cat >> "$TMP_FILE" << EOF

  ],
  "summary": {
    "total_agents": ${#AGENTS[@]},
    "total_prompt_versions": $(git log --oneline -- 'actors/*/prompt.md' 2>/dev/null | wc -l || echo "0")
  }
}
EOF

# Move temp file to output (atomic operation)
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Prompt history data updated: $OUTPUT_FILE"
