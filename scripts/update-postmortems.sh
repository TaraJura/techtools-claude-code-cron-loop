#!/bin/bash
# update-postmortems.sh - Manages incident postmortem data
# Output: JSON data for the postmortem.html dashboard

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/postmortems.json"
TEMP_FILE="/tmp/postmortems_temp.json"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EPOCH=$(date +%s)

# Initialize postmortems.json if it doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    cat > "$OUTPUT_FILE" << 'INIT_JSON'
{
  "timestamp": "",
  "epoch": 0,
  "postmortems": [],
  "templates": [
    {
      "id": "agent-failure",
      "name": "Agent Failure",
      "icon": "&#9888;",
      "description": "An agent encountered errors or failed to complete its task",
      "suggested_sections": ["Summary", "Timeline", "Impact", "Root Cause", "Resolution", "Lessons Learned"]
    },
    {
      "id": "high-resource",
      "name": "High Resource Usage",
      "icon": "&#128200;",
      "description": "CPU, memory, or disk usage exceeded normal thresholds",
      "suggested_sections": ["Summary", "Metrics Snapshot", "Timeline", "Root Cause", "Resolution", "Action Items"]
    },
    {
      "id": "security-event",
      "name": "Security Event",
      "icon": "&#128274;",
      "description": "Security incident such as unauthorized access attempts or vulnerabilities",
      "suggested_sections": ["Summary", "Timeline", "Impact", "Indicators of Compromise", "Containment", "Lessons Learned"]
    },
    {
      "id": "service-outage",
      "name": "Service Outage",
      "icon": "&#9760;",
      "description": "A service or component was unavailable",
      "suggested_sections": ["Summary", "Timeline", "Impact", "Root Cause", "Resolution", "Prevention"]
    },
    {
      "id": "custom",
      "name": "Custom Incident",
      "icon": "&#128221;",
      "description": "Define your own incident type and sections",
      "suggested_sections": ["Summary", "Timeline", "Impact", "Root Cause", "Resolution", "Action Items", "Lessons Learned"]
    }
  ],
  "stats": {
    "total": 0,
    "by_type": {},
    "this_week": 0,
    "this_month": 0
  }
}
INIT_JSON
fi

# Load existing data
EXISTING_DATA=$(cat "$OUTPUT_FILE")

# Calculate stats from existing postmortems
TOTAL_POSTMORTEMS=$(echo "$EXISTING_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('postmortems',[])))" 2>/dev/null || echo "0")

# Get counts by type
BY_TYPE=$(echo "$EXISTING_DATA" | python3 -c "
import sys, json
from collections import Counter
d = json.load(sys.stdin)
postmortems = d.get('postmortems', [])
counts = Counter(p.get('type', 'unknown') for p in postmortems)
print(json.dumps(dict(counts)))
" 2>/dev/null || echo "{}")

# Get this week and this month counts
WEEK_COUNT=$(echo "$EXISTING_DATA" | python3 -c "
import sys, json
from datetime import datetime, timedelta
d = json.load(sys.stdin)
postmortems = d.get('postmortems', [])
week_ago = (datetime.now() - timedelta(days=7)).isoformat()
count = sum(1 for p in postmortems if p.get('created', '') >= week_ago)
print(count)
" 2>/dev/null || echo "0")

MONTH_COUNT=$(echo "$EXISTING_DATA" | python3 -c "
import sys, json
from datetime import datetime, timedelta
d = json.load(sys.stdin)
postmortems = d.get('postmortems', [])
month_ago = (datetime.now() - timedelta(days=30)).isoformat()
count = sum(1 for p in postmortems if p.get('created', '') >= month_ago)
print(count)
" 2>/dev/null || echo "0")

# Collect current system context for incident creation
# Get recent errors
RECENT_ERRORS=$(cat /var/www/cronloop.techtools.cz/api/error-patterns.json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
errors = d.get('recent_errors', [])[:10]
print(json.dumps(errors))
" 2>/dev/null || echo "[]")

# Get recent commits
RECENT_COMMITS=$(cat /var/www/cronloop.techtools.cz/api/changelog.json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
commits = d.get('commits', [])[:10]
simplified = [{'hash': c.get('short_hash',''), 'subject': c.get('subject',''), 'date': c.get('date',''), 'agent': c.get('agent','')} for c in commits]
print(json.dumps(simplified))
" 2>/dev/null || echo "[]")

# Get system metrics (validate JSON)
SYSTEM_METRICS=$(python3 -c "
import json
try:
    with open('/var/www/cronloop.techtools.cz/api/system-metrics.json', 'r') as f:
        d = json.load(f)
    print(json.dumps(d))
except:
    print('{}')
" 2>/dev/null || echo "{}")

# Get security metrics (validate JSON)
SECURITY_METRICS=$(python3 -c "
import json
try:
    with open('/var/www/cronloop.techtools.cz/api/security-metrics.json', 'r') as f:
        d = json.load(f)
    print(json.dumps(d))
except:
    print('{}')
" 2>/dev/null || echo "{}")

# Update the JSON file with fresh timestamp and stats
python3 << PYTHON_SCRIPT
import json
import sys

# Load existing data
with open("$OUTPUT_FILE", 'r') as f:
    data = json.load(f)

# Update timestamp
data['timestamp'] = "$TIMESTAMP"
data['epoch'] = $EPOCH

# Update stats
data['stats'] = {
    'total': $TOTAL_POSTMORTEMS,
    'by_type': $BY_TYPE,
    'this_week': $WEEK_COUNT,
    'this_month': $MONTH_COUNT
}

# Add current context for incident creation
data['current_context'] = {
    'recent_errors': $RECENT_ERRORS,
    'recent_commits': $RECENT_COMMITS,
    'system_metrics': $SYSTEM_METRICS,
    'security_metrics': $SECURITY_METRICS
}

# Write back
with open("$OUTPUT_FILE", 'w') as f:
    json.dump(data, f, indent=2)
PYTHON_SCRIPT

# Set proper permissions
chmod 666 "$OUTPUT_FILE" 2>/dev/null || true

echo "Postmortems data updated: $OUTPUT_FILE"
echo "Stats: $TOTAL_POSTMORTEMS total, $WEEK_COUNT this week, $MONTH_COUNT this month"
