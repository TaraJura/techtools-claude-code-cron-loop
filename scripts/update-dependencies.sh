#!/bin/bash
# update-dependencies.sh - Scans and reports dependency health status
# Output: JSON data for the dependencies.html dashboard

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/dependencies.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/dependencies-history.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
EPOCH=$(date +%s)

# Initialize counters
TOTAL_PACKAGES=0
OUTDATED_COUNT=0
VULNERABLE_COUNT=0
UPTODATE_COUNT=0

# Temporary files
APT_PACKAGES=$(mktemp)
APT_UPGRADABLE=$(mktemp)
NPM_PACKAGES=$(mktemp)
PIP_PACKAGES=$(mktemp)
PACKAGES_JSON=$(mktemp)

# Cleanup on exit
trap "rm -f $APT_PACKAGES $APT_UPGRADABLE $NPM_PACKAGES $PIP_PACKAGES $PACKAGES_JSON" EXIT

# Initialize packages JSON array
echo '[' > "$PACKAGES_JSON"
FIRST_PACKAGE=true

add_package() {
    local name="$1"
    local current="$2"
    local latest="$3"
    local type="$4"
    local status="$5"
    local cve_count="$6"
    local severity="$7"

    if [ "$FIRST_PACKAGE" = "true" ]; then
        FIRST_PACKAGE=false
    else
        echo ',' >> "$PACKAGES_JSON"
    fi

    cat >> "$PACKAGES_JSON" <<EOF
    {
      "name": "$name",
      "current_version": "$current",
      "latest_version": "$latest",
      "type": "$type",
      "status": "$status",
      "cve_count": $cve_count,
      "severity": "$severity"
    }
EOF

    TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
    case "$status" in
        "vulnerable") VULNERABLE_COUNT=$((VULNERABLE_COUNT + 1)) ;;
        "outdated") OUTDATED_COUNT=$((OUTDATED_COUNT + 1)) ;;
        "up-to-date") UPTODATE_COUNT=$((UPTODATE_COUNT + 1)) ;;
    esac
}

# ============================================
# APT PACKAGES (System packages)
# ============================================

# Get list of installed packages
dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | sort > "$APT_PACKAGES"

# Get list of upgradable packages
apt list --upgradable 2>/dev/null | grep -v "^Listing" | sed 's/\// /g' | awk '{print $1, $3, $6}' > "$APT_UPGRADABLE" || true

# Known security-relevant packages to track
SECURITY_PACKAGES="openssl libssl3 openssh-server openssh-client nginx curl wget git sudo bash coreutils systemd"

# Process security-relevant packages
for pkg in $SECURITY_PACKAGES; do
    current_version=$(grep "^${pkg}	" "$APT_PACKAGES" | cut -f2 || echo "")
    if [ -n "$current_version" ]; then
        # Check if there's an upgrade available
        upgrade_info=$(grep "^${pkg} " "$APT_UPGRADABLE" || echo "")
        if [ -n "$upgrade_info" ]; then
            latest_version=$(echo "$upgrade_info" | awk '{print $2}')
            # Check if it looks like a security update
            if echo "$upgrade_info" | grep -qi "security"; then
                add_package "$pkg" "$current_version" "$latest_version" "apt" "vulnerable" 1 "high"
            else
                add_package "$pkg" "$current_version" "$latest_version" "apt" "outdated" 0 "none"
            fi
        else
            add_package "$pkg" "$current_version" "$current_version" "apt" "up-to-date" 0 "none"
        fi
    fi
done

# Get count of all upgradable packages
APT_UPGRADABLE_COUNT=$(wc -l < "$APT_UPGRADABLE" | tr -d ' ')
APT_INSTALLED_COUNT=$(wc -l < "$APT_PACKAGES" | tr -d ' ')

# ============================================
# NPM PACKAGES (if any exist in the project)
# ============================================

NPM_OUTDATED_COUNT=0
NPM_VULNERABLE_COUNT=0
NPM_TOTAL=0

