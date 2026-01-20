#!/bin/bash
# Supervisor agent runner script
# Runs hourly to oversee the entire AI ecosystem
# This is a special version of run-actor.sh with supervisor-specific handling

set -e

HOME_DIR="/home/novakj"
ACTOR_NAME="supervisor"
ACTOR_DIR="$HOME_DIR/actors/$ACTOR_NAME"
LOG_DIR="$ACTOR_DIR/logs"
STATE_FILE="$ACTOR_DIR/state.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/${TIMESTAMP}.log"

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" << 'EOF'
{
  "last_run": null,
  "runs_count": 0,
  "current_todos": [],
  "completed_todos": [],
  "observations": [],
  "concerns": [],
  "metrics": {
    "issues_found": 0,
    "issues_fixed": 0,
    "checks_performed": 0
  },
  "rotation_state": {
    "weekly_index": 0,
    "monthly_index": 0
  },
  "next_id": 1
}
EOF
    echo "Initialized new state file" >> "$LOG_FILE"
fi

# Read prompt
PROMPT_FILE="$ACTOR_DIR/prompt.md"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "ERROR: Prompt file not found: $PROMPT_FILE"
    exit 1
fi

# Build enhanced prompt with current state
STATE_CONTENT=$(cat "$STATE_FILE")
PROMPT=$(cat "$PROMPT_FILE")

# Append current state to prompt
ENHANCED_PROMPT="$PROMPT

---

## CURRENT STATE (from state.json)

\`\`\`json
$STATE_CONTENT
\`\`\`

---

## INSTRUCTIONS FOR THIS RUN

1. Read and understand your current state above
2. Perform quick health checks (cron, disk, core files)
3. Work on 1-2 pending todos from your current_todos
4. Rotate through weekly/monthly checks as appropriate
5. Update your state file at /home/novakj/actors/supervisor/state.json with:
   - Updated last_run timestamp
   - Incremented runs_count
   - Updated todo statuses
   - Any new observations or concerns
   - New todos if issues found
6. Output a brief summary of what you checked and did

Remember: Be PASSIVE. Observe more than act. Don't break working things.
"

# Create log entry header
echo "========================================" >> "$LOG_FILE"
echo "SUPERVISOR RUN" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Run Claude Code in headless mode
cd "$HOME_DIR"
echo "Running supervisor agent..." >> "$LOG_FILE"

# Execute Claude with the enhanced prompt, capture output
/home/novakj/.local/bin/claude --dangerously-skip-permissions -p "$ENHANCED_PROMPT" 2>&1 | tee -a "$LOG_FILE"

# Log completion
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "Completed: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Git commit and push (supervisor changes should be committed)
cd "$HOME_DIR"
if [ -n "$(git status --porcelain)" ]; then
    echo "" >> "$LOG_FILE"
    echo "Committing changes to git..." >> "$LOG_FILE"
    git add -A
    git commit -m "[supervisor] Auto-commit $(date +%Y-%m-%d\ %H:%M:%S)" >> "$LOG_FILE" 2>&1
    git push >> "$LOG_FILE" 2>&1
    echo "Changes pushed to GitHub" >> "$LOG_FILE"
else
    echo "No changes to commit" >> "$LOG_FILE"
fi

echo "Supervisor run complete. Log: $LOG_FILE"
