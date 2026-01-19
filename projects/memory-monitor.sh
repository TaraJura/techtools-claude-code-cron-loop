#!/bin/bash
#
# memory-monitor.sh - Display top 10 memory-consuming processes
# Created by: Developer Agent
# Date: 2026-01-19
#

echo "=============================================="
echo "       TOP 10 MEMORY-CONSUMING PROCESSES"
echo "=============================================="
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get total system memory in KB for percentage calculation
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_mb=$((total_mem_kb / 1024))

echo "System Total Memory: ${total_mem_mb} MB"
echo ""

# Header
printf "%-8s  %-8s  %-40s\n" "PID" "MEM (MB)" "PROCESS NAME"
printf "%-8s  %-8s  %-40s\n" "--------" "--------" "----------------------------------------"

# Get top 10 processes by memory usage
# Using ps with RSS (Resident Set Size) which is actual memory in KB
ps aux --sort=-%mem | awk 'NR>1 {print $2, $6, $11}' | head -10 | while read pid rss_kb cmd; do
    # Convert RSS from KB to MB
    rss_mb=$((rss_kb / 1024))

    # Get just the process name (basename of command)
    proc_name=$(basename "$cmd" 2>/dev/null | cut -c1-40)

    printf "%-8s  %-8s  %-40s\n" "$pid" "$rss_mb" "$proc_name"
done

echo ""
echo "----------------------------------------------"

# Summary
used_mem_kb=$(grep -E '^(MemTotal|MemAvailable):' /proc/meminfo | awk '{sum+=$2} END {print sum}')
mem_available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_used_kb=$((total_mem_kb - mem_available_kb))
mem_used_mb=$((mem_used_kb / 1024))
mem_available_mb=$((mem_available_kb / 1024))
usage_percent=$((mem_used_kb * 100 / total_mem_kb))

echo ""
echo "MEMORY SUMMARY:"
echo "  Used:      ${mem_used_mb} MB (${usage_percent}%)"
echo "  Available: ${mem_available_mb} MB"
echo "  Total:     ${total_mem_mb} MB"

# Warning if memory usage is high
if [ "$usage_percent" -ge 90 ]; then
    echo ""
    echo "[CRITICAL] Memory usage is at ${usage_percent}%! Consider freeing up memory."
elif [ "$usage_percent" -ge 80 ]; then
    echo ""
    echo "[WARNING] Memory usage is at ${usage_percent}%. Monitor closely."
fi

echo ""
echo "=============================================="
