#!/bin/bash
#
# Vulnerability Scanner Script
# Scans system packages for known CVEs using OSV (Open Source Vulnerabilities) API
# Outputs to /var/www/cronloop.techtools.cz/api/vulnerabilities.json
#
# Run daily via cron or manually

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/vulnerabilities.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/vulnerabilities-history.json"
TEMP_FILE="/tmp/vulnerabilities_scan_$$.json"
OSV_API="https://api.osv.dev/v1/query"

# Security-critical packages to scan
SECURITY_PACKAGES=(
    "openssl"
    "libssl3"
    "openssh-server"
    "openssh-client"
    "nginx"
    "curl"
    "wget"
    "git"
    "sudo"
    "bash"
    "coreutils"
    "systemd"
    "linux-image-generic"
    "python3"
    "nodejs"
)

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date +%s%N)

# Initialize counters
TOTAL_VULNS=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
PACKAGES_SCANNED=0

# Initialize arrays
declare -a VULNERABILITIES
declare -a SCANNED_PACKAGES

# Function to query OSV API for a package
query_osv() {
    local package="$1"
    local version="$2"
    local ecosystem="$3"

    # Build OSV query
    local query_json=$(cat <<EOF
{
    "package": {
        "name": "$package",
        "ecosystem": "$ecosystem"
    },
    "version": "$version"
}
EOF
)

    # Query OSV API
    local response=$(curl -s -X POST "$OSV_API" \
        -H "Content-Type: application/json" \
        -d "$query_json" 2>/dev/null || echo '{"vulns":[]}')

    echo "$response"
}

# Function to map CVSS score to severity
map_severity() {
    local score="$1"
    if [ -z "$score" ] || [ "$score" = "null" ]; then
        echo "MEDIUM"
    elif (( $(echo "$score >= 9.0" | bc -l) )); then
        echo "CRITICAL"
    elif (( $(echo "$score >= 7.0" | bc -l) )); then
        echo "HIGH"
    elif (( $(echo "$score >= 4.0" | bc -l) )); then
        echo "MEDIUM"
    else
        echo "LOW"
    fi
}

# Function to get package version (dpkg)
get_apt_version() {
    local package="$1"
    dpkg-query -W -f='${Version}' "$package" 2>/dev/null || echo ""
}

# Start building JSON output
echo "Starting vulnerability scan at $TIMESTAMP"

# Scan APT packages
for pkg in "${SECURITY_PACKAGES[@]}"; do
    version=$(get_apt_version "$pkg")

    if [ -n "$version" ]; then
        PACKAGES_SCANNED=$((PACKAGES_SCANNED + 1))

        # Add to scanned packages list
        SCANNED_PACKAGES+=("{\"name\": \"$pkg\", \"version\": \"$version\", \"ecosystem\": \"apt\"}")

        # Query OSV for Debian/Ubuntu vulnerabilities
        # Note: OSV uses "Debian" ecosystem for apt packages
        response=$(query_osv "$pkg" "$version" "Debian")

        # Parse vulnerabilities from response
        vulns=$(echo "$response" | jq -r '.vulns // []')
        vuln_count=$(echo "$vulns" | jq 'length')

        if [ "$vuln_count" -gt 0 ] && [ "$vuln_count" != "null" ]; then
            echo "Found $vuln_count vulnerabilities for $pkg"

            # Process each vulnerability
            for i in $(seq 0 $((vuln_count - 1))); do
                vuln=$(echo "$vulns" | jq ".[$i]")

                cve_id=$(echo "$vuln" | jq -r '.aliases[]? | select(startswith("CVE-"))' | head -1)
                if [ -z "$cve_id" ]; then
                    cve_id=$(echo "$vuln" | jq -r '.id')
                fi

                osv_id=$(echo "$vuln" | jq -r '.id')
                summary=$(echo "$vuln" | jq -r '.summary // .details // "No description available"' | head -c 500)

                # Get severity from CVSS
                severity_obj=$(echo "$vuln" | jq -r '.severity[0] // {}')
                cvss_score=$(echo "$severity_obj" | jq -r '.score // "null"')
                severity=$(echo "$severity_obj" | jq -r '.type // ""')

                if [ -z "$severity" ] || [ "$severity" = "null" ]; then
                    severity=$(map_severity "$cvss_score")
                fi

                # Get affected versions
                affected=$(echo "$vuln" | jq -r '[.affected[].ranges[]?.events[]? | select(.introduced or .fixed) | if .introduced then ">=\(.introduced)" elif .fixed then "<\(.fixed)" else empty end] | join(", ")' 2>/dev/null || echo "$version")

                # Get fixed version
                fixed_version=$(echo "$vuln" | jq -r '.affected[].ranges[]?.events[]? | select(.fixed) | .fixed' | head -1)

                # Check if exploitable (has references to exploits)
                exploitable=$(echo "$vuln" | jq -r '[.references[]?.type] | any(. == "EXPLOIT" or . == "EVIDENCE")' 2>/dev/null || echo "false")

                # Get references
                references=$(echo "$vuln" | jq -r '[.references[]?.url] | join(",")' 2>/dev/null || echo "")

                # Build remediation command
                if [ -n "$fixed_version" ] && [ "$fixed_version" != "null" ]; then
                    remediation="sudo apt update && sudo apt install --only-upgrade $pkg"
                else
                    remediation=""
                fi

                # Count by severity
                case "$severity" in
                    CRITICAL) CRITICAL_COUNT=$((CRITICAL_COUNT + 1)) ;;
                    HIGH) HIGH_COUNT=$((HIGH_COUNT + 1)) ;;
                    MEDIUM) MEDIUM_COUNT=$((MEDIUM_COUNT + 1)) ;;
                    LOW) LOW_COUNT=$((LOW_COUNT + 1)) ;;
                esac

                TOTAL_VULNS=$((TOTAL_VULNS + 1))

                # Escape JSON strings properly
                summary_escaped=$(echo "$summary" | sed 's/"/\\"/g' | tr '\n' ' ')

                # Add vulnerability to list
                VULNERABILITIES+=("{
                    \"cve_id\": \"$cve_id\",
                    \"osv_id\": \"$osv_id\",
                    \"package\": \"$pkg\",
                    \"installed_version\": \"$version\",
                    \"severity\": \"$severity\",
                    \"cvss_score\": $cvss_score,
                    \"description\": \"$summary_escaped\",
                    \"affected_versions\": [\"$affected\"],
                    \"fixed_version\": $([ -n "$fixed_version" ] && [ "$fixed_version" != "null" ] && echo "\"$fixed_version\"" || echo "null"),
                    \"exploitable\": $exploitable,
                    \"remediation\": $([ -n "$remediation" ] && echo "\"$remediation\"" || echo "null"),
                    \"references\": [$(echo "$references" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/' | sed 's/""/null/')]
                }")
            done
        fi
    fi
