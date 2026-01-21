#!/bin/bash
# update-prompt-efficiency.sh - Analyze token efficiency across task types and agents
# Part of TASK-122: Prompt efficiency analyzer

set -e

# Output file
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/prompt-efficiency.json"

# Create Python script for analysis
python3 << 'PYTHON_SCRIPT'
import os
import re
import json
import glob
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Directories
ACTORS_DIR = "/home/novakj/actors"
TASKS_FILE = "/home/novakj/tasks.md"
TASKS_ARCHIVE = "/home/novakj/logs/tasks-archive/tasks-2026-01.md"
WEB_ROOT = "/var/www/cronloop.techtools.cz"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/prompt-efficiency.json"
COST_DATA_FILE = "/var/www/cronloop.techtools.cz/api/costs.json"

# Pricing (Claude Opus 4.5)
INPUT_PRICE_PER_MILLION = 15.00
OUTPUT_PRICE_PER_MILLION = 75.00
CACHE_READ_PER_MILLION = 1.50
CACHE_WRITE_PER_MILLION = 18.75
AVG_PRICE_PER_TOKEN = (INPUT_PRICE_PER_MILLION + OUTPUT_PRICE_PER_MILLION) / 2 / 1_000_000

# Approximate tokens from file size (4 chars per token estimate)
CHARS_PER_TOKEN = 4

