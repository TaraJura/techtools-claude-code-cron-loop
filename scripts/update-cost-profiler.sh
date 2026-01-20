#!/bin/bash
# update-cost-profiler.sh - Analyze agent logs and correlate costs with specific tasks
# Part of TASK-101: Agent cost-per-task profiler

set -e

# Output file
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/cost-profiler.json"

# Directories
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"
TASKS_ARCHIVE="/home/novakj/logs/tasks-archive/tasks-2026-01.md"

# Pricing (from Claude Opus 4.5 pricing)
INPUT_PRICE_PER_MILLION=15.00
OUTPUT_PRICE_PER_MILLION=75.00
CACHE_READ_PER_MILLION=1.50
CACHE_WRITE_PER_MILLION=18.75

# Estimate tokens from log file size (approximate)
# Claude Code logs are approximately 4 chars per token
CHARS_PER_TOKEN=4

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +"%Y-%m-%d")

# Create Python script for more complex analysis
python3 << 'PYTHON_SCRIPT'
import os
import re
import json
import glob
from datetime import datetime, timedelta
from collections import defaultdict

# Directories
ACTORS_DIR = "/home/novakj/actors"
TASKS_FILE = "/home/novakj/tasks.md"
TASKS_ARCHIVE = "/home/novakj/logs/tasks-archive/tasks-2026-01.md"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/cost-profiler.json"

# Pricing
INPUT_PRICE_PER_MILLION = 15.00
OUTPUT_PRICE_PER_MILLION = 75.00
CACHE_READ_PER_MILLION = 1.50
CACHE_WRITE_PER_MILLION = 18.75
AVG_PRICE_PER_TOKEN = (INPUT_PRICE_PER_MILLION + OUTPUT_PRICE_PER_MILLION) / 2 / 1_000_000

# Approximate tokens from file size (4 chars per token estimate)
CHARS_PER_TOKEN = 4

def parse_log_file(log_path):
    """Parse a single log file and extract task references and metrics."""
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        return None, [], 0

    # Extract task IDs mentioned
    task_ids = list(set(re.findall(r'TASK-(\d+)', content)))

    # Estimate tokens from file size
    file_size = len(content)
    estimated_tokens = file_size // CHARS_PER_TOKEN

    # Extract timestamp from log
    timestamp_match = re.search(r'Started: (.+)', content)
    timestamp = None
    if timestamp_match:
        try:
            timestamp = datetime.strptime(timestamp_match.group(1).strip(), "%a %b %d %H:%M:%S UTC %Y")
        except:
            pass

    # Detect if task was completed
    completed = 'Status: DONE' in content or 'Completed:' in content or 'completed' in content.lower()

    return timestamp, task_ids, estimated_tokens

def parse_tasks_file(filepath):
    """Parse tasks.md or archive file to extract task metadata."""
    tasks = {}
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        return tasks

    # Parse task blocks
    task_pattern = r'### TASK-(\d+): (.+?)\n(.*?)(?=### TASK-|\Z)'
    matches = re.findall(task_pattern, content, re.DOTALL)

    for match in matches:
        task_id = match[0]
        title = match[1].strip()
        body = match[2]

        # Extract status
        status_match = re.search(r'\*\*Status\*\*:\s*(\w+)', body)
        status = status_match.group(1) if status_match else 'UNKNOWN'

        # Extract priority
        priority_match = re.search(r'\*\*Priority\*\*:\s*(\w+)', body)
        priority = priority_match.group(1) if priority_match else 'MEDIUM'

        # Detect task type from title and description
        task_type = 'feature'  # default
        title_lower = title.lower()
        body_lower = body.lower()

        if any(x in title_lower for x in ['fix', 'bug', 'error', 'issue']):
            task_type = 'bug_fix'
        elif any(x in title_lower for x in ['document', 'readme', 'doc']):
            task_type = 'documentation'
        elif any(x in title_lower for x in ['refactor', 'cleanup', 'clean up']):
            task_type = 'refactoring'
        elif any(x in title_lower for x in ['security', 'audit', 'vulnerability']):
            task_type = 'security'
        elif any(x in title_lower for x in ['test', 'testing']):
            task_type = 'testing'
        elif any(x in title_lower for x in ['config', 'setting', 'setup']):
            task_type = 'configuration'
        elif any(x in title_lower for x in ['script', 'utility', 'tool']):
            task_type = 'script'
        elif 'web app' in title_lower or 'page' in title_lower or 'dashboard' in title_lower:
            task_type = 'web_feature'

        tasks[task_id] = {
            'id': f'TASK-{task_id}',
            'title': title,
            'status': status,
            'priority': priority,
            'type': task_type
        }

    return tasks

