#!/bin/bash
# archive-tasks.sh - Move VERIFIED tasks to archive to keep tasks.md lean
# Run during maintenance or manually when tasks.md gets too large

set -e

TASKS_FILE="/home/novakj/tasks.md"
ARCHIVE_DIR="/home/novakj/logs/tasks-archive"
MONTH=$(date +%Y-%m)
ARCHIVE_FILE="$ARCHIVE_DIR/tasks-$MONTH.md"

# Create archive directory if needed
mkdir -p "$ARCHIVE_DIR"

# Initialize archive file if it doesn't exist
if [ ! -f "$ARCHIVE_FILE" ]; then
    cat > "$ARCHIVE_FILE" << 'EOF'
# Archived Tasks

> Completed tasks moved from tasks.md to keep the active task board lean.
> Tasks are archived monthly after reaching VERIFIED status.

---

EOF
fi

# Count VERIFIED tasks before archiving
VERIFIED_COUNT=$(grep -c "^\- \*\*Status\*\*: VERIFIED" "$TASKS_FILE" 2>/dev/null || echo "0")

if [ "$VERIFIED_COUNT" -eq 0 ]; then
    echo "No VERIFIED tasks to archive"
    exit 0
fi

echo "Found $VERIFIED_COUNT VERIFIED tasks to archive"

# Extract and archive VERIFIED tasks using Python for reliable parsing
python3 << 'PYTHON_SCRIPT'
import re
import os
from datetime import datetime

tasks_file = "/home/novakj/tasks.md"
archive_file = os.environ.get('ARCHIVE_FILE', f"/home/novakj/logs/tasks-archive/tasks-{datetime.now().strftime('%Y-%m')}.md")

with open(tasks_file, 'r') as f:
    content = f.read()

# Split into sections: header and tasks
# Find the Backlog section
parts = content.split("## Backlog (Project Manager assigns these)")
if len(parts) != 2:
    print("Could not find Backlog section")
    exit(1)

header = parts[0] + "## Backlog (Project Manager assigns these)\n"
tasks_section = parts[1]

# Parse individual tasks (### TASK-XXX blocks)
task_pattern = r'(### TASK-\d+:.*?)(?=### TASK-|\Z)'
tasks = re.findall(task_pattern, tasks_section, re.DOTALL)

active_tasks = []
verified_tasks = []

for task in tasks:
    if '**Status**: VERIFIED' in task:
        verified_tasks.append(task.strip())
    else:
        active_tasks.append(task.strip())

if not verified_tasks:
    print("No VERIFIED tasks found")
    exit(0)

# Append verified tasks to archive
with open(archive_file, 'a') as f:
    f.write(f"\n## Archived on {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
    for task in verified_tasks:
        f.write(task + "\n\n")

# Rebuild tasks.md with only active tasks
new_content = header + "\n"
for task in active_tasks:
    new_content += task + "\n\n"

with open(tasks_file, 'w') as f:
    f.write(new_content.rstrip() + "\n")

print(f"Archived {len(verified_tasks)} tasks to {archive_file}")
print(f"Remaining active tasks: {len(active_tasks)}")
PYTHON_SCRIPT

# Show result
NEW_SIZE=$(wc -c < "$TASKS_FILE")
echo "New tasks.md size: $(echo "scale=1; $NEW_SIZE/1024" | bc)KB"
