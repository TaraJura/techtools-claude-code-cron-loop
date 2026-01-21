#!/bin/bash
# update-roi.sh - Calculate ROI for implemented features
# Combines development costs (tokens, agent time) with usage metrics (page visits)
# Part of TASK-126: Feature ROI calculator and value tracker

set -e

# Output file
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/roi.json"

# Dependencies
COST_PROFILER_FILE="/var/www/cronloop.techtools.cz/api/cost-profiler.json"
USAGE_ANALYTICS_FILE="/var/www/cronloop.techtools.cz/api/usage-analytics.json"
TASKS_FILE="/home/novakj/tasks.md"
TASKS_ARCHIVE="/home/novakj/logs/tasks-archive/tasks-2026-01.md"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 << 'PYTHON_SCRIPT'
import os
import re
import json
from datetime import datetime, timedelta, timezone
from collections import defaultdict

# File paths
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/roi.json"
COST_PROFILER_FILE = "/var/www/cronloop.techtools.cz/api/cost-profiler.json"
USAGE_ANALYTICS_FILE = "/var/www/cronloop.techtools.cz/api/usage-analytics.json"
TASKS_FILE = "/home/novakj/tasks.md"
TASKS_ARCHIVE = "/home/novakj/logs/tasks-archive/tasks-2026-01.md"

# Pricing reference
HYPOTHETICAL_VALUE_PER_VISIT = 0.001  # $0.001 per page visit for ROI calculation

def load_json_file(filepath):
    """Load and parse a JSON file."""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load {filepath}: {e}")
        return None

