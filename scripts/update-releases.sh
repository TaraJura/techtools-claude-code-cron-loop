#!/bin/bash
# update-releases.sh - Generate deployment/release timeline data
# Parses git history to track releases, feature grouping, and deployment velocity

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/releases.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get current directory (git repo root)
REPO_DIR="/home/novakj"
cd "$REPO_DIR" || exit 1

# Date ranges
now=$(date +%s)
seven_days_ago=$((now - 7*24*60*60))
thirty_days_ago=$((now - 30*24*60*60))

# Initialize arrays for JSON building
declare -a releases_json
declare -A daily_commits
declare -A task_commits
declare -A category_counts

total_commits=0
total_tasks=0
commits_7d=0
commits_30d=0
tasks_7d=0

# Get first commit date
first_commit_date=$(git log --reverse --format="%ci" | head -1 | cut -d' ' -f1)

# Parse git log for releases (group by date)
while IFS='|' read -r hash date author subject; do
    [[ -z "$hash" ]] && continue

    # Clean up date to get YYYY-MM-DD
    day=$(echo "$date" | cut -d' ' -f1)
    timestamp=$(date -d "$date" +%s 2>/dev/null || echo "0")

    # Count totals
    total_commits=$((total_commits + 1))

    # Track daily commits
    daily_commits[$day]=$((${daily_commits[$day]:-0} + 1))

    # Check if within 7 or 30 days
    if [[ $timestamp -ge $seven_days_ago ]]; then
        commits_7d=$((commits_7d + 1))
    fi
    if [[ $timestamp -ge $thirty_days_ago ]]; then
        commits_30d=$((commits_30d + 1))
    fi

    # Extract TASK-XXX if present
    if [[ $subject =~ TASK-([0-9]+) ]]; then
        task_id="TASK-${BASH_REMATCH[1]}"
        task_commits[$task_id]=1
        total_tasks=$((total_tasks + 1))
        if [[ $timestamp -ge $seven_days_ago ]]; then
            tasks_7d=$((tasks_7d + 1))
        fi
    fi

    # Categorize changes
    if [[ $subject =~ [Ff]ix|[Bb]ug|[Ee]rror ]]; then
        category_counts["fixes"]=$((${category_counts["fixes"]:-0} + 1))
    elif [[ $subject =~ [Aa]dd|[Cc]reate|[Nn]ew|[Ii]mplement ]]; then
        category_counts["features"]=$((${category_counts["features"]:-0} + 1))
    elif [[ $subject =~ [Uu]pdate|[Rr]efactor|[Ii]mprove ]]; then
        category_counts["improvements"]=$((${category_counts["improvements"]:-0} + 1))
    elif [[ $subject =~ [Ss]ecurity|[Aa]udit ]]; then
        category_counts["security"]=$((${category_counts["security"]:-0} + 1))
    elif [[ $subject =~ [Tt]est|[Vv]erify ]]; then
        category_counts["testing"]=$((${category_counts["testing"]:-0} + 1))
    else
        category_counts["other"]=$((${category_counts["other"]:-0} + 1))
    fi

done < <(git log --format="%H|%ci|%an|%s" --since="90 days ago")

# Get git tags (releases)
declare -a tags_json
while IFS='|' read -r tag date; do
    [[ -z "$tag" ]] && continue
    tags_json+=("{\"tag\": \"$tag\", \"date\": \"$date\"}")
done < <(git tag --format='%(refname:short)|%(creatordate:short)' --sort=-version:refname 2>/dev/null || echo "")

# Build daily activity for last 30 days
declare -a daily_activity_json
for i in $(seq 29 -1 0); do
    day=$(date -d "$i days ago" +%Y-%m-%d)
    count=${daily_commits[$day]:-0}
    daily_activity_json+=("{\"date\": \"$day\", \"commits\": $count}")
done

