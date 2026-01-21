#!/bin/bash
# Generate git repository health data for the Git Health Dashboard
# This script analyzes the local git repository and creates /api/git-health.json

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/git-health.json"
REPO_DIR="/home/novakj"

cd "$REPO_DIR" || exit 1

echo "Analyzing git repository health..."

# Get current timestamp
TIMESTAMP=$(date -Iseconds)

# Current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached HEAD")

# Check if HEAD is detached
DETACHED_HEAD=false
if [[ "$CURRENT_BRANCH" == "" ]]; then
    DETACHED_HEAD=true
    CURRENT_BRANCH="(detached HEAD)"
fi

# Tracking status
TRACKING_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none")

# Remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "none")

# Get uncommitted changes
STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l)
UNSTAGED_COUNT=$(git diff --name-only 2>/dev/null | wc -l)
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

# Get unpushed commits
AHEAD_COUNT=0
BEHIND_COUNT=0
if [[ "$TRACKING_BRANCH" != "none" ]]; then
    AHEAD_COUNT=$(git rev-list --count HEAD ^@{upstream} 2>/dev/null || echo 0)
    BEHIND_COUNT=$(git rev-list --count @{upstream} ^HEAD 2>/dev/null || echo 0)
fi

# Check for merge conflicts
MERGE_CONFLICTS=$(git ls-files -u 2>/dev/null | wc -l)
HAS_CONFLICTS=false
[[ $MERGE_CONFLICTS -gt 0 ]] && HAS_CONFLICTS=true

# Repository size
REPO_SIZE=$(du -sb "$REPO_DIR/.git" 2>/dev/null | cut -f1 || echo 0)

# Count total commits
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)

# Count total branches
LOCAL_BRANCHES=$(git branch 2>/dev/null | wc -l)
REMOTE_BRANCHES=$(git branch -r 2>/dev/null | wc -l)

# Last commit info
LAST_COMMIT_DATE=$(git log -1 --format=%ci 2>/dev/null || echo "unknown")
LAST_COMMIT_AUTHOR=$(git log -1 --format=%an 2>/dev/null || echo "unknown")
LAST_COMMIT_MESSAGE=$(git log -1 --format=%s 2>/dev/null || echo "unknown")
LAST_COMMIT_HASH=$(git log -1 --format=%h 2>/dev/null || echo "unknown")

# Calculate days since last commit
LAST_COMMIT_EPOCH=$(git log -1 --format=%ct 2>/dev/null || echo 0)
NOW_EPOCH=$(date +%s)
DAYS_SINCE_COMMIT=$(( (NOW_EPOCH - LAST_COMMIT_EPOCH) / 86400 ))

# Get stash count
STASH_COUNT=$(git stash list 2>/dev/null | wc -l)

# Build stale branches list (merged or older than 30 days)
STALE_BRANCHES_JSON="["
FIRST_STALE=true

# Check for merged branches (excluding current and main/master)
for branch in $(git branch --merged HEAD 2>/dev/null | grep -v "^\*" | grep -v "main" | grep -v "master" | head -10); do
    branch=$(echo "$branch" | tr -d ' ')
    [[ -z "$branch" ]] && continue

    last_commit=$(git log -1 --format=%ci "$branch" 2>/dev/null || echo "unknown")

    if [[ "$FIRST_STALE" == "true" ]]; then
        FIRST_STALE=false
    else
        STALE_BRANCHES_JSON+=","
    fi
    STALE_BRANCHES_JSON+="{\"name\":\"$branch\",\"reason\":\"merged\",\"lastCommit\":\"$last_commit\"}"
done

# Check for old branches (> 30 days without commits)
for branch in $(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads 2>/dev/null | head -20); do
    [[ "$branch" == "$CURRENT_BRANCH" ]] && continue
    [[ "$branch" == "main" || "$branch" == "master" ]] && continue

    branch_epoch=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo 0)
    days_old=$(( (NOW_EPOCH - branch_epoch) / 86400 ))

    if [[ $days_old -gt 30 ]]; then
        last_commit=$(git log -1 --format=%ci "$branch" 2>/dev/null || echo "unknown")

        if [[ "$FIRST_STALE" == "true" ]]; then
            FIRST_STALE=false
        else
            STALE_BRANCHES_JSON+=","
        fi
        STALE_BRANCHES_JSON+="{\"name\":\"$branch\",\"reason\":\"inactive (${days_old} days)\",\"lastCommit\":\"$last_commit\"}"
    fi
