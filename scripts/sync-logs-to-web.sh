#!/bin/bash
# sync-logs-to-web.sh - Sync agent logs to web-accessible directory
# Copies recent log files to /var/www/cronloop.techtools.cz/logs/
# for safe web access

ACTORS_DIR="/home/novakj/actors"
WEB_LOGS_DIR="/var/www/cronloop.techtools.cz/logs"
AGENTS=("idea-maker" "project-manager" "developer" "tester" "security")

# Ensure web logs directory structure exists
for agent in "${AGENTS[@]}"; do
    mkdir -p "$WEB_LOGS_DIR/$agent"
done

# Sync recent logs (last 20 per agent)
for agent in "${AGENTS[@]}"; do
    src_dir="$ACTORS_DIR/$agent/logs"
    dst_dir="$WEB_LOGS_DIR/$agent"

    if [ -d "$src_dir" ]; then
        # Copy most recent 20 log files
        for log_file in $(ls -t "$src_dir"/*.log 2>/dev/null | head -20); do
            filename=$(basename "$log_file")
            # Copy with same name (we'll configure nginx to serve .log from this path)
            cp "$log_file" "$dst_dir/$filename" 2>/dev/null
        done

        # Clean up old files in web dir (keep only 20 newest)
        cd "$dst_dir"
        ls -t *.log 2>/dev/null | tail -n +21 | xargs -r rm
    fi
done

# Also update the logs index
/home/novakj/scripts/update-logs-index.sh > /var/www/cronloop.techtools.cz/api/logs-index.json 2>/dev/null

echo "Logs synced at $(date)"