def count_lines_of_code(filepath):
    """Count non-empty, non-comment lines in a file."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        count = 0
        in_comment = False

        for line in lines:
            stripped = line.strip()

            # Skip empty lines
            if not stripped:
                continue

            # Skip comments
            if stripped.startswith('//') or stripped.startswith('#') or stripped.startswith('<!--'):
                continue

            # Skip multi-line comment markers
            if '/*' in stripped:
                in_comment = True
            if '*/' in stripped:
                in_comment = False
                continue
            if in_comment:
                continue

            count += 1

        return count
    except:
        return 0

def get_files_changed_by_git(since_date):
    """Get list of files changed in git since a date."""
    try:
        import subprocess
        result = subprocess.run(
            ['git', '-C', '/home/novakj', 'log', '--since', since_date, '--name-only', '--pretty=format:'],
            capture_output=True, text=True
        )
        files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
        return list(set(files))
    except:
        return []

def count_web_files_loc():
    """Count lines of code in web files."""
    total_loc = 0
    file_counts = {}

    for ext in ['*.html', '*.js', '*.css', '*.json']:
        files = glob.glob(os.path.join(WEB_ROOT, '**', ext), recursive=True)
        for f in files:
            if '/api/' in f and f.endswith('.json'):
                continue  # Skip API data files
            loc = count_lines_of_code(f)
            if loc > 0:
                file_counts[f] = loc
                total_loc += loc

    return total_loc, file_counts

def parse_log_file(log_path):
    """Parse a single log file and extract metrics."""
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        return None

    file_size = len(content)
    estimated_tokens = file_size // CHARS_PER_TOKEN

    # Extract task IDs mentioned
    task_ids = list(set(re.findall(r'TASK-(\d+)', content)))

    # Extract timestamp
    timestamp = None
    timestamp_match = re.search(r'Started: (.+)', content)
    if timestamp_match:
        try:
            timestamp = datetime.strptime(timestamp_match.group(1).strip(), "%a %b %d %H:%M:%S UTC %Y")
        except:
            pass

    # Count tool calls (indicators of token usage)
    tool_calls = len(re.findall(r'(Read|Edit|Write|Bash|Grep|Glob)', content))

    # Detect repetitive patterns (waste indicators)
    repeated_reads = len(re.findall(r'Read.*Read.*Read', content, re.DOTALL)[:10])
    retries = len(re.findall(r'(try again|let me try|attempting again)', content, re.IGNORECASE))

    # Detect successful completion
    success = 'DONE' in content or 'completed' in content.lower() or 'VERIFIED' in content

    return {
        'tokens': estimated_tokens,
        'task_ids': task_ids,
        'timestamp': timestamp,
        'tool_calls': tool_calls,
        'repeated_reads': repeated_reads,
        'retries': retries,
        'success': success,
        'file_size': file_size
    }

def parse_tasks_file(filepath):
    """Parse tasks.md to extract task metadata."""
    tasks = {}
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        return tasks

    task_pattern = r'### TASK-(\d+): (.+?)\n(.*?)(?=### TASK-|\Z)'
    matches = re.findall(task_pattern, content, re.DOTALL)

    for match in matches:
        task_id = match[0]
        title = match[1].strip()
        body = match[2]

        status_match = re.search(r'\*\*Status\*\*:\s*(\w+)', body)
        status = status_match.group(1) if status_match else 'UNKNOWN'

        # Detect task type
        task_type = 'feature'
        title_lower = title.lower()

        if any(x in title_lower for x in ['fix', 'bug', 'error', 'issue']):
            task_type = 'bug_fix'
        elif any(x in title_lower for x in ['document', 'readme', 'doc']):
            task_type = 'documentation'
        elif any(x in title_lower for x in ['refactor', 'cleanup']):
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
            'type': task_type
        }

    return tasks

def analyze_efficiency():
    """Main analysis function."""
    agents = ['developer', 'developer2', 'project-manager', 'tester', 'security', 'idea-maker', 'supervisor']

    # Parse task metadata
    all_tasks = {}
    all_tasks.update(parse_tasks_file(TASKS_FILE))
    all_tasks.update(parse_tasks_file(TASKS_ARCHIVE))

    # Track metrics
    type_metrics = defaultdict(lambda: {
        'total_tokens': 0,
        'total_lines': 0,
        'task_count': 0,
        'successful_tasks': 0,
        'total_tool_calls': 0,
        'total_retries': 0,
        'total_repeated_reads': 0
    })

    agent_metrics = defaultdict(lambda: {
        'total_tokens': 0,
        'total_lines': 0,
        'task_count': 0,
        'successful_tasks': 0,
        'total_cost': 0
    })

    daily_metrics = defaultdict(lambda: {
        'tokens': 0,
        'lines_output': 0,
        'tasks': 0
    })

    # Patterns detected
    waste_patterns = []

    # Cutoff for recent data
    cutoff_date = datetime.now() - timedelta(days=30)

    # Total metrics
    total_tokens = 0
    total_waste_tokens = 0

    # Track task tokens
    task_token_map = defaultdict(int)

    # Scan all logs
    for agent in agents:
        log_dir = os.path.join(ACTORS_DIR, agent, 'logs')
        if not os.path.exists(log_dir):
            continue

        log_files = glob.glob(os.path.join(log_dir, '*.log'))

        for log_path in log_files:
            data = parse_log_file(log_path)
            if not data:
                continue

            if data['timestamp'] and data['timestamp'] < cutoff_date:
                continue

            tokens = data['tokens']
            total_tokens += tokens

            # Track waste from retries and repeated reads
            waste_from_retries = data['retries'] * 500  # Estimate 500 tokens per retry
            waste_from_repeated = data['repeated_reads'] * 1000  # Estimate 1000 tokens per repeated read pattern
            total_waste_tokens += waste_from_retries + waste_from_repeated

            # Update agent metrics
            agent_metrics[agent]['total_tokens'] += tokens
            agent_metrics[agent]['total_cost'] += tokens * AVG_PRICE_PER_TOKEN
            if data['success']:
                agent_metrics[agent]['successful_tasks'] += 1
            agent_metrics[agent]['task_count'] += 1

            # Update daily metrics
            if data['timestamp']:
                date_key = data['timestamp'].strftime('%Y-%m-%d')
                daily_metrics[date_key]['tokens'] += tokens
                daily_metrics[date_key]['tasks'] += 1

            # Track by task type
            for task_id in data['task_ids']:
                task_info = all_tasks.get(task_id, {'type': 'feature'})
                task_type = task_info.get('type', 'feature')

                type_metrics[task_type]['total_tokens'] += tokens
                type_metrics[task_type]['task_count'] += 1
                type_metrics[task_type]['total_tool_calls'] += data['tool_calls']
                type_metrics[task_type]['total_retries'] += data['retries']
                type_metrics[task_type]['total_repeated_reads'] += data['repeated_reads']
                if data['success']:
                    type_metrics[task_type]['successful_tasks'] += 1

                task_token_map[task_id] += tokens

    # Get total LOC in web project
    total_loc, _ = count_web_files_loc()

    # Estimate lines generated (rough estimation based on completed tasks)
    completed_tasks = sum(1 for t in all_tasks.values() if t.get('status') in ['DONE', 'VERIFIED'])
    estimated_lines_per_task = 150  # Conservative estimate
    estimated_total_lines = completed_tasks * estimated_lines_per_task

    # Update type metrics with line estimates
    for task_type, metrics in type_metrics.items():
        if metrics['task_count'] > 0:
            # Estimate lines based on task type
            lines_factor = {
                'web_feature': 200,
                'feature': 150,
                'bug_fix': 50,
                'script': 100,
                'documentation': 80,
                'security': 60,
                'configuration': 30,
                'refactoring': 120,
                'testing': 80
            }
            metrics['total_lines'] = metrics['task_count'] * lines_factor.get(task_type, 100)

    # Update agent metrics with line estimates
    for agent, metrics in agent_metrics.items():
        if agent in ['developer', 'developer2']:
            metrics['total_lines'] = metrics['task_count'] * 180
        elif agent == 'idea-maker':
            metrics['total_lines'] = metrics['task_count'] * 50
        elif agent == 'project-manager':
            metrics['total_lines'] = metrics['task_count'] * 30
        else:
            metrics['total_lines'] = metrics['task_count'] * 60

    # Update daily metrics with line estimates
    for date_key, metrics in daily_metrics.items():
        metrics['lines_output'] = metrics['tasks'] * 100  # Average lines per task

    # Calculate efficiency scores
    def calc_efficiency_score(tokens, lines, success_rate):
        """Calculate efficiency score (0-100)."""
        if tokens == 0 or lines == 0:
            return 50

        tokens_per_loc = tokens / max(lines, 1)

        # Ideal is around 50-100 tokens per line
        if tokens_per_loc <= 50:
            base_score = 95
        elif tokens_per_loc <= 100:
            base_score = 85
        elif tokens_per_loc <= 200:
            base_score = 70
        elif tokens_per_loc <= 500:
            base_score = 55
        else:
            base_score = 40

        # Adjust for success rate
        score = base_score * (0.7 + 0.3 * success_rate)

        return min(100, max(0, round(score)))

    # Process type efficiency
    by_type = {}
    total_type_lines = sum(m['total_lines'] for m in type_metrics.values())
    total_type_tokens = sum(m['total_tokens'] for m in type_metrics.values())

    for task_type, metrics in type_metrics.items():
        if metrics['total_tokens'] > 0:
            success_rate = metrics['successful_tasks'] / max(metrics['task_count'], 1)
            tokens_per_loc = metrics['total_tokens'] / max(metrics['total_lines'], 1)
            eff_score = calc_efficiency_score(metrics['total_tokens'], metrics['total_lines'], success_rate)

            by_type[task_type] = {
                'task_count': metrics['task_count'],
                'total_tokens': metrics['total_tokens'],
                'total_lines': metrics['total_lines'],
                'tokens_per_loc': round(tokens_per_loc, 2),
                'success_rate': round(success_rate * 100, 1),
                'efficiency_score': eff_score,
                'avg_tokens_per_task': round(metrics['total_tokens'] / max(metrics['task_count'], 1)),
                'retries_per_task': round(metrics['total_retries'] / max(metrics['task_count'], 1), 2)
            }

    # Process agent efficiency
    by_agent = {}
    for agent, metrics in agent_metrics.items():
        if metrics['total_tokens'] > 0:
            success_rate = metrics['successful_tasks'] / max(metrics['task_count'], 1)
            tokens_per_loc = metrics['total_tokens'] / max(metrics['total_lines'], 1)
            eff_score = calc_efficiency_score(metrics['total_tokens'], metrics['total_lines'], success_rate)

            by_agent[agent] = {
                'task_count': metrics['task_count'],
                'total_tokens': metrics['total_tokens'],
                'total_lines': metrics['total_lines'],
                'tokens_per_loc': round(tokens_per_loc, 2),
                'efficiency_score': eff_score,
                'avg_cost_per_task': round(metrics['total_cost'] / max(metrics['task_count'], 1), 4)
            }

    # Build daily trend (last 7 days)
    daily_trend = []
    for i in range(7):
        date = (datetime.now() - timedelta(days=6-i)).strftime('%Y-%m-%d')
        if date in daily_metrics:
            daily_trend.append({
                'date': date,
                'tokens': daily_metrics[date]['tokens'],
                'lines_output': daily_metrics[date]['lines_output'],
                'efficiency': calc_efficiency_score(
                    daily_metrics[date]['tokens'],
                    daily_metrics[date]['lines_output'],
                    0.8
                )
            })
        else:
            daily_trend.append({
                'date': date,
                'tokens': 0,
                'lines_output': 0,
                'efficiency': 50
            })

    # Detect patterns
    patterns = []

    # Check for high retry rates
    for task_type, metrics in type_metrics.items():
        if metrics['task_count'] > 0:
            retry_rate = metrics['total_retries'] / metrics['task_count']
            if retry_rate > 2:
                patterns.append({
                    'id': 'excessive_retries',
                    'type': 'waste',
                    'title': f'High Retry Rate in {task_type.replace("_", " ").title()}',
                    'description': f'{task_type.replace("_", " ").title()} tasks average {retry_rate:.1f} retries each, wasting tokens on repeated attempts.',
                    'impact': f'{int(retry_rate * metrics["task_count"] * 500)}',
                    'impact_type': 'waste',
                    'impact_label': 'tokens wasted'
                })

    # Check for inefficient task types
    for task_type, metrics in by_type.items():
        if metrics['tokens_per_loc'] > 500 and metrics['task_count'] >= 3:
            patterns.append({
                'id': 'low_efficiency',
                'type': 'insight',
                'title': f'{task_type.replace("_", " ").title()} Tasks Are Token-Heavy',
                'description': f'This task type uses {metrics["tokens_per_loc"]:.0f} tokens per line of code, significantly above the ideal range of 50-100.',
                'impact': f'{metrics["efficiency_score"]}',
                'impact_type': 'waste',
                'impact_label': 'efficiency score'
                })

    # Check for developer differences
    if 'developer' in by_agent and 'developer2' in by_agent:
        dev1 = by_agent['developer']
        dev2 = by_agent['developer2']

        if abs(dev1['tokens_per_loc'] - dev2['tokens_per_loc']) > 50:
            more_efficient = 'developer' if dev1['tokens_per_loc'] < dev2['tokens_per_loc'] else 'developer2'
            less_efficient = 'developer2' if more_efficient == 'developer' else 'developer'
            patterns.append({
                'id': 'agent_variance',
                'type': 'insight',
                'title': 'Developer Efficiency Variance',
                'description': f'{more_efficient} is more token-efficient ({by_agent[more_efficient]["tokens_per_loc"]:.0f} tok/LOC) than {less_efficient} ({by_agent[less_efficient]["tokens_per_loc"]:.0f} tok/LOC). Consider sharing techniques.',
                'impact': f'{abs(dev1["tokens_per_loc"] - dev2["tokens_per_loc"]):.0f}',
                'impact_type': 'savings',
                'impact_label': 'tok/LOC gap'
            })

    # Generate recommendations
    recommendations = []

    # Find most inefficient type
    if by_type:
        worst_type = max(by_type.items(), key=lambda x: x[1]['tokens_per_loc'])
        if worst_type[1]['tokens_per_loc'] > 200:
            potential_savings = (worst_type[1]['tokens_per_loc'] - 100) * worst_type[1]['total_lines']
            recommendations.append({
                'id': 'prompt_shortening',
                'title': f'Optimize {worst_type[0].replace("_", " ").title()} Prompts',
                'description': f'Reducing token usage for {worst_type[0].replace("_", " ")} tasks from {worst_type[1]["tokens_per_loc"]:.0f} to 100 tokens/LOC could save significant costs.',
                'priority': 'high' if worst_type[1]['task_count'] > 10 else 'medium',
                'potential_token_savings': int(potential_savings * 0.5),
                'potential_cost_savings': round(potential_savings * 0.5 * AVG_PRICE_PER_TOKEN, 2),
                'efficiency_gain': min(30, int((worst_type[1]['tokens_per_loc'] - 100) / 10))
            })

    # Check for caching opportunities
    if total_waste_tokens > 10000:
        recommendations.append({
            'id': 'caching',
            'title': 'Reduce Redundant File Reads',
            'description': 'Analysis shows repeated file reads and retries. Consider caching frequently accessed context or improving task specifications.',
            'priority': 'medium',
            'potential_token_savings': int(total_waste_tokens * 0.7),
            'potential_cost_savings': round(total_waste_tokens * 0.7 * AVG_PRICE_PER_TOKEN, 2),
            'efficiency_gain': 15
        })

    # Token budget recommendation
    if total_tokens > 100000:
        avg_per_task = total_tokens / max(completed_tasks, 1)
        if avg_per_task > 5000:
            recommendations.append({
                'id': 'token_budget',
                'title': 'Set Per-Task Token Budgets',
                'description': f'Tasks average {avg_per_task:.0f} tokens. Setting a 4000-token budget per task could improve efficiency.',
                'priority': 'low',
                'potential_token_savings': int((avg_per_task - 4000) * completed_tasks * 0.3),
                'potential_cost_savings': round((avg_per_task - 4000) * completed_tasks * 0.3 * AVG_PRICE_PER_TOKEN, 2),
                'efficiency_gain': 10
            })

    # Calculate overall efficiency
    overall_tokens_per_loc = total_tokens / max(estimated_total_lines, 1)
    overall_efficiency_score = calc_efficiency_score(total_tokens, estimated_total_lines, 0.85)

    # Calculate trend (compare last 3 days to previous 4 days)
    recent_tokens = sum(d['tokens'] for d in daily_trend[-3:])
    older_tokens = sum(d['tokens'] for d in daily_trend[:4])
    recent_lines = sum(d['lines_output'] for d in daily_trend[-3:])
    older_lines = sum(d['lines_output'] for d in daily_trend[:4])

    recent_efficiency = recent_tokens / max(recent_lines, 1)
    older_efficiency = older_tokens / max(older_lines, 1)

    if older_efficiency > 0:
        trend_change = ((older_efficiency - recent_efficiency) / older_efficiency) * 100
    else:
        trend_change = 0

    # Potential savings
    potential_savings = (overall_tokens_per_loc - 100) * estimated_total_lines * AVG_PRICE_PER_TOKEN * 0.3

    # Efficiency message
    if overall_efficiency_score >= 85:
        efficiency_message = "Token usage is highly optimized. The system efficiently converts tokens to code output."
    elif overall_efficiency_score >= 70:
        efficiency_message = "Good efficiency with room for improvement. Consider the optimization recommendations below."
    elif overall_efficiency_score >= 50:
        efficiency_message = "Moderate efficiency. Several optimization opportunities identified in the patterns section."
    else:
        efficiency_message = "Low efficiency detected. Significant token waste identified. Review recommendations urgently."

    # Build output
    output = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'summary': {
            'efficiency_score': overall_efficiency_score,
            'efficiency_message': efficiency_message,
            'tokens_per_loc': round(overall_tokens_per_loc, 2),
            'total_tokens': total_tokens,
            'total_lines_output': estimated_total_lines,
            'waste_tokens': total_waste_tokens,
            'efficiency_trend': round(trend_change, 1),
            'potential_savings_usd': round(max(0, potential_savings), 2)
        },
        'daily_trend': daily_trend,
        'by_type': by_type,
        'by_agent': by_agent,
        'patterns': patterns[:10],
        'recommendations': recommendations[:5],
        'pricing': {
            'model': 'claude-opus-4-5-20251101',
            'avg_price_per_token': round(AVG_PRICE_PER_TOKEN * 1_000_000, 4)
        }
    }

    # Write output
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Prompt efficiency data written to {OUTPUT_FILE}")
    print(f"Overall efficiency score: {overall_efficiency_score}/100")
    print(f"Tokens per LOC: {overall_tokens_per_loc:.1f}")

if __name__ == '__main__':
    analyze_efficiency()
PYTHON_SCRIPT

echo "Prompt efficiency update complete"
