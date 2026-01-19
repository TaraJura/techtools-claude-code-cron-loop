#!/bin/bash
# port-scanner.sh - Scan localhost for listening ports and services
# Part of the multi-agent system utilities

# Common ports to scan
COMMON_PORTS=(
    "22:SSH"
    "80:HTTP"
    "443:HTTPS"
    "3306:MySQL"
    "5432:PostgreSQL"
    "6379:Redis"
    "27017:MongoDB"
    "8080:HTTP-Alt"
    "8443:HTTPS-Alt"
    "9000:PHP-FPM"
    "3000:Node.js"
    "5000:Flask/Dev"
    "8000:Django/Dev"
    "25:SMTP"
    "53:DNS"
    "110:POP3"
    "143:IMAP"
    "993:IMAPS"
    "995:POP3S"
    "21:FTP"
    "23:Telnet"
    "2222:SSH-Alt"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Scan localhost for listening ports and display associated services."
    echo ""
    echo "Options:"
    echo "  -a, --all       Show all common ports (including closed)"
    echo "  -c, --custom    Scan additional custom ports (comma-separated)"
    echo "                  Example: -c 9090,9091,9092"
    echo "  -s, --ss        Use ss command to show all listening ports"
    echo "  -h, --help      Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0              Scan common ports, show only open ones"
    echo "  $0 -a           Scan common ports, show all (open and closed)"
    echo "  $0 -c 9090,9091 Scan common ports plus custom ports"
    echo "  $0 -s           Show all listening ports using ss"
}

# Parse command line arguments
SHOW_ALL=false
CUSTOM_PORTS=""
USE_SS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -c|--custom)
            CUSTOM_PORTS="$2"
            shift 2
            ;;
        -s|--ss)
            USE_SS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "========================================"
echo "       Port Scanner Utility"
echo "========================================"
echo "Scanning: localhost (127.0.0.1)"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# If -s flag, use ss to show all listening ports
if [ "$USE_SS" = true ]; then
    echo -e "${CYAN}All listening ports (from ss):${NC}"
    echo "----------------------------------------"
    printf "%-8s %-8s %-25s %s\n" "PROTO" "PORT" "LOCAL ADDRESS" "PROCESS"
    echo "----------------------------------------"

    # Get listening TCP and UDP ports
    if command -v ss &> /dev/null; then
        ss -tlnp 2>/dev/null | tail -n +2 | while read -r line; do
            proto="tcp"
            local_addr=$(echo "$line" | awk '{print $4}')
            port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
            process=$(echo "$line" | grep -oP '\"[^\"]+\"' | head -1 | tr -d '"')
            [ -z "$process" ] && process="-"
            printf "%-8s %-8s %-25s %s\n" "$proto" "$port" "$local_addr" "$process"
        done

        ss -ulnp 2>/dev/null | tail -n +2 | while read -r line; do
            proto="udp"
            local_addr=$(echo "$line" | awk '{print $4}')
            port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
            process=$(echo "$line" | grep -oP '\"[^\"]+\"' | head -1 | tr -d '"')
            [ -z "$process" ] && process="-"
            printf "%-8s %-8s %-25s %s\n" "$proto" "$port" "$local_addr" "$process"
        done
    else
        echo "Error: 'ss' command not found"
        exit 1
    fi

    echo ""
    echo "Note: Run with sudo for process names"
    exit 0
fi

# Add custom ports to scan
if [ -n "$CUSTOM_PORTS" ]; then
    IFS=',' read -ra CUSTOM_ARRAY <<< "$CUSTOM_PORTS"
    for port in "${CUSTOM_ARRAY[@]}"; do
        COMMON_PORTS+=("${port}:Custom")
    done
fi

# Function to check if port is open
check_port() {
    local port=$1
    local service=$2

    # Try using ss first (most reliable)
    if command -v ss &> /dev/null; then
        if ss -tlnH "sport = :$port" 2>/dev/null | grep -q ":$port"; then
            return 0
        fi
    # Fall back to /dev/tcp
    elif (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null; then
        return 0
    fi
    return 1
}

# Get actual service name from ss/netstat if available
get_actual_service() {
    local port=$1
    local default_service=$2

    if command -v ss &> /dev/null; then
        local actual=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP '\"[^\"]+\"' | head -1 | tr -d '"')
        if [ -n "$actual" ]; then
            echo "$actual"
            return
        fi
    fi
    echo "$default_service"
}

# Scan ports
echo -e "${CYAN}Scanning common ports:${NC}"
echo "----------------------------------------"
printf "%-8s %-20s %s\n" "PORT" "SERVICE" "STATUS"
echo "----------------------------------------"

OPEN_COUNT=0
CLOSED_COUNT=0

for entry in "${COMMON_PORTS[@]}"; do
    port="${entry%%:*}"
    service="${entry#*:}"

    if check_port "$port" "$service"; then
        actual_service=$(get_actual_service "$port" "$service")
        printf "%-8s %-20s ${GREEN}[OPEN]${NC}\n" "$port" "$actual_service"
        ((OPEN_COUNT++))
    else
        if [ "$SHOW_ALL" = true ]; then
            printf "%-8s %-20s ${RED}[CLOSED]${NC}\n" "$port" "$service"
        fi
        ((CLOSED_COUNT++))
    fi
done

echo "----------------------------------------"
echo ""

# Summary
echo -e "${CYAN}Summary:${NC}"
echo "  Open ports:   $OPEN_COUNT"
echo "  Closed ports: $CLOSED_COUNT"
echo "  Total scanned: $((OPEN_COUNT + CLOSED_COUNT))"
echo ""

# Security notes
if [ $OPEN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Security Notes:${NC}"
    echo "  - Review open ports to ensure they are intentionally exposed"
    echo "  - Use 'sudo ss -tlnp' for detailed process information"
    echo "  - Consider using UFW to restrict access: sudo ufw allow <port>"
fi