# Get recent commits for timeline (last 50)
declare -a recent_commits_json
while IFS='|' read -r hash date author subject; do
    [[ -z "$hash" ]] && continue

    # Extract agent from subject [agent-name]
    agent=""
    if [[ $subject =~ ^\[([^\]]+)\] ]]; then
        agent="${BASH_REMATCH[1]}"
    fi

    # Extract task ID if present
    task=""
    if [[ $subject =~ (TASK-[0-9]+) ]]; then
        task="${BASH_REMATCH[1]}"
    fi

    # Get files changed count
    files_changed=$(git diff-tree --no-commit-id --name-only -r "$hash" 2>/dev/null | wc -l)

    # Categorize
    category="other"
    if [[ $subject =~ [Ff]ix|[Bb]ug|[Ee]rror ]]; then
        category="fix"
    elif [[ $subject =~ [Aa]dd|[Cc]reate|[Nn]ew|[Ii]mplement ]]; then
        category="feature"
    elif [[ $subject =~ [Uu]pdate|[Rr]efactor|[Ii]mprove ]]; then
        category="improvement"
    elif [[ $subject =~ [Ss]ecurity|[Aa]udit ]]; then
        category="security"
    elif [[ $subject =~ [Tt]est|[Vv]erify ]]; then
        category="testing"
    fi

    # Escape subject for JSON
    subject_escaped=$(echo "$subject" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | tr -d '\n')

    recent_commits_json+=("{\"hash\": \"${hash:0:7}\", \"full_hash\": \"$hash\", \"date\": \"$date\", \"author\": \"$agent\", \"subject\": \"$subject_escaped\", \"task\": \"$task\", \"category\": \"$category\", \"files_changed\": $files_changed}")

done < <(git log --format="%H|%ci|%an|%s" -50)

# Get unreleased changes (commits since last tag or all if no tags)
last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$last_tag" ]]; then
    unreleased_count=$(git rev-list "$last_tag"..HEAD --count)
else
    unreleased_count=$total_commits
fi

# Calculate velocity metrics
avg_commits_per_day=0
if [[ $commits_30d -gt 0 ]]; then
    avg_commits_per_day=$((commits_30d / 30))
fi

days_active=$(echo "${!daily_commits[@]}" | tr ' ' '\n' | wc -l)

# Get commit heatmap by hour
declare -A hourly_commits
while read -r hour; do
    [[ -z "$hour" ]] && continue
    hourly_commits[$hour]=$((${hourly_commits[$hour]:-0} + 1))
done < <(git log --format="%ci" --since="30 days ago" | cut -d' ' -f2 | cut -d':' -f1)

# Build JSON output
{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"summary\": {"
    echo "    \"total_commits\": $total_commits,"
    echo "    \"total_tasks_completed\": ${#task_commits[@]},"
    echo "    \"commits_7d\": $commits_7d,"
    echo "    \"commits_30d\": $commits_30d,"
    echo "    \"tasks_7d\": $tasks_7d,"
    echo "    \"unreleased_count\": $unreleased_count,"
    echo "    \"avg_commits_per_day\": $avg_commits_per_day,"
    echo "    \"days_active\": $days_active,"
    echo "    \"first_commit\": \"$first_commit_date\""
    echo "  },"

    # Tags/releases
    echo "  \"tags\": ["
    first=true
    for tag_json in "${tags_json[@]}"; do
        [[ $first == true ]] && first=false || echo ","
        echo -n "    $tag_json"
    done
    echo ""
    echo "  ],"

    # Category breakdown
    echo "  \"categories\": {"
    echo "    \"features\": ${category_counts["features"]:-0},"
    echo "    \"fixes\": ${category_counts["fixes"]:-0},"
    echo "    \"improvements\": ${category_counts["improvements"]:-0},"
    echo "    \"security\": ${category_counts["security"]:-0},"
    echo "    \"testing\": ${category_counts["testing"]:-0},"
    echo "    \"other\": ${category_counts["other"]:-0}"
    echo "  },"

    # Daily activity
    echo "  \"daily_activity\": ["
    first=true
    for day_json in "${daily_activity_json[@]}"; do
        [[ $first == true ]] && first=false || echo ","
        echo -n "    $day_json"
    done
    echo ""
    echo "  ],"

    # Hourly distribution
    echo "  \"hourly_distribution\": {"
    first=true
    for hour in $(echo "${!hourly_commits[@]}" | tr ' ' '\n' | sort -n); do
        [[ $first == true ]] && first=false || echo ","
        echo -n "    \"$hour\": ${hourly_commits[$hour]}"
    done
    echo ""
    echo "  },"

    # Recent commits
    echo "  \"recent_commits\": ["
    first=true
    for commit_json in "${recent_commits_json[@]}"; do
        [[ $first == true ]] && first=false || echo ","
        echo -n "    $commit_json"
    done
    echo ""
    echo "  ]"

    echo "}"
} > "$OUTPUT_FILE"

echo "Releases data updated: $OUTPUT_FILE"
