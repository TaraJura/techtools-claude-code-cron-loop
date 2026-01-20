#!/bin/bash
# send-webhooks.sh - Send webhook notifications to configured endpoints
# Part of CronLoop Webhook Notifications Hub (TASK-056)
#
# Usage:
#   ./send-webhooks.sh <event_type> [payload_json]
#
# Event types:
#   - agent_error      : When any agent fails during execution
#   - security_alert   : High SSH attack attempts or new attackers
#   - resource_warning : Memory or disk usage exceeds 80%
#   - task_completed   : When a task reaches VERIFIED status
#   - orchestrator_complete : When full agent pipeline finishes

set -e

WEBHOOKS_FILE="/var/www/cronloop.techtools.cz/api/webhooks.json"
RATE_LIMIT_DIR="/tmp/cronloop-webhooks"
LOG_FILE="/home/novakj/logs/webhooks.log"

# Create directories
mkdir -p "$RATE_LIMIT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

# Check rate limit (1 notification per event type per 5 minutes)
check_rate_limit() {
    local event_type="$1"
    local webhook_id="$2"
    local rate_limit_file="$RATE_LIMIT_DIR/${webhook_id}_${event_type}"

    if [[ -f "$rate_limit_file" ]]; then
        local last_sent=$(cat "$rate_limit_file")
        local now=$(date +%s)
        local diff=$((now - last_sent))

        # 5 minutes = 300 seconds
        if [[ $diff -lt 300 ]]; then
            log "Rate limited: $webhook_id for $event_type (${diff}s since last)"
            return 1
        fi
    fi

    # Update rate limit timestamp
    date +%s > "$rate_limit_file"
    return 0
}

# Format Slack payload
format_slack_payload() {
    local event_type="$1"
    local payload="$2"

    local emoji=""
    local text=""

    case "$event_type" in
        agent_error)
            emoji=":x:"
            local agent=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('agent', 'unknown'))" 2>/dev/null || echo "unknown")
            local error=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
            text="${emoji} *CronLoop Alert*\nAgent *${agent}* failed: ${error}"
            ;;
        security_alert)
            emoji=":rotating_light:"
            local attempts=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total_attempts', 0))" 2>/dev/null || echo "0")
            local attackers=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('unique_attackers', 0))" 2>/dev/null || echo "0")
            text="${emoji} *CronLoop Security Alert*\n${attempts} SSH attempts from ${attackers} unique attackers"
            ;;
        resource_warning)
            emoji=":warning:"
            local resource=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('resource', 'unknown'))" 2>/dev/null || echo "unknown")
            local value=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_value', 0))" 2>/dev/null || echo "0")
            text="${emoji} *CronLoop Resource Warning*\n${resource} usage at ${value}%"
            ;;
        task_completed)
            emoji=":white_check_mark:"
            local task_id=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('task_id', 'TASK-XXX'))" 2>/dev/null || echo "TASK-XXX")
            local title=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('title', 'Unknown task'))" 2>/dev/null || echo "Unknown task")
            text="${emoji} *CronLoop Task Completed*\n${task_id}: ${title}"
            ;;
        orchestrator_complete)
            emoji=":robot_face:"
            local duration=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('duration_seconds', 0))" 2>/dev/null || echo "0")
            local errors=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('errors', 0))" 2>/dev/null || echo "0")
            text="${emoji} *CronLoop Pipeline Complete*\nCompleted in ${duration}s with ${errors} errors"
            ;;
        *)
            emoji=":bell:"
            text="${emoji} *CronLoop Notification*\n$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', 'Notification'))" 2>/dev/null || echo "Notification")"
            ;;
    esac

    text="${text}\n<https://cronloop.techtools.cz|View Dashboard>"

    # Return JSON payload
    python3 -c "import json; print(json.dumps({'text': '''$text''', 'unfurl_links': False}))"
}

