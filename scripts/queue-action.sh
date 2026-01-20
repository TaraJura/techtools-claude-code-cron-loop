#!/bin/bash
# Queue Action - Adds a quick action to the processing queue
# Part of CronLoop Quick Actions Panel (TASK-031)
#
# Usage: queue-action.sh <action_type>
# Action types: health_check, refresh_metrics, sync_logs, cleanup_logs, update_security, git_status

QUEUE_FILE="/var/www/cronloop.techtools.cz/api/action-queue.json"
STATUS_FILE="/var/www/cronloop.techtools.cz/api/action-status.json"
RATE_LIMIT_FILE="/tmp/action-rate-limit"

# Rate limiting: max 1 action per type per minute
check_rate_limit() {
    local action_type="$1"
    local now=$(date +%s)
    local limit_file="${RATE_LIMIT_FILE}_${action_type}"

    if [[ -f "$limit_file" ]]; then
        local last_time=$(cat "$limit_file")
        local diff=$((now - last_time))
        if [[ $diff -lt 60 ]]; then
            echo '{"success":false,"error":"Rate limited. Please wait 60 seconds between actions."}'
            return 1
        fi
    fi

    echo "$now" > "$limit_file"
    return 0
}

# Valid action types
VALID_ACTIONS="health_check refresh_metrics sync_logs cleanup_logs update_security git_status create_backup"

# Parse arguments
ACTION_TYPE="$1"

if [[ -z "$ACTION_TYPE" ]]; then
    echo '{"success":false,"error":"Missing action type"}'
    exit 1
fi

# Validate action type
if ! echo "$VALID_ACTIONS" | grep -qw "$ACTION_TYPE"; then
    echo '{"success":false,"error":"Invalid action type"}'
    exit 1
fi

# Check rate limit
if ! check_rate_limit "$ACTION_TYPE"; then
    exit 0
fi

# Generate unique ID
ACTION_ID="${ACTION_TYPE}_$(date +%s)_$$"
TIMESTAMP=$(date -Iseconds)

# Ensure queue file exists
if [[ ! -f "$QUEUE_FILE" ]]; then
    echo '{"actions":[]}' > "$QUEUE_FILE"
fi

# Add action to queue using Python for reliable JSON handling
python3 -c "
import json
import sys

queue_file = '$QUEUE_FILE'
action = {
    'id': '$ACTION_ID',
    'type': '$ACTION_TYPE',
    'status': 'pending',
    'queued_at': '$TIMESTAMP'
}

try:
    with open(queue_file, 'r') as f:
        data = json.load(f)
except:
    data = {'actions': []}

# Check if there's already a pending action of this type
for existing in data.get('actions', []):
    if existing.get('type') == '$ACTION_TYPE' and existing.get('status') == 'pending':
        print(json.dumps({'success': False, 'error': 'Action already queued'}))
        sys.exit(0)

data['actions'].append(action)

# Keep only last 50 actions in queue
if len(data['actions']) > 50:
    data['actions'] = data['actions'][-50:]

with open(queue_file, 'w') as f:
    json.dump(data, f, indent=2)

print(json.dumps({'success': True, 'action_id': '$ACTION_ID', 'message': 'Action queued'}))
"

# Also update status file to show pending
python3 -c "
import json

status_file = '$STATUS_FILE'

try:
    with open(status_file, 'r') as f:
        data = json.load(f)
except:
    data = {'last_processed': None, 'actions': {}}

data['actions']['$ACTION_ID'] = {
    'status': 'pending',
    'message': 'Queued for processing',
    'timestamp': '$TIMESTAMP'
}

with open(status_file, 'w') as f:
    json.dump(data, f, indent=2)
"
