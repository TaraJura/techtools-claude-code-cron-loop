#!/bin/bash
# security-metrics.sh - Generates security metrics JSON for the web dashboard
# Consolidates data from existing security tools:
#   - ssh-login-detector.sh (SSH brute force attempts)
#   - port-scanner.sh (open ports)
#   - file-permission-auditor.sh (permission issues)
#   - package-update-checker.sh (security updates)
#
# Created: 2026-01-20
# Task: TASK-032

set -e

# Output file location
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/security-metrics.json"
AUTH_LOG="/var/log/auth.log"

# JSON escape function
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Get SSH brute force data
get_ssh_attacks() {
    local total_attempts=0
    local unique_ips=0
    local top_attackers=""

    if [[ -r "$AUTH_LOG" ]]; then
        # Count total failed attempts
        total_attempts=$(grep -cE "(Failed password|Invalid user|authentication failure.*ssh)" "$AUTH_LOG" 2>/dev/null || echo 0)

        # Get unique IPs
        unique_ips=$(grep -E "(Failed password|Invalid user|authentication failure.*ssh)" "$AUTH_LOG" 2>/dev/null | \
            grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
            sed 's/from //' | sort -u | wc -l || echo 0)

        # Get top 5 attackers with counts
        local ip_data=$(grep -E "(Failed password|Invalid user|authentication failure.*ssh)" "$AUTH_LOG" 2>/dev/null | \
            grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
            sed 's/from //' | sort | uniq -c | sort -rn | head -5)

        # Format as JSON array
        local first=true
        top_attackers="["
        while read -r count ip; do
            [[ -z "$ip" ]] && continue
            if [ "$first" = true ]; then
                first=false
            else
                top_attackers+=","
            fi
            top_attackers+="{\"ip\":\"$ip\",\"count\":$count}"
        done <<< "$ip_data"
        top_attackers+="]"
    else
        top_attackers="[]"
    fi

    echo "{\"total_attempts\":$total_attempts,\"unique_ips\":$unique_ips,\"top_attackers\":$top_attackers}"
}

# Get open ports data
get_open_ports() {
    local ports="["
    local first=true
    local open_count=0

    # Check common ports using ss
    local common_ports="22:SSH 80:HTTP 443:HTTPS 3306:MySQL 5432:PostgreSQL 6379:Redis 27017:MongoDB 53:DNS"

    for entry in $common_ports; do
        port="${entry%%:*}"
        service="${entry#*:}"

        # Check if port is open
        if ss -tlnH "sport = :$port" 2>/dev/null | grep -q ":$port"; then
            if [ "$first" = true ]; then
                first=false
            else
                ports+=","
            fi
            ports+="{\"port\":$port,\"service\":\"$service\",\"status\":\"open\"}"
            ((open_count++))
        fi
    done

    ports+="]"
    echo "{\"open_count\":$open_count,\"ports\":$ports}"
}

# Get file permission issues (quick scan)
get_permission_issues() {
    local world_writable=0
    local permissive=0

    # Count world-writable files in /home and /tmp (excluding common dirs)
    world_writable=$(find /home /tmp -xdev -type f -perm -0002 2>/dev/null | \
        grep -v -E "\.git/|node_modules/|\.cache/|__pycache__/" | wc -l || echo 0)

    # Count 777/666 permission files in /home
    permissive=$(find /home -xdev -type f \( -perm 777 -o -perm 666 \) 2>/dev/null | \
        grep -v -E "\.git/|node_modules/|\.cache/|__pycache__/" | wc -l || echo 0)

    local total=$((world_writable + permissive))
    echo "{\"world_writable\":$world_writable,\"permissive\":$permissive,\"total\":$total}"
}

# Get package update info
get_package_updates() {
    local total_updates=0
    local security_updates=0
    local reboot_required=false

    # Get upgradable packages
    local upgradable=$(apt list --upgradable 2>/dev/null | grep -v "^Listing" || true)
    total_updates=$(echo "$upgradable" | grep -c . || echo 0)

    # Count security updates
    security_updates=$(echo "$upgradable" | grep -cE "security|Security" || echo 0)

    # Check reboot required
    if [ -f /var/run/reboot-required ]; then
        reboot_required=true
    fi

    echo "{\"total\":$total_updates,\"security\":$security_updates,\"reboot_required\":$reboot_required}"
}

