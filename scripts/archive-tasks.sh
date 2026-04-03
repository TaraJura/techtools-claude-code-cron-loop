#!/bin/bash
# archive-tasks.sh - Archive VERIFIED tasks from tasks.md to monthly archive
# Called by maintenance.sh when tasks.md exceeds 100KB

set -e

HOME_DIR="/home/novakj"
TASKS_FILE="$HOME_DIR/tasks.md"
ARCHIVE_DIR="$HOME_DIR/logs/tasks-archive"
ARCHIVE_FILE="$ARCHIVE_DIR/tasks-$(date '+%Y-%m').md"

# Safety check
if [ ! -f "$TASKS_FILE" ]; then
    echo "ERROR: tasks.md not found"
    exit 1
fi

# Create archive dir if needed
mkdir -p "$ARCHIVE_DIR"

# Create temp files
TEMP_ARCHIVE=$(mktemp)
TEMP_TASKS=$(mktemp)
trap "rm -f $TEMP_ARCHIVE $TEMP_TASKS" EXIT

# Extract VERIFIED task blocks and remaining content
# A task block starts with ### TASK- and ends before the next ### TASK- or end of file
awk '
BEGIN { in_verified = 0; count = 0 }
/^### TASK-/ {
    # Start of a new task block - flush previous if needed
    if (in_verified) {
        print block > "/dev/fd/3"
        count++
    } else if (block != "") {
        print block
    }
    block = $0
    in_verified = 0
    next
}
/^\*\*Status\*\*: VERIFIED/ {
    in_verified = 1
}
{
    if (block != "") {
        block = block "\n" $0
    } else {
        print $0
    }
}
END {
    if (in_verified) {
        print block > "/dev/fd/3"
        count++
    } else if (block != "") {
        print block
    }
    print count > "/dev/fd/4"
}
' "$TASKS_FILE" > "$TEMP_TASKS" 3>"$TEMP_ARCHIVE" 4>/tmp/archive_count

COUNT=$(cat /tmp/archive_count 2>/dev/null || echo 0)
rm -f /tmp/archive_count

if [ "$COUNT" -eq 0 ]; then
    echo "No VERIFIED tasks to archive"
    exit 0
fi

# Append to monthly archive file
if [ -f "$ARCHIVE_FILE" ]; then
    echo "" >> "$ARCHIVE_FILE"
fi
echo "# Archived $(date '+%Y-%m-%d %H:%M')" >> "$ARCHIVE_FILE"
echo "" >> "$ARCHIVE_FILE"
cat "$TEMP_ARCHIVE" >> "$ARCHIVE_FILE"

# Replace tasks.md with filtered version (backup first)
cp "$TASKS_FILE" "${TASKS_FILE}.bak"
mv "$TEMP_TASKS" "$TASKS_FILE"

echo "Archived $COUNT VERIFIED tasks to $ARCHIVE_FILE"
echo "tasks.md reduced from $(stat -c%s "${TASKS_FILE}.bak" 2>/dev/null || echo '?') to $(stat -c%s "$TASKS_FILE" 2>/dev/null || echo '?') bytes"
