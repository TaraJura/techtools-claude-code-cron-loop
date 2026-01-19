#!/bin/bash
#
# Package Update Checker
# Checks for available system package updates and summarizes them
#
# Usage: ./package-update-checker.sh [-r] [-u] [-h]
#   -r  Refresh package cache before checking (requires sudo)
#   -u  Show full list of upgradable packages
#   -h  Show help message

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options
REFRESH_CACHE=false
SHOW_FULL_LIST=false

show_help() {
    echo "Package Update Checker"
    echo ""
    echo "Usage: $0 [-r] [-u] [-h]"
    echo ""
    echo "Options:"
    echo "  -r    Refresh package cache before checking (requires sudo)"
    echo "  -u    Show full list of upgradable packages"
    echo "  -h    Show this help message"
    echo ""
    echo "Information shown:"
    echo "  - Count of available updates"
    echo "  - Security updates (listed separately)"
    echo "  - Last package cache update time"
    echo "  - Reboot required status"
    echo ""
    echo "Examples:"
    echo "  $0           # Quick check with current cache"
    echo "  $0 -r        # Refresh cache and check (needs sudo)"
    echo "  $0 -u        # Show all upgradable packages"
    echo "  $0 -r -u     # Refresh and show full list"
}

# Parse arguments
while getopts "ruh" opt; do
    case $opt in
        r)
            REFRESH_CACHE=true
            ;;
        u)
            SHOW_FULL_LIST=true
            ;;
        h)
            show_help
            exit 0
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
done

echo "========================================"
echo "  Package Update Checker"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Check if apt is available
if ! command -v apt &> /dev/null; then
    echo -e "${RED}Error: apt not found. This script is for Debian/Ubuntu systems.${NC}"
    exit 1
fi

# Refresh cache if requested
if [ "$REFRESH_CACHE" = true ]; then
    echo -e "${BLUE}Refreshing package cache...${NC}"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Note: Running with sudo for cache refresh${NC}"
        sudo apt update -qq 2>/dev/null
    else
        apt update -qq 2>/dev/null
    fi
    echo ""
fi

# Get last update time
echo -e "${BLUE}Last Cache Update:${NC}"
if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
    LAST_UPDATE=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d'.' -f1)
    echo "  $LAST_UPDATE"
elif [ -f /var/cache/apt/pkgcache.bin ]; then
    LAST_UPDATE=$(stat -c %y /var/cache/apt/pkgcache.bin 2>/dev/null | cut -d'.' -f1)
    echo "  $LAST_UPDATE (from package cache)"
else
    echo "  Unknown"
fi
echo ""

# Get upgradable packages
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "^Listing" || true)
TOTAL_COUNT=$(echo "$UPGRADABLE" | grep -c . || echo 0)

# Count security updates (packages from security repos)
SECURITY_UPDATES=$(echo "$UPGRADABLE" | grep -E "security|Security" || true)
SECURITY_COUNT=$(echo "$SECURITY_UPDATES" | grep -c . || echo 0)

# Regular (non-security) updates
REGULAR_COUNT=$((TOTAL_COUNT - SECURITY_COUNT))

echo -e "${BLUE}Available Updates:${NC}"
if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}System is up to date!${NC}"
else
    echo -e "  Total:    ${YELLOW}$TOTAL_COUNT${NC} packages"
    if [ "$SECURITY_COUNT" -gt 0 ]; then
        echo -e "  Security: ${RED}$SECURITY_COUNT${NC} packages"
    else
        echo -e "  Security: ${GREEN}0${NC} packages"
    fi
    echo -e "  Regular:  $REGULAR_COUNT packages"
fi
echo ""

# Show security updates if any
if [ "$SECURITY_COUNT" -gt 0 ]; then
    echo -e "${RED}Security Updates:${NC}"
    echo "$SECURITY_UPDATES" | while read -r line; do
        PACKAGE=$(echo "$line" | cut -d'/' -f1)
        VERSION=$(echo "$line" | awk '{print $2}')
        echo "  - $PACKAGE ($VERSION)"
    done
    echo ""
fi

# Show full list if requested
if [ "$SHOW_FULL_LIST" = true ] && [ "$TOTAL_COUNT" -gt 0 ]; then
    echo -e "${BLUE}All Upgradable Packages:${NC}"
    echo "$UPGRADABLE" | while read -r line; do
        PACKAGE=$(echo "$line" | cut -d'/' -f1)
        VERSION=$(echo "$line" | awk '{print $2}')
        if echo "$line" | grep -qE "security|Security"; then
            echo -e "  ${RED}[SEC]${NC} $PACKAGE ($VERSION)"
        else
            echo "  [   ] $PACKAGE ($VERSION)"
        fi
    done
    echo ""
fi

# Check if reboot is required
echo -e "${BLUE}Reboot Status:${NC}"
if [ -f /var/run/reboot-required ]; then
    echo -e "  ${RED}*** REBOOT REQUIRED ***${NC}"
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo "  Packages requiring reboot:"
        while read -r pkg; do
            echo "    - $pkg"
        done < /var/run/reboot-required.pkgs
    fi
else
    echo -e "  ${GREEN}No reboot required${NC}"
fi
echo ""

# Summary
echo "========================================"
if [ "$TOTAL_COUNT" -gt 0 ]; then
    echo -e "Summary: ${YELLOW}$TOTAL_COUNT updates available${NC}"
    if [ "$SECURITY_COUNT" -gt 0 ]; then
        echo -e "         ${RED}$SECURITY_COUNT are security updates${NC}"
    fi
    echo ""
    echo "To upgrade all packages:"
    echo "  sudo apt upgrade"
    echo ""
    echo "To upgrade security packages only:"
    echo "  sudo apt upgrade -y \$(apt list --upgradable 2>/dev/null | grep -i security | cut -d/ -f1)"
else
    echo -e "Summary: ${GREEN}System is up to date${NC}"
fi
echo "========================================"

# Exit with status based on updates available
if [ "$SECURITY_COUNT" -gt 0 ]; then
    exit 2  # Security updates available
elif [ "$TOTAL_COUNT" -gt 0 ]; then
    exit 1  # Regular updates available
else
    exit 0  # All up to date
fi