# Check for package.json in web directory
if [ -f "/var/www/cronloop.techtools.cz/package.json" ]; then
    cd /var/www/cronloop.techtools.cz

    # Get outdated packages
    if command -v npm &> /dev/null; then
        npm outdated --json 2>/dev/null > "$NPM_PACKAGES" || true

        if [ -s "$NPM_PACKAGES" ] && [ "$(cat "$NPM_PACKAGES")" != "{}" ]; then
            # Parse npm outdated JSON
            for pkg in $(jq -r 'keys[]' "$NPM_PACKAGES" 2>/dev/null); do
                current=$(jq -r ".\"$pkg\".current // \"unknown\"" "$NPM_PACKAGES")
                latest=$(jq -r ".\"$pkg\".latest // \"unknown\"" "$NPM_PACKAGES")
                wanted=$(jq -r ".\"$pkg\".wanted // \"unknown\"" "$NPM_PACKAGES")

                if [ "$current" != "$latest" ]; then
                    add_package "$pkg" "$current" "$latest" "npm" "outdated" 0 "none"
                    NPM_OUTDATED_COUNT=$((NPM_OUTDATED_COUNT + 1))
                fi
            done
        fi

        # Check for vulnerabilities with npm audit
        audit_result=$(npm audit --json 2>/dev/null || echo '{"vulnerabilities":{}}')
        vuln_count=$(echo "$audit_result" | jq '.metadata.vulnerabilities.total // 0' 2>/dev/null || echo "0")

        if [ "$vuln_count" -gt 0 ]; then
            # Get vulnerable packages
            for pkg in $(echo "$audit_result" | jq -r '.vulnerabilities | keys[]' 2>/dev/null); do
                severity=$(echo "$audit_result" | jq -r ".vulnerabilities.\"$pkg\".severity // \"unknown\"" 2>/dev/null)
                via=$(echo "$audit_result" | jq -r ".vulnerabilities.\"$pkg\".via[0] // \"unknown\"" 2>/dev/null)

                # Get package version from package-lock or node_modules
                pkg_version="unknown"
                if [ -f "package-lock.json" ]; then
                    pkg_version=$(jq -r ".packages.\"node_modules/$pkg\".version // \"unknown\"" package-lock.json 2>/dev/null || echo "unknown")
                fi

                add_package "$pkg" "$pkg_version" "update needed" "npm" "vulnerable" 1 "$severity"
                NPM_VULNERABLE_COUNT=$((NPM_VULNERABLE_COUNT + 1))
            done
        fi

        # Count total npm packages
        if [ -f "package-lock.json" ]; then
            NPM_TOTAL=$(jq '.packages | keys | length' package-lock.json 2>/dev/null || echo "0")
        elif [ -f "package.json" ]; then
            NPM_TOTAL=$(jq '(.dependencies // {} | keys | length) + (.devDependencies // {} | keys | length)' package.json 2>/dev/null || echo "0")
        fi
    fi
fi

# ============================================
# PYTHON PACKAGES
# ============================================

PIP_OUTDATED_COUNT=0
PIP_TOTAL=0

