#!/bin/bash
# update-login-history.sh - Gathers user login history for the CronLoop dashboard
# Called periodically to update /var/www/cronloop.techtools.cz/api/login-history.json

API_DIR="/var/www/cronloop.techtools.cz/api"
LOGIN_FILE="$API_DIR/login-history.json"

# Ensure API directory exists
mkdir -p "$API_DIR"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get currently logged in users
CURRENT_USERS="[]"
if command -v who &>/dev/null; then
    CURRENT_USERS=$(who 2>/dev/null | awk '{
        user = $1
        tty = $2
        date = $3
        time = $4
        if ($5 ~ /^\(/) {
            # Has IP/host in parentheses
            gsub(/[()]/, "", $5)
            source = $5
        } else {
            source = "local"
        }
        printf "{\"user\":\"%s\",\"tty\":\"%s\",\"login_time\":\"%s %s\",\"source\":\"%s\"},", user, tty, date, time, source
    }' | sed 's/,$//' | awk 'BEGIN{print "["} {print} END{print "]"}' | tr -d '\n' | sed 's/\[\]/[]/;s/\[,/[/')
fi

# Clean up JSON if empty
if [ "$CURRENT_USERS" = "[
]" ] || [ -z "$CURRENT_USERS" ]; then
    CURRENT_USERS="[]"
fi

# Get recent successful logins (last 50)
RECENT_LOGINS="[]"
if command -v last &>/dev/null; then
    RECENT_LOGINS=$(last -50 -F 2>/dev/null | grep -v "^$" | grep -v "^wtmp begins" | grep -v "^reboot" | grep -v "^shutdown" | head -30 | awk '{
        user = $1
        tty = $2
        if ($3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || $3 ~ /:/) {
            source = $3
            # Date is in $4-$8 for -F format
            date = $4 " " $5 " " $6 " " $7 " " $8
            status_start = 9
        } else {
            source = "local"
            # Date is in $3-$7 for -F format
            date = $3 " " $4 " " $5 " " $6 " " $7
            status_start = 8
        }
        # Clean up date format
        gsub(/  +/, " ", date)

        # Determine if still logged in or session duration
        duration = ""
        still_logged_in = "false"
        for (i = status_start; i <= NF; i++) {
            if ($i == "still") {
                still_logged_in = "true"
                break
            }
            if ($i ~ /^\(/) {
                duration = $i
                gsub(/[()]/, "", duration)
                break
            }
        }

        if (user != "" && user !~ /^$/) {
            printf "{\"user\":\"%s\",\"tty\":\"%s\",\"source\":\"%s\",\"login_time\":\"%s\",\"duration\":\"%s\",\"still_logged_in\":%s},", user, tty, source, date, duration, still_logged_in
        }
    }' | sed 's/,$//' | awk 'BEGIN{print "["} {print} END{print "]"}' | tr -d '\n' | sed 's/\[\]/[]/;s/\[,/[/')
fi

# Clean up JSON if empty
if [ "$RECENT_LOGINS" = "[
]" ] || [ -z "$RECENT_LOGINS" ]; then
    RECENT_LOGINS="[]"
fi

# Get failed login attempts from auth.log (last 24 hours)
FAILED_LOGINS="[]"
if [ -r /var/log/auth.log ]; then
    YESTERDAY=$(date -d "24 hours ago" +%s 2>/dev/null || date -v-24H +%s 2>/dev/null || echo "0")
    FAILED_LOGINS=$(grep -i "authentication failure\|failed password\|invalid user" /var/log/auth.log 2>/dev/null | tail -50 | while read line; do
        # Extract timestamp
        timestamp=$(echo "$line" | awk '{print $1, $2, $3}')

        # Extract user (various formats)
        user="unknown"
        if echo "$line" | grep -qi "user="; then
            user=$(echo "$line" | sed -n 's/.*user=\([^ ]*\).*/\1/p')
        elif echo "$line" | grep -qi "invalid user"; then
            user=$(echo "$line" | sed -n 's/.*invalid user \([^ ]*\).*/\1/p')
        elif echo "$line" | grep -qi "for "; then
            user=$(echo "$line" | sed -n 's/.*for \(invalid user \)\?\([^ ]*\) from.*/\2/p')
        fi

        # Extract source IP
        source="unknown"
        if echo "$line" | grep -qoE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
            source=$(echo "$line" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
        fi

        # Extract service
        service=$(echo "$line" | awk -F'[][]' '{print $1}' | awk '{print $NF}' | sed 's/:$//')

        echo "{\"timestamp\":\"$timestamp\",\"user\":\"$user\",\"source\":\"$source\",\"service\":\"$service\"},"
    done | sed 's/,$//' | awk 'BEGIN{print "["} {print} END{print "]"}' | tr -d '\n')
fi

# Clean up JSON if empty
if [ "$FAILED_LOGINS" = "[
]" ] || [ -z "$FAILED_LOGINS" ]; then
    FAILED_LOGINS="[]"
fi

# Count unique users who logged in today
TODAY=$(date +%Y-%m-%d)
TODAY_USERS=$(last 2>/dev/null | grep "$TODAY" | awk '{print $1}' | sort -u | wc -l)

# Get login statistics
TOTAL_CURRENT=$(echo "$CURRENT_USERS" | jq 'length' 2>/dev/null || echo "0")
TOTAL_RECENT=$(echo "$RECENT_LOGINS" | jq 'length' 2>/dev/null || echo "0")
TOTAL_FAILED=$(echo "$FAILED_LOGINS" | jq 'length' 2>/dev/null || echo "0")

# Calculate unique IPs from recent logins
UNIQUE_SOURCES=$(echo "$RECENT_LOGINS" | jq '[.[].source] | unique | length' 2>/dev/null || echo "0")

# Detect unusual logins (outside business hours 6am-10pm)
UNUSUAL_LOGINS="[]"
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" -lt 6 ] || [ "$CURRENT_HOUR" -gt 22 ]; then
    # Check if there are current logins during unusual hours
    UNUSUAL_LOGINS=$(echo "$CURRENT_USERS" | jq '[.[] | . + {"reason": "Login during off-hours (before 6am or after 10pm)"}]' 2>/dev/null || echo "[]")
fi

# Get login counts by hour (for timeline visualization)
HOURLY_LOGINS=$(last -50 2>/dev/null | grep -v "^$" | grep -v "^wtmp\|^reboot\|^shutdown" | awk '{
    # Try to extract hour from login time
    for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9][0-9]:[0-9][0-9]/) {
            split($i, t, ":")
            hours[t[1]]++
            break
        }
    }
} END {
    printf "{"
    first = 1
    for (h = 0; h < 24; h++) {
        hh = sprintf("%02d", h)
        if (!first) printf ","
        printf "\"%s\":%d", hh, (hours[hh] ? hours[hh] : 0)
        first = 0
    }
    printf "}"
}')

