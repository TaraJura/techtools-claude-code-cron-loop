#!/bin/bash

# File Permission Auditor
# Scans important directories for potentially insecure file permissions
# Checks for: world-writable files, SUID/SGID binaries, overly permissive modes

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default directories to scan
HOME_DIRS="/home"
TMP_DIRS="/tmp /var/tmp"
SYSTEM_DIRS="/usr/local/bin /opt"

show_help() {
    echo "File Permission Auditor"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Show all findings (not just summary counts)"
    echo "  -d, --dir DIR   Scan specific directory instead of defaults"
    echo "  -q, --quick     Quick scan (skip SUID/SGID system scan)"
    echo ""
    echo "Checks performed:"
    echo "  1. World-writable files in home directories and /tmp"
    echo "  2. SUID/SGID binaries in non-standard locations"
    echo "  3. Files with overly permissive modes (777, 666)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full audit with default directories"
    echo "  $0 -v               # Verbose output showing all findings"
    echo "  $0 -d /var/www      # Scan specific directory"
    echo "  $0 -q               # Quick scan (skip SUID/SGID)"
}

VERBOSE=false
QUICK=false
CUSTOM_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quick)
            QUICK=true
            shift
            ;;
        -d|--dir)
            CUSTOM_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}       File Permission Auditor${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "Scan started: $(date)"
echo ""

# Counters
WORLD_WRITABLE_COUNT=0
SUID_SGID_COUNT=0
PERMISSIVE_COUNT=0
TOTAL_ISSUES=0

# Arrays to store findings
declare -a WORLD_WRITABLE_FILES
declare -a SUID_SGID_FILES
declare -a PERMISSIVE_FILES

# Function to check if path should be excluded
should_exclude() {
    local path="$1"
    # Exclude common false positives
    case "$path" in
        */\.git/*) return 0 ;;
        */node_modules/*) return 0 ;;
        */\.cache/*) return 0 ;;
        */__pycache__/*) return 0 ;;
    esac
    return 1
}

# 1. Check for world-writable files
echo -e "${YELLOW}[1/3] Scanning for world-writable files...${NC}"

if [[ -n "$CUSTOM_DIR" ]]; then
    SCAN_DIRS="$CUSTOM_DIR"
else
    SCAN_DIRS="$HOME_DIRS $TMP_DIRS"
fi

for dir in $SCAN_DIRS; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            should_exclude "$file" && continue
            WORLD_WRITABLE_FILES+=("$file")
            ((WORLD_WRITABLE_COUNT++))
        done < <(find "$dir" -xdev -type f -perm -0002 2>/dev/null)
    fi
done

if [[ $WORLD_WRITABLE_COUNT -gt 0 ]]; then
    echo -e "  ${RED}Found $WORLD_WRITABLE_COUNT world-writable file(s)${NC}"
    if [[ "$VERBOSE" == "true" ]]; then
        for f in "${WORLD_WRITABLE_FILES[@]}"; do
            echo -e "    ${RED}[!]${NC} $f"
        done
    fi
else
    echo -e "  ${GREEN}No world-writable files found${NC}"
fi
echo ""

# 2. Check for SUID/SGID binaries in non-standard locations
echo -e "${YELLOW}[2/3] Scanning for SUID/SGID binaries in non-standard locations...${NC}"

if [[ "$QUICK" == "true" ]]; then
    echo "  (Skipped - quick mode enabled)"
else
    # Standard locations where SUID/SGID is expected
    STANDARD_SUID_DIRS="/usr/bin /usr/sbin /bin /sbin /usr/lib /usr/libexec"

    if [[ -n "$CUSTOM_DIR" ]]; then
        SUID_SCAN_DIRS="$CUSTOM_DIR"
    else
        SUID_SCAN_DIRS="$HOME_DIRS $SYSTEM_DIRS /var"
    fi

    for dir in $SUID_SCAN_DIRS; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                should_exclude "$file" && continue

                # Check if file is in a standard location
                in_standard=false
                for std_dir in $STANDARD_SUID_DIRS; do
                    if [[ "$file" == "$std_dir"/* ]]; then
                        in_standard=true
                        break
                    fi
                done

                if [[ "$in_standard" == "false" ]]; then
                    SUID_SGID_FILES+=("$file")
                    ((SUID_SGID_COUNT++))
                fi
            done < <(find "$dir" -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null)
        fi
    done

    if [[ $SUID_SGID_COUNT -gt 0 ]]; then
        echo -e "  ${RED}Found $SUID_SGID_COUNT SUID/SGID binary(ies) in non-standard locations${NC}"
        if [[ "$VERBOSE" == "true" ]]; then
            for f in "${SUID_SGID_FILES[@]}"; do
                perms=$(stat -c '%a' "$f" 2>/dev/null)
                echo -e "    ${RED}[!]${NC} $f (mode: $perms)"
            done
        fi
    else
        echo -e "  ${GREEN}No SUID/SGID binaries in non-standard locations${NC}"
    fi
fi
echo ""

# 3. Check for overly permissive files (777, 666)
echo -e "${YELLOW}[3/3] Scanning for overly permissive files (777, 666)...${NC}"

if [[ -n "$CUSTOM_DIR" ]]; then
    PERM_SCAN_DIRS="$CUSTOM_DIR"
else
    PERM_SCAN_DIRS="$HOME_DIRS"
fi

for dir in $PERM_SCAN_DIRS; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            should_exclude "$file" && continue
            PERMISSIVE_FILES+=("$file")
            ((PERMISSIVE_COUNT++))
        done < <(find "$dir" -xdev -type f \( -perm 777 -o -perm 666 \) 2>/dev/null)
    fi
done

if [[ $PERMISSIVE_COUNT -gt 0 ]]; then
    echo -e "  ${RED}Found $PERMISSIVE_COUNT file(s) with mode 777 or 666${NC}"
    if [[ "$VERBOSE" == "true" ]]; then
        for f in "${PERMISSIVE_FILES[@]}"; do
            perms=$(stat -c '%a' "$f" 2>/dev/null)
            echo -e "    ${RED}[!]${NC} $f (mode: $perms)"
        done
    fi
else
    echo -e "  ${GREEN}No files with overly permissive modes${NC}"
fi
echo ""

# Summary
TOTAL_ISSUES=$((WORLD_WRITABLE_COUNT + SUID_SGID_COUNT + PERMISSIVE_COUNT))

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}                 Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "World-writable files:     $WORLD_WRITABLE_COUNT"
echo "SUID/SGID (non-standard): $SUID_SGID_COUNT"
echo "Overly permissive (777/666): $PERMISSIVE_COUNT"
echo "----------------------------"
echo -e "Total issues found:       ${TOTAL_ISSUES}"
echo ""

if [[ $TOTAL_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}[OK] No permission issues found${NC}"
else
    echo -e "${YELLOW}[ATTENTION] Found $TOTAL_ISSUES permission issue(s)${NC}"
    echo ""
    echo -e "${CYAN}Recommendations:${NC}"

    if [[ $WORLD_WRITABLE_COUNT -gt 0 ]]; then
        echo "  - World-writable files: Remove world-write permission"
        echo "    Command: chmod o-w <file>"
    fi

    if [[ $SUID_SGID_COUNT -gt 0 ]]; then
        echo "  - SUID/SGID binaries: Review if setuid/setgid is needed"
        echo "    Command: chmod u-s <file>  (remove SUID)"
        echo "    Command: chmod g-s <file>  (remove SGID)"
    fi

    if [[ $PERMISSIVE_COUNT -gt 0 ]]; then
        echo "  - Overly permissive files: Restrict permissions"
        echo "    Command: chmod 644 <file>  (read-only for others)"
        echo "    Command: chmod 755 <file>  (for executables)"
    fi
fi

echo ""
echo "Scan completed: $(date)"

# Exit with non-zero if issues found
if [[ $TOTAL_ISSUES -gt 0 ]]; then
    exit 1
fi
exit 0