# Format Discord payload
format_discord_payload() {
    local event_type="$1"
    local payload="$2"

    local color=3447003  # Default blue
    local title=""
    local description=""

    case "$event_type" in
        agent_error)
            color=15548997  # Red
            title="Agent Error"
            local agent=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('agent', 'unknown'))" 2>/dev/null || echo "unknown")
            local error=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
            description="**${agent}** failed: ${error}"
            ;;
        security_alert)
            color=16744192  # Orange
            title="Security Alert"
            local attempts=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total_attempts', 0))" 2>/dev/null || echo "0")
            local attackers=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('unique_attackers', 0))" 2>/dev/null || echo "0")
            description="${attempts} SSH attempts from ${attackers} unique attackers"
            ;;
        resource_warning)
            color=16763904  # Yellow
            title="Resource Warning"
            local resource=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('resource', 'unknown'))" 2>/dev/null || echo "unknown")
            local value=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_value', 0))" 2>/dev/null || echo "0")
            description="${resource} usage at ${value}%"
            ;;
        task_completed)
            color=2067276  # Green
            title="Task Completed"
            local task_id=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('task_id', 'TASK-XXX'))" 2>/dev/null || echo "TASK-XXX")
            local task_title=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('title', 'Unknown task'))" 2>/dev/null || echo "Unknown task")
            description="**${task_id}**: ${task_title}"
            ;;
        orchestrator_complete)
            color=3447003  # Blue
            title="Pipeline Complete"
            local duration=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('duration_seconds', 0))" 2>/dev/null || echo "0")
            local errors=$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('errors', 0))" 2>/dev/null || echo "0")
            description="Completed in ${duration}s with ${errors} errors"
            ;;
        *)
            title="Notification"
            description="$(echo "$payload" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', 'Notification'))" 2>/dev/null || echo "Notification")"
            ;;
    esac

    # Return JSON payload with embed
    python3 << EOF
import json
print(json.dumps({
    'content': ':bell: **CronLoop Alert**',
    'embeds': [{
        'title': '$title',
        'description': '$description',
        'color': $color,
        'url': 'https://cronloop.techtools.cz',
        'timestamp': '$(date -Iseconds)'
    }]
}))
EOF
}

# Send webhook
send_webhook() {
    local webhook_id="$1"
    local webhook_name="$2"
    local webhook_url="$3"
    local webhook_type="$4"
    local event_type="$5"
    local payload="$6"
    local headers="$7"

    # Check rate limit
    if ! check_rate_limit "$event_type" "$webhook_id"; then
        return 0  # Rate limited, but not an error
    fi

    # Format payload based on type
    local formatted_payload
    case "$webhook_type" in
        slack)
            formatted_payload=$(format_slack_payload "$event_type" "$payload")
            ;;
        discord)
            formatted_payload=$(format_discord_payload "$event_type" "$payload")
            ;;
        *)
            formatted_payload="$payload"
            ;;
    esac

    # Build curl command
    local curl_args=(-s -S -X POST -H "Content-Type: application/json")

    # Add custom headers if provided
    if [[ -n "$headers" && "$headers" != "{}" && "$headers" != "null" ]]; then
        while IFS='=' read -r key value; do
            curl_args+=(-H "$key: $value")
        done < <(echo "$headers" | python3 -c "import sys, json; [print(f'{k}={v}') for k,v in json.load(sys.stdin).items()]" 2>/dev/null)
    fi

    curl_args+=(-d "$formatted_payload" "$webhook_url")

    # Send the webhook
    local response
    local http_code

    response=$(curl -w "\n%{http_code}" "${curl_args[@]}" 2>&1)
    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | head -n -1)

    # Check result
    if [[ "$http_code" =~ ^2 ]]; then
        log "SUCCESS: Sent $event_type to $webhook_name (HTTP $http_code)"
        update_webhook_history "$webhook_id" "$webhook_name" "$event_type" true "$http_code"
        return 0
    else
        log "FAILED: $event_type to $webhook_name (HTTP $http_code): $response"
        update_webhook_history "$webhook_id" "$webhook_name" "$event_type" false "$http_code: $response"
        return 1
    fi
}

