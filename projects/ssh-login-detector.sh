#!/bin/bash
# ssh-login-detector.sh - Scans auth logs for failed SSH login attempts
# Created: 2026-01-19
# Task: TASK-006

AUTH_LOG="/var/log/auth.log"
AUTH_LOG_ALT="/var/log/secure"

# Determine which log file to use
if [[ -r "$AUTH_LOG" ]]; then
    LOG_FILE="$AUTH_LOG"
elif [[ -r "$AUTH_LOG_ALT" ]]; then
    LOG_FILE="$AUTH_LOG_ALT"
else
    echo "Error: Cannot read auth log. Run with sudo or check permissions."
    echo "Tried: $AUTH_LOG and $AUTH_LOG_ALT"
    exit 1
fi

echo "=========================================="
echo "   Failed SSH Login Detector"
echo "=========================================="
echo "Log file: $LOG_FILE"
echo "Generated: $(date)"
echo ""

# Extract failed SSH login attempts
# Patterns: "Failed password", "Invalid user", "Connection closed by ... [preauth]"
FAILED_ATTEMPTS=$(grep -E "(Failed password|Invalid user|authentication failure.*ssh)" "$LOG_FILE" 2>/dev/null)

if [[ -z "$FAILED_ATTEMPTS" ]]; then
    echo "No failed SSH login attempts found in the current log."
    echo ""
    echo "This is good news - no brute-force attempts detected!"
    exit 0
fi

echo "Summary of Failed SSH Login Attempts by IP Address:"
echo "------------------------------------------"
printf "%-8s %-18s %s\n" "COUNT" "IP ADDRESS" "MOST RECENT"
echo "------------------------------------------"

# Extract IPs and count them, with most recent timestamp
echo "$FAILED_ATTEMPTS" | \
    grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
    sed 's/from //' | \
    sort | uniq -c | sort -rn | \
    while read count ip; do
        # Get most recent timestamp for this IP
        last_attempt=$(grep -E "(Failed password|Invalid user|authentication failure.*ssh).*$ip" "$LOG_FILE" | tail -1 | awk '{print $1, $2, $3}')
        printf "%-8s %-18s %s\n" "$count" "$ip" "$last_attempt"
    done

echo "------------------------------------------"
echo ""

# Total count
TOTAL=$(echo "$FAILED_ATTEMPTS" | wc -l)
echo "Total failed attempts: $TOTAL"

# Unique IPs
UNIQUE_IPS=$(echo "$FAILED_ATTEMPTS" | grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sed 's/from //' | sort -u | wc -l)
echo "Unique IP addresses: $UNIQUE_IPS"
echo ""

# High-risk warning (more than 10 attempts from single IP)
echo "$FAILED_ATTEMPTS" | \
    grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
    sed 's/from //' | \
    sort | uniq -c | sort -rn | \
    while read count ip; do
        if [[ $count -gt 10 ]]; then
            echo "WARNING: $ip has $count failed attempts - possible brute-force attack!"
        fi
    done

echo ""
echo "Tip: Consider blocking suspicious IPs with: sudo ufw deny from <IP>"
