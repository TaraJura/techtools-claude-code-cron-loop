#!/bin/bash
# maintenance.sh - Routine maintenance for the self-sustaining system
# Runs hourly to keep the system healthy
# Part of the Self-Sustaining Engine (see CLAUDE.md)

set -e

HOME_DIR="/home/novakj"
LOG_FILE="/home/novakj/logs/maintenance.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Maintenance Started ==="

# 1. Check disk usage - abort if critical
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 90 ]; then
    log "CRITICAL: Disk usage at ${DISK_USAGE}%. Running emergency cleanup."
    # Emergency: delete ALL logs older than 1 day
    find "$HOME_DIR/actors/*/logs/" -name "*.log" -mtime +1 -delete 2>/dev/null || true
    log "Emergency cleanup complete."
elif [ "$DISK_USAGE" -gt 80 ]; then
    log "WARNING: Disk usage at ${DISK_USAGE}%. Running cleanup."
    # Delete logs older than 3 days instead of 7
    find "$HOME_DIR/actors/*/logs/" -name "*.log" -mtime +3 -delete 2>/dev/null || true
else
    log "Disk usage: ${DISK_USAGE}% - OK"
fi

# 2. Rotate cron.log if too large (>1MB)
CRON_LOG="$HOME_DIR/actors/cron.log"
if [ -f "$CRON_LOG" ]; then
    CRON_SIZE=$(stat -f%z "$CRON_LOG" 2>/dev/null || stat -c%s "$CRON_LOG" 2>/dev/null || echo 0)
    if [ "$CRON_SIZE" -gt 1048576 ]; then
        log "Rotating cron.log (size: $CRON_SIZE bytes)"
        tail -n 1000 "$CRON_LOG" > "${CRON_LOG}.tmp" && mv "${CRON_LOG}.tmp" "$CRON_LOG"
    fi
fi

# 3. Check core files exist
CORE_FILES=(
    "$HOME_DIR/CLAUDE.md"
    "$HOME_DIR/tasks.md"
    "$HOME_DIR/scripts/cron-orchestrator.sh"
    "$HOME_DIR/scripts/run-actor.sh"
)

MISSING=0
for file in "${CORE_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log "ERROR: Core file missing: $file"
        MISSING=1
    fi
done

if [ "$MISSING" -eq 1 ]; then
    log "Attempting to restore from git..."
    cd "$HOME_DIR"
    git checkout HEAD -- CLAUDE.md tasks.md scripts/*.sh 2>/dev/null || true
    log "Restore attempted. Check manually if issues persist."
fi

# 4. Verify script syntax
for script in "$HOME_DIR/scripts/"*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        log "ERROR: Syntax error in $script"
        log "Attempting to restore from git..."
        git checkout HEAD -- "$script" 2>/dev/null || true
    fi
done

# 5. Check cron is running
if ! systemctl is-active --quiet cron; then
    log "WARNING: Cron service is not running. Attempting restart..."
    sudo systemctl restart cron || log "ERROR: Failed to restart cron"
fi

# 6. Check git status
cd "$HOME_DIR"
if git status --porcelain | grep -q "^"; then
    UNCOMMITTED=$(git status --porcelain | wc -l)
    log "Note: $UNCOMMITTED uncommitted changes in repository"
fi

# 7. Clean git garbage (weekly, only on Sunday)
if [ "$(date +%u)" -eq 7 ] && [ "$(date +%H)" -eq 3 ]; then
    log "Running weekly git garbage collection..."
    git gc --auto 2>/dev/null || true
fi

# 8. Archive completed tasks if >50
COMPLETED_COUNT=$(grep -c "^### TASK-.*VERIFIED\|^### TASK-.*DONE" "$HOME_DIR/tasks.md" 2>/dev/null || echo 0)
if [ "$COMPLETED_COUNT" -gt 50 ]; then
    log "WARNING: $COMPLETED_COUNT completed tasks. Consider archiving to tasks-archive.md"
fi

# 9. Check backlog size
BACKLOG_COUNT=$(grep -c "^### TASK-.*TODO" "$HOME_DIR/tasks.md" 2>/dev/null || echo 0)
if [ "$BACKLOG_COUNT" -gt 30 ]; then
    log "WARNING: Backlog has $BACKLOG_COUNT items. idea-maker should pause."
fi

log "=== Maintenance Completed ==="
