#!/bin/bash
#
# disk-space-monitor.sh
# Monitors disk usage and warns if any partition exceeds 80% capacity
#
# Usage: ./disk-space-monitor.sh
#

WARNING_THRESHOLD=80

echo "====================================="
echo "  Disk Space Monitor"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "====================================="
echo ""

# Get disk usage for all mounted filesystems (excluding tmpfs, devtmpfs, etc.)
# Using df with -h for human-readable and -P for POSIX output format
df -hP | grep -vE '^Filesystem|tmpfs|devtmpfs|udev|/dev/loop' | while read line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    use_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')

    # Determine status based on usage
    if [ "$use_percent" -ge 90 ]; then
        status="[CRITICAL]"
    elif [ "$use_percent" -ge "$WARNING_THRESHOLD" ]; then
        status="[WARNING] "
    else
        status="[OK]      "
    fi

    printf "%s %3s%% used - %s (Size: %s, Used: %s, Avail: %s)\n" \
        "$status" "$use_percent" "$mount" "$size" "$used" "$avail"
done

echo ""
echo "-------------------------------------"
echo "Threshold: Warning at ${WARNING_THRESHOLD}%, Critical at 90%"
echo "-------------------------------------"

# Check if any filesystem exceeds the threshold and provide summary
critical_count=$(df -hP | grep -vE '^Filesystem|tmpfs|devtmpfs|udev|/dev/loop' | awk '{gsub(/%/,"",$5); if ($5 >= 90) count++} END {print count+0}')
warning_count=$(df -hP | grep -vE '^Filesystem|tmpfs|devtmpfs|udev|/dev/loop' | awk -v thresh="$WARNING_THRESHOLD" '{gsub(/%/,"",$5); if ($5 >= thresh && $5 < 90) count++} END {print count+0}')

echo ""
if [ "$critical_count" -gt 0 ]; then
    echo "ALERT: $critical_count filesystem(s) at CRITICAL level (>=90%)!"
    echo "Immediate action recommended to prevent disk-full issues."
fi

if [ "$warning_count" -gt 0 ]; then
    echo "WARNING: $warning_count filesystem(s) exceeding ${WARNING_THRESHOLD}% usage."
    echo "Consider cleaning up old files or expanding storage."
fi

if [ "$critical_count" -eq 0 ] && [ "$warning_count" -eq 0 ]; then
    echo "All filesystems are within normal usage limits."
fi

exit 0
