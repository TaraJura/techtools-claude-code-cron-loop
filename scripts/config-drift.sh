#!/bin/bash
# config-drift.sh - Configuration drift detection for critical system files
# Tracks changes to important config files by comparing current hashes against baseline
#
# Created: 2026-01-20
# Task: TASK-053

set -e

# Output files
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/config-drift.json"
BASELINE_FILE="/var/www/cronloop.techtools.cz/api/config-baseline.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/config-drift-history.json"

# Critical config files to monitor
declare -a CONFIG_FILES=(
    # Nginx configs
    "/etc/nginx/nginx.conf"
    "/etc/nginx/sites-enabled/cronloop.techtools.cz"
    "/etc/nginx/sites-enabled/default"
    # SSH config
    "/etc/ssh/sshd_config"
    # System configs
    "/etc/crontab"
    "/etc/passwd"
    "/etc/group"
    "/etc/sudoers"
    # CronLoop core files
    "/home/novakj/CLAUDE.md"
    "/home/novakj/scripts/cron-orchestrator.sh"
    "/home/novakj/scripts/run-actor.sh"
    # Agent prompts
    "/home/novakj/actors/idea-maker/prompt.md"
    "/home/novakj/actors/project-manager/prompt.md"
    "/home/novakj/actors/developer/prompt.md"
    "/home/novakj/actors/developer2/prompt.md"
    "/home/novakj/actors/tester/prompt.md"
    "/home/novakj/actors/security/prompt.md"
    "/home/novakj/actors/supervisor/prompt.md"
)

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

# Get file hash
get_file_hash() {
    local file="$1"
    if [[ -r "$file" ]]; then
        sha256sum "$file" 2>/dev/null | cut -d' ' -f1
    else
        echo "not_found"
    fi
}