# Update webhook history in JSON file
update_webhook_history() {
    local webhook_id="$1"
    local webhook_name="$2"
    local event_type="$3"
    local success="$4"
    local response="$5"

    python3 << EOF
import json
import os

try:
    with open('$WEBHOOKS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {'webhooks': [], 'history': [], 'config': {}}

# Add history entry
entry = {
    'webhookId': '$webhook_id',
    'webhookName': '$webhook_name',
    'event': '$event_type',
    'timestamp': '$(date -Iseconds)',
    'success': $success,
    'response': '$response'
}

data['history'] = [entry] + data.get('history', [])

# Keep only last 50 entries
data['history'] = data['history'][:50]

# Update success/fail counts on webhook
for webhook in data.get('webhooks', []):
    if webhook.get('id') == '$webhook_id':
        if $success:
            webhook['successCount'] = webhook.get('successCount', 0) + 1
        else:
            webhook['failCount'] = webhook.get('failCount', 0) + 1
        break

data['lastUpdated'] = '$(date -Iseconds)'

with open('$WEBHOOKS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
EOF
}

# Main: Process webhooks for an event
process_event() {
    local event_type="$1"
    local payload="$2"

    # Add timestamp and dashboard URL to payload if not present
    payload=$(echo "$payload" | python3 -c "
import sys, json
p = json.load(sys.stdin)
p['event'] = '$event_type'
if 'timestamp' not in p:
    import datetime
    p['timestamp'] = datetime.datetime.now().isoformat()
if 'dashboard_url' not in p:
    p['dashboard_url'] = 'https://cronloop.techtools.cz'
print(json.dumps(p))
")

    log "Processing event: $event_type"

    # Check if webhooks file exists
    if [[ ! -f "$WEBHOOKS_FILE" ]]; then
        log "No webhooks file found at $WEBHOOKS_FILE"
        exit 0
    fi

    # Get webhooks that subscribe to this event
    local webhooks
    webhooks=$(python3 << EOF
import json
with open('$WEBHOOKS_FILE', 'r') as f:
    data = json.load(f)

for webhook in data.get('webhooks', []):
    if webhook.get('enabled', False) and '$event_type' in webhook.get('events', []):
        print(f"{webhook['id']}|{webhook['name']}|{webhook['url']}|{webhook.get('type', 'generic')}|{json.dumps(webhook.get('headers', {}))}")
EOF
)

    if [[ -z "$webhooks" ]]; then
        log "No webhooks subscribed to $event_type"
        exit 0
    fi

    # Send to each webhook
    local sent=0
    local failed=0

    while IFS='|' read -r id name url type headers; do
        if [[ -n "$id" ]]; then
            if send_webhook "$id" "$name" "$url" "$type" "$event_type" "$payload" "$headers"; then
                ((sent++)) || true
            else
                ((failed++)) || true
            fi
        fi
    done <<< "$webhooks"

    log "Event $event_type complete: $sent sent, $failed failed"
    echo "Sent $sent webhook(s), $failed failed"
}

# Entry point
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <event_type> [payload_json]"
    echo ""
    echo "Event types:"
    echo "  agent_error         - Agent failure notification"
    echo "  security_alert      - Security incident notification"
    echo "  resource_warning    - Resource threshold warning"
    echo "  task_completed      - Task completion notification"
    echo "  orchestrator_complete - Pipeline completion notification"
    exit 1
fi

EVENT_TYPE="$1"
PAYLOAD="${2:-'{}'}"

# Validate event type
case "$EVENT_TYPE" in
    agent_error|security_alert|resource_warning|task_completed|orchestrator_complete|test)
        process_event "$EVENT_TYPE" "$PAYLOAD"
        ;;
    *)
        echo "Unknown event type: $EVENT_TYPE"
        exit 1
        ;;
esac
