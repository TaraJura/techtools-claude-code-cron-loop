#!/bin/bash
# update-resource-profile.sh - Profile resource consumption per agent execution
# Part of TASK-107: Agent resource consumption profiler

set -e

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/resource-profile.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/resource-profile-history.json"
ACTORS_DIR="/home/novakj/actors"

python3 << 'PYTHON_SCRIPT'
import os
import re
import json
import glob
from datetime import datetime, timedelta
from collections import defaultdict
import subprocess

ACTORS_DIR = "/home/novakj/actors"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/resource-profile.json"
HISTORY_FILE = "/var/www/cronloop.techtools.cz/api/resource-profile-history.json"
AGENTS = ['developer', 'developer2', 'project-manager', 'tester', 'security', 'idea-maker', 'supervisor']

def get_system_baseline():
    """Get current system resource baseline."""
    try:
        # Get memory info
        with open('/proc/meminfo', 'r') as f:
            meminfo = f.read()
        total_mem = int(re.search(r'MemTotal:\s+(\d+)', meminfo).group(1))
        avail_mem = int(re.search(r'MemAvailable:\s+(\d+)', meminfo).group(1))

        # Get CPU count
        cpu_count = os.cpu_count() or 1

        # Get load average
        with open('/proc/loadavg', 'r') as f:
            load = float(f.read().split()[0])

        return {
            'total_memory_mb': total_mem // 1024,
            'available_memory_mb': avail_mem // 1024,
            'cpu_count': cpu_count,
            'load_avg': load
        }
    except Exception as e:
        return {'error': str(e)}

def parse_log_file(log_path):
    """Parse a log file to extract timing and resource estimates."""
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception:
        return None

    # Extract start and end times
    start_match = re.search(r'Started: (.+)', content)
    end_match = re.search(r'Completed: (.+)', content)

    start_time = None
    end_time = None
    duration_seconds = None

    if start_match:
        try:
            start_time = datetime.strptime(start_match.group(1).strip(), "%a %b %d %H:%M:%S UTC %Y")
        except:
            pass

    if end_match:
        try:
            end_time = datetime.strptime(end_match.group(1).strip(), "%a %b %d %H:%M:%S UTC %Y")
        except:
            pass

    if start_time and end_time:
        duration_seconds = (end_time - start_time).total_seconds()

    # Estimate resource usage from log characteristics
    file_size = len(content)
    lines = len(content.split('\n'))

    # Detect expensive operations from log content
    operations = []

    # Git operations
    git_ops = len(re.findall(r'git (diff|log|status|add|commit|push)', content, re.IGNORECASE))
    if git_ops > 0:
        operations.append({'type': 'git', 'count': git_ops, 'estimated_memory_mb': git_ops * 50})

    # File reads (Read tool)
    file_reads = len(re.findall(r'Read tool|Reading file|file_path', content, re.IGNORECASE))
    if file_reads > 0:
        operations.append({'type': 'file_read', 'count': file_reads, 'estimated_memory_mb': file_reads * 5})

    # File writes (Edit/Write tools)
    file_writes = len(re.findall(r'Write tool|Edit tool|Writing to|Editing|updated successfully', content, re.IGNORECASE))
    if file_writes > 0:
        operations.append({'type': 'file_write', 'count': file_writes, 'estimated_memory_mb': file_writes * 2})

    # Bash commands
    bash_cmds = len(re.findall(r'Bash command|Executing|subprocess|npm|python3', content, re.IGNORECASE))
    if bash_cmds > 0:
        operations.append({'type': 'bash', 'count': bash_cmds, 'estimated_memory_mb': bash_cmds * 30})

    # Search operations (Grep/Glob)
    searches = len(re.findall(r'Grep tool|Glob tool|searching|matches found', content, re.IGNORECASE))
    if searches > 0:
        operations.append({'type': 'search', 'count': searches, 'estimated_memory_mb': searches * 10})

    # Estimate total memory based on operations
    estimated_memory_mb = sum(op.get('estimated_memory_mb', 0) for op in operations)
    # Add base memory for Claude Code process (estimate ~200MB base)
    estimated_memory_mb += 200

    # Estimate CPU based on duration and operation count
    total_ops = sum(op.get('count', 0) for op in operations)
    estimated_cpu_percent = min(100, 10 + total_ops * 2)  # Base 10% + 2% per operation

    # Estimate disk I/O
    estimated_disk_read_mb = file_reads * 0.5  # ~500KB per file read on average
    estimated_disk_write_mb = file_writes * 0.1 + (file_size / 1024 / 1024)  # Files + log itself

    # Detect task IDs
    task_ids = list(set(re.findall(r'TASK-(\d+)', content)))

    return {
        'start_time': start_time.isoformat() if start_time else None,
        'end_time': end_time.isoformat() if end_time else None,
        'duration_seconds': duration_seconds,
        'log_size_bytes': file_size,
        'log_lines': lines,
        'estimated_peak_memory_mb': estimated_memory_mb,
        'estimated_cpu_percent': estimated_cpu_percent,
        'estimated_disk_read_mb': round(estimated_disk_read_mb, 2),
        'estimated_disk_write_mb': round(estimated_disk_write_mb, 2),
        'operations': operations,
        'total_operations': total_ops,
        'task_ids': task_ids
    }