def analyze_logs():
    """Analyze all agent logs and correlate with tasks."""
    agents = ['developer', 'developer2', 'project-manager', 'tester', 'security', 'idea-maker', 'supervisor']

    # Track cost per task
    task_costs = defaultdict(lambda: {
        'total_tokens': 0,
        'total_cost': 0,
        'runs': [],
        'agents_involved': set(),
        'first_seen': None,
        'last_seen': None,
        'run_count': 0
    })

    # Track agent involvement
    agent_task_stats = defaultdict(lambda: defaultdict(lambda: {'tokens': 0, 'runs': 0}))

    # Scan all logs from last 30 days
    cutoff_date = datetime.now() - timedelta(days=30)

    for agent in agents:
        log_dir = os.path.join(ACTORS_DIR, agent, 'logs')
        if not os.path.exists(log_dir):
            continue

        log_files = glob.glob(os.path.join(log_dir, '*.log'))

        for log_path in log_files:
            timestamp, task_ids, tokens = parse_log_file(log_path)

            if timestamp and timestamp < cutoff_date:
                continue

            log_name = os.path.basename(log_path)
            cost = tokens * AVG_PRICE_PER_TOKEN

            for task_id in task_ids:
                task_costs[task_id]['total_tokens'] += tokens
                task_costs[task_id]['total_cost'] += cost
                task_costs[task_id]['run_count'] += 1
                task_costs[task_id]['agents_involved'].add(agent)
                task_costs[task_id]['runs'].append({
                    'agent': agent,
                    'log': log_name,
                    'tokens': tokens,
                    'cost': round(cost, 4),
                    'timestamp': timestamp.isoformat() if timestamp else None
                })

                if timestamp:
                    if task_costs[task_id]['first_seen'] is None or timestamp < datetime.fromisoformat(task_costs[task_id]['first_seen']):
                        task_costs[task_id]['first_seen'] = timestamp.isoformat()
                    if task_costs[task_id]['last_seen'] is None or timestamp > datetime.fromisoformat(task_costs[task_id]['last_seen']):
                        task_costs[task_id]['last_seen'] = timestamp.isoformat()

                # Track per-agent stats
                agent_task_stats[agent][task_id]['tokens'] += tokens
                agent_task_stats[agent][task_id]['runs'] += 1

    return task_costs, agent_task_stats

