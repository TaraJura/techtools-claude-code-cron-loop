#!/bin/bash
# mirror-webroot.sh — back up the live PDF Editor web root into the git repo.
#
# Source of truth = the LIVE web root (option "b" in TASK-311). The autonomous
# agents keep editing /var/www/cronloop.techtools.cz/ directly; this script
# mirrors that tree (read-only on the source) into the repo-tracked web/ dir so
# the pipeline's auto-commit pushes the app code to GitHub every tick.
#
# This is a ONE-WAY mirror: LIVE -> repo. It NEVER writes to /var/www, so it
# cannot destabilize the live site. Do NOT add a repo -> live direction here
# (that would race the agents editing live). See docs/server-config.md.
#
# Usage: scripts/mirror-webroot.sh
# Exit 0 on success; non-zero on rsync failure (callers guard with || true so a
# mirror hiccup never aborts the pipeline commit).

set -euo pipefail

REPO_DIR="/home/novakj/techtools-claude-code-cron-loop"
LIVE_ROOT="/var/www/cronloop.techtools.cz/"
WEB_DIR="$REPO_DIR/web/"

if [ ! -d "$LIVE_ROOT" ]; then
    echo "mirror-webroot: live root $LIVE_ROOT not found — nothing to mirror" >&2
    exit 1
fi

mkdir -p "$WEB_DIR"

# -rlptD  : recurse, preserve symlinks/perms/times/devices (NOT owner/group —
#           repo files are owned by novakj; preserving www-data would warn).
# --delete: drop files in web/ that no longer exist live, so a restore is exact.
# Excludes keep the mirror clean of runtime/junk that .gitignore would drop anyway.
rsync -rlptD --delete \
    --exclude='*.bak' \
    --exclude='*.bak.*' \
    --exclude='*.swp' \
    --exclude='*.log' \
    "$LIVE_ROOT" "$WEB_DIR"

echo "mirror-webroot: synced $LIVE_ROOT -> $WEB_DIR"
