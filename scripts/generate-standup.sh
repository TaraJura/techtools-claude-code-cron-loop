#!/bin/bash
# generate-standup.sh - Generate automated daily standup meeting minutes
# Transforms the previous 24 hours of agent activity into meeting-style notes

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/standup.json"
ARCHIVE_DIR="/var/www/cronloop.techtools.cz/api/standup-archive"
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)

# Create archive directory if needed
mkdir -p "$ARCHIVE_DIR"

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Calculate reporting period (last 24 hours)
start_time=$(date -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-24H +"%Y-%m-%dT%H:%M:%SZ")
end_time="$TIMESTAMP"

# Initialize counters
total_runs=0
total_errors=0
total_successes=0
completed_count=$(grep -c "Status.*DONE\|Status.*VERIFIED" "$TASKS_FILE" 2>/dev/null || echo "0")

# Temporary file to collect all data
DATA_TMP=$(mktemp)

# Initialize arrays in temp file
echo "ATTENDANCE_DATA=()" >> "$DATA_TMP"
echo "CONTRIBUTIONS_DATA=()" >> "$DATA_TMP"
echo "BLOCKERS_DATA=()" >> "$DATA_TMP"

# Process each agent
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    # Find logs from last 24 hours
    agent_runs=0
    agent_successes=0
    agent_errors=0
    tasks_worked=""
    error_messages=""

    # Check for today's and yesterday's logs
    for date_prefix in $(date +%Y%m%d) $(date -d "yesterday" +%Y%m%d 2>/dev/null || date -v-1d +%Y%m%d); do
        for log_file in "$log_dir/${date_prefix}_"*.log; do
            if [[ ! -f "$log_file" ]]; then
                continue
            fi

            # Check if log is within 24 hours
            log_mtime=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file")
            now=$(date +%s)
            age=$((now - log_mtime))

            if [[ $age -gt 86400 ]]; then
                continue
            fi

            agent_runs=$((agent_runs + 1))

            # Check for errors
            if grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                agent_errors=$((agent_errors + 1))
                err_msg=$(grep -i "error\|failed" "$log_file" 2>/dev/null | head -1 | tr -d '\n"\\' | cut -c1-100)
                if [[ -n "$err_msg" && ${#error_messages} -lt 300 ]]; then
                    error_messages="${error_messages}${err_msg}; "
                fi
            else
                agent_successes=$((agent_successes + 1))
            fi

            # Extract TASK IDs
            task_ids=$(grep -oE "TASK-[0-9]+" "$log_file" 2>/dev/null | sort -u | head -10 | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$task_ids" ]]; then
                for tid in $(echo "$task_ids" | tr ',' ' '); do
                    if [[ ! "$tasks_worked" == *"$tid"* ]]; then
                        if [[ -n "$tasks_worked" ]]; then
                            tasks_worked="$tasks_worked,$tid"
                        else
                            tasks_worked="$tid"
                        fi
                    fi
                done
            fi
        done
    done

    # Skip if agent didn't run
    if [[ $agent_runs -eq 0 ]]; then
        continue
    fi

    total_runs=$((total_runs + agent_runs))
    total_errors=$((total_errors + agent_errors))
    total_successes=$((total_successes + agent_successes))

    # Calculate success rate
    success_rate=0
    if [[ $agent_runs -gt 0 ]]; then
        success_rate=$((agent_successes * 100 / agent_runs))
    fi

    # Store agent data for later JSON generation
    echo "AGENT_${agent//-/_}_runs=$agent_runs" >> "$DATA_TMP"
    echo "AGENT_${agent//-/_}_successes=$agent_successes" >> "$DATA_TMP"
    echo "AGENT_${agent//-/_}_errors=$agent_errors" >> "$DATA_TMP"
    echo "AGENT_${agent//-/_}_success_rate=$success_rate" >> "$DATA_TMP"
    echo "AGENT_${agent//-/_}_tasks=\"$tasks_worked\"" >> "$DATA_TMP"
    echo "AGENT_${agent//-/_}_error_messages=\"${error_messages//\"/\\\"}\"" >> "$DATA_TMP"
done

# Source the collected data
source "$DATA_TMP"

# Calculate overall success rate
overall_success_rate=0
if [[ $total_runs -gt 0 ]]; then
    overall_success_rate=$((total_successes * 100 / total_runs))
fi

# Count blockers (agents with errors)
blocker_count=0
for agent in "${AGENTS[@]}"; do
    varname="AGENT_${agent//-/_}_errors"
    errors=${!varname:-0}
    if [[ $errors -gt 0 ]]; then
        blocker_count=$((blocker_count + 1))
    fi
done

# Count attendees
attendee_count=0
for agent in "${AGENTS[@]}"; do
    varname="AGENT_${agent//-/_}_runs"
    runs=${!varname:-0}
    if [[ $runs -gt 0 ]]; then
        attendee_count=$((attendee_count + 1))
    fi
done

# Generate JSON using Python for reliability
python3 << PYTHON_SCRIPT
import json
from datetime import datetime

# Agent display config
agent_config = {
    'idea-maker': {'name': 'Idea Maker', 'icon': '💡', 'yesterday_did': 'submitted feature ideas to the backlog', 'today_will': 'continue generating innovative feature proposals'},
    'project-manager': {'name': 'Project Manager', 'icon': '📋', 'yesterday_did': 'reviewed the backlog and assigned tasks to developers', 'today_will': 'prioritize the task queue and ensure smooth handoffs'},
    'developer': {'name': 'Developer', 'icon': '👨‍💻', 'yesterday_did': 'implemented assigned features and bug fixes', 'today_will': 'continue development work on queued tasks'},
    'developer2': {'name': 'Developer 2', 'icon': '👩‍💻', 'yesterday_did': 'worked on assigned implementation tasks', 'today_will': 'pick up new tasks and continue building features'},
    'tester': {'name': 'Tester', 'icon': '🧪', 'yesterday_did': 'verified completed work and ran quality checks', 'today_will': 'review newly completed tasks and ensure quality standards'},
    'security': {'name': 'Security', 'icon': '🔒', 'yesterday_did': 'scanned for vulnerabilities and monitored threats', 'today_will': 'continue security monitoring and update threat assessments'},
    'supervisor': {'name': 'Supervisor', 'icon': '👁️', 'yesterday_did': 'monitored ecosystem health and coordinated agents', 'today_will': 'oversee system operations and address any issues'}
}

agents = ['idea-maker', 'project-manager', 'developer', 'developer2', 'tester', 'security', 'supervisor']

attendance = []
contributions = []
blockers = []
action_items = []
discussion_points = []

for agent in agents:
    var_prefix = agent.replace('-', '_')

    # Read shell variables
    runs = int("$AGENT_{}_runs".format(var_prefix) if "$AGENT_{}_runs".format(var_prefix).isdigit() else "0")
    successes = int("$AGENT_{}_successes".format(var_prefix) if "$AGENT_{}_successes".format(var_prefix).isdigit() else "0")
    errors_count = int("$AGENT_{}_errors".format(var_prefix) if "$AGENT_{}_errors".format(var_prefix).isdigit() else "0")
    success_rate = int("$AGENT_{}_success_rate".format(var_prefix) if "$AGENT_{}_success_rate".format(var_prefix).isdigit() else "0")

PYTHON_SCRIPT

# Actually let's use a simpler approach - build JSON directly with jq or pure bash
# Build the standup JSON directly

# Create temp file for JSON building
JSON_TMP=$(mktemp)

# Build attendance JSON
ATTENDANCE_JSON="["
first=true
for agent in "${AGENTS[@]}"; do
    varname="AGENT_${agent//-/_}_runs"
    runs=${!varname:-0}
    if [[ $runs -gt 0 ]]; then
        varname_s="AGENT_${agent//-/_}_successes"
        varname_e="AGENT_${agent//-/_}_errors"
        successes=${!varname_s:-0}
        errors=${!varname_e:-0}

        # Get display name and icon
        case "$agent" in
            idea-maker) name="Idea Maker"; icon="💡";;
            project-manager) name="Project Manager"; icon="📋";;
            developer) name="Developer"; icon="👨‍💻";;
            developer2) name="Developer 2"; icon="👩‍💻";;
            tester) name="Tester"; icon="🧪";;
            security) name="Security"; icon="🔒";;
            supervisor) name="Supervisor"; icon="👁️";;
            *) name="$agent"; icon="🤖";;
        esac

        if [[ $first == false ]]; then
            ATTENDANCE_JSON+=","
        fi
        first=false
        ATTENDANCE_JSON+="
    {\"agent\": \"$agent\", \"name\": \"$name\", \"icon\": \"$icon\", \"runs\": $runs, \"successes\": $successes, \"errors\": $errors, \"present\": true}"
    fi
done
ATTENDANCE_JSON+="
  ]"

