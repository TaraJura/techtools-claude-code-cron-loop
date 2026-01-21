#!/bin/bash
# generate-retrospective.sh - Generate automated sprint retrospective analysis
# Analyzes the past week's performance and generates actionable insights

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/retrospective.json"
ARCHIVE_DIR="/var/www/cronloop.techtools.cz/api/retrospective-archive"
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"
COSTS_FILE="/var/www/cronloop.techtools.cz/api/costs.json"
SYSTEM_METRICS="/var/www/cronloop.techtools.cz/api/system-metrics.json"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
WEEK_START=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

# Agents to analyze
AGENTS="idea-maker project-manager developer developer2 tester security supervisor"

# Calculate days until Sunday (next retrospective)
day_of_week=$(date +%u)
days_until_sunday=$((7 - day_of_week))
if [[ $days_until_sunday -eq 7 ]]; then
    days_until_sunday=0
fi

# Collect agent data using a temporary file
TMP_DATA=$(mktemp)

for agent in $AGENTS; do
    log_dir="$ACTORS_DIR/$agent/logs"
    runs=0
    successes=0
    errors=0
    tasks_worked=""

    if [[ -d "$log_dir" ]]; then
        # Check logs from last 7 days
        for i in $(seq 0 6); do
            date_prefix=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d)
            for log_file in "$log_dir/${date_prefix}_"*.log; do
                if [[ -f "$log_file" ]]; then
                    runs=$((runs + 1))

                    # Check for errors
                    if grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                        errors=$((errors + 1))
                    else
                        successes=$((successes + 1))
                    fi

                    # Extract task IDs
                    task_ids=$(grep -oE "TASK-[0-9]+" "$log_file" 2>/dev/null | sort -u | head -20 | tr '\n' ',' | sed 's/,$//')
                    if [[ -n "$task_ids" ]]; then
                        if [[ -n "$tasks_worked" ]]; then
                            tasks_worked="$tasks_worked,$task_ids"
                        else
                            tasks_worked="$task_ids"
                        fi
                    fi
                fi
            done
        done
    fi

    # Limit tasks to first 50 unique ones
    tasks_worked=$(echo "$tasks_worked" | tr ',' '\n' | sort -u | head -50 | tr '\n' ',' | sed 's/,$//')

    echo "$agent|$runs|$successes|$errors|$tasks_worked" >> "$TMP_DATA"
done

