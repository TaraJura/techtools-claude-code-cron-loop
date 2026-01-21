#!/bin/bash
# update-provenance.sh - Generates file provenance data for archaeology explorer
# Output: JSON data for file provenance analysis

set -e

REPO_DIR="/home/novakj"
WEB_DIR="/var/www/cronloop.techtools.cz"
OUTPUT_FILE="$WEB_DIR/api/provenance.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cd "$REPO_DIR"

# Create temporary file
TMP_FILE=$(mktemp)

# Start JSON structure
cat > "$TMP_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "repo_root": "$REPO_DIR",
  "web_root": "$WEB_DIR",
EOF

# Get list of all tracked files
echo '  "tracked_files": [' >> "$TMP_FILE"

FIRST=true
git ls-files 2>/dev/null | while read -r file; do
    [ -z "$file" ] && continue

    # Get first commit for this file
    FIRST_COMMIT=$(git log --follow --diff-filter=A --format="%H|%aI|%an|%s" -- "$file" 2>/dev/null | tail -1)

    if [ -n "$FIRST_COMMIT" ]; then
        HASH=$(echo "$FIRST_COMMIT" | cut -d'|' -f1)
        DATE=$(echo "$FIRST_COMMIT" | cut -d'|' -f2)
        AUTHOR=$(echo "$FIRST_COMMIT" | cut -d'|' -f3)
        SUBJECT=$(echo "$FIRST_COMMIT" | cut -d'|' -f4- | sed 's/"/\\"/g' | tr -d '\r\n')

        # Extract agent from commit message
        AGENT=""
        if [[ "$SUBJECT" =~ ^\[([a-zA-Z0-9-]+)\] ]]; then
            AGENT="${BASH_REMATCH[1]}"
        fi

        # Extract task reference
        TASK=$(echo "$SUBJECT" | grep -oE 'TASK-[0-9]+' | head -1 || echo "")

        # Get modification count
        MOD_COUNT=$(git log --follow --oneline -- "$file" 2>/dev/null | wc -l)

        # Get last modification date
        LAST_MOD=$(git log -1 --format="%aI" -- "$file" 2>/dev/null || echo "$DATE")

        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ',' >> "$TMP_FILE"
        fi

        echo -n "    {\"path\": \"$file\", \"created\": \"$DATE\", \"creator_agent\": \"$AGENT\", \"task\": \"$TASK\", \"first_commit\": \"${HASH:0:7}\", \"modifications\": $MOD_COUNT, \"last_modified\": \"$LAST_MOD\"}" >> "$TMP_FILE"
    fi
done

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Get recently modified files (last 50)
echo '  "recent_files": [' >> "$TMP_FILE"

git log --pretty=format: --name-only -n 100 2>/dev/null | grep -v '^$' | sort -u | head -50 | while read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue

    LAST_MOD=$(git log -1 --format="%aI" -- "$file" 2>/dev/null || echo "")
    LAST_AGENT=""
    LAST_SUBJECT=$(git log -1 --format="%s" -- "$file" 2>/dev/null || echo "")
    if [[ "$LAST_SUBJECT" =~ ^\[([a-zA-Z0-9-]+)\] ]]; then
        LAST_AGENT="${BASH_REMATCH[1]}"
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ',' >> "$TMP_FILE"
    fi

    echo -n "    {\"path\": \"$file\", \"last_modified\": \"$LAST_MOD\", \"last_agent\": \"$LAST_AGENT\"}" >> "$TMP_FILE"
done

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Orphan candidates: files not modified in 30 days
echo '  "orphan_candidates": [' >> "$TMP_FILE"
THIRTY_DAYS_AGO=$(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s 2>/dev/null || echo "0")

FIRST=true
git ls-files 2>/dev/null | while read -r file; do
    [ -z "$file" ] && continue

    LAST_MOD=$(git log -1 --format="%at" -- "$file" 2>/dev/null || echo "0")

    if [ "$LAST_MOD" -lt "$THIRTY_DAYS_AGO" ] 2>/dev/null; then
        DAYS_OLD=$(( ($(date +%s) - LAST_MOD) / 86400 ))

        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ',' >> "$TMP_FILE"
        fi

        echo -n "    {\"path\": \"$file\", \"days_since_modified\": $DAYS_OLD}" >> "$TMP_FILE"
    fi
done

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Files without task references (unknown provenance)
echo '  "unknown_provenance": [' >> "$TMP_FILE"

FIRST=true
git ls-files 2>/dev/null | head -100 | while read -r file; do
    [ -z "$file" ] && continue

    FIRST_COMMIT_MSG=$(git log --follow --diff-filter=A --format="%s" -- "$file" 2>/dev/null | tail -1)

    if ! echo "$FIRST_COMMIT_MSG" | grep -qE 'TASK-[0-9]+'; then
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ',' >> "$TMP_FILE"
        fi

        ESCAPED_MSG=$(echo "$FIRST_COMMIT_MSG" | sed 's/"/\\"/g' | tr -d '\r\n')
        echo -n "    {\"path\": \"$file\", \"first_commit_msg\": \"$ESCAPED_MSG\"}" >> "$TMP_FILE"
    fi
done

echo '' >> "$TMP_FILE"
echo '  ],' >> "$TMP_FILE"

# Statistics
TOTAL_FILES=$(git ls-files 2>/dev/null | wc -l)
FILES_WITH_TASKS=$(git log --all --format="%s" 2>/dev/null | grep -c 'TASK-[0-9]' || echo "0")
UNIQUE_AGENTS=$(git log --all --format="%s" -n 500 2>/dev/null | grep -oE '^\[[a-zA-Z0-9-]+\]' | sort -u | wc -l)

cat >> "$TMP_FILE" << EOF
  "statistics": {
    "total_tracked_files": $TOTAL_FILES,
    "commits_with_tasks": $FILES_WITH_TASKS,
    "unique_agents": $UNIQUE_AGENTS
  }
}
EOF

# Move temp file to output
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 644 "$OUTPUT_FILE"

echo "Provenance data updated: $OUTPUT_FILE"