done

STALE_BRANCHES_JSON+="]"

# Build large files list (files larger than 500KB in working tree)
LARGE_FILES_JSON="["
FIRST_LARGE=true

# Find large files in the current working tree (more reliable than blob scanning)
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    size=$(echo "$line" | awk '{print $1}')
    filepath=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
    [[ -z "$filepath" ]] && continue

    if [[ "$FIRST_LARGE" == "true" ]]; then
        FIRST_LARGE=false
    else
        LARGE_FILES_JSON+=","
    fi
    # Escape the filepath for JSON
    filepath_escaped=$(echo "$filepath" | sed 's/"/\\"/g')
    LARGE_FILES_JSON+="{\"path\":\"$filepath_escaped\",\"size\":$size}"
done < <(find "$REPO_DIR" -type f -size +512k ! -path "*/.git/*" -printf '%s %p\n' 2>/dev/null | sort -rn | head -10)

LARGE_FILES_JSON+="]"

# Build uncommitted changes list
UNCOMMITTED_JSON="["
FIRST_UNCOMMITTED=true

# Staged changes
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$FIRST_UNCOMMITTED" == "true" ]]; then
        FIRST_UNCOMMITTED=false
    else
        UNCOMMITTED_JSON+=","
    fi
    # Escape quotes in filename
    file_escaped=$(echo "$file" | sed 's/"/\\"/g')
    UNCOMMITTED_JSON+="{\"file\":\"$file_escaped\",\"status\":\"staged\"}"
done < <(git diff --cached --name-only 2>/dev/null | head -20)

# Unstaged changes
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$FIRST_UNCOMMITTED" == "true" ]]; then
        FIRST_UNCOMMITTED=false
    else
        UNCOMMITTED_JSON+=","
    fi
    file_escaped=$(echo "$file" | sed 's/"/\\"/g')
    UNCOMMITTED_JSON+="{\"file\":\"$file_escaped\",\"status\":\"modified\"}"
done < <(git diff --name-only 2>/dev/null | head -20)

# Untracked files
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$FIRST_UNCOMMITTED" == "true" ]]; then
        FIRST_UNCOMMITTED=false
    else
        UNCOMMITTED_JSON+=","
    fi
    file_escaped=$(echo "$file" | sed 's/"/\\"/g')
    UNCOMMITTED_JSON+="{\"file\":\"$file_escaped\",\"status\":\"untracked\"}"
done < <(git ls-files --others --exclude-standard 2>/dev/null | head -20)

UNCOMMITTED_JSON+="]"

# Build recent commits list
RECENT_COMMITS_JSON="["
FIRST_COMMIT=true

while IFS=$'\t' read -r hash author date subject; do
    [[ -z "$hash" ]] && continue
    if [[ "$FIRST_COMMIT" == "true" ]]; then
        FIRST_COMMIT=false
    else
        RECENT_COMMITS_JSON+=","
    fi
    # Escape quotes
    subject_escaped=$(echo "$subject" | sed 's/"/\\"/g')
    author_escaped=$(echo "$author" | sed 's/"/\\"/g')
    RECENT_COMMITS_JSON+="{\"hash\":\"$hash\",\"author\":\"$author_escaped\",\"date\":\"$date\",\"subject\":\"$subject_escaped\"}"
done < <(git log --format="%h%x09%an%x09%ci%x09%s" -15 2>/dev/null)

RECENT_COMMITS_JSON+="]"

# Generate warnings
WARNINGS_JSON="["
FIRST_WARNING=true

add_warning() {
    local severity="$1"
    local title="$2"
    local desc="$3"

    if [[ "$FIRST_WARNING" == "true" ]]; then
        FIRST_WARNING=false
    else
        WARNINGS_JSON+=","
    fi
    WARNINGS_JSON+="{\"severity\":\"$severity\",\"title\":\"$title\",\"description\":\"$desc\"}"
}

# Check for various issues
if [[ "$DETACHED_HEAD" == "true" ]]; then
    add_warning "error" "Detached HEAD" "Repository is in detached HEAD state. Consider checking out a branch."
fi

if [[ $MERGE_CONFLICTS -gt 0 ]]; then
    add_warning "error" "Merge Conflicts" "There are $MERGE_CONFLICTS unresolved merge conflicts."
fi

