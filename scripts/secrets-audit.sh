#!/bin/bash
# secrets-audit.sh - Scans for environment variables and potential exposed secrets
# Generates JSON output for the secrets-audit.html web page
#
# Created: 2026-01-20
# Task: TASK-040

set -e

# Output file location
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/secrets-audit.json"

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

# Patterns that indicate a secret (case insensitive)
SECRET_PATTERNS=(
    "_KEY="
    "_SECRET="
    "_TOKEN="
    "_PASSWORD="
    "_PWD="
    "_PASS="
    "_API_KEY="
    "API_KEY="
    "SECRET_KEY="
    "ACCESS_KEY="
    "AUTH_TOKEN="
    "PRIVATE_KEY="
    "DATABASE_URL="
    "REDIS_URL="
    "MONGODB_URI="
    "AWS_ACCESS"
    "GITHUB_TOKEN="
    "NPM_TOKEN="
    "DOCKER_"
)

# Locations to scan for env files
ENV_LOCATIONS=(
    "/home/novakj/.env"
    "/home/novakj/.bashrc"
    "/home/novakj/.profile"
    "/home/novakj/.bash_profile"
    "/home/novakj/.zshrc"
    "/etc/environment"
    "/var/www/cronloop.techtools.cz/.env"
    "/home/novakj/projects/.env"
)

