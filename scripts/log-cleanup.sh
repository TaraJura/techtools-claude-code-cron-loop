#!/bin/bash
# log-cleanup.sh - Log cleanup utility for the autonomous AI ecosystem
# Removes log files older than 7 days from actors/*/logs/ directories
#
# Usage:
#   ./log-cleanup.sh           # Dry-run mode (shows what would be deleted)
#   ./log-cleanup.sh --delete  # Actually delete old log files
#   ./log-cleanup.sh --help    # Show help
#
# Part of the CronLoop system (see CLAUDE.md)

set -e

HOME_DIR="/home/novakj"
ACTORS_DIR="$HOME_DIR/actors"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=true
for arg in "$@"; do
    case $arg in
        --delete)
            DRY_RUN=false
            ;;
        --help|-h)
            echo "Log Cleanup Utility"
            echo ""
            echo "Removes log files older than $RETENTION_DAYS days from actors/*/logs/ directories."
            echo ""
            echo "Usage:"
            echo "  $0           Dry-run mode (shows what would be deleted)"
            echo "  $0 --delete  Actually delete old log files"
            echo "  $0 --help    Show this help message"
            echo ""
            echo "Directories scanned:"
            echo "  $ACTORS_DIR/*/logs/"
            echo ""
            echo "Retention: Files older than $RETENTION_DAYS days are considered for removal."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

echo "======================================"
echo "Log Cleanup Utility"
echo "======================================"
echo ""
echo "Retention policy: $RETENTION_DAYS days"
echo "Target: $ACTORS_DIR/*/logs/*.log"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}MODE: DRY-RUN (no files will be deleted)${NC}"
    echo -e "${YELLOW}Use --delete flag to actually remove files.${NC}"
else
    echo -e "${RED}MODE: DELETE (files will be permanently removed)${NC}"
fi
echo ""

# Find old log files
OLD_FILES=$(find "$ACTORS_DIR"/*/logs/ -name "*.log" -mtime +$RETENTION_DAYS 2>/dev/null || true)

if [ -z "$OLD_FILES" ]; then
    echo -e "${GREEN}No log files older than $RETENTION_DAYS days found.${NC}"
    echo ""
    echo "Summary:"
    echo "  Files to delete: 0"
    echo "  Space to reclaim: 0 bytes"
    exit 0
fi

# Count and calculate size
FILE_COUNT=$(echo "$OLD_FILES" | wc -l)
TOTAL_SIZE=0

echo "Files older than $RETENTION_DAYS days:"
echo "--------------------------------------"

while IFS= read -r file; do
    if [ -f "$file" ]; then
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        MOD_DATE=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1)
        SIZE_HR=$(numfmt --to=iec $SIZE 2>/dev/null || echo "${SIZE}B")

        # Extract agent name from path
        AGENT=$(echo "$file" | sed "s|$ACTORS_DIR/||" | cut -d'/' -f1)
        FILENAME=$(basename "$file")

        if [ "$DRY_RUN" = true ]; then
            echo -e "  ${BLUE}[WOULD DELETE]${NC} $AGENT/$FILENAME ($SIZE_HR, modified $MOD_DATE)"
        else
            rm -f "$file"
            echo -e "  ${RED}[DELETED]${NC} $AGENT/$FILENAME ($SIZE_HR, modified $MOD_DATE)"
        fi
    fi
done <<< "$OLD_FILES"

echo ""
echo "--------------------------------------"
echo "Summary:"
echo "  Files processed: $FILE_COUNT"
TOTAL_SIZE_HR=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
if [ "$DRY_RUN" = true ]; then
    echo -e "  Space to reclaim: ${YELLOW}$TOTAL_SIZE_HR${NC}"
    echo ""
    echo -e "${YELLOW}Run with --delete flag to actually remove these files.${NC}"
else
    echo -e "  Space reclaimed: ${GREEN}$TOTAL_SIZE_HR${NC}"
fi
echo ""
