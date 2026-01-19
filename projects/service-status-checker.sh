#!/bin/bash
#
# Service Status Checker
# Checks if key system services are running and reports their status
#

# Default list of critical services to check
CRITICAL_SERVICES=(
    "ssh"
    "sshd"
    "cron"
)

# Default list of optional services to check (non-critical)
OPTIONAL_SERVICES=(
    "systemd-timesyncd"
    "systemd-resolved"
    "systemd-journald"
    "systemd-logind"
    "networkd-dispatcher"
)

# Config file for user-defined services (one service per line)
CONFIG_FILE="/home/novakj/projects/service-status-checker.conf"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
total_checked=0
active_count=0
inactive_count=0
failed_count=0
critical_failed=0

print_header() {
    echo "======================================"
    echo "       Service Status Checker"
    echo "======================================"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $(hostname)"
    echo ""
}

check_service() {
    local service="$1"
    local is_critical="$2"

    ((total_checked++))

    # Get service status
    local status
    status=$(systemctl is-active "$service" 2>/dev/null)
    local exit_code=$?

    # Format output based on status
    case "$status" in
        active)
            ((active_count++))
            printf "  %-30s ${GREEN}[ACTIVE]${NC}\n" "$service"
            ;;
        inactive)
            ((inactive_count++))
            if [[ "$is_critical" == "critical" ]]; then
                ((critical_failed++))
                printf "  %-30s ${RED}[INACTIVE]${NC} (critical)\n" "$service"
            else
                printf "  %-30s ${YELLOW}[INACTIVE]${NC}\n" "$service"
            fi
            ;;
        failed)
            ((failed_count++))
            if [[ "$is_critical" == "critical" ]]; then
                ((critical_failed++))
            fi
            printf "  %-30s ${RED}[FAILED]${NC}\n" "$service"
            ;;
        *)
            # Service doesn't exist or unknown status
            if [[ "$is_critical" == "critical" ]]; then
                ((critical_failed++))
                printf "  %-30s ${RED}[NOT FOUND]${NC} (critical)\n" "$service"
            else
                printf "  %-30s ${YELLOW}[NOT FOUND]${NC}\n" "$service"
            fi
            ;;
    esac
}

# Load user-defined services from config file
load_config_services() {
    local user_critical=()
    local user_optional=()

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # Check if line specifies critical (starts with !)
            if [[ "$line" =~ ^! ]]; then
                user_critical+=("${line#!}")
            else
                user_optional+=("$line")
            fi
        done < "$CONFIG_FILE"

        # Add user services to arrays
        CRITICAL_SERVICES+=("${user_critical[@]}")
        OPTIONAL_SERVICES+=("${user_optional[@]}")
    fi
}

print_summary() {
    echo ""
    echo "--------------------------------------"
    echo "Summary:"
    echo "  Total checked:    $total_checked"
    echo "  Active:           $active_count"
    echo "  Inactive:         $inactive_count"
    echo "  Failed:           $failed_count"
    echo ""

    if [[ $critical_failed -gt 0 ]]; then
        echo -e "${RED}WARNING: $critical_failed critical service(s) not running!${NC}"
    else
        echo -e "${GREEN}All critical services are running.${NC}"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --config   Path to custom config file"
    echo "  -q, --quiet    Only show non-active services"
    echo ""
    echo "Config file format:"
    echo "  - One service name per line"
    echo "  - Lines starting with # are comments"
    echo "  - Lines starting with ! mark critical services"
    echo "  - Example:"
    echo "      # My services"
    echo "      !nginx"
    echo "      postgresql"
    echo ""
    echo "Exit codes:"
    echo "  0 - All critical services are running"
    echo "  1 - One or more critical services are not running"
}

# Parse command line arguments
QUIET_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_header

# Load any user-defined services
load_config_services

# Check critical services
echo "Critical Services:"
for service in "${CRITICAL_SERVICES[@]}"; do
    # Handle ssh/sshd - only check one
    if [[ "$service" == "sshd" ]]; then
        # Skip sshd if ssh is active (they're the same service on some systems)
        if systemctl is-active ssh &>/dev/null; then
            continue
        fi
    fi
    check_service "$service" "critical"
done

echo ""
echo "Optional Services:"
for service in "${OPTIONAL_SERVICES[@]}"; do
    check_service "$service" "optional"
done

# Print summary
print_summary

# Exit with non-zero status if any critical service is down
if [[ $critical_failed -gt 0 ]]; then
    exit 1
else
    exit 0
fi