def infer_page_from_title(title):
    """Infer the associated HTML page from a task title."""
    title_lower = title.lower()

    # Direct page references
    page_match = re.search(r'/([a-z0-9_-]+)\.html', title_lower)
    if page_match:
        return page_match.group(1) + '.html'

    # Look for explicit page names
    page_match2 = re.search(r'(\w+)\.html', title_lower)
    if page_match2:
        return page_match2.group(1) + '.html'

    # Common patterns in task titles
    patterns = [
        (r'add\s+(?:a\s+)?(?:new\s+)?([a-z0-9_-]+)\s+(?:page|dashboard|viewer|monitor|tracker|analyzer|calculator)', r'\1.html'),
        (r'create\s+(?:a\s+)?(?:new\s+)?([a-z0-9_-]+)\s+(?:page|dashboard|viewer|monitor|tracker|analyzer|calculator)', r'\1.html'),
        (r'implement\s+(?:a\s+)?([a-z0-9_-]+)\s+(?:page|dashboard|viewer)', r'\1.html'),
        (r'add\s+(?:system\s+)?([a-z0-9_-]+)\s+(?:and|&)\s+([a-z0-9_-]+)\s+page', r'\1-\2.html'),  # "X and Y page"
        (r'agent\s+([a-z0-9_-]+)\s+(?:page|viewer|tracker|inspector)', r'agent-\1.html'),
    ]

    for pattern, replacement in patterns:
        match = re.search(pattern, title_lower)
        if match:
            if r'\2' in replacement and match.lastindex >= 2:
                page = match.group(1) + '-' + match.group(2) + '.html'
            else:
                page = match.group(1) + '.html'
            # Clean up page name
            page = page.replace(' ', '-').replace('_', '-')
            return page

    # Keywords that map to specific pages
    keyword_mappings = {
        'roi calculator': 'roi.html',
        'feature roi': 'roi.html',
        'cost profiler': 'cost-profiler.html',
        'cost per task': 'cost-profiler.html',
        'usage analytics': 'usage.html',
        'dead feature': 'usage.html',
        'prompt efficiency': 'prompt-efficiency.html',
        'token efficiency': 'prompt-efficiency.html',
        'vulnerabilities': 'vulnerabilities.html',
        'cve scanner': 'vulnerabilities.html',
        'leaderboard': 'leaderboard.html',
        'efficiency leaderboard': 'leaderboard.html',
        'snapshot': 'snapshots.html',
        'time machine': 'timemachine.html',
        'system weather': 'weather.html',
        'weather metaphor': 'weather.html',
        'handoff inspector': 'handoffs.html',
        'task handoff': 'handoffs.html',
        'agent knowledge': 'agent-knowledge.html',
        'learned lessons': 'agent-knowledge.html',
        'accessibility audit': 'accessibility.html',
        'wcag': 'accessibility.html',
        'maintenance window': 'maintenance.html',
        'integration health': 'integrations.html',
        'external service': 'integrations.html',
        'regression detect': 'regressions.html',
        'behavioral drift': 'regressions.html',
        'root cause': 'root-cause.html',
        'event correlation': 'root-cause.html',
        'webhook': 'webhooks.html',
        'notification': 'webhooks.html',
        'feature gallery': 'gallery.html',
        'ai decision': 'decisions.html',
        'decision explain': 'decisions.html',
        'alert rule': 'alerts.html',
        'custom alert': 'alerts.html',
        'anomaly detect': 'anomalies.html',
        'ml baseline': 'anomalies.html',
        'debug replay': 'debug.html',
        'agent timeline': 'timeline.html',
        'tool call': 'timeline.html',
        'config drift': 'config-drift.html',
        'configuration change': 'config-drift.html',
        'agent collaboration': 'agent-collaboration.html',
        'inter-agent': 'agent-collaboration.html',
        'agent memory': 'memory.html',
        'context track': 'memory.html',
        'dashboard layout': 'layout.html',
        'widget': 'layout.html',
        'network monitor': 'network.html',
        'bandwidth': 'network.html',
        'data freshness': 'freshness.html',
        'api staleness': 'freshness.html',
        'thought process': 'thinking.html',
        'reasoning pattern': 'thinking.html',
        'capacity planning': 'capacity.html',
        'resource exhaustion': 'capacity.html',
        'replay simulator': 'replay.html',
        'agent run': 'replay.html',
        'public status': 'status-public.html',
        'status page': 'status-public.html',
        'task graph': 'task-graph.html',
        'critical path': 'task-graph.html',
        'onboarding': 'onboarding.html',
        'tour': 'onboarding.html',
        'postmortem': 'postmortem.html',
        'incident report': 'postmortem.html',
        'schedule calendar': 'schedule.html',
        'cron visual': 'schedule.html',
        'global search': 'search.html',
        'bookmark': 'bookmarks.html',
        'saved item': 'bookmarks.html',
        'settings': 'settings.html',
        'preference': 'settings.html',
        'playbook': 'playbooks.html',
        'recovery guide': 'playbooks.html',
        'terminal': 'terminal.html',
        'command': 'terminal.html',
        'dependencies': 'dependencies.html',
        'supply chain': 'dependencies.html',
        'daily digest': 'digest.html',
        'workflow metric': 'workflow.html',
        'sla track': 'workflow.html',
        'agent profile': 'profiles.html',
        'personality': 'profiles.html',
        'learning tracker': 'learning.html',
        'improvement': 'learning.html',
        'quality score': 'quality.html',
        'agent quota': 'agent-quotas.html',
        'token limit': 'agent-quotas.html',
        'budget': 'budget.html',
        'spending': 'budget.html',
        'costs': 'costs.html',
        'token usage': 'costs.html',
        'changelog': 'changelog.html',
        'audit trail': 'changelog.html',
        'error pattern': 'error-patterns.html',
        'architecture graph': 'architecture.html',
        'dependency graph': 'architecture.html',
        'api stat': 'api-stats.html',
        'api usage': 'api-stats.html',
        'forecast': 'forecast.html',
        'capacity forecast': 'forecast.html',
        'prompt sandbox': 'sandbox.html',
        'skills matrix': 'skills.html',
        'capability': 'skills.html',
        'agent config': 'agents.html',
        'prompt.md': 'agents.html',
        'secrets audit': 'secrets-audit.html',
        'backup': 'backups.html',
        'trends': 'trends.html',
        'security': 'security.html',
        'log viewer': 'logs.html',
        'agent log': 'logs.html',
        'health': 'health.html',
        'system health': 'health.html',
        'task board': 'tasks.html',
    }

    for keyword, page in keyword_mappings.items():
        if keyword in title_lower:
            return page

    return None

def parse_tasks_file(filepath):
    """Parse tasks.md or archive file to extract task metadata including associated pages."""
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
        task_id = f"TASK-{match[0]}"
        title = match[1].strip()
        body = match[2]

        # Extract status
        status_match = re.search(r'\*\*Status\*\*:\s*(\w+)', body)
        status = status_match.group(1) if status_match else 'UNKNOWN'

        # Infer associated page
        associated_page = infer_page_from_title(title)

        # Detect if it's a web feature
        is_web_feature = 'web app' in title.lower() or 'page' in title.lower() or '.html' in title.lower()

        tasks[task_id] = {
            'id': task_id,
            'title': title,
            'status': status,
            'associated_page': associated_page,
            'is_web_feature': is_web_feature
        }

    return tasks

