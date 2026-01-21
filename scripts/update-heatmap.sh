#!/bin/bash
# update-heatmap.sh - Generate file change heatmap data from git history
# Parses git log to count commits per file/directory over configurable time periods

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/heatmap.json"
REPO_DIR="/home/novakj"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cd "$REPO_DIR" || exit 1

# Calculate date thresholds
SEVEN_DAYS_AGO=$(date -d "7 days ago" +"%Y-%m-%d")
THIRTY_DAYS_AGO=$(date -d "30 days ago" +"%Y-%m-%d")

# Temporary files for processing
TMP_7D=$(mktemp)
TMP_30D=$(mktemp)
TMP_ALL=$(mktemp)
TMP_AGENTS=$(mktemp)

# Get file changes for different time periods
git log --since="$SEVEN_DAYS_AGO" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -100 > "$TMP_7D"
git log --since="$THIRTY_DAYS_AGO" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -150 > "$TMP_30D"
git log --name-only --pretty=format: | sort | uniq -c | sort -rn | head -200 > "$TMP_ALL"

# Count commits by agent (from commit messages containing [agent-name])
for agent in idea-maker project-manager developer developer2 tester security supervisor; do
    count=$(git log --grep="\[$agent\]" --oneline 2>/dev/null | wc -l)
    echo "$agent $count" >> "$TMP_AGENTS"
done

# Count total files tracked
TOTAL_FILES=$(git ls-files | wc -l)
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")

# Get directory-level aggregation (top modified directories)
declare -A dir_counts_7d
declare -A dir_counts_30d
declare -A dir_counts_all

# Process 7-day data
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    dir=$(dirname "$filepath")
    [[ "$dir" == "." ]] && dir="root"
    dir_counts_7d[$dir]=$((${dir_counts_7d[$dir]:-0} + count))
done < "$TMP_7D"

# Process 30-day data
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    dir=$(dirname "$filepath")
    [[ "$dir" == "." ]] && dir="root"
    dir_counts_30d[$dir]=$((${dir_counts_30d[$dir]:-0} + count))
done < "$TMP_30D"

# Process all-time data
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    dir=$(dirname "$filepath")
    [[ "$dir" == "." ]] && dir="root"
    dir_counts_all[$dir]=$((${dir_counts_all[$dir]:-0} + count))
done < "$TMP_ALL"

# Calculate churn rate (files changed in last 7 days / total files)
FILES_CHANGED_7D=$(wc -l < "$TMP_7D")
CHURN_RATE=$(echo "scale=2; $FILES_CHANGED_7D * 100 / $TOTAL_FILES" | bc 2>/dev/null || echo "0")

# Identify protected core files and their change counts
CORE_FILES=("CLAUDE.md" "tasks.md" "scripts/cron-orchestrator.sh" "scripts/run-actor.sh")
core_file_changes=""
for cf in "${CORE_FILES[@]}"; do
    count=$(git log --oneline -- "$cf" 2>/dev/null | wc -l)
    core_file_changes="$core_file_changes{\"file\":\"$cf\",\"commits\":$count},"
done
core_file_changes="${core_file_changes%,}"

# Build JSON arrays
# Top files (7 days)
files_7d_json=""
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')
    files_7d_json="$files_7d_json{\"path\":\"$filepath_escaped\",\"commits\":$count},"
done < "$TMP_7D"
files_7d_json="${files_7d_json%,}"

# Top files (30 days)
files_30d_json=""
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')
    files_30d_json="$files_30d_json{\"path\":\"$filepath_escaped\",\"commits\":$count},"
done < "$TMP_30D"
files_30d_json="${files_30d_json%,}"

# Top files (all time)
files_all_json=""
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')
    files_all_json="$files_all_json{\"path\":\"$filepath_escaped\",\"commits\":$count},"
done < "$TMP_ALL"
files_all_json="${files_all_json%,}"