def analyze_agent_logs(agent, days=7):
    """Analyze logs for a specific agent over the past N days."""
    log_dir = os.path.join(ACTORS_DIR, agent, 'logs')
    if not os.path.exists(log_dir):
        return None

    cutoff = datetime.now() - timedelta(days=days)
    runs = []

    log_files = sorted(glob.glob(os.path.join(log_dir, '*.log')), reverse=True)

    for log_path in log_files[:100]:  # Limit to last 100 logs
        result = parse_log_file(log_path)
        if not result:
            continue

        # Check if within time window
        if result['start_time']:
            log_time = datetime.fromisoformat(result['start_time'])
            if log_time < cutoff:
                continue

        result['log_file'] = os.path.basename(log_path)
        runs.append(result)

    if not runs:
        return None

    # Calculate aggregates
    durations = [r['duration_seconds'] for r in runs if r['duration_seconds']]
    memories = [r['estimated_peak_memory_mb'] for r in runs]
    cpus = [r['estimated_cpu_percent'] for r in runs]
    disk_reads = [r['estimated_disk_read_mb'] for r in runs]
    disk_writes = [r['estimated_disk_write_mb'] for r in runs]

    return {
        'agent': agent,
        'total_runs': len(runs),
        'avg_duration_seconds': round(sum(durations) / len(durations), 1) if durations else None,
        'max_duration_seconds': max(durations) if durations else None,
        'min_duration_seconds': min(durations) if durations else None,
        'avg_memory_mb': round(sum(memories) / len(memories), 1) if memories else None,
        'max_memory_mb': max(memories) if memories else None,
        'avg_cpu_percent': round(sum(cpus) / len(cpus), 1) if cpus else None,
        'max_cpu_percent': max(cpus) if cpus else None,
        'total_disk_read_mb': round(sum(disk_reads), 2),
        'total_disk_write_mb': round(sum(disk_writes), 2),
        'avg_disk_read_mb': round(sum(disk_reads) / len(disk_reads), 2) if disk_reads else 0,
        'avg_disk_write_mb': round(sum(disk_writes) / len(disk_writes), 2) if disk_writes else 0,
        'recent_runs': runs[:10]  # Include last 10 runs for detail view
    }

def identify_expensive_operations():
    """Identify the most resource-expensive operations across all agents."""
    all_operations = defaultdict(lambda: {'count': 0, 'total_memory': 0, 'agents': set()})

    for agent in AGENTS:
        log_dir = os.path.join(ACTORS_DIR, agent, 'logs')
        if not os.path.exists(log_dir):
            continue

        log_files = sorted(glob.glob(os.path.join(log_dir, '*.log')), reverse=True)[:20]

        for log_path in log_files:
            result = parse_log_file(log_path)
            if not result:
                continue

            for op in result.get('operations', []):
                op_type = op['type']
                all_operations[op_type]['count'] += op.get('count', 0)
                all_operations[op_type]['total_memory'] += op.get('estimated_memory_mb', 0)
                all_operations[op_type]['agents'].add(agent)

    # Convert to list
    operations_list = []
    for op_type, data in all_operations.items():
        operations_list.append({
            'operation': op_type,
            'total_count': data['count'],
            'total_memory_mb': data['total_memory'],
            'avg_memory_per_op': round(data['total_memory'] / max(data['count'], 1), 2),
            'used_by_agents': list(data['agents'])
        })

    # Sort by total memory usage
    operations_list.sort(key=lambda x: x['total_memory_mb'], reverse=True)
    return operations_list

def detect_anomalies(agent_profiles):
    """Detect agents with anomalous resource usage."""
    anomalies = []

    if len(agent_profiles) < 2:
        return anomalies

    # Calculate averages across all agents
    all_durations = [p['avg_duration_seconds'] for p in agent_profiles if p and p.get('avg_duration_seconds')]
    all_memories = [p['avg_memory_mb'] for p in agent_profiles if p and p.get('avg_memory_mb')]

    if not all_durations or not all_memories:
        return anomalies

    avg_duration = sum(all_durations) / len(all_durations)
    avg_memory = sum(all_memories) / len(all_memories)

    for profile in agent_profiles:
        if not profile:
            continue

        # Check for duration anomaly (>2x average)
        if profile.get('avg_duration_seconds') and profile['avg_duration_seconds'] > avg_duration * 2:
            anomalies.append({
                'agent': profile['agent'],
                'type': 'duration',
                'severity': 'warning',
                'message': f"{profile['agent']} takes {profile['avg_duration_seconds']:.0f}s on average (2x+ the {avg_duration:.0f}s average)",
                'value': profile['avg_duration_seconds'],
                'expected': avg_duration
            })

        # Check for memory anomaly (>2x average)
        if profile.get('avg_memory_mb') and profile['avg_memory_mb'] > avg_memory * 2:
            anomalies.append({
                'agent': profile['agent'],
                'type': 'memory',
                'severity': 'warning',
                'message': f"{profile['agent']} uses ~{profile['avg_memory_mb']:.0f}MB on average (2x+ the {avg_memory:.0f}MB average)",
                'value': profile['avg_memory_mb'],
                'expected': avg_memory
            })

    return anomalies

