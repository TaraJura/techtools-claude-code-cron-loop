#!/bin/bash
# Action Processor - Processes queued quick actions from the web dashboard
# Part of CronLoop Quick Actions Panel (TASK-031)

set -e

QUEUE_FILE="/var/www/cronloop.techtools.cz/api/action-queue.json"
STATUS_FILE="/var/www/cronloop.techtools.cz/api/action-status.json"
LOCK_FILE="/tmp/action-processor.lock"
LOG_DIR="/home/novakj/logs/actions"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Ensure files exist
if [[ ! -f "$QUEUE_FILE" ]]; then
    echo '{"actions":[]}' > "$QUEUE_FILE"
fi

if [[ ! -f "$STATUS_FILE" ]]; then
    echo '{"last_processed":null,"actions":{}}' > "$STATUS_FILE"
fi

# Lock to prevent concurrent processing
if [[ -f "$LOCK_FILE" ]]; then
    # Check if lock is stale (older than 5 minutes)
    if [[ $(find "$LOCK_FILE" -mmin +5 2>/dev/null) ]]; then
        rm -f "$LOCK_FILE"
    else
        exit 0  # Another instance is running
    fi
fi
trap "rm -f $LOCK_FILE" EXIT
touch "$LOCK_FILE"

# JSON helper: escape strings for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# Update action status
update_status() {
    local action_id="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date -Iseconds)

    python3 -c "
import json
import sys

try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {'last_processed': None, 'actions': {}}

data['last_processed'] = '$timestamp'
data['actions']['$action_id'] = {
    'status': '$status',
    'message': '''$(json_escape "$message")''',
    'timestamp': '$timestamp'
}

# Keep only last 20 action statuses
if len(data['actions']) > 20:
    sorted_actions = sorted(data['actions'].items(), key=lambda x: x[1].get('timestamp', ''), reverse=True)
    data['actions'] = dict(sorted_actions[:20])

with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

# Process a single action
process_action() {
    local action_id="$1"
    local action_type="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$LOG_DIR/${action_type}_${timestamp}.log"

    update_status "$action_id" "running" "Processing..."

    case "$action_type" in
        health_check)
            echo "Running health check..." > "$log_file"
            if /home/novakj/scripts/health-check.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Health check completed successfully"
            else
                update_status "$action_id" "error" "Health check failed - see logs"
            fi
            ;;

        refresh_metrics)
            echo "Refreshing system metrics..." > "$log_file"
            if /home/novakj/scripts/update-metrics.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Metrics refreshed"
            else
                update_status "$action_id" "error" "Metrics refresh failed"
            fi
            ;;

        sync_logs)
            echo "Syncing logs to web..." > "$log_file"
            if /home/novakj/scripts/sync-logs-to-web.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Logs synced successfully"
            else
                update_status "$action_id" "error" "Log sync failed"
            fi
            ;;

        cleanup_logs)
            echo "Cleaning up old logs..." > "$log_file"
            # Delete logs older than 7 days (safe operation)
            local count=$(find /home/novakj/actors/*/logs/ -name "*.log" -mtime +7 2>/dev/null | wc -l)
            find /home/novakj/actors/*/logs/ -name "*.log" -mtime +7 -delete >> "$log_file" 2>&1
            update_status "$action_id" "completed" "Cleaned up $count old log files"
            ;;

        update_security)
            echo "Updating security metrics..." > "$log_file"
            if sudo /home/novakj/scripts/security-metrics.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Security metrics updated"
            else
                update_status "$action_id" "error" "Security metrics update failed"
            fi
            ;;

        config_drift)
            echo "Checking configuration drift..." > "$log_file"
            if /home/novakj/scripts/config-drift.sh check >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Config drift check completed"
            else
                update_status "$action_id" "error" "Config drift check failed"
            fi
            ;;

        update_timeline)
            echo "Updating agent timeline..." > "$log_file"
            if /home/novakj/scripts/update-timeline.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Timeline data updated"
            else
                update_status "$action_id" "error" "Timeline update failed"
            fi
            ;;

        detect_anomalies)
            echo "Running anomaly detection..." > "$log_file"
            if /home/novakj/scripts/update-anomalies.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Anomaly detection completed"
            else
                update_status "$action_id" "error" "Anomaly detection failed"
            fi
            ;;

        evaluate_alerts)
            echo "Evaluating alert rules..." > "$log_file"
            if /home/novakj/scripts/evaluate-alerts.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Alert evaluation completed"
            else
                update_status "$action_id" "error" "Alert evaluation failed"
            fi
            ;;

        update_decisions)
            echo "Updating AI decision analysis..." > "$log_file"
            if /home/novakj/scripts/update-decisions.sh >> "$log_file" 2>&1; then
                update_status "$action_id" "completed" "Decision analysis completed"
            else
                update_status "$action_id" "error" "Decision analysis failed"
            fi
            ;;

        git_status)
            echo "Checking git status..." > "$log_file"
            cd /home/novakj
            git status >> "$log_file" 2>&1
            git log --oneline -5 >> "$log_file" 2>&1
            update_status "$action_id" "completed" "Git status retrieved"
            ;;

        create_backup)
            echo "Creating configuration backup..." > "$log_file"
            if /home/novakj/projects/config-backup.sh >> "$log_file" 2>&1; then
                # Refresh backup status JSON
                /home/novakj/scripts/backup-status.sh >> "$log_file" 2>&1
                update_status "$action_id" "completed" "Backup created successfully"
            else
                update_status "$action_id" "error" "Backup creation failed - see logs"
            fi
            ;;

        *)
            update_status "$action_id" "error" "Unknown action type: $action_type"
            return 1
            ;;
    esac
}

# Process queue
process_queue() {
    # Read pending actions
    local pending=$(python3 -c "
import json
try:
    with open('$QUEUE_FILE', 'r') as f:
        data = json.load(f)
    for action in data.get('actions', []):
        if action.get('status') == 'pending':
            print(f\"{action['id']}|{action['type']}\")
except Exception as e:
    pass
")

    if [[ -z "$pending" ]]; then
        exit 0  # No pending actions
    fi

    # Process each pending action
    while IFS='|' read -r action_id action_type; do
        if [[ -n "$action_id" ]]; then
            # Mark as processing in queue
            python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    data = json.load(f)
for action in data['actions']:
    if action['id'] == '$action_id':
        action['status'] = 'processing'
        break
with open('$QUEUE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
            # Process the action
            process_action "$action_id" "$action_type"

            # Remove from queue
            python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    data = json.load(f)
data['actions'] = [a for a in data['actions'] if a['id'] != '$action_id']
with open('$QUEUE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
        fi
    done <<< "$pending"
}

# Run the processor
process_queue
