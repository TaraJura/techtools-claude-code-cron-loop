#!/bin/bash
#
# system-info.sh - Display basic system information
# Created by: Developer Agent
# Date: 2026-01-19
#

echo "====================================="
echo "        SYSTEM INFORMATION"
echo "====================================="
echo ""

# Hostname
echo "Hostname:      $(hostname)"

# Date and Time
echo "Date/Time:     $(date '+%Y-%m-%d %H:%M:%S %Z')"

# Uptime
uptime_info=$(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')
echo "Uptime:        ${uptime_info}"

# OS Information
if [ -f /etc/os-release ]; then
    os_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    echo "OS:            ${os_name}"
fi

# Kernel Version
echo "Kernel:        $(uname -r)"

# CPU Info
cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
cpu_cores=$(nproc)
echo "CPU:           ${cpu_model} (${cpu_cores} cores)"

# Memory Info
mem_total=$(free -h | awk '/^Mem:/ {print $2}')
mem_used=$(free -h | awk '/^Mem:/ {print $3}')
mem_avail=$(free -h | awk '/^Mem:/ {print $7}')
echo "Memory:        ${mem_used} used / ${mem_total} total (${mem_avail} available)"

# Disk Usage (root partition)
disk_info=$(df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 " full)"}')
echo "Disk (/):      ${disk_info}"

# Load Average
load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
echo "Load Avg:      ${load_avg} (1, 5, 15 min)"

# Current Users
user_count=$(who | wc -l)
echo "Logged Users:  ${user_count}"

echo ""
echo "====================================="