def generate_recommendations(agent_profiles, expensive_ops):
    """Generate optimization recommendations based on analysis."""
    recommendations = []

    # Check for expensive git operations
    git_op = next((op for op in expensive_ops if op['operation'] == 'git'), None)
    if git_op and git_op['total_count'] > 50:
        recommendations.append({
            'type': 'optimization',
            'priority': 'medium',
            'title': 'Reduce git operation frequency',
            'description': f"Detected {git_op['total_count']} git operations using ~{git_op['total_memory_mb']}MB. Consider batching git commands.",
            'affected_agents': git_op['used_by_agents']
        })

    # Check for long-running agents
    for profile in agent_profiles:
        if not profile:
            continue
        if profile.get('avg_duration_seconds') and profile['avg_duration_seconds'] > 300:
            recommendations.append({
                'type': 'performance',
                'priority': 'high',
                'title': f"Optimize {profile['agent']} execution time",
                'description': f"{profile['agent']} averages {profile['avg_duration_seconds']:.0f}s per run. Consider reducing scope or parallelizing operations.",
                'affected_agents': [profile['agent']]
            })

    # Check for high disk I/O
    for profile in agent_profiles:
        if not profile:
            continue
        if profile.get('avg_disk_write_mb') and profile['avg_disk_write_mb'] > 5:
            recommendations.append({
                'type': 'io',
                'priority': 'low',
                'title': f"High disk write activity for {profile['agent']}",
                'description': f"{profile['agent']} writes ~{profile['avg_disk_write_mb']:.1f}MB per run on average.",
                'affected_agents': [profile['agent']]
            })

    return recommendations

def main():
    timestamp = datetime.utcnow().isoformat() + 'Z'

    # Get system baseline
    system_baseline = get_system_baseline()

    # Analyze each agent
    agent_profiles = []
    for agent in AGENTS:
        profile = analyze_agent_logs(agent)
        if profile:
            agent_profiles.append(profile)

    # Identify expensive operations
    expensive_ops = identify_expensive_operations()

    # Detect anomalies
    anomalies = detect_anomalies(agent_profiles)

    # Generate recommendations
    recommendations = generate_recommendations(agent_profiles, expensive_ops)

    # Calculate summary statistics
    total_runs = sum(p['total_runs'] for p in agent_profiles if p)
    total_memory_used = sum(p.get('avg_memory_mb', 0) * p.get('total_runs', 0) for p in agent_profiles if p)
    total_disk_written = sum(p.get('total_disk_write_mb', 0) for p in agent_profiles if p)

    # Find most/least resource-intensive agents
    sorted_by_memory = sorted([p for p in agent_profiles if p], key=lambda x: x.get('avg_memory_mb', 0), reverse=True)
    sorted_by_duration = sorted([p for p in agent_profiles if p], key=lambda x: x.get('avg_duration_seconds', 0) or 0, reverse=True)

    output = {
        'timestamp': timestamp,
        'analysis_period_days': 7,
        'system_baseline': system_baseline,
        'summary': {
            'total_agent_runs': total_runs,
            'total_estimated_memory_mb': round(total_memory_used, 1),
            'total_disk_written_mb': round(total_disk_written, 2),
            'most_memory_intensive': sorted_by_memory[0]['agent'] if sorted_by_memory else None,
            'longest_running': sorted_by_duration[0]['agent'] if sorted_by_duration else None,
            'anomaly_count': len(anomalies),
            'recommendation_count': len(recommendations)
        },
        'agents': agent_profiles,
        'expensive_operations': expensive_ops[:10],
        'anomalies': anomalies,
        'recommendations': recommendations
    }

    # Write output
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    # Update history (keep last 24 hours of snapshots)
    history = []
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f:
                history = json.load(f)
        except:
            pass

    # Add summary snapshot to history
    history.append({
        'timestamp': timestamp,
        'total_runs': total_runs,
        'avg_memory_mb': round(sum(p.get('avg_memory_mb', 0) for p in agent_profiles if p) / len(agent_profiles), 1) if agent_profiles else 0,
        'anomaly_count': len(anomalies)
    })

    # Keep only last 48 entries (24 hours at 30-min intervals)
    history = history[-48:]

    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)

    print(f"Resource profile updated: {len(agent_profiles)} agents, {total_runs} runs analyzed")
    print(f"Found {len(anomalies)} anomalies and generated {len(recommendations)} recommendations")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

echo "Resource profile update complete"