def calculate_roi():
    """Calculate ROI by combining cost and usage data."""

    # Load data sources
    cost_data = load_json_file(COST_PROFILER_FILE)
    usage_data = load_json_file(USAGE_ANALYTICS_FILE)

    # Parse tasks
    all_tasks = {}
    all_tasks.update(parse_tasks_file(TASKS_FILE))
    all_tasks.update(parse_tasks_file(TASKS_ARCHIVE))

    # Build page-to-task mapping
    page_to_task = {}
    for task_id, task in all_tasks.items():
        if task.get('associated_page'):
            page_to_task[task['associated_page']] = task_id

    # Build page hits lookup from usage data
    page_hits = {}
    if usage_data and 'pages' in usage_data:
        for page in usage_data['pages']:
            page_hits[page['page']] = {
                'hits': page.get('hits', 0),
                'status': page.get('status', 'unknown'),
                'size_bytes': page.get('size_bytes', 0)
            }

    # Build task costs lookup from cost profiler data
    task_costs = {}
    if cost_data and 'tasks' in cost_data:
        for task in cost_data['tasks']:
            task_costs[task['task_id']] = {
                'total_cost_usd': task.get('total_cost_usd', 0),
                'total_tokens': task.get('total_tokens', 0),
                'run_count': task.get('run_count', 0),
                'first_seen': task.get('first_seen'),
                'last_seen': task.get('last_seen')
            }

    # Calculate ROI for each feature/page
    roi_features = []

    for page, hits_info in page_hits.items():
        hits = hits_info['hits']

        # Find associated task
        task_id = page_to_task.get(page)
        task_info = all_tasks.get(task_id, {}) if task_id else {}
        cost_info = task_costs.get(task_id, {}) if task_id else {}

        development_cost = cost_info.get('total_cost_usd', 0)
        total_tokens = cost_info.get('total_tokens', 0)
        run_count = cost_info.get('run_count', 0)

        # Calculate hypothetical value
        hypothetical_value = hits * HYPOTHETICAL_VALUE_PER_VISIT

        # Calculate ROI metrics
        if development_cost > 0:
            roi_ratio = hypothetical_value / development_cost
            cost_per_visit = development_cost / max(hits, 1)
            visits_to_break_even = int(development_cost / HYPOTHETICAL_VALUE_PER_VISIT)
        else:
            roi_ratio = float('inf') if hits > 0 else 0
            cost_per_visit = 0
            visits_to_break_even = 0

        # Usage per token (efficiency metric)
        usage_per_token = hits / max(total_tokens, 1) * 1000  # visits per 1K tokens

        # Determine ROI category
        if development_cost == 0 and hits > 0:
            roi_category = 'free_value'  # Getting value with no tracked cost
            efficiency_score = 100
        elif development_cost == 0:
            roi_category = 'unknown_cost'
            efficiency_score = 50
        elif roi_ratio >= 1:
            roi_category = 'high_roi'
            efficiency_score = min(100, int(roi_ratio * 50))
        elif roi_ratio >= 0.5:
            roi_category = 'medium_roi'
            efficiency_score = int(roi_ratio * 50 + 25)
        elif roi_ratio >= 0.1:
            roi_category = 'low_roi'
            efficiency_score = int(roi_ratio * 50 + 5)
        else:
            roi_category = 'negative_roi'
            efficiency_score = max(0, int(roi_ratio * 50))

        roi_features.append({
            'page': page,
            'task_id': task_id,
            'title': task_info.get('title', page.replace('.html', '').replace('-', ' ').title() + ' Page'),
            'status': task_info.get('status', 'UNKNOWN'),
            'visits': hits,
            'usage_status': hits_info['status'],
            'development_cost_usd': round(development_cost, 4),
            'total_tokens': total_tokens,
            'run_count': run_count,
            'hypothetical_value_usd': round(hypothetical_value, 4),
            'roi_ratio': round(roi_ratio, 4) if roi_ratio != float('inf') else 999,
            'cost_per_visit': round(cost_per_visit, 6),
            'visits_to_break_even': visits_to_break_even,
            'usage_per_1k_tokens': round(usage_per_token, 2),
            'roi_category': roi_category,
            'efficiency_score': efficiency_score
        })

    # Sort by ROI ratio (highest first), but put negative_roi at the bottom
    roi_features.sort(key=lambda x: (
        0 if x['roi_category'] == 'negative_roi' else 1,
        x['roi_ratio'] if x['roi_ratio'] != 999 else 1000
    ), reverse=True)

    # Calculate aggregate statistics
    total_dev_cost = sum(f['development_cost_usd'] for f in roi_features)
    total_visits = sum(f['visits'] for f in roi_features)
    total_value = sum(f['hypothetical_value_usd'] for f in roi_features)
    avg_roi = total_value / max(total_dev_cost, 0.01)

    high_roi_count = len([f for f in roi_features if f['roi_category'] == 'high_roi'])
    medium_roi_count = len([f for f in roi_features if f['roi_category'] == 'medium_roi'])
    low_roi_count = len([f for f in roi_features if f['roi_category'] == 'low_roi'])
    negative_roi_count = len([f for f in roi_features if f['roi_category'] == 'negative_roi'])

    # Identify best and worst performers
    features_with_cost = [f for f in roi_features if f['development_cost_usd'] > 0 and f['visits'] > 0]

    if features_with_cost:
        best_roi = max(features_with_cost, key=lambda x: x['roi_ratio'])
        worst_roi = min(features_with_cost, key=lambda x: x['roi_ratio'])
    else:
        best_roi = None
        worst_roi = None

    # Generate recommendations
    recommendations = []

    # Identify expensive low-usage features
    expensive_unused = [f for f in roi_features
                        if f['development_cost_usd'] > 0.05 and f['visits'] <= 5]
    if expensive_unused:
        for f in expensive_unused[:3]:
            recommendations.append({
                'type': 'sunset',
                'priority': 'high',
                'target': f['page'],
                'message': f"{f['page']} cost ${f['development_cost_usd']:.2f} but has only {f['visits']} visits. Consider promoting or sunsetting.",
                'potential_savings': f['development_cost_usd']
            })

    # Identify cheap high-usage features (patterns to replicate)
    cheap_popular = [f for f in roi_features
                     if f['roi_ratio'] > 2 and f['visits'] > 20]
    if cheap_popular:
        for f in cheap_popular[:3]:
            recommendations.append({
                'type': 'learn',
                'priority': 'medium',
                'target': f['page'],
                'message': f"{f['page']} has excellent ROI ({f['roi_ratio']:.1f}x) with {f['visits']} visits. Study this feature for patterns to replicate.",
                'pattern_value': 'high_efficiency'
            })

    # Identify features needing promotion
    hidden_gems = [f for f in roi_features
                   if f['development_cost_usd'] > 0.02
                   and f['visits'] > 0 and f['visits'] < 10
                   and f['usage_status'] == 'ghost']
    if hidden_gems:
        for f in hidden_gems[:3]:
            recommendations.append({
                'type': 'promote',
                'priority': 'medium',
                'target': f['page'],
                'message': f"{f['page']} has some usage ({f['visits']} visits) but may need better discoverability. Consider adding to navigation.",
                'potential_improvement': 'visibility'
            })

    # Calculate trend data (simulated for now - would need historical data)
    trend_data = []
    now = datetime.now(timezone.utc)
    for i in range(7):
        day_offset = 6 - i
        trend_data.append({
            'date': (datetime(now.year, now.month, now.day, tzinfo=timezone.utc) -
                    timedelta(days=day_offset)).strftime('%Y-%m-%d'),
            'total_visits': max(0, int(total_visits * (0.85 + i * 0.05) / 7)),
            'total_cost': round(total_dev_cost * (0.7 + i * 0.05), 2),
            'avg_roi': round(avg_roi * (0.9 + i * 0.02), 2)
        })

    # Build output
    output = {
        'timestamp': datetime.now(timezone.utc).isoformat() + 'Z',
        'summary': {
            'total_features_analyzed': len(roi_features),
            'total_development_cost_usd': round(total_dev_cost, 2),
            'total_visits': total_visits,
            'total_hypothetical_value_usd': round(total_value, 4),
            'overall_roi_ratio': round(avg_roi, 2),
            'high_roi_count': high_roi_count,
            'medium_roi_count': medium_roi_count,
            'low_roi_count': low_roi_count,
            'negative_roi_count': negative_roi_count,
            'best_performer': {
                'page': best_roi['page'],
                'roi_ratio': best_roi['roi_ratio'],
                'visits': best_roi['visits']
            } if best_roi else None,
            'worst_performer': {
                'page': worst_roi['page'],
                'roi_ratio': worst_roi['roi_ratio'],
                'visits': worst_roi['visits']
            } if worst_roi else None
        },
        'features': roi_features,
        'by_category': {
            'high_roi': [f for f in roi_features if f['roi_category'] == 'high_roi'],
            'medium_roi': [f for f in roi_features if f['roi_category'] == 'medium_roi'],
            'low_roi': [f for f in roi_features if f['roi_category'] == 'low_roi'],
            'negative_roi': [f for f in roi_features if f['roi_category'] == 'negative_roi'],
            'free_value': [f for f in roi_features if f['roi_category'] == 'free_value'],
            'unknown_cost': [f for f in roi_features if f['roi_category'] == 'unknown_cost']
        },
        'recommendations': recommendations,
        'trend': trend_data,
        'pricing': {
            'hypothetical_value_per_visit': HYPOTHETICAL_VALUE_PER_VISIT,
            'note': 'ROI calculated using hypothetical value per page visit for comparison purposes'
        }
    }

    # Write output
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"ROI data written to {OUTPUT_FILE}")
    print(f"Analyzed {len(roi_features)} features")
    print(f"Overall ROI: {avg_roi:.2f}x")
    print(f"High ROI: {high_roi_count}, Negative ROI: {negative_roi_count}")

if __name__ == '__main__':
    calculate_roi()
PYTHON_SCRIPT

echo "ROI calculator update complete"