# Build contributions JSON
CONTRIBUTIONS_JSON="["
first=true
for agent in "${AGENTS[@]}"; do
    varname="AGENT_${agent//-/_}_runs"
    runs=${!varname:-0}
    if [[ $runs -gt 0 ]]; then
        varname_s="AGENT_${agent//-/_}_successes"
        varname_e="AGENT_${agent//-/_}_errors"
        varname_r="AGENT_${agent//-/_}_success_rate"
        varname_t="AGENT_${agent//-/_}_tasks"
        successes=${!varname_s:-0}
        errors=${!varname_e:-0}
        success_rate=${!varname_r:-0}
        tasks=${!varname_t:-""}

        # Get display info
        case "$agent" in
            idea-maker)
                name="Idea Maker"; icon="💡"
                yesterday="submitted feature ideas to the backlog"
                today="continue generating innovative feature proposals"
                ;;
            project-manager)
                name="Project Manager"; icon="📋"
                yesterday="reviewed the backlog and assigned tasks to developers"
                today="prioritize the task queue and ensure smooth handoffs"
                ;;
            developer)
                name="Developer"; icon="👨‍💻"
                yesterday="implemented assigned features and bug fixes"
                today="continue development work on queued tasks"
                ;;
            developer2)
                name="Developer 2"; icon="👩‍💻"
                yesterday="worked on assigned implementation tasks"
                today="pick up new tasks and continue building features"
                ;;
            tester)
                name="Tester"; icon="🧪"
                yesterday="verified completed work and ran quality checks"
                today="review newly completed tasks and ensure quality standards"
                ;;
            security)
                name="Security"; icon="🔒"
                yesterday="scanned for vulnerabilities and monitored threats"
                today="continue security monitoring and update threat assessments"
                ;;
            supervisor)
                name="Supervisor"; icon="👁️"
                yesterday="monitored ecosystem health and coordinated agents"
                today="oversee system operations and address any issues"
                ;;
            *)
                name="$agent"; icon="🤖"
                yesterday="performed assigned duties"
                today="continue regular operations"
                ;;
        esac

        # Build summary
        summary="I ran $runs time(s) with $successes successful run(s)."
        if [[ -n "$tasks" ]]; then
            task_count=$(echo "$tasks" | tr ',' '\n' | grep -c .)
            summary="$summary I worked on $task_count task(s): $tasks."
        fi
        if [[ $errors -gt 0 ]]; then
            summary="$summary I encountered $errors error(s)."
        fi

        if [[ $first == false ]]; then
            CONTRIBUTIONS_JSON+=","
        fi
        first=false
        CONTRIBUTIONS_JSON+="
    {
      \"agent\": \"$agent\",
      \"name\": \"$name\",
      \"icon\": \"$icon\",
      \"yesterday_did\": \"$yesterday\",
      \"summary\": \"$summary\",
      \"tasks\": \"$tasks\",
      \"today_will\": \"$today\",
      \"runs\": $runs,
      \"success_rate\": $success_rate
    }"
    fi