# Get file modification time
get_file_mtime() {
    local file="$1"
    if [[ -r "$file" ]]; then
        stat -c '%Y' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get file size
get_file_size() {
    local file="$1"
    if [[ -r "$file" ]]; then
        stat -c '%s' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Classify file as security-sensitive
get_file_category() {
    local file="$1"
    case "$file" in
        /etc/ssh/*|/etc/sudoers|/etc/shadow)
            echo "security"
            ;;
        /etc/nginx/*)
            echo "nginx"
            ;;
        /etc/passwd|/etc/group)
            echo "system"
            ;;
        /etc/crontab|/etc/cron.d/*)
            echo "cron"
            ;;
        /home/novakj/CLAUDE.md|/home/novakj/scripts/*)
            echo "orchestrator"
            ;;
        /home/novakj/actors/*)
            echo "agent"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Get alert level based on category and change type
get_alert_level() {
    local category="$1"
    local change_type="$2"

    case "$category" in
        security)
            echo "critical"
            ;;
        orchestrator)
            if [[ "$change_type" == "deleted" ]]; then
                echo "critical"
            else
                echo "warning"
            fi
            ;;
        nginx|cron)
            echo "warning"
            ;;
        *)
            echo "info"
            ;;
    esac
}

# Initialize baseline if it doesn't exist
init_baseline() {
    if [[ ! -f "$BASELINE_FILE" ]]; then
        echo "Creating initial baseline..."
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local files="{"
        local first=true

        for file in "${CONFIG_FILES[@]}"; do
            local hash=$(get_file_hash "$file")
            local mtime=$(get_file_mtime "$file")
            local size=$(get_file_size "$file")
            local category=$(get_file_category "$file")

            if [ "$first" = true ]; then
                first=false
            else
                files+=","
            fi

            files+="\"$(json_escape "$file")\":{\"hash\":\"$hash\",\"mtime\":$mtime,\"size\":$size,\"category\":\"$category\"}"
        done

        files+="}"

        echo "{\"created\":\"$timestamp\",\"updated\":\"$timestamp\",\"files\":$files}" > "$BASELINE_FILE"
        echo "Baseline created at $BASELINE_FILE"
    fi
}

# Update baseline with current state
update_baseline() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local created=$(jq -r '.created // ""' "$BASELINE_FILE" 2>/dev/null || echo "$timestamp")
    local files="{"
    local first=true

    for file in "${CONFIG_FILES[@]}"; do
        local hash=$(get_file_hash "$file")
        local mtime=$(get_file_mtime "$file")
        local size=$(get_file_size "$file")
        local category=$(get_file_category "$file")

        if [ "$first" = true ]; then
            first=false
        else
            files+=","
        fi

        files+="\"$(json_escape "$file")\":{\"hash\":\"$hash\",\"mtime\":$mtime,\"size\":$size,\"category\":\"$category\"}"
    done

    files+="}"

    echo "{\"created\":\"$created\",\"updated\":\"$timestamp\",\"files\":$files}" > "$BASELINE_FILE"
}

# Compare current state against baseline
detect_drift() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local changes="[]"
    local change_count=0
    local critical_count=0
    local warning_count=0
    local info_count=0
    local files_json="["
    local first_file=true

    # Load baseline
    local baseline=$(cat "$BASELINE_FILE" 2>/dev/null)

    for file in "${CONFIG_FILES[@]}"; do
        local current_hash=$(get_file_hash "$file")
        local current_mtime=$(get_file_mtime "$file")
        local current_size=$(get_file_size "$file")
        local category=$(get_file_category "$file")

        # Get baseline values using jq
        local base_hash=$(echo "$baseline" | jq -r ".files[\"$file\"].hash // \"\"" 2>/dev/null)
        local base_mtime=$(echo "$baseline" | jq -r ".files[\"$file\"].mtime // 0" 2>/dev/null)
        local base_size=$(echo "$baseline" | jq -r ".files[\"$file\"].size // 0" 2>/dev/null)

        local status="unchanged"
        local change_type=""
        local alert_level="none"

        # Detect changes
        if [[ "$current_hash" == "not_found" ]] && [[ "$base_hash" != "not_found" ]] && [[ -n "$base_hash" ]]; then
            status="deleted"
            change_type="deleted"
            alert_level=$(get_alert_level "$category" "deleted")
            ((change_count++))
        elif [[ "$current_hash" != "not_found" ]] && [[ "$base_hash" == "not_found" || -z "$base_hash" ]]; then
            status="new"
            change_type="created"
            alert_level=$(get_alert_level "$category" "created")
            ((change_count++))
        elif [[ "$current_hash" != "$base_hash" ]] && [[ -n "$base_hash" ]]; then
            status="modified"
            change_type="modified"
            alert_level=$(get_alert_level "$category" "modified")
            ((change_count++))
        fi

        # Count by alert level
        case "$alert_level" in
            critical) ((critical_count++)) ;;
            warning) ((warning_count++)) ;;
            info) ((info_count++)) ;;
        esac

        # Build file entry
        if [ "$first_file" = true ]; then
            first_file=false
        else
            files_json+=","
        fi

        local mtime_formatted=""
        if [[ "$current_mtime" != "0" ]]; then
            mtime_formatted=$(date -d "@$current_mtime" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
        fi

        files_json+="{\"path\":\"$(json_escape "$file")\",\"category\":\"$category\",\"status\":\"$status\",\"alert_level\":\"$alert_level\",\"current_hash\":\"$current_hash\",\"baseline_hash\":\"$base_hash\",\"current_size\":$current_size,\"baseline_size\":$base_size,\"modified\":\"$mtime_formatted\"}"
    done

    files_json+="]"

    # Calculate overall status
    local overall_status="ok"
    if [[ $critical_count -gt 0 ]]; then
        overall_status="critical"
    elif [[ $warning_count -gt 0 ]]; then
        overall_status="warning"
    elif [[ $info_count -gt 0 ]]; then
        overall_status="info"
    fi

    # Get baseline timestamps
    local baseline_created=$(echo "$baseline" | jq -r '.created // ""' 2>/dev/null)
    local baseline_updated=$(echo "$baseline" | jq -r '.updated // ""' 2>/dev/null)

    # Build final JSON
    local json="{
  \"timestamp\": \"$timestamp\",
  \"status\": \"$overall_status\",
  \"summary\": {
    \"total_files\": ${#CONFIG_FILES[@]},
    \"changes_detected\": $change_count,
    \"critical\": $critical_count,
    \"warning\": $warning_count,
    \"info\": $info_count
  },
  \"baseline\": {
    \"created\": \"$baseline_created\",
    \"updated\": \"$baseline_updated\"
  },
  \"files\": $files_json
}"

    echo "$json" > "$OUTPUT_FILE"

    # Append to history (keep last 100 entries)
    if [[ -f "$HISTORY_FILE" ]]; then
        local history_entry="{\"timestamp\":\"$timestamp\",\"status\":\"$overall_status\",\"changes\":$change_count,\"critical\":$critical_count,\"warning\":$warning_count,\"info\":$info_count}"

        # Read current history, add new entry, and keep last 100
        local updated_history=$(jq --argjson entry "$history_entry" '
            . + [$entry] | .[-100:]
        ' "$HISTORY_FILE" 2>/dev/null || echo "[$history_entry]")

        echo "$updated_history" > "$HISTORY_FILE"
    else
        echo "[{\"timestamp\":\"$timestamp\",\"status\":\"$overall_status\",\"changes\":$change_count,\"critical\":$critical_count,\"warning\":$warning_count,\"info\":$info_count}]" > "$HISTORY_FILE"
    fi

    echo "Config drift check completed: $change_count changes detected ($critical_count critical, $warning_count warning, $info_count info)"
}

# Main
main() {
    case "${1:-check}" in
        init)
            init_baseline
            ;;
        update)
            update_baseline
            echo "Baseline updated"
            ;;
        check|*)
            init_baseline
            detect_drift
            ;;
    esac
}

main "$@"