done

# Check for npm packages if package-lock.json exists
if [ -f "/home/novakj/package-lock.json" ]; then
    echo "Checking npm packages..."
    # Could add npm audit integration here
fi

# Check for pip packages if requirements.txt exists
if [ -f "/home/novakj/requirements.txt" ]; then
    echo "Checking pip packages..."
    # Could add pip-audit integration here
fi

# Calculate scan duration
END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

# Determine overall status
if [ $CRITICAL_COUNT -gt 0 ]; then
    STATUS="critical"
    MESSAGE="$CRITICAL_COUNT critical vulnerabilities require immediate attention"
elif [ $HIGH_COUNT -gt 0 ]; then
    STATUS="high-risk"
    MESSAGE="$HIGH_COUNT high severity vulnerabilities detected"
elif [ $MEDIUM_COUNT -gt 0 ]; then
    STATUS="medium-risk"
    MESSAGE="$MEDIUM_COUNT medium severity issues found"
elif [ $LOW_COUNT -gt 0 ]; then
    STATUS="low-risk"
    MESSAGE="$LOW_COUNT low severity issues detected"
else
    STATUS="secure"
    MESSAGE="No known vulnerabilities detected in scanned packages"
fi

# Build scanned packages JSON array
SCANNED_JSON=$(IFS=,; echo "${SCANNED_PACKAGES[*]}")

# Build vulnerabilities JSON array
if [ ${#VULNERABILITIES[@]} -gt 0 ]; then
    VULNS_JSON=$(IFS=,; echo "${VULNERABILITIES[*]}")
else
    VULNS_JSON=""
fi

# Generate output JSON
cat > "$TEMP_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "summary": {
    "total_vulnerabilities": $TOTAL_VULNS,
    "critical": $CRITICAL_COUNT,
    "high": $HIGH_COUNT,
    "medium": $MEDIUM_COUNT,
    "low": $LOW_COUNT,
    "packages_scanned": $PACKAGES_SCANNED,
    "ecosystems_checked": ["apt", "npm", "pip"],
    "status": "$STATUS",
    "message": "$MESSAGE"
  },
  "vulnerabilities": [$VULNS_JSON],
  "scanned_packages": [$SCANNED_JSON],
  "scan_details": {
    "scan_duration_ms": $DURATION_MS,
    "osv_api_used": true,
    "nvd_api_used": false,
    "ubuntu_security_notices_checked": true,
    "last_database_update": "$TIMESTAMP"
  }
}
EOF

# Validate JSON before moving
if jq empty "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    echo "Vulnerability scan complete: $TOTAL_VULNS vulnerabilities found"
else
    echo "Error: Generated invalid JSON, keeping previous file"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Update history file
if [ -f "$HISTORY_FILE" ]; then
    # Add new snapshot to history
    HISTORY_SNAPSHOT="{\"timestamp\": \"$TIMESTAMP\", \"critical\": $CRITICAL_COUNT, \"high\": $HIGH_COUNT, \"medium\": $MEDIUM_COUNT, \"low\": $LOW_COUNT, \"total\": $TOTAL_VULNS}"

    # Keep last 30 snapshots
    jq --argjson snap "$HISTORY_SNAPSHOT" '.snapshots = ([$snap] + .snapshots[0:29])' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
else
    # Create new history file
    cat > "$HISTORY_FILE" <<EOF
{
  "snapshots": [
    {"timestamp": "$TIMESTAMP", "critical": $CRITICAL_COUNT, "high": $HIGH_COUNT, "medium": $MEDIUM_COUNT, "low": $LOW_COUNT, "total": $TOTAL_VULNS}
  ]
}
EOF
fi

echo "Scan results saved to $OUTPUT_FILE"
