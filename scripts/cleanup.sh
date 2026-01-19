#!/bin/bash
# cleanup.sh - Daily cleanup for the self-sustaining system
# Runs at 3 AM daily to keep the system clean
# Part of the Self-Sustaining Engine (see CLAUDE.md)

set -e

HOME_DIR="/home/novakj"
LOG_FILE="/home/novakj/logs/cleanup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Daily Cleanup Started ==="

# 1. Delete actor logs older than 7 days
log "Cleaning actor logs older than 7 days..."
DELETED=$(find "$HOME_DIR/actors/*/logs/" -name "*.log" -mtime +7 -delete -print 2>/dev/null | wc -l || echo 0)
log "Deleted $DELETED old log files"

# 2. Clean maintenance logs older than 30 days
log "Cleaning maintenance logs older than 30 days..."
find "$HOME_DIR/logs/" -name "*.log" -mtime +30 -delete 2>/dev/null || true

# 3. Rotate cron.log (keep last 2000 lines)
CRON_LOG="$HOME_DIR/actors/cron.log"
if [ -f "$CRON_LOG" ]; then
    LINES=$(wc -l < "$CRON_LOG")
    if [ "$LINES" -gt 2000 ]; then
        log "Rotating cron.log ($LINES lines -> 2000 lines)"
        tail -n 2000 "$CRON_LOG" > "${CRON_LOG}.tmp" && mv "${CRON_LOG}.tmp" "$CRON_LOG"
    fi
fi

# 4. Clean old backups (keep last 5)
BACKUP_DIR="$HOME_DIR/backups"
if [ -d "$BACKUP_DIR" ]; then
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l || echo 0)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        log "Rotating backups (keeping last 5)..."
        ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
    fi
fi

# 5. Archive completed tasks if >50
TASKS_FILE="$HOME_DIR/tasks.md"
ARCHIVE_FILE="$HOME_DIR/tasks-archive.md"
COMPLETED_COUNT=$(grep -c "^### TASK-.*VERIFIED\|^### TASK-.*DONE" "$TASKS_FILE" 2>/dev/null || echo 0)

if [ "$COMPLETED_COUNT" -gt 50 ]; then
    log "Archiving completed tasks ($COMPLETED_COUNT found)..."

    # Create archive header if it doesn't exist
    if [ ! -f "$ARCHIVE_FILE" ]; then
        echo "# Task Archive" > "$ARCHIVE_FILE"
        echo "" >> "$ARCHIVE_FILE"
        echo "Archived tasks from the main task board." >> "$ARCHIVE_FILE"
        echo "" >> "$ARCHIVE_FILE"
        echo "---" >> "$ARCHIVE_FILE"
        echo "" >> "$ARCHIVE_FILE"
    fi

    # Add date header
    echo "## Archived on $(date '+%Y-%m-%d')" >> "$ARCHIVE_FILE"
    echo "" >> "$ARCHIVE_FILE"

    log "Tasks should be manually reviewed and archived. Auto-archive disabled for safety."
fi

# 6. Clean temporary files
log "Cleaning temporary files..."
rm -f /tmp/agent-orchestrator.lock 2>/dev/null || true
rm -f /tmp/*.tmp 2>/dev/null || true

# 7. Run git garbage collection
log "Running git garbage collection..."
cd "$HOME_DIR"
git gc --auto 2>/dev/null || true

# 8. Report disk usage
DISK_USAGE=$(df / | awk 'NR==2 {print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
log "Disk status: $DISK_USAGE used, $DISK_AVAIL available"

# 9. Report system health summary
log "System health summary:"
log "  - Cron: $(systemctl is-active cron)"
log "  - Nginx: $(systemctl is-active nginx)"
log "  - Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
log "  - Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"

log "=== Daily Cleanup Completed ==="