# Get top users by login frequency
TOP_USERS=$(last -100 2>/dev/null | grep -v "^$" | grep -v "^wtmp\|^reboot\|^shutdown" | awk '{print $1}' | sort | uniq -c | sort -rn | head -5 | awk '{printf "{\"user\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')
if [ -z "$TOP_USERS" ]; then
    TOP_USERS=""
fi

# Build the final JSON
cat > "$LOGIN_FILE" << EOF
{
    "timestamp": "$TIMESTAMP",
    "current_users": $CURRENT_USERS,
    "recent_logins": $RECENT_LOGINS,
    "failed_logins": $FAILED_LOGINS,
    "unusual_logins": $UNUSUAL_LOGINS,
    "statistics": {
        "current_sessions": $TOTAL_CURRENT,
        "recent_logins_count": $TOTAL_RECENT,
        "failed_attempts_24h": $TOTAL_FAILED,
        "unique_sources": $UNIQUE_SOURCES,
        "users_today": $TODAY_USERS
    },
    "hourly_distribution": $HOURLY_LOGINS,
    "top_users": [$TOP_USERS]
}
EOF

# Output status for logging
echo "Login history updated: $TOTAL_CURRENT current, $TOTAL_RECENT recent, $TOTAL_FAILED failed ($(date))"
