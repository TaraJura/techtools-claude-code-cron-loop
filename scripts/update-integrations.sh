#!/bin/bash
# update-integrations.sh - Gather external integration status
# Part of the CronLoop autonomous AI ecosystem

# Don't exit on error - we want to continue checking other integrations
set +e

API_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$API_DIR/integrations.json"
HOME_DIR="/home/novakj"
TIMESTAMP=$(date -Iseconds)

# Initialize output structure
declare -A integrations

# Function to test URL connectivity
test_url() {
    local url="$1"
    local timeout="${2:-5}"
    local start_time=$(date +%s%N)
    local result

    if result=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" -m "$timeout" "$url" 2>/dev/null); then
        local end_time=$(date +%s%N)
        local latency_ms=$(( (end_time - start_time) / 1000000 ))
        echo "$result|$latency_ms"
    else
        echo "0|0"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Start building JSON
cat > "$OUTPUT_FILE" << 'JSONSTART'
{
  "lastUpdated": "TIMESTAMP_PLACEHOLDER",
  "overallHealth": 0,
  "integrations": {
JSONSTART

# Replace timestamp placeholder
sed -i "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/" "$OUTPUT_FILE"

# Track health for overall score
total_integrations=0
healthy_integrations=0

# 1. GitHub API Check
echo "Checking GitHub API..."
gh_status="unknown"
gh_rate_limit="0"
gh_rate_remaining="0"
gh_rate_reset=""
gh_latency=0
gh_last_error=""
gh_recent_calls=0

if command_exists gh; then
    # Check if gh is authenticated
    if gh auth status >/dev/null 2>&1; then
        # Test API connectivity
        result=$(test_url "https://api.github.com/rate_limit" 10)
        http_code=$(echo "$result" | cut -d'|' -f1)
        gh_latency=$(echo "$result" | cut -d'|' -f2)

        if [ "$http_code" = "200" ]; then
            gh_status="connected"
            ((healthy_integrations++))

            # Get rate limit details
            rate_info=$(gh api rate_limit 2>/dev/null || echo '{}')
            gh_rate_limit=$(echo "$rate_info" | jq -r '.rate.limit // 0')
            gh_rate_remaining=$(echo "$rate_info" | jq -r '.rate.remaining // 0')
            gh_rate_reset_epoch=$(echo "$rate_info" | jq -r '.rate.reset // 0')
            if [ "$gh_rate_reset_epoch" != "0" ]; then
                gh_rate_reset=$(date -d "@$gh_rate_reset_epoch" -Iseconds 2>/dev/null || echo "")
            fi

            # Count recent git operations from changelog
            if [ -f "$API_DIR/changelog.json" ]; then
                gh_recent_calls=$(jq '[.commits[] | select(.timestamp >= (now - 86400 | todate))] | length' "$API_DIR/changelog.json" 2>/dev/null || echo "0")
            fi
        else
            gh_status="error"
            gh_last_error="HTTP $http_code"
        fi
    else
        gh_status="not_authenticated"
        gh_last_error="GitHub CLI not authenticated"
    fi
else
    gh_status="not_installed"
    gh_last_error="GitHub CLI (gh) not installed"
fi
((total_integrations++))

# Add GitHub integration to JSON
cat >> "$OUTPUT_FILE" << EOF
    "github": {
      "name": "GitHub API",
      "icon": "github",
      "status": "$gh_status",
      "latencyMs": $gh_latency,
      "rateLimit": {
        "limit": $gh_rate_limit,
        "remaining": $gh_rate_remaining,
        "resetTime": "$gh_rate_reset"
      },
      "recentCalls": $gh_recent_calls,
      "lastError": "$gh_last_error",
      "description": "Git repository hosting and API for commits, issues, PRs",
      "dependentFeatures": ["changelog.html", "commits feed", "git operations"]
    },
EOF

# 2. Claude/Anthropic API Check (inferred from costs.json)
echo "Checking Claude API status..."
claude_status="unknown"
claude_last_success=""
claude_total_calls=0
claude_errors=0
claude_latency=0
claude_last_error=""

if [ -f "$API_DIR/costs.json" ]; then
    costs_data=$(cat "$API_DIR/costs.json")
    claude_total_calls=$(echo "$costs_data" | jq -r '.total.total_calls // 0')
    claude_last_run=$(echo "$costs_data" | jq -r '.last_updated // ""')

    # Check if we have recent successful API calls (agents running = API working)
    if [ -f "$API_DIR/agent-status.json" ]; then
        last_agent_run=$(jq -r '[.agents[].last_run // ""] | map(select(. != "")) | max // ""' "$API_DIR/agent-status.json" 2>/dev/null || echo "")
        now_epoch=$(date +%s)

        # If an agent ran in last 2 hours, API is working
        if [ -n "$last_agent_run" ] && [ "$last_agent_run" != "null" ] && [ "$last_agent_run" != "" ]; then
            # Convert ISO date to epoch
            last_run_epoch=$(date -d "$last_agent_run" +%s 2>/dev/null || echo "0")
            if [ "$last_run_epoch" -gt 0 ] && [ $((now_epoch - last_run_epoch)) -lt 7200 ]; then
                claude_status="connected"
                ((healthy_integrations++))
                claude_last_success="$last_agent_run"
            else
                claude_status="stale"
                claude_last_error="No agent runs in last 2 hours"
            fi
        else
            claude_status="unknown"
        fi
    fi
else
    claude_status="unknown"
    claude_last_error="No cost tracking data available"
fi
((total_integrations++))

# Add Claude API integration to JSON
cat >> "$OUTPUT_FILE" << EOF
    "claude": {
      "name": "Claude API (Anthropic)",
      "icon": "anthropic",
      "status": "$claude_status",
      "latencyMs": $claude_latency,
      "totalCalls": $claude_total_calls,
      "lastSuccess": "$claude_last_success",
      "lastError": "$claude_last_error",
      "description": "AI model API powering all agent operations",
      "dependentFeatures": ["All agents", "costs.html", "agent-quotas.html"]
    },
EOF

# 3. Webhooks Check
echo "Checking webhook integrations..."
webhook_count=0
webhook_active=0
webhook_failed=0
webhook_success_rate=100
webhooks_json="[]"

if [ -f "$API_DIR/webhooks.json" ]; then
    webhook_data=$(cat "$API_DIR/webhooks.json")
    webhook_count=$(echo "$webhook_data" | jq '.webhooks | length')
    webhook_active=$(echo "$webhook_data" | jq '[.webhooks[] | select(.enabled == true)] | length')

    # Calculate success rate from history
    total_sends=$(echo "$webhook_data" | jq '.history | length')
    if [ "$total_sends" -gt 0 ]; then
        successful_sends=$(echo "$webhook_data" | jq '[.history[] | select(.status == "success")] | length')
        webhook_success_rate=$(echo "scale=1; $successful_sends * 100 / $total_sends" | bc 2>/dev/null || echo "100")
    fi

    # Get webhook details
    webhooks_json=$(echo "$webhook_data" | jq '[.webhooks[] | {
        name: .name,
        type: .type,
        enabled: .enabled,
        lastSent: .lastSent,
        successRate: (if .history then ([.history[] | select(.status == "success")] | length) / ([.history[]] | length) * 100 else 100 end)
    }]' 2>/dev/null || echo "[]")
fi

webhook_status="connected"
if [ "$webhook_count" -eq 0 ]; then
    webhook_status="not_configured"
elif [ "$webhook_active" -eq 0 ]; then
    webhook_status="disabled"
elif [ "${webhook_success_rate%.*}" -lt 80 ]; then
    webhook_status="degraded"
else
    ((healthy_integrations++))
fi
((total_integrations++))

# Add webhooks integration to JSON
cat >> "$OUTPUT_FILE" << EOF
    "webhooks": {
      "name": "Webhook Notifications",
      "icon": "webhook",
      "status": "$webhook_status",
      "totalWebhooks": $webhook_count,
      "activeWebhooks": $webhook_active,
      "successRate": $webhook_success_rate,
      "endpoints": $webhooks_json,
      "description": "External notification delivery (Slack, Discord, custom)",
      "dependentFeatures": ["webhooks.html", "alerts.html", "notifications"]
    },
EOF

# 4. Web Server (Nginx) Check
echo "Checking Nginx web server..."
nginx_status="unknown"
nginx_latency=0

result=$(test_url "https://cronloop.techtools.cz/api/system-metrics.json" 5)
http_code=$(echo "$result" | cut -d'|' -f1)
nginx_latency=$(echo "$result" | cut -d'|' -f2)

if [ "$http_code" = "200" ]; then
    nginx_status="connected"
    ((healthy_integrations++))
elif [ "$http_code" != "0" ]; then
    nginx_status="error"
else
    nginx_status="unreachable"
fi
((total_integrations++))

# Check if nginx is running locally
nginx_running="false"
if systemctl is-active --quiet nginx 2>/dev/null; then
    nginx_running="true"
fi

# Add Nginx integration to JSON
cat >> "$OUTPUT_FILE" << EOF
    "nginx": {
      "name": "Web Server (Nginx)",
      "icon": "server",
      "status": "$nginx_status",
      "latencyMs": $nginx_latency,
      "serviceRunning": $nginx_running,
      "url": "https://cronloop.techtools.cz",
      "description": "Serves the CronLoop dashboard and API endpoints",
      "dependentFeatures": ["All dashboard pages", "All API endpoints"]
    },
EOF

# 5. Cron Service Check
echo "Checking Cron service..."
cron_status="unknown"
cron_jobs=0
cron_last_run=""

if systemctl is-active --quiet cron 2>/dev/null; then
    cron_status="connected"
    ((healthy_integrations++))

    # Count cron jobs
    cron_jobs=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)

    # Get last orchestrator run time
    if [ -f "$HOME_DIR/actors/cron.log" ]; then
        cron_last_run=$(tail -1 "$HOME_DIR/actors/cron.log" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' | head -1 || echo "")
    fi
else
    cron_status="stopped"
fi
((total_integrations++))

# Add Cron integration to JSON
cat >> "$OUTPUT_FILE" << EOF
    "cron": {
      "name": "Cron Scheduler",
      "icon": "clock",
      "status": "$cron_status",
      "activeJobs": $cron_jobs,
      "lastRun": "$cron_last_run",
      "description": "Schedules the 30-minute agent pipeline execution",
      "dependentFeatures": ["Agent pipeline", "schedule.html", "automated tasks"]
    },
EOF

# 6. SSL Certificate Check
echo "Checking SSL certificate..."
ssl_status="unknown"
ssl_expiry=""
ssl_days_remaining=0
ssl_issuer=""

if command_exists openssl; then
    cert_info=$(echo | openssl s_client -servername cronloop.techtools.cz -connect cronloop.techtools.cz:443 2>/dev/null | openssl x509 -noout -dates -issuer 2>/dev/null || echo "")

    if [ -n "$cert_info" ]; then
        ssl_expiry=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        ssl_issuer=$(echo "$cert_info" | grep "issuer" | sed 's/issuer=//')

        if [ -n "$ssl_expiry" ]; then
            expiry_epoch=$(date -d "$ssl_expiry" +%s 2>/dev/null || echo "0")
            now_epoch=$(date +%s)
            ssl_days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

            if [ "$ssl_days_remaining" -gt 30 ]; then
                ssl_status="connected"
                ((healthy_integrations++))
            elif [ "$ssl_days_remaining" -gt 7 ]; then
                ssl_status="warning"
            else
                ssl_status="critical"
            fi
        fi
    fi
fi
((total_integrations++))

# Add SSL integration to JSON (remove trailing comma for last item)
cat >> "$OUTPUT_FILE" << EOF
    "ssl": {
      "name": "SSL Certificate",
      "icon": "lock",
      "status": "$ssl_status",
      "expiryDate": "$ssl_expiry",
      "daysRemaining": $ssl_days_remaining,
      "issuer": "$ssl_issuer",
      "description": "HTTPS encryption for secure dashboard access",
      "dependentFeatures": ["Secure web access", "API security"]
    }
EOF

# Calculate overall health percentage
if [ "$total_integrations" -gt 0 ]; then
    overall_health=$(echo "scale=0; $healthy_integrations * 100 / $total_integrations" | bc)
else
    overall_health=0
fi

# Close the JSON
cat >> "$OUTPUT_FILE" << EOF
  },
  "summary": {
    "total": $total_integrations,
    "healthy": $healthy_integrations,
    "degraded": $((total_integrations - healthy_integrations)),
    "healthScore": $overall_health
  },
  "history": []
}
EOF

# Update overall health in the file
sed -i "s/\"overallHealth\": 0/\"overallHealth\": $overall_health/" "$OUTPUT_FILE"

# Validate JSON
if command_exists jq; then
    if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo "Warning: Generated JSON may be invalid"
    fi
fi

echo "Integration status updated: $OUTPUT_FILE"
echo "Overall health: $overall_health% ($healthy_integrations/$total_integrations healthy)"