# Check if a line looks like a secret
looks_like_secret() {
    local line="$1"
    local upper_line=$(echo "$line" | tr '[:lower:]' '[:upper:]')

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if [[ "$upper_line" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# Mask a secret value - show only first 2 and last 2 chars
mask_value() {
    local value="$1"
    local len=${#value}

    if [ "$len" -le 4 ]; then
        echo "****"
    elif [ "$len" -le 8 ]; then
        echo "${value:0:1}***${value: -1}"
    else
        echo "${value:0:2}***${value: -2}"
    fi
}

# Get risk level for a secret type
get_risk_level() {
    local var_name="$1"
    local upper_name=$(echo "$var_name" | tr '[:lower:]' '[:upper:]')

    # High risk patterns
    if [[ "$upper_name" == *"PRIVATE_KEY"* ]] || \
       [[ "$upper_name" == *"SECRET_KEY"* ]] || \
       [[ "$upper_name" == *"PASSWORD"* ]] || \
       [[ "$upper_name" == *"DATABASE_URL"* ]] || \
       [[ "$upper_name" == *"AWS_SECRET"* ]] || \
       [[ "$upper_name" == *"GITHUB_TOKEN"* ]]; then
        echo "high"
    # Medium risk patterns
    elif [[ "$upper_name" == *"API_KEY"* ]] || \
         [[ "$upper_name" == *"AUTH_TOKEN"* ]] || \
         [[ "$upper_name" == *"ACCESS_KEY"* ]] || \
         [[ "$upper_name" == *"TOKEN"* ]]; then
        echo "medium"
    else
        echo "low"
    fi
}

# Scan environment files for secrets
scan_env_files() {
    local findings="["
    local first=true

    for file in "${ENV_LOCATIONS[@]}"; do
        if [ -f "$file" ] && [ -r "$file" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${line// }" ]] && continue

                # Check for export statements or direct assignments
                if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                    local var_name="${BASH_REMATCH[2]}"
                    local var_value="${BASH_REMATCH[3]}"

                    # Remove quotes from value
                    var_value="${var_value#\"}"
                    var_value="${var_value%\"}"
                    var_value="${var_value#\'}"
                    var_value="${var_value%\'}"

                    if looks_like_secret "$var_name"; then
                        local masked=$(mask_value "$var_value")
                        local risk=$(get_risk_level "$var_name")
                        local escaped_name=$(json_escape "$var_name")
                        local escaped_file=$(json_escape "$file")
                        local escaped_masked=$(json_escape "$masked")

                        if [ "$first" = true ]; then
                            first=false
                        else
                            findings+=","
                        fi

                        findings+="{\"source\":\"$escaped_file\",\"variable\":\"$escaped_name\",\"masked_value\":\"$escaped_masked\",\"risk\":\"$risk\",\"type\":\"env_file\"}"
                    fi
                fi
            done < "$file"
        fi
    done

    findings+="]"
    echo "$findings"
}

# Check for secrets in current environment
scan_current_env() {
    local findings="["
    local first=true

    while IFS='=' read -r name value; do
        if looks_like_secret "$name"; then
            local masked=$(mask_value "$value")
            local risk=$(get_risk_level "$name")
            local escaped_name=$(json_escape "$name")
            local escaped_masked=$(json_escape "$masked")

            if [ "$first" = true ]; then
                first=false
            else
                findings+=","
            fi

            findings+="{\"source\":\"runtime_env\",\"variable\":\"$escaped_name\",\"masked_value\":\"$escaped_masked\",\"risk\":\"$risk\",\"type\":\"runtime\"}"
        fi
    done < <(env)

    findings+="]"
    echo "$findings"
}

# Check for secrets in git history (limited scan)
check_git_history() {
    local result="{\"checked\":false,\"issues_found\":0,\"details\":[]}"

    if [ -d "/home/novakj/.git" ]; then
        cd /home/novakj

        # Quick scan of last 50 commits for common secret patterns
        local found_count=0
        local details="["
        local first=true

        # Search for common secret patterns in git log
        for pattern in "password" "secret" "api_key" "token" "private_key"; do
            local matches=$(git log -50 --all -p -S"$pattern" --oneline 2>/dev/null | head -5 || true)
            if [ -n "$matches" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    details+=","
                fi
                local escaped_pattern=$(json_escape "$pattern")
                details+="{\"pattern\":\"$escaped_pattern\",\"found\":true}"
                ((found_count++)) || true
            fi
        done

        details+="]"
        result="{\"checked\":true,\"issues_found\":$found_count,\"details\":$details}"
    fi

    echo "$result"
}

# Check if any secrets are in web-accessible files
check_web_exposed() {
    local web_root="/var/www/cronloop.techtools.cz"
    local findings="["
    local first=true
    local issues_count=0

    if [ -d "$web_root" ]; then
        # Check JS files for hardcoded secrets
        while IFS= read -r file; do
            for pattern in "password" "api_key" "secret" "token" "private_key"; do
                if grep -qi "$pattern.*=" "$file" 2>/dev/null; then
                    local escaped_file=$(json_escape "${file#$web_root}")
                    local escaped_pattern=$(json_escape "$pattern")

                    if [ "$first" = true ]; then
                        first=false
                    else
                        findings+=","
                    fi

                    findings+="{\"file\":\"$escaped_file\",\"pattern\":\"$escaped_pattern\",\"type\":\"potential_hardcoded\"}"
                    ((issues_count++)) || true
                fi
            done
        done < <(find "$web_root" -name "*.js" -type f 2>/dev/null)

        # Check for .env files in web root
        while IFS= read -r file; do
            local escaped_file=$(json_escape "${file#$web_root}")

            if [ "$first" = true ]; then
                first=false
            else
                findings+=","
            fi

            findings+="{\"file\":\"$escaped_file\",\"pattern\":\".env file\",\"type\":\"env_in_webroot\"}"
            ((issues_count++)) || true
        done < <(find "$web_root" -name ".env*" -type f 2>/dev/null)
    fi

    findings+="]"
    echo "{\"issues_count\":$issues_count,\"findings\":$findings}"
}

# Check file permissions on sensitive files
check_sensitive_permissions() {
    local findings="["
    local first=true
    local issues_count=0

    # Sensitive files to check
    local sensitive_files=(
        "/home/novakj/.ssh/id_ed25519"
        "/home/novakj/.ssh/id_rsa"
        "/home/novakj/.ssh/config"
        "/home/novakj/.gitconfig"
        "/home/novakj/CLAUDE.md"
        "/home/novakj/.env"
    )

    for file in "${sensitive_files[@]}"; do
        if [ -f "$file" ]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")
            local owner=$(stat -c "%U" "$file" 2>/dev/null || echo "unknown")
            local escaped_file=$(json_escape "$file")
            local status="ok"
            local recommendation=""

            # Check for overly permissive permissions
            if [[ "$file" == *"id_rsa"* ]] || [[ "$file" == *"id_ed25519"* ]]; then
                if [ "$perms" != "600" ]; then
                    status="warning"
                    recommendation="Should be 600 (chmod 600 $file)"
                    ((issues_count++)) || true
                fi
            elif [[ "$file" == *".ssh"* ]]; then
                if [ "$perms" != "600" ] && [ "$perms" != "644" ]; then
                    status="warning"
                    recommendation="Should be 600 or 644"
                    ((issues_count++)) || true
                fi
            elif [[ "$perms" == *"7"* ]] && [[ "${perms: -1}" == "7" || "${perms: -2:1}" == "7" ]]; then
                status="warning"
                recommendation="World or group writable, consider restricting"
                ((issues_count++)) || true
            fi

            if [ "$first" = true ]; then
                first=false
            else
                findings+=","
            fi

            local escaped_rec=$(json_escape "$recommendation")
            findings+="{\"file\":\"$escaped_file\",\"permissions\":\"$perms\",\"owner\":\"$owner\",\"status\":\"$status\",\"recommendation\":\"$escaped_rec\"}"
        fi
    done

    findings+="]"
    echo "{\"issues_count\":$issues_count,\"files\":$findings}"
}

# Generate recommendations
generate_recommendations() {
    local env_count="$1"
    local git_issues="$2"
    local web_issues="$3"
    local perm_issues="$4"

    local recs="["
    local first=true

    # High priority: web-exposed secrets
    if [ "$web_issues" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"high\",\"message\":\"Potential secrets found in web-accessible files\",\"action\":\"Review and remove hardcoded credentials from JS files\"}"
    fi

    # High priority: git history secrets
    if [ "$git_issues" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"high\",\"message\":\"Secret patterns found in git history\",\"action\":\"Use git-filter-repo to remove sensitive data from history\"}"
    fi

    # Medium priority: permission issues
    if [ "$perm_issues" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"medium\",\"message\":\"Sensitive files have permissive permissions\",\"action\":\"Restrict file permissions using chmod\"}"
    fi

    # Info: env file secrets
    if [ "$env_count" -gt 0 ]; then
        if [ "$first" = true ]; then first=false; else recs+=","; fi
        recs+="{\"severity\":\"low\",\"message\":\"$env_count environment variables detected that may contain secrets\",\"action\":\"Ensure these are not committed to git or exposed via web\"}"
    fi

    recs+="]"
    echo "$recs"
}

# Calculate audit score (0-100)
calculate_audit_score() {
    local env_count="$1"
    local git_issues="$2"
    local web_issues="$3"
    local perm_issues="$4"

    local score=100

    # Major deductions
    if [ "$web_issues" -gt 0 ]; then
        score=$((score - web_issues * 20))
    fi

    if [ "$git_issues" -gt 0 ]; then
        score=$((score - git_issues * 15))
    fi

    # Minor deductions
    if [ "$perm_issues" -gt 0 ]; then
        score=$((score - perm_issues * 5))
    fi

    # Env variables are expected, small deduction if many
    if [ "$env_count" -gt 10 ]; then
        score=$((score - 5))
    fi

    # Ensure score doesn't go negative
    if [ "$score" -lt 0 ]; then
        score=0
    fi

    echo "$score"
}

# Get audit status based on score
get_audit_status() {
    local score="$1"

    if [ "$score" -ge 90 ]; then
        echo "Secure"
    elif [ "$score" -ge 70 ]; then
        echo "Warning"
    else
        echo "Critical"
    fi
}

# Count findings in JSON array
count_json_array() {
    local json="$1"
    # Use Python for reliable JSON parsing
    echo "$json" | python3 -c "import sys,json; arr=json.load(sys.stdin); print(len(arr))" 2>/dev/null || echo "0"
}

# Main execution
main() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Collect all audit data
    local env_findings=$(scan_env_files)
    local runtime_findings=$(scan_current_env)
    local git_check=$(check_git_history)
    local web_check=$(check_web_exposed)
    local perm_check=$(check_sensitive_permissions)

    # Count issues
    local env_count=$(count_json_array "$env_findings")
    local runtime_count=$(count_json_array "$runtime_findings")
    local git_issues=$(echo "$git_check" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('issues_found',0))" 2>/dev/null || echo "0")
    local web_issues=$(echo "$web_check" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('issues_count',0))" 2>/dev/null || echo "0")
    local perm_issues=$(echo "$perm_check" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('issues_count',0))" 2>/dev/null || echo "0")

    # Calculate score and status
    local total_secrets=$((env_count + runtime_count))
    local score=$(calculate_audit_score "$total_secrets" "$git_issues" "$web_issues" "$perm_issues")
    local status=$(get_audit_status "$score")
    local recommendations=$(generate_recommendations "$total_secrets" "$git_issues" "$web_issues" "$perm_issues")

    # Build JSON output
    local json="{
  \"timestamp\": \"$timestamp\",
  \"score\": $score,
  \"status\": \"$status\",
  \"summary\": {
    \"env_secrets_count\": $env_count,
    \"runtime_secrets_count\": $runtime_count,
    \"total_secrets_detected\": $total_secrets,
    \"git_history_issues\": $git_issues,
    \"web_exposed_issues\": $web_issues,
    \"permission_issues\": $perm_issues
  },
  \"env_file_findings\": $env_findings,
  \"runtime_findings\": $runtime_findings,
  \"git_history\": $git_check,
  \"web_exposure\": $web_check,
  \"file_permissions\": $perm_check,
  \"recommendations\": $recommendations
}"

    # Write to file
    echo "$json" > "$OUTPUT_FILE"
    echo "Secrets audit completed: $OUTPUT_FILE"
}

# Run main
main