# Count tasks from tasks.md (ensure no newlines)
tasks_completed=$(grep -c "Status.*DONE\|Status.*VERIFIED" "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo 0)
tasks_failed=$(grep -c "Status.*FAILED" "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo 0)
tasks_in_progress=$(grep -c "Status.*IN_PROGRESS" "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo 0)
tasks_todo=$(grep -c "Status.*TODO" "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo 0)

# Default to 0 if empty
tasks_completed=${tasks_completed:-0}
tasks_failed=${tasks_failed:-0}
tasks_in_progress=${tasks_in_progress:-0}
tasks_todo=${tasks_todo:-0}

# Get cost if available
total_cost="0.00"
if [[ -f "$COSTS_FILE" ]]; then
    total_cost=$(python3 -c "
import json
try:
    with open('$COSTS_FILE') as f:
        data = json.load(f)
        cost = data.get('last_7_days_cost', data.get('total_cost', data.get('weekly_cost', 0)))
        print(f'{float(cost):.2f}')
except:
    print('0.00')
" 2>/dev/null || echo "0.00")
fi

# Get uptime
uptime_pct="99.0"
if [[ -f "$SYSTEM_METRICS" ]]; then
    uptime_pct=$(python3 -c "
import json
try:
    with open('$SYSTEM_METRICS') as f:
        data = json.load(f)
        uptime = data.get('uptime_percentage', 99.0)
        print(f'{float(uptime):.1f}')
except:
    print('99.0')
" 2>/dev/null || echo "99.0")
fi

# Get previous week data if available
prev_week_file="$ARCHIVE_DIR/retrospective-$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d).json"

# Find a challenge task (completed task)
challenge_task=$(grep -B5 "Status.*DONE\|Status.*VERIFIED" "$TASKS_FILE" 2>/dev/null | grep -oE "TASK-[0-9]+" | tail -1 || echo "")
challenge_title=""
if [[ -n "$challenge_task" ]]; then
    challenge_title=$(grep -A1 "$challenge_task" "$TASKS_FILE" 2>/dev/null | grep -v "^--$" | head -1 | sed 's/^### //' | cut -c1-100 | sed 's/"/\\"/g')
fi

# Generate JSON using Python for reliability
python3 << PYTHON_SCRIPT
import json
from datetime import datetime

# Read agent data
agent_data = []
try:
    with open('$TMP_DATA', 'r') as f:
        for line in f:
            parts = line.strip().split('|')
            if len(parts) >= 5:
                agent_data.append({
                    'agent': parts[0],
                    'runs': int(parts[1] or 0),
                    'successes': int(parts[2] or 0),
                    'errors': int(parts[3] or 0),
                    'tasks': parts[4] if len(parts) > 4 else ''
                })
except Exception as e:
    print(f"Warning reading agent data: {e}")

# Agent display info
agent_info = {
    'idea-maker': ('Idea Maker', '&#128161;'),
    'project-manager': ('Project Manager', '&#128203;'),
    'developer': ('Developer', '&#128104;&#8205;&#128187;'),
    'developer2': ('Developer 2', '&#128105;&#8205;&#128187;'),
    'tester': ('Tester', '&#129514;'),
    'security': ('Security', '&#128274;'),
    'supervisor': ('Supervisor', '&#128065;&#65039;')
}

# Calculate totals
total_runs = sum(a['runs'] for a in agent_data)
total_successes = sum(a['successes'] for a in agent_data)
total_errors = sum(a['errors'] for a in agent_data)
overall_success_rate = int(total_successes * 100 / total_runs) if total_runs > 0 else 0

# Find best agent
best_agent = None
best_rate = 0
for a in agent_data:
    if a['runs'] > 0:
        rate = int(a['successes'] * 100 / a['runs'])
        if rate > best_rate or (rate == best_rate and a['runs'] > (best_agent['runs'] if best_agent else 0)):
            best_rate = rate
            best_agent = a

# Find struggling agents (error rate > 30%)
struggling_agents = []
for a in agent_data:
    if a['runs'] > 0:
        error_rate = int(a['errors'] * 100 / a['runs'])
        if error_rate > 30:
            struggling_agents.append((a['agent'], error_rate))

# Load previous week data for comparison
prev_success_rate = 0
prev_total_runs = 0
prev_tasks_completed = 0
try:
    with open('$prev_week_file', 'r') as f:
        prev_data = json.load(f)
        prev_success_rate = prev_data.get('metrics', {}).get('success_rate', 0)
        prev_total_runs = prev_data.get('metrics', {}).get('total_runs', 0)
        prev_tasks_completed = prev_data.get('metrics', {}).get('tasks_completed', 0)
except:
    pass

# Calculate trends
success_trend = 'stable'
if prev_success_rate > 0:
    diff = overall_success_rate - prev_success_rate
    if diff > 5:
        success_trend = 'improving'
    elif diff < -5:
        success_trend = 'declining'

runs_trend = 'stable'
if prev_total_runs > 0:
    diff = total_runs - prev_total_runs
    if diff > 10:
        runs_trend = 'increasing'
    elif diff < -10:
        runs_trend = 'decreasing'

# Build what went well
what_went_well = []
if overall_success_rate >= 70:
    what_went_well.append({
        'item': f'Maintained strong success rate of {overall_success_rate}%',
        'category': 'reliability',
        'metric': overall_success_rate
    })
tasks_completed = int('$tasks_completed' or 0)
if tasks_completed > 0:
    what_went_well.append({
        'item': f'Completed {tasks_completed} tasks this period',
        'category': 'productivity',
        'metric': tasks_completed
    })
if best_agent:
    name, icon = agent_info.get(best_agent['agent'], (best_agent['agent'], '&#129302;'))
    what_went_well.append({
        'item': f'{name} achieved highest success rate at {best_rate}%',
        'category': 'agent',
        'agent': best_agent['agent'],
        'metric': best_rate
    })
uptime_pct = float('$uptime_pct' or 99.0)
if uptime_pct >= 95:
    what_went_well.append({
        'item': f'System maintained {uptime_pct}% uptime',
        'category': 'stability',
        'metric': uptime_pct
    })
total_cost = float('$total_cost' or 0)
if total_cost < 10:
    what_went_well.append({
        'item': f'Cost-efficient operations at \${total_cost:.2f} for the period',
        'category': 'cost',
        'metric': total_cost
    })

# Build what didn't go well
what_didnt_go_well = []
tasks_failed = int('$tasks_failed' or 0)
if tasks_failed > 0:
    what_didnt_go_well.append({
        'item': f'{tasks_failed} task(s) failed during the period',
        'category': 'failures',
        'metric': tasks_failed,
        'severity': 'high'
    })
for agent, error_rate in struggling_agents:
    name, _ = agent_info.get(agent, (agent, ''))
    what_didnt_go_well.append({
        'item': f'{name} had {error_rate}% error rate',
        'category': 'agent_issues',
        'agent': agent,
        'metric': error_rate,
        'severity': 'medium'
    })
if total_errors > 5:
    what_didnt_go_well.append({
        'item': f'{total_errors} errors occurred across all agents',
        'category': 'errors',
        'metric': total_errors,
        'severity': 'medium'
    })
if success_trend == 'declining':
    diff = prev_success_rate - overall_success_rate
    what_didnt_go_well.append({
        'item': f'Success rate declined by {diff}% from last period',
        'category': 'regression',
        'metric': diff,
        'severity': 'high'
    })

# Build action items
action_items = []
for agent, _ in struggling_agents[:3]:  # Limit to top 3
    name, _ = agent_info.get(agent, (agent, ''))
    action_items.append({
        'item': f'Review {name} agent logs and update prompt.md to address recurring errors',
        'priority': 'high',
        'assignee': 'supervisor',
        'category': 'improvement'
    })
if tasks_failed > 0:
    action_items.append({
        'item': f'Investigate root causes of {tasks_failed} failed task(s) and create follow-up tasks',
        'priority': 'high',
        'assignee': 'project-manager',
        'category': 'process'
    })
if overall_success_rate < 90:
    action_items.append({
        'item': 'Continue monitoring and optimizing agent performance toward 90%+ success rate',
        'priority': 'medium',
        'assignee': 'all',
        'category': 'monitoring'
    })

# Build spotlight
spotlight = {'agent': None, 'name': 'No standout performer', 'reason': 'Not enough data to determine MVP'}
if best_agent:
    name, icon = agent_info.get(best_agent['agent'], (best_agent['agent'], '&#129302;'))
    spotlight = {
        'agent': best_agent['agent'],
        'name': name,
        'icon': icon,
        'title': 'MVP of the Week',
        'stats': {
            'runs': best_agent['runs'],
            'successes': best_agent['successes'],
            'success_rate': best_rate,
            'tasks': best_agent['tasks'][:500] if best_agent['tasks'] else ''
        },
        'reason': 'Highest success rate with consistent performance'
    }

# Challenge of the week
challenge = {'task_id': None, 'title': 'No major challenges identified', 'solved': True}
challenge_task = '$challenge_task'
challenge_title = '$challenge_title'
if challenge_task and challenge_title:
    challenge = {
        'task_id': challenge_task,
        'title': challenge_title,
        'solved': True,
        'description': 'Successfully delivered this feature during the sprint'
    }

# Agent breakdown
agent_breakdown = []
for a in agent_data:
    if a['runs'] > 0:
        name, icon = agent_info.get(a['agent'], (a['agent'], '&#129302;'))
        agent_breakdown.append({
            'agent': a['agent'],
            'name': name,
            'icon': icon,
            'runs': a['runs'],
            'successes': a['successes'],
            'errors': a['errors'],
            'success_rate': int(a['successes'] * 100 / a['runs']) if a['runs'] > 0 else 0,
            'tasks': a['tasks'][:500] if a['tasks'] else ''
        })

# History - include today's data
history = [{'date': '$TODAY', 'success_rate': overall_success_rate, 'runs': total_runs, 'tasks': tasks_completed}]

# Build final output
output = {
    'generated': '$TIMESTAMP',
    'reporting_period': {
        'start': '${WEEK_START}T00:00:00Z',
        'end': '${TODAY}T23:59:59Z',
        'days': 7
    },
    'next_retrospective': {
        'days_until': $days_until_sunday,
        'day': 'Sunday'
    },
    'metrics': {
        'total_runs': total_runs,
        'total_successes': total_successes,
        'total_errors': total_errors,
        'success_rate': overall_success_rate,
        'tasks_completed': tasks_completed,
        'tasks_failed': tasks_failed,
        'tasks_in_progress': int('$tasks_in_progress' or 0),
        'tasks_todo': int('$tasks_todo' or 0),
        'cost_usd': total_cost,
        'uptime_percentage': uptime_pct
    },
    'comparison': {
        'prev_success_rate': prev_success_rate,
        'prev_total_runs': prev_total_runs,
        'prev_tasks_completed': prev_tasks_completed,
        'success_trend': success_trend,
        'runs_trend': runs_trend
    },
    'what_went_well': what_went_well,
    'what_didnt_go_well': what_didnt_go_well,
    'action_items': action_items,
    'spotlight': spotlight,
    'challenge_of_week': challenge,
    'agent_breakdown': agent_breakdown,
    'history': history
}

# Write output
with open('$OUTPUT_FILE', 'w') as f:
    json.dump(output, f, indent=2)

print(f"Retrospective generated: $OUTPUT_FILE")
print(f"Sprint Stats: {total_runs} runs, {overall_success_rate}% success, {tasks_completed} tasks completed")
PYTHON_SCRIPT

# Clean up temp file
rm -f "$TMP_DATA"

# Validate JSON
if python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    # Archive today's retrospective
    cp "$OUTPUT_FILE" "$ARCHIVE_DIR/retrospective-$TODAY.json"
    echo "Archived to: $ARCHIVE_DIR/retrospective-$TODAY.json"
else
    echo "Warning: Generated JSON may have syntax errors"
fi