def main():
    # Parse task metadata
    all_tasks = {}
    all_tasks.update(parse_tasks_file(TASKS_FILE))
    all_tasks.update(parse_tasks_file(TASKS_ARCHIVE))

    # Analyze logs
    task_costs, agent_task_stats = analyze_logs()

    # Build output data
    tasks_with_costs = []

    for task_id, cost_data in task_costs.items():
        task_info = all_tasks.get(task_id, {
            'id': f'TASK-{task_id}',
            'title': 'Unknown Task',
            'status': 'UNKNOWN',
            'priority': 'MEDIUM',
            'type': 'feature'
        })

        tasks_with_costs.append({
            'task_id': f'TASK-{task_id}',
            'title': task_info.get('title', 'Unknown'),
            'status': task_info.get('status', 'UNKNOWN'),
            'priority': task_info.get('priority', 'MEDIUM'),
            'type': task_info.get('type', 'feature'),
            'total_tokens': cost_data['total_tokens'],
            'total_cost_usd': round(cost_data['total_cost'], 4),
            'run_count': cost_data['run_count'],
            'agents_involved': list(cost_data['agents_involved']),
            'first_seen': cost_data['first_seen'],
            'last_seen': cost_data['last_seen'],
            'cost_per_run': round(cost_data['total_cost'] / max(cost_data['run_count'], 1), 4),
            'runs': sorted(cost_data['runs'], key=lambda x: x['timestamp'] or '', reverse=True)[:10]
        })

    # Sort by total cost (highest first)
    tasks_with_costs.sort(key=lambda x: x['total_cost_usd'], reverse=True)

    # Calculate aggregates by type
    type_costs = defaultdict(lambda: {'count': 0, 'total_tokens': 0, 'total_cost': 0, 'avg_cost': 0})
    for task in tasks_with_costs:
        task_type = task['type']
        type_costs[task_type]['count'] += 1
        type_costs[task_type]['total_tokens'] += task['total_tokens']
        type_costs[task_type]['total_cost'] += task['total_cost_usd']

    for task_type in type_costs:
        if type_costs[task_type]['count'] > 0:
            type_costs[task_type]['avg_cost'] = round(
                type_costs[task_type]['total_cost'] / type_costs[task_type]['count'], 4
            )
        type_costs[task_type]['total_cost'] = round(type_costs[task_type]['total_cost'], 4)

    # Calculate agent contribution breakdown
    agent_contributions = {}
    for agent, tasks in agent_task_stats.items():
        total_tokens = sum(t['tokens'] for t in tasks.values())
        total_runs = sum(t['runs'] for t in tasks.values())
        total_cost = total_tokens * AVG_PRICE_PER_TOKEN
        agent_contributions[agent] = {
            'total_tokens': total_tokens,
            'total_cost_usd': round(total_cost, 4),
            'total_runs': total_runs,
            'task_count': len(tasks)
        }

    # Find outliers (tasks costing significantly more than average)
    if tasks_with_costs:
        avg_cost = sum(t['total_cost_usd'] for t in tasks_with_costs) / len(tasks_with_costs)
        outliers = [t for t in tasks_with_costs if t['total_cost_usd'] > avg_cost * 2]
    else:
        avg_cost = 0
        outliers = []

    # Generate recommendations
    recommendations = []

    if outliers:
        recommendations.append({
            'type': 'outlier',
            'message': f'{len(outliers)} tasks cost more than 2x the average (${round(avg_cost, 2)}). Consider breaking complex tasks into smaller pieces.',
            'severity': 'warning'
        })

    # Check for high rework
    high_rework = [t for t in tasks_with_costs if t['run_count'] > 5]
    if high_rework:
        recommendations.append({
            'type': 'rework',
            'message': f'{len(high_rework)} tasks required more than 5 runs. Clearer task descriptions may reduce rework costs.',
            'severity': 'info'
        })

    # Check for most expensive type
    if type_costs:
        expensive_type = max(type_costs.items(), key=lambda x: x[1]['avg_cost'])
        recommendations.append({
            'type': 'pattern',
            'message': f'{expensive_type[0].replace("_", " ").title()} tasks cost ${round(expensive_type[1]["avg_cost"], 2)} on average - the most expensive category.',
            'severity': 'info'
        })

    # Build final output
    output = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'summary': {
            'total_tasks_analyzed': len(tasks_with_costs),
            'total_tokens_spent': sum(t['total_tokens'] for t in tasks_with_costs),
            'total_cost_usd': round(sum(t['total_cost_usd'] for t in tasks_with_costs), 4),
            'avg_cost_per_task': round(avg_cost, 4),
            'most_expensive_task': tasks_with_costs[0]['task_id'] if tasks_with_costs else None,
            'most_expensive_cost': tasks_with_costs[0]['total_cost_usd'] if tasks_with_costs else 0
        },
        'tasks': tasks_with_costs[:50],  # Top 50 most expensive
        'by_type': dict(type_costs),
        'by_agent': agent_contributions,
        'outliers': [{'task_id': t['task_id'], 'title': t['title'], 'cost': t['total_cost_usd']} for t in outliers[:10]],
        'recommendations': recommendations,
        'pricing': {
            'model': 'claude-opus-4-5-20251101',
            'input_per_million': INPUT_PRICE_PER_MILLION,
            'output_per_million': OUTPUT_PRICE_PER_MILLION,
            'estimated_avg_per_token': round(AVG_PRICE_PER_TOKEN * 1_000_000, 4)
        }
    }

    # Write output
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Cost profiler data written to {OUTPUT_FILE}")
    print(f"Analyzed {len(tasks_with_costs)} tasks with total cost ${output['summary']['total_cost_usd']}")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

echo "Cost profiler update complete"
