#!/bin/bash
# Universal actor runner script
# Usage: ./run-actor.sh <actor-name>
# Example: ./run-actor.sh developer

set -e

ACTOR_NAME="$1"
HOME_DIR="/home/novakj"
ACTOR_DIR="$HOME_DIR/actors/$ACTOR_NAME"
LOG_DIR="$ACTOR_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/${TIMESTAMP}.log"

# Validate actor
if [ -z "$ACTOR_NAME" ]; then
    echo "Usage: $0 <actor-name>"
    exit 1
fi

if [ ! -d "$ACTOR_DIR" ]; then
    echo "Actor '$ACTOR_NAME' not found at $ACTOR_DIR"
    exit 1
fi

# Read prompt
PROMPT_FILE="$ACTOR_DIR/prompt.md"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Prompt file not found: $PROMPT_FILE"
    exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")

# Create log entry header
echo "========================================" >> "$LOG_FILE"
echo "Actor: $ACTOR_NAME" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Run Claude Code in headless mode
cd "$HOME_DIR"
echo "Running $ACTOR_NAME agent..." >> "$LOG_FILE"

# Execute Claude with the prompt, capture output
/home/novakj/.local/bin/claude --dangerously-skip-permissions -p "$PROMPT" 2>&1 | tee -a "$LOG_FILE"

# Log completion
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "Completed: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Git commit and push
cd "$HOME_DIR"
if [ -n "$(git status --porcelain)" ]; then
    echo "" >> "$LOG_FILE"
    echo "Committing changes to git..." >> "$LOG_FILE"
    git add -A
    git commit -m "[$ACTOR_NAME] Auto-commit $(date +%Y-%m-%d\ %H:%M:%S)" >> "$LOG_FILE" 2>&1
    git push >> "$LOG_FILE" 2>&1
    echo "Changes pushed to GitHub" >> "$LOG_FILE"
else
    echo "No changes to commit" >> "$LOG_FILE"
fi

echo "Done. Log saved to: $LOG_FILE"