# Get nginx security status
get_nginx_security() {
    local blocks_git=false
    local blocks_env=false
    local blocks_logs=false

    # Check nginx config for security rules
    if grep -q "\.git" /etc/nginx/sites-enabled/* 2>/dev/null; then
        blocks_git=true
    fi
    if grep -q "\.env" /etc/nginx/sites-enabled/* 2>/dev/null; then
        blocks_env=true
    fi
    if grep -q "\.log" /etc/nginx/sites-enabled/* 2>/dev/null; then
        blocks_logs=true
    fi

    echo "{\"blocks_git\":$blocks_git,\"blocks_env\":$blocks_env,\"blocks_logs\":$blocks_logs}"
}

# Calculate overall security score (0-100)
calculate_security_score() {
    local ssh_attempts="$1"
    local permission_issues="$2"
    local security_updates="$3"
    local reboot_required="$4"

    local score=100

    # Deduct for SSH brute force attacks (max -30)
    if [ "$ssh_attempts" -gt 1000 ]; then
        score=$((score - 30))
    elif [ "$ssh_attempts" -gt 100 ]; then
        score=$((score - 15))
    elif [ "$ssh_attempts" -gt 10 ]; then
        score=$((score - 5))
    fi

    # Deduct for permission issues (max -20)
    if [ "$permission_issues" -gt 10 ]; then
        score=$((score - 20))
    elif [ "$permission_issues" -gt 5 ]; then
        score=$((score - 10))
    elif [ "$permission_issues" -gt 0 ]; then
        score=$((score - 5))
    fi

    # Deduct for security updates (max -30)
    if [ "$security_updates" -gt 20 ]; then
        score=$((score - 30))
    elif [ "$security_updates" -gt 10 ]; then
        score=$((score - 20))
    elif [ "$security_updates" -gt 0 ]; then
        score=$((score - 10))
    fi

    # Deduct for reboot required (-10)
    if [ "$reboot_required" = "true" ]; then
        score=$((score - 10))
    fi

    # Ensure score doesn't go negative
    if [ "$score" -lt 0 ]; then
        score=0
    fi

    echo "$score"
}

# Determine security status based on score
get_security_status() {
    local score="$1"

    if [ "$score" -ge 90 ]; then
        echo "Secure"
    elif [ "$score" -ge 70 ]; then
        echo "Warning"
    else
        echo "Critical"
    fi
}

# Generate recommendations
get_recommendations() {
    local ssh_attempts="$1"
    local permission_issues="$2"
    local security_updates="$3"
    local reboot_required="$4"

    local recs="["
    local first=true

    # SSH brute force recommendation
    if [ "$ssh_attempts" -gt 100 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"high\",\"message\":\"Install fail2ban to block SSH brute force attackers\",\"action\":\"sudo apt install fail2ban\"}"
    fi

    # Security updates recommendation
    if [ "$security_updates" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"high\",\"message\":\"$security_updates security updates available\",\"action\":\"sudo apt upgrade\"}"
    fi

    # Permission issues recommendation
    if [ "$permission_issues" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"medium\",\"message\":\"$permission_issues file permission issues found\",\"action\":\"Run file-permission-auditor.sh -v\"}"
    fi

    # Reboot required recommendation
    if [ "$reboot_required" = "true" ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"medium\",\"message\":\"System reboot required\",\"action\":\"sudo reboot\"}"
    fi

    recs+="]"
    echo "$recs"
}

# Main execution
main() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Collect all metrics
    local ssh_data=$(get_ssh_attacks)
    local ports_data=$(get_open_ports)
    local perms_data=$(get_permission_issues)
    local updates_data=$(get_package_updates)
    local nginx_data=$(get_nginx_security)

    # Extract values for score calculation
    local ssh_attempts=$(echo "$ssh_data" | grep -oP '"total_attempts":\K[0-9]+')
    local perm_total=$(echo "$perms_data" | grep -oP '"total":\K[0-9]+')
    local sec_updates=$(echo "$updates_data" | grep -oP '"security":\K[0-9]+')
    local reboot=$(echo "$updates_data" | grep -oP '"reboot_required":\K(true|false)')

    # Calculate score and status
    local score=$(calculate_security_score "$ssh_attempts" "$perm_total" "$sec_updates" "$reboot")
    local status=$(get_security_status "$score")
    local recommendations=$(get_recommendations "$ssh_attempts" "$perm_total" "$sec_updates" "$reboot")

    # Build JSON output
    local json="{
  \"timestamp\": \"$timestamp\",
  \"score\": $score,
  \"status\": \"$status\",
  \"ssh_attacks\": $ssh_data,
  \"open_ports\": $ports_data,
  \"permissions\": $perms_data,
  \"updates\": $updates_data,
  \"nginx_security\": $nginx_data,
  \"recommendations\": $recommendations
}"

    # Write to file
    echo "$json" > "$OUTPUT_FILE"
    echo "Security metrics updated: $OUTPUT_FILE"
}

# Run main
main