# Top directories (30 days)
dirs_30d_json=""
for dir in "${!dir_counts_30d[@]}"; do
    count=${dir_counts_30d[$dir]}
    dir_escaped=$(echo "$dir" | sed 's/"/\\"/g')
    dirs_30d_json="$dirs_30d_json{\"path\":\"$dir_escaped\",\"commits\":$count},"
done
dirs_30d_json="${dirs_30d_json%,}"

# Top directories (all time)
dirs_all_json=""
for dir in "${!dir_counts_all[@]}"; do
    count=${dir_counts_all[$dir]}
    dir_escaped=$(echo "$dir" | sed 's/"/\\"/g')
    dirs_all_json="$dirs_all_json{\"path\":\"$dir_escaped\",\"commits\":$count},"
done
dirs_all_json="${dirs_all_json%,}"

# Agent commit counts
agent_commits_json=""
while read -r agent count; do
    agent_commits_json="$agent_commits_json{\"agent\":\"$agent\",\"commits\":$count},"
done < "$TMP_AGENTS"
agent_commits_json="${agent_commits_json%,}"

# File type breakdown (last 30 days)
declare -A type_counts
while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    ext="${filepath##*.}"
    [[ "$ext" == "$filepath" ]] && ext="no-ext"
    type_counts[$ext]=$((${type_counts[$ext]:-0} + count))
done < "$TMP_30D"

file_types_json=""
for ext in "${!type_counts[@]}"; do
    count=${type_counts[$ext]}
    file_types_json="$file_types_json{\"type\":\".$ext\",\"commits\":$count},"
done
file_types_json="${file_types_json%,}"

# Recent daily activity (last 7 days)
daily_activity_json=""
for i in {6..0}; do
    day=$(date -d "$i days ago" +"%Y-%m-%d")
    count=$(git log --since="$day 00:00:00" --until="$day 23:59:59" --oneline 2>/dev/null | wc -l)
    daily_activity_json="$daily_activity_json{\"date\":\"$day\",\"commits\":$count},"
done
daily_activity_json="${daily_activity_json%,}"

# Cold zones: files not modified in 30+ days but still tracked
cold_files_json=""
cold_count=0
while read -r filepath; do
    [[ -z "$filepath" ]] && continue
    last_commit=$(git log -1 --format="%ci" -- "$filepath" 2>/dev/null | cut -d' ' -f1)
    if [[ -n "$last_commit" ]] && [[ "$last_commit" < "$THIRTY_DAYS_AGO" ]]; then
        filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')
        if [[ $cold_count -lt 20 ]]; then
            cold_files_json="$cold_files_json{\"path\":\"$filepath_escaped\",\"last_modified\":\"$last_commit\"},"
            cold_count=$((cold_count + 1))
        fi
    fi
done < <(git ls-files)
cold_files_json="${cold_files_json%,}"

# Cleanup
rm -f "$TMP_7D" "$TMP_30D" "$TMP_ALL" "$TMP_AGENTS"

# Write JSON output
cat > "$OUTPUT_FILE" << EOF
{
    "timestamp": "$TIMESTAMP",
    "summary": {
        "total_files": $TOTAL_FILES,
        "total_commits": $TOTAL_COMMITS,
        "files_changed_7d": $FILES_CHANGED_7D,
        "churn_rate_percent": $CHURN_RATE
    },
    "hot_files": {
        "7_days": [$files_7d_json],
        "30_days": [$files_30d_json],
        "all_time": [$files_all_json]
    },
    "hot_directories": {
        "30_days": [$dirs_30d_json],
        "all_time": [$dirs_all_json]
    },
    "agent_commits": [$agent_commits_json],
    "file_types": [$file_types_json],
    "daily_activity": [$daily_activity_json],
    "core_files": [$core_file_changes],
    "cold_zones": [$cold_files_json]
}
EOF

echo "Heatmap data updated: $OUTPUT_FILE"