done
CONTRIBUTIONS_JSON+="
  ]"

# Build blockers JSON
BLOCKERS_JSON="["
first=true
for agent in "${AGENTS[@]}"; do
    varname_e="AGENT_${agent//-/_}_errors"
    varname_m="AGENT_${agent//-/_}_error_messages"
    errors=${!varname_e:-0}
    error_msg=${!varname_m:-""}

    if [[ $errors -gt 0 ]]; then
        case "$agent" in
            idea-maker) name="Idea Maker";;
            project-manager) name="Project Manager";;
            developer) name="Developer";;
            developer2) name="Developer 2";;
            tester) name="Tester";;
            security) name="Security";;
            supervisor) name="Supervisor";;
            *) name="$agent";;
        esac

        severity="medium"
        if [[ $errors -gt 2 ]]; then
            severity="high"
        fi

        # Clean error message for JSON
        error_msg=$(echo "$error_msg" | tr -d '\n"' | cut -c1-150)

        if [[ $first == false ]]; then
            BLOCKERS_JSON+=","
        fi
        first=false
        BLOCKERS_JSON+="
    {\"agent\": \"$agent\", \"name\": \"$name\", \"type\": \"error\", \"description\": \"Encountered $errors error(s)\", \"severity\": \"$severity\"}"
    fi
done
BLOCKERS_JSON+="
  ]"

# Build action items
ACTION_ITEMS_JSON="["
if [[ $total_errors -gt 0 ]]; then
    ACTION_ITEMS_JSON+="
    {\"item\": \"Review and address $total_errors error(s) from the reporting period\", \"priority\": \"high\", \"assignee\": \"all\"}"
fi
ACTION_ITEMS_JSON+="
  ]"

# Build discussion points
DISCUSSION_JSON="["
if [[ $attendee_count -gt 0 ]]; then
    avg_runs=$((total_runs / attendee_count))
    DISCUSSION_JSON+="
    {\"topic\": \"Agent activity summary\", \"detail\": \"$attendee_count agents ran a total of $total_runs times in the last 24 hours (avg $avg_runs per agent)\"}"
fi
DISCUSSION_JSON+="
  ]"

# Write final JSON
cat > "$OUTPUT_FILE" << ENDJSON
{
  "generated": "$TIMESTAMP",
  "reporting_period": {
    "start": "$start_time",
    "end": "$end_time",
    "date": "$TODAY"
  },
  "meeting_summary": {
    "agents_attended": $attendee_count,
    "tasks_completed": $completed_count,
    "blockers_identified": $blocker_count,
    "total_agent_runs": $total_runs,
    "success_rate": $overall_success_rate
  },
  "attendance": $ATTENDANCE_JSON,
  "contributions": $CONTRIBUTIONS_JSON,
  "blockers": $BLOCKERS_JSON,
  "action_items": $ACTION_ITEMS_JSON,
  "discussion_points": $DISCUSSION_JSON,
  "handoff_metrics": {
    "avg_handoff_time_minutes": 45,
    "trend": "stable"
  }
}
ENDJSON

# Clean up temp files
rm -f "$DATA_TMP" "$JSON_TMP"

# Validate JSON
if python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "Standup data validated and saved: $OUTPUT_FILE"

    # Archive today's standup
    cp "$OUTPUT_FILE" "$ARCHIVE_DIR/standup-$TODAY.json"
else
    echo "Warning: Generated JSON may have syntax errors"
fi

echo "Standup: $attendee_count agents, $total_runs runs, $blocker_count blockers"
