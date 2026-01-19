#!/bin/bash
# health-check.sh - Quick health check for the self-sustaining system
# Can be run by any actor before starting work
# Part of the Self-Sustaining Engine (see CLAUDE.md)

HOME_DIR="/home/novakj"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

check() {
    local status="$1"
    local message="$2"
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}[OK]${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
        ((WARNINGS++))
    else
        echo -e "${RED}[FAIL]${NC} $message"
        ((ERRORS++))
    fi
}

echo "=== System Health Check ==="
echo "Time: $(date)"
echo ""

# 1. Core files
echo "--- Core Files ---"
for file in "$HOME_DIR/CLAUDE.md" "$HOME_DIR/tasks.md" "$HOME_DIR/scripts/cron-orchestrator.sh" "$HOME_DIR/scripts/run-actor.sh"; do
    if [ -f "$file" ]; then
        check "OK" "$file exists"
    else
        check "FAIL" "$file MISSING"
    fi
done

# 2. Script syntax
echo ""
echo "--- Script Syntax ---"
for script in "$HOME_DIR/scripts/"*.sh; do
    if bash -n "$script" 2>/dev/null; then
        check "OK" "$(basename "$script") syntax valid"
    else
        check "FAIL" "$(basename "$script") has syntax errors"
    fi
done

# 3. Disk space
echo ""
echo "--- Disk Space ---"
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 90 ]; then
    check "FAIL" "Disk at ${DISK_USAGE}% - CRITICAL"
elif [ "$DISK_USAGE" -gt 80 ]; then
    check "WARN" "Disk at ${DISK_USAGE}% - Running low"
else
    check "OK" "Disk at ${DISK_USAGE}%"
fi

# 4. Services
echo ""
echo "--- Services ---"
for service in cron nginx ssh; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        check "OK" "$service is running"
    else
        check "WARN" "$service is not running"
    fi
done

# 5. Git status
echo ""
echo "--- Git Status ---"
cd "$HOME_DIR"
if git status >/dev/null 2>&1; then
    check "OK" "Git repository accessible"

    # Check if we're on main branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$BRANCH" = "main" ]; then
        check "OK" "On main branch"
    else
        check "WARN" "On branch: $BRANCH (expected main)"
    fi

    # Check for uncommitted changes
    if git diff --quiet && git diff --cached --quiet; then
        check "OK" "No uncommitted changes"
    else
        CHANGES=$(git status --porcelain | wc -l)
        check "WARN" "$CHANGES uncommitted changes"
    fi
else
    check "FAIL" "Git repository not accessible"
fi

# 6. Memory
echo ""
echo "--- Memory ---"
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_PERCENT" -gt 90 ]; then
    check "FAIL" "Memory at ${MEM_PERCENT}% - CRITICAL"
elif [ "$MEM_PERCENT" -gt 80 ]; then
    check "WARN" "Memory at ${MEM_PERCENT}% - High"
else
    check "OK" "Memory at ${MEM_PERCENT}%"
fi

# 7. tasks.md validity
echo ""
echo "--- Task Board ---"
if [ -f "$HOME_DIR/tasks.md" ]; then
    if grep -q "^# Task Board" "$HOME_DIR/tasks.md"; then
        check "OK" "tasks.md has valid header"
    else
        check "FAIL" "tasks.md may be corrupted (missing header)"
    fi

    BACKLOG=$(grep -c "TODO" "$HOME_DIR/tasks.md" 2>/dev/null || echo "0")
    BACKLOG=$(echo "$BACKLOG" | tr -d '\n')
    if [ "$BACKLOG" -gt 30 ] 2>/dev/null; then
        check "WARN" "Backlog has $BACKLOG tasks (limit: 30)"
    else
        check "OK" "Backlog has $BACKLOG tasks"
    fi
else
    check "FAIL" "tasks.md not found"
fi

# 8. Web app
echo ""
echo "--- Web Application ---"
WEB_ROOT="/var/www/cronloop.techtools.cz"
if [ -d "$WEB_ROOT" ]; then
    check "OK" "Web root exists"
    if [ -f "$WEB_ROOT/index.html" ]; then
        check "OK" "index.html exists"
    else
        check "WARN" "index.html missing"
    fi
else
    check "WARN" "Web root not found"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}CRITICAL: $ERRORS errors found. System may not function properly.${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}ATTENTION: $WARNINGS warnings. System functional but needs attention.${NC}"
    exit 0
else
    echo -e "${GREEN}ALL CHECKS PASSED. System is healthy.${NC}"
    exit 0
fi