# Check for Python packages
if command -v pip3 &> /dev/null; then
    pip3 list --format=freeze 2>/dev/null > "$PIP_PACKAGES" || true
    PIP_TOTAL=$(wc -l < "$PIP_PACKAGES" | tr -d ' ')

    # Check for outdated packages
    pip3 list --outdated --format=json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read -r pkg_json; do
        pkg_name=$(echo "$pkg_json" | jq -r '.name')
        current=$(echo "$pkg_json" | jq -r '.version')
        latest=$(echo "$pkg_json" | jq -r '.latest_version')

        # Only add significant Python packages
        case "$pkg_name" in
            pip|setuptools|wheel|requests|urllib3|certifi|cryptography|paramiko|pyyaml|jinja2)
                add_package "$pkg_name" "$current" "$latest" "pip" "outdated" 0 "none"
                ;;
        esac
    done || true

    PIP_OUTDATED_COUNT=$(pip3 list --outdated --format=json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
fi

# Close packages array
echo '' >> "$PACKAGES_JSON"
echo ']' >> "$PACKAGES_JSON"

# ============================================
# Generate security score
# ============================================

# Security score: 100 - (vulnerable * 20) - (outdated * 5), minimum 0
SECURITY_SCORE=$((100 - (VULNERABLE_COUNT * 20) - (OUTDATED_COUNT * 5)))
[ $SECURITY_SCORE -lt 0 ] && SECURITY_SCORE=0

# Determine overall status
if [ $VULNERABLE_COUNT -gt 0 ]; then
    OVERALL_STATUS="critical"
    OVERALL_MESSAGE="$VULNERABLE_COUNT packages have known vulnerabilities"
elif [ $OUTDATED_COUNT -gt 5 ]; then
    OVERALL_STATUS="warning"
    OVERALL_MESSAGE="$OUTDATED_COUNT packages need updates"
elif [ $OUTDATED_COUNT -gt 0 ]; then
    OVERALL_STATUS="info"
    OVERALL_MESSAGE="$OUTDATED_COUNT minor updates available"
else
    OVERALL_STATUS="healthy"
    OVERALL_MESSAGE="All tracked packages are up-to-date"
fi

# ============================================
# Generate update commands
# ============================================

UPDATE_COMMANDS='[]'

if [ "$APT_UPGRADABLE_COUNT" -gt 0 ]; then
    UPDATE_COMMANDS=$(echo "$UPDATE_COMMANDS" | jq '. + ["sudo apt update && sudo apt upgrade -y"]')
fi

if [ "$NPM_OUTDATED_COUNT" -gt 0 ]; then
    UPDATE_COMMANDS=$(echo "$UPDATE_COMMANDS" | jq '. + ["npm update"]')
fi

if [ "$NPM_VULNERABLE_COUNT" -gt 0 ]; then
    UPDATE_COMMANDS=$(echo "$UPDATE_COMMANDS" | jq '. + ["npm audit fix"]')
fi

if [ "$PIP_OUTDATED_COUNT" -gt 0 ]; then
    UPDATE_COMMANDS=$(echo "$UPDATE_COMMANDS" | jq '. + ["pip3 install --upgrade pip setuptools wheel"]')
fi

# ============================================
# Write output JSON
# ============================================

cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "date": "$TODAY",
  "summary": {
    "total_tracked": $TOTAL_PACKAGES,
    "up_to_date": $UPTODATE_COUNT,
    "outdated": $OUTDATED_COUNT,
    "vulnerable": $VULNERABLE_COUNT,
    "security_score": $SECURITY_SCORE,
    "status": "$OVERALL_STATUS",
    "message": "$OVERALL_MESSAGE"
  },
  "system": {
    "apt_installed": $APT_INSTALLED_COUNT,
    "apt_upgradable": $APT_UPGRADABLE_COUNT,
    "npm_total": $NPM_TOTAL,
    "npm_outdated": $NPM_OUTDATED_COUNT,
    "npm_vulnerable": $NPM_VULNERABLE_COUNT,
    "pip_total": $PIP_TOTAL,
    "pip_outdated": $PIP_OUTDATED_COUNT
  },
  "packages": $(cat "$PACKAGES_JSON"),
  "update_commands": $UPDATE_COMMANDS,
  "scan_details": {
    "security_packages_checked": "$(echo $SECURITY_PACKAGES | tr ' ' ', ')",
    "npm_audit_enabled": $(command -v npm &> /dev/null && [ -f "/var/www/cronloop.techtools.cz/package.json" ] && echo "true" || echo "false"),
    "pip_available": $(command -v pip3 &> /dev/null && echo "true" || echo "false")
  }
}
EOF

# ============================================
# Update history file
# ============================================

# Create history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo '{"snapshots": []}' > "$HISTORY_FILE"
fi

# Add current snapshot to history (keep last 30 snapshots)
SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "total_tracked": $TOTAL_PACKAGES,
  "outdated": $OUTDATED_COUNT,
  "vulnerable": $VULNERABLE_COUNT,
  "security_score": $SECURITY_SCORE
}
EOF
)

# Use jq to add snapshot and keep last 30
TMP_HISTORY=$(mktemp)
jq --argjson snapshot "$SNAPSHOT" '.snapshots = ([$snapshot] + .snapshots | .[0:30])' "$HISTORY_FILE" > "$TMP_HISTORY" && mv "$TMP_HISTORY" "$HISTORY_FILE"

echo "Dependency scan complete: $TOTAL_PACKAGES packages tracked, $OUTDATED_COUNT outdated, $VULNERABLE_COUNT vulnerable"
