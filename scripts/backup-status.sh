#!/bin/bash
# Backup Status Generator - Creates JSON for backup dashboard
# Part of CronLoop Backup Status Dashboard (TASK-037)
#
# Output: JSON file at /var/www/cronloop.techtools.cz/api/backup-status.json
#
# JSON structure:
# {
#   "timestamp": "ISO timestamp",
#   "backup_dir": "/path/to/backups",
#   "retention_policy": 5,
#   "last_backup": { "file": "...", "date": "...", "size_bytes": ..., "age_hours": ... },
#   "backups": [ { "file": "...", "date": "...", "size_bytes": ..., "size_human": "..." } ],
#   "total_count": 2,
#   "total_size_bytes": 123456,
#   "total_size_human": "123 KB",
#   "disk_usage": { "backups_mb": 0.1, "available_mb": 70000, "percent_of_available": 0.0001 },
#   "files_included": [ "list of files that would be backed up" ],
#   "health": { "status": "ok|warning|critical", "message": "..." }
# }

BACKUP_DIR="/home/novakj/backups/configs"
CONFIG_BACKUP_SCRIPT="/home/novakj/projects/config-backup.sh"
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/backup-status.json"
RETENTION_POLICY=5

# Ensure directories exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Get list of backup files sorted by time (newest first)
get_backups() {
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -t "$BACKUP_DIR"/config-backup-*.tar.gz 2>/dev/null
    fi
}

# Get file size in bytes
file_size_bytes() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || echo 0
}

# Convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( bytes / 1024 )) KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( bytes / 1048576 )) MB"
    else
        echo "$(( bytes / 1073741824 )) GB"
    fi
}

# Get modification time as ISO timestamp
file_date_iso() {
    local file="$1"
    stat -c %y "$file" 2>/dev/null | cut -d'.' -f1 | sed 's/ /T/'
}

# Get age in hours
file_age_hours() {
    local file="$1"
    local now=$(date +%s)
    local file_time=$(stat -c %Y "$file" 2>/dev/null || echo "$now")
    local diff=$(( (now - file_time) / 3600 ))
    echo $diff
}

# Get files that would be backed up (from config-backup.sh -l)
get_backup_files_list() {
    # Extract the file lists from config-backup.sh or use defaults
    local files=(
        "/etc/nginx/nginx.conf"
        "/etc/nginx/sites-available"
        "/etc/ssh/sshd_config"
        "/etc/crontab"
        "/etc/cron.d"
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d"
        "/etc/fstab"
        "/etc/hosts"
        "/etc/hostname"
        "$HOME/.bashrc"
        "$HOME/.profile"
        "$HOME/.gitconfig"
        "$HOME/.ssh/config"
        "$HOME/CLAUDE.md"
        "$HOME/README.md"
        "$HOME/tasks.md"
        "$HOME/actors/idea-maker/CLAUDE.md"
        "$HOME/actors/project-manager/CLAUDE.md"
        "$HOME/actors/developer/CLAUDE.md"
        "$HOME/actors/tester/CLAUDE.md"
    )

    local existing=()
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            existing+=("$file")
        fi
    done
    printf '%s\n' "${existing[@]}"
}

# Calculate health status
get_health_status() {
    local last_backup_age_hours=$1
    local backup_count=$2

    if [[ $backup_count -eq 0 ]]; then
        echo "critical|No backups exist! Run config-backup.sh to create one."
    elif [[ $last_backup_age_hours -gt 168 ]]; then  # > 7 days
        echo "critical|Last backup is over 7 days old!"
    elif [[ $last_backup_age_hours -gt 48 ]]; then  # > 2 days
        echo "warning|Last backup is over 2 days old."
    else
        echo "ok|Backups are up to date."
    fi
}

# Generate JSON output
generate_json() {
    local timestamp=$(date -Iseconds)
    local backups=($(get_backups))
    local backup_count=${#backups[@]}
    local total_size=0

    # Calculate total size
    for backup in "${backups[@]}"; do
        local size=$(file_size_bytes "$backup")
        total_size=$((total_size + size))
    done

    # Get disk usage info
    local available_mb=$(df -m "$BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
    local backups_mb=$(( total_size / 1048576 ))
    local percent_of_available=0
    if [[ $available_mb -gt 0 ]]; then
        percent_of_available=$(python3 -c "print(round($total_size / ($available_mb * 1048576) * 100, 4))")
    fi

    # Get last backup info
    local last_backup_file=""
    local last_backup_date=""
    local last_backup_size=0
    local last_backup_age=0

    if [[ $backup_count -gt 0 ]]; then
        last_backup_file=$(basename "${backups[0]}")
        last_backup_date=$(file_date_iso "${backups[0]}")
        last_backup_size=$(file_size_bytes "${backups[0]}")
        last_backup_age=$(file_age_hours "${backups[0]}")
    fi

    # Get health status
    local health_info=$(get_health_status $last_backup_age $backup_count)
    local health_status="${health_info%%|*}"
    local health_message="${health_info#*|}"

    # Get list of files that would be backed up
    local files_list=$(get_backup_files_list)

    # Build JSON with Python for proper escaping
    python3 << PYTHON_EOF
import json
import sys

data = {
    "timestamp": "$timestamp",
    "backup_dir": "$BACKUP_DIR",
    "retention_policy": $RETENTION_POLICY,
    "last_backup": {
        "file": "$last_backup_file" if "$last_backup_file" else None,
        "date": "$last_backup_date" if "$last_backup_date" else None,
        "size_bytes": $last_backup_size,
        "size_human": "$(bytes_to_human $last_backup_size)",
        "age_hours": $last_backup_age
    } if $backup_count > 0 else None,
    "backups": [],
    "total_count": $backup_count,
    "total_size_bytes": $total_size,
    "total_size_human": "$(bytes_to_human $total_size)",
    "disk_usage": {
        "backups_mb": $backups_mb,
        "available_mb": $available_mb,
        "percent_of_available": $percent_of_available
    },
    "files_included": [],
    "health": {
        "status": "$health_status",
        "message": "$health_message"
    }
}

# Add backup list
backups_list = """$(for backup in "${backups[@]}"; do
    echo "$(basename "$backup")|$(file_date_iso "$backup")|$(file_size_bytes "$backup")|$(bytes_to_human $(file_size_bytes "$backup"))"
done)""".strip().split('\n')

for line in backups_list:
    if line and '|' in line:
        parts = line.split('|')
        if len(parts) >= 4:
            data["backups"].append({
                "file": parts[0],
                "date": parts[1],
                "size_bytes": int(parts[2]),
                "size_human": parts[3]
            })

# Add files list
files_raw = """$files_list""".strip().split('\n')
data["files_included"] = [f for f in files_raw if f]

# Output JSON
with open("$OUTPUT_FILE", "w") as f:
    json.dump(data, f, indent=2)

print(json.dumps(data, indent=2))
PYTHON_EOF
}

# Main
generate_json
