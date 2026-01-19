#!/bin/bash
# system-metrics-api.sh - Output system metrics in JSON format
# Part of CronLoop web app - provides data for system health dashboard
# Usage: ./system-metrics-api.sh [-o FILE] [-h]
#   -o FILE  Write output to FILE (default: stdout)
#   -c       Output with HTTP Content-Type header (for CGI use)
#   -h       Show help

set -e

# Default values
OUTPUT_FILE=""
CGI_MODE=false

# Parse options
while getopts "o:ch" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG" ;;
        c) CGI_MODE=true ;;
        h)
            echo "Usage: $0 [-o FILE] [-c] [-h]"
            echo ""
            echo "Output system metrics in JSON format for web dashboard."
            echo ""
            echo "Options:"
            echo "  -o FILE  Write output to FILE instead of stdout"
            echo "  -c       Output HTTP Content-Type header (for CGI)"
            echo "  -h       Show this help message"
            echo ""
            echo "Output fields:"
            echo "  hostname     - Server hostname"
            echo "  timestamp    - ISO 8601 formatted timestamp"
            echo "  uptime       - Human-readable uptime string"
            echo "  uptime_seconds - Uptime in seconds"
            echo "  memory       - Memory stats (used_mb, available_mb, total_mb, percent)"
            echo "  disk         - Array of partition stats (mount, used_gb, total_gb, percent)"
            echo "  cpu          - CPU info (cores, load_1m, load_5m, load_15m)"
            echo "  services     - Key service status (ssh, nginx, cron)"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "Use -h for help" >&2
            exit 1
            ;;
    esac
done

# Helper function to escape strings for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo -n "$str"
}

# Get hostname
HOSTNAME=$(hostname)

# Get timestamp in ISO 8601 format
TIMESTAMP=$(date -Iseconds)

# Get uptime
UPTIME_SECONDS=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
if command -v uptime &>/dev/null && uptime -p &>/dev/null 2>&1; then
    UPTIME_STR=$(uptime -p | sed 's/up //')
else
    # Fallback: calculate from seconds
    days=$((UPTIME_SECONDS / 86400))
    hours=$(((UPTIME_SECONDS % 86400) / 3600))
    mins=$(((UPTIME_SECONDS % 3600) / 60))
    if [ $days -gt 0 ]; then
        UPTIME_STR="${days}d ${hours}h ${mins}m"
    elif [ $hours -gt 0 ]; then
        UPTIME_STR="${hours}h ${mins}m"
    else
        UPTIME_STR="${mins}m"
    fi
fi

# Get memory info from /proc/meminfo (in KB)
MEM_TOTAL_KB=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE_KB=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))

# Convert to MB
MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
MEM_AVAILABLE_MB=$((MEM_AVAILABLE_KB / 1024))
MEM_USED_MB=$((MEM_USED_KB / 1024))

# Calculate percentage (avoid division by zero)
if [ "$MEM_TOTAL_KB" -gt 0 ]; then
    MEM_PERCENT=$((MEM_USED_KB * 100 / MEM_TOTAL_KB))
else
    MEM_PERCENT=0
fi

# Get disk info - build JSON array
DISK_JSON="["
first_disk=true
while IFS= read -r line; do
    # Skip header line
    if [[ "$line" == Filesystem* ]]; then
        continue
    fi

    # Parse df output: Filesystem Size Used Avail Use% Mounted
    read -r fs size used avail percent mount <<< "$line"

    # Skip pseudo-filesystems
    if [[ "$fs" == tmpfs || "$fs" == devtmpfs || "$fs" == udev || "$fs" == /dev/loop* ]]; then
        continue
    fi

    # Extract numeric percent
    percent_num="${percent%\%}"

    # Convert sizes to GB (they come in human-readable format from df -h)
    # For accurate numbers, we'll use df without -h
    size_bytes=$(df -B1 "$mount" 2>/dev/null | tail -1 | awk '{print $2}')
    used_bytes=$(df -B1 "$mount" 2>/dev/null | tail -1 | awk '{print $3}')

    # Convert to GB with one decimal (ensure leading zero for JSON)
    size_gb_raw=$(echo "scale=1; $size_bytes / 1073741824" | bc 2>/dev/null || echo "0")
    used_gb_raw=$(echo "scale=1; $used_bytes / 1073741824" | bc 2>/dev/null || echo "0")
    # Add leading 0 if number starts with decimal point
    size_gb=$(echo "$size_gb_raw" | sed 's/^\./0./')
    used_gb=$(echo "$used_gb_raw" | sed 's/^\./0./')

    if [ "$first_disk" = false ]; then
        DISK_JSON+=","
    fi
    first_disk=false

    mount_escaped=$(json_escape "$mount")
    DISK_JSON+="{\"mount\":\"$mount_escaped\",\"used_gb\":$used_gb,\"total_gb\":$size_gb,\"percent\":$percent_num}"
done < <(df -h 2>/dev/null)
DISK_JSON+="]"

# Get CPU info
CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)
read -r LOAD_1M LOAD_5M LOAD_15M _ < /proc/loadavg

# Get service status
check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "running"
    elif systemctl is-active --quiet "${service}d" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

SSH_STATUS=$(check_service ssh)
NGINX_STATUS=$(check_service nginx)
CRON_STATUS=$(check_service cron)

# Build JSON output
JSON_OUTPUT=$(cat <<EOF
{
  "hostname": "$(json_escape "$HOSTNAME")",
  "timestamp": "$TIMESTAMP",
  "uptime": "$(json_escape "$UPTIME_STR")",
  "uptime_seconds": $UPTIME_SECONDS,
  "memory": {
    "used_mb": $MEM_USED_MB,
    "available_mb": $MEM_AVAILABLE_MB,
    "total_mb": $MEM_TOTAL_MB,
    "percent": $MEM_PERCENT
  },
  "disk": $DISK_JSON,
  "cpu": {
    "cores": $CPU_CORES,
    "load_1m": $LOAD_1M,
    "load_5m": $LOAD_5M,
    "load_15m": $LOAD_15M
  },
  "services": {
    "ssh": "$SSH_STATUS",
    "nginx": "$NGINX_STATUS",
    "cron": "$CRON_STATUS"
  }
}
EOF
)

# Output
if [ "$CGI_MODE" = true ]; then
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo ""
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
    echo "Metrics written to $OUTPUT_FILE"
else
    echo "$JSON_OUTPUT"
fi