total_uncommitted=$((STAGED_COUNT + UNSTAGED_COUNT + UNTRACKED_COUNT))
if [[ $total_uncommitted -gt 20 ]]; then
    add_warning "warning" "Many Uncommitted Changes" "$total_uncommitted uncommitted files. Consider committing or stashing changes."
elif [[ $total_uncommitted -gt 5 ]]; then
    add_warning "info" "Uncommitted Changes" "$total_uncommitted uncommitted files."
fi

if [[ $DAYS_SINCE_COMMIT -gt 7 ]]; then
    add_warning "warning" "Stale Repository" "No commits in $DAYS_SINCE_COMMIT days."
fi

if [[ $AHEAD_COUNT -gt 10 ]]; then
    add_warning "warning" "Many Unpushed Commits" "$AHEAD_COUNT commits ahead of remote. Consider pushing."
elif [[ $AHEAD_COUNT -gt 0 ]]; then
    add_warning "info" "Unpushed Commits" "$AHEAD_COUNT commit(s) ahead of remote."
fi

if [[ $BEHIND_COUNT -gt 0 ]]; then
    add_warning "warning" "Behind Remote" "$BEHIND_COUNT commit(s) behind remote. Consider pulling."
fi

if [[ $STASH_COUNT -gt 5 ]]; then
    add_warning "info" "Stash Buildup" "$STASH_COUNT stashed changes. Consider cleaning up old stashes."
fi

WARNINGS_JSON+="]"

# Calculate health score (0-100)
HEALTH_SCORE=100

# Deductions
[[ "$DETACHED_HEAD" == "true" ]] && HEALTH_SCORE=$((HEALTH_SCORE - 20))
[[ $MERGE_CONFLICTS -gt 0 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 30))
[[ $total_uncommitted -gt 20 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 15))
[[ $total_uncommitted -gt 5 && $total_uncommitted -le 20 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 5))
[[ $DAYS_SINCE_COMMIT -gt 7 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 10))
[[ $AHEAD_COUNT -gt 10 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 10))
[[ $BEHIND_COUNT -gt 5 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 10))

[[ $HEALTH_SCORE -lt 0 ]] && HEALTH_SCORE=0

# Determine health status
if [[ $HEALTH_SCORE -ge 80 ]]; then
    HEALTH_STATUS="healthy"
elif [[ $HEALTH_SCORE -ge 50 ]]; then
    HEALTH_STATUS="warning"
else
    HEALTH_STATUS="critical"
fi

# Build final JSON
cat > "$OUTPUT_FILE" << EOF
{
    "generated": "$TIMESTAMP",
    "healthScore": $HEALTH_SCORE,
    "healthStatus": "$HEALTH_STATUS",
    "branch": {
        "current": "$CURRENT_BRANCH",
        "tracking": "$TRACKING_BRANCH",
        "detached": $DETACHED_HEAD,
        "localCount": $LOCAL_BRANCHES,
        "remoteCount": $REMOTE_BRANCHES
    },
    "remote": {
        "url": "$REMOTE_URL",
        "ahead": $AHEAD_COUNT,
        "behind": $BEHIND_COUNT
    },
    "changes": {
        "staged": $STAGED_COUNT,
        "unstaged": $UNSTAGED_COUNT,
        "untracked": $UNTRACKED_COUNT,
        "conflicts": $MERGE_CONFLICTS,
        "hasConflicts": $HAS_CONFLICTS,
        "stashCount": $STASH_COUNT
    },
    "uncommittedFiles": $UNCOMMITTED_JSON,
    "lastCommit": {
        "hash": "$LAST_COMMIT_HASH",
        "author": "$LAST_COMMIT_AUTHOR",
        "date": "$LAST_COMMIT_DATE",
        "message": "$(echo "$LAST_COMMIT_MESSAGE" | sed 's/"/\\"/g')",
        "daysAgo": $DAYS_SINCE_COMMIT
    },
    "repository": {
        "size": $REPO_SIZE,
        "totalCommits": $TOTAL_COMMITS
    },
    "staleBranches": $STALE_BRANCHES_JSON,
    "largeFiles": $LARGE_FILES_JSON,
    "recentCommits": $RECENT_COMMITS_JSON,
    "warnings": $WARNINGS_JSON
}
EOF

echo "Git health data generated at $OUTPUT_FILE"
echo "Health Score: $HEALTH_SCORE ($HEALTH_STATUS)"
