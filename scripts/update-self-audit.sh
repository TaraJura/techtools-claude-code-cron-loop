#!/bin/bash
# update-self-audit.sh - Track self-modifying changes to system configuration files
# Part of TASK-130: System self-modification audit trail

set -e

# Output file
OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/self-audit.json"

# Create Python script for analysis
python3 << 'PYTHON_SCRIPT'
import os
import re
import json
import subprocess
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Directories and files
HOME_DIR = "/home/novakj"
WEB_ROOT = "/var/www/cronloop.techtools.cz"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/self-audit.json"

# Define critical self-defining files
SELF_DEFINING_FILES = {
    'CLAUDE.md': {
        'path': 'CLAUDE.md',
        'type': 'core_rules',
        'description': 'Core system rules and instructions',
        'risk': 'critical'
    },
    'actors/idea-maker/prompt.md': {
        'path': 'actors/idea-maker/prompt.md',
        'type': 'agent_prompt',
        'description': 'Idea Maker agent behavior',
        'risk': 'high'
    },
    'actors/project-manager/prompt.md': {
        'path': 'actors/project-manager/prompt.md',
        'type': 'agent_prompt',
        'description': 'Project Manager agent behavior',
        'risk': 'high'
    },
    'actors/developer/prompt.md': {
        'path': 'actors/developer/prompt.md',
        'type': 'agent_prompt',
        'description': 'Developer agent behavior',
        'risk': 'high'
    },
    'actors/developer2/prompt.md': {
        'path': 'actors/developer2/prompt.md',
        'type': 'agent_prompt',
        'description': 'Developer 2 agent behavior',
        'risk': 'high'
    },
    'actors/tester/prompt.md': {
        'path': 'actors/tester/prompt.md',
        'type': 'agent_prompt',
        'description': 'Tester agent behavior',
        'risk': 'high'
    },
    'actors/security/prompt.md': {
        'path': 'actors/security/prompt.md',
        'type': 'agent_prompt',
        'description': 'Security agent behavior',
        'risk': 'high'
    },
    'actors/supervisor/prompt.md': {
        'path': 'actors/supervisor/prompt.md',
        'type': 'agent_prompt',
        'description': 'Supervisor agent behavior',
        'risk': 'high'
    },
    'scripts/cron-orchestrator.sh': {
        'path': 'scripts/cron-orchestrator.sh',
        'type': 'execution_logic',
        'description': 'Main orchestrator execution',
        'risk': 'critical'
    },
    'scripts/run-actor.sh': {
        'path': 'scripts/run-actor.sh',
        'type': 'execution_logic',
        'description': 'Agent execution wrapper',
        'risk': 'critical'
    },
    'scripts/maintenance.sh': {
        'path': 'scripts/maintenance.sh',
        'type': 'execution_logic',
        'description': 'System maintenance scripts',
        'risk': 'high'
    },
    'docs/autonomous-system.md': {
        'path': 'docs/autonomous-system.md',
        'type': 'documentation',
        'description': 'Autonomous system documentation',
        'risk': 'medium'
    },
    'docs/server-config.md': {
        'path': 'docs/server-config.md',
        'type': 'documentation',
        'description': 'Server configuration docs',
        'risk': 'medium'
    },
    'docs/security-guide.md': {
        'path': 'docs/security-guide.md',
        'type': 'documentation',
        'description': 'Security guidelines',
        'risk': 'high'
    },
    'docs/engine-guide.md': {
        'path': 'docs/engine-guide.md',
        'type': 'documentation',
        'description': 'Engine and recovery procedures',
        'risk': 'medium'
    },
    'tasks.md': {
        'path': 'tasks.md',
        'type': 'task_board',
        'description': 'Shared task board',
        'risk': 'medium'
    }
}

# Content changes (normal development)
CONTENT_FILE_PATTERNS = [
    r'^var/www/',
    r'^projects/',
    r'\.html$',
    r'\.js$',
    r'\.css$'
]

def run_git_command(cmd, cwd=HOME_DIR):
    """Run a git command and return output."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd
        )
        return result.stdout.strip()
    except Exception as e:
        return ""

def get_git_log_for_file(filepath, since_days=30):
    """Get git log for a specific file."""
    since_date = (datetime.now() - timedelta(days=since_days)).strftime('%Y-%m-%d')

    cmd = [
        'git', 'log',
        '--since', since_date,
        '--format=%H|%an|%ae|%ai|%s',
        '--follow',
        '--', filepath
    ]

    output = run_git_command(cmd)
    commits = []

    for line in output.split('\n'):
        if '|' in line:
            parts = line.split('|', 4)
            if len(parts) >= 5:
                commits.append({
                    'hash': parts[0][:8],
                    'full_hash': parts[0],
                    'author': parts[1],
                    'email': parts[2],
                    'date': parts[3][:10],
                    'time': parts[3][11:19],
                    'message': parts[4]
                })

    return commits

def get_file_diff(commit_hash, filepath):
    """Get the diff for a file in a specific commit."""
    cmd = [
        'git', 'show',
        '--format=',
        '--stat',
        commit_hash,
        '--', filepath
    ]

    output = run_git_command(cmd)

    # Parse stats
    additions = 0
    deletions = 0

    stat_match = re.search(r'(\d+) insertion', output)
    if stat_match:
        additions = int(stat_match.group(1))

    stat_match = re.search(r'(\d+) deletion', output)
    if stat_match:
        deletions = int(stat_match.group(1))

    return {
        'additions': additions,
        'deletions': deletions,
        'net_change': additions - deletions
    }

def get_full_diff(commit_hash, filepath):
    """Get the actual diff content for a file."""
    cmd = [
        'git', 'show',
        '--format=',
        '-p',
        commit_hash,
        '--', filepath
    ]

    output = run_git_command(cmd)

    # Limit diff size
    lines = output.split('\n')
    if len(lines) > 100:
        lines = lines[:100] + ['... (truncated)']

    return '\n'.join(lines)

def extract_agent_from_commit(commit_msg):
    """Extract agent name from commit message."""
    # Pattern: [agent-name] message
    match = re.match(r'\[(\w+(?:-\w+)?)\]', commit_msg)
    if match:
        return match.group(1)
    return 'unknown'

def analyze_change_type(filepath, diff_content, commit_msg):
    """Analyze what type of change was made."""
    change_types = []

    msg_lower = commit_msg.lower()

    # Check commit message
    if 'self-improvement' in msg_lower or 'learned' in msg_lower:
        change_types.append('learning')
    if 'fix' in msg_lower or 'bug' in msg_lower:
        change_types.append('bug_fix')
    if 'security' in msg_lower:
        change_types.append('security')
    if 'revert' in msg_lower:
        change_types.append('revert')
    if 'refactor' in msg_lower:
        change_types.append('refactoring')

    # Analyze content if it's a prompt file
    if 'prompt.md' in filepath:
        if 'LEARNED' in diff_content or 'Lessons Learned' in diff_content:
            change_types.append('lesson_learned')
        if '+## ' in diff_content or '+### ' in diff_content:
            change_types.append('section_added')
        if '-## ' in diff_content or '-### ' in diff_content:
            change_types.append('section_removed')

    # Check for rule changes
    if '+- **' in diff_content or '+- [ ]' in diff_content:
        change_types.append('rule_added')
    if '-- **' in diff_content or '-- [ ]' in diff_content:
        change_types.append('rule_removed')

    if not change_types:
        change_types.append('content_update')

    return change_types

def calculate_risk_score(file_info, diff_stats, change_types):
    """Calculate risk score for a change (0-100)."""
    base_risk = {
        'critical': 80,
        'high': 60,
        'medium': 40,
        'low': 20
    }

    score = base_risk.get(file_info.get('risk', 'medium'), 40)

    # Adjust based on change size
    net_change = abs(diff_stats.get('net_change', 0))
    if net_change > 100:
        score += 15
    elif net_change > 50:
        score += 10
    elif net_change > 20:
        score += 5

    # Adjust based on change types
    if 'security' in change_types:
        score += 10
    if 'rule_removed' in change_types:
        score += 10
    if 'revert' in change_types:
        score += 5
    if 'learning' in change_types or 'lesson_learned' in change_types:
        score -= 5  # Learning is generally positive

    return min(100, max(0, score))

def get_prompt_metrics(filepath):
    """Get metrics for a prompt file."""
    try:
        full_path = os.path.join(HOME_DIR, filepath)
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # Count various metrics
        lines = content.split('\n')
        word_count = len(content.split())

        # Count rules (lines starting with - or *)
        rule_count = len([l for l in lines if l.strip().startswith(('-', '*', '1.', '2.', '3.'))])

        # Count sections
        section_count = len([l for l in lines if l.startswith('#')])

        # Check for lessons learned
        lessons_match = re.findall(r'\*\*LEARNED.*?\*\*:.*', content, re.IGNORECASE)
        lessons_count = len(lessons_match)

        return {
            'lines': len(lines),
            'words': word_count,
            'rules': rule_count,
            'sections': section_count,
            'lessons_learned': lessons_count,
            'size_kb': round(len(content) / 1024, 2)
        }
    except:
        return None

def extract_lessons_learned():
    """Extract lessons learned from all prompt files."""
    lessons = []

    for name, info in SELF_DEFINING_FILES.items():
        if info['type'] != 'agent_prompt':
            continue

        filepath = os.path.join(HOME_DIR, info['path'])
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            # Find lessons learned section
            match = re.search(r'## Lessons Learned(.*?)(?=##|\Z)', content, re.DOTALL)
            if match:
                section = match.group(1)
                # Extract individual lessons
                lesson_matches = re.findall(r'-\s*\*\*LEARNED.*?\*\*:?\s*(.*?)(?=\n-|\Z)', section, re.DOTALL)
                for lesson in lesson_matches:
                    lessons.append({
                        'agent': name.replace('actors/', '').replace('/prompt.md', ''),
                        'lesson': lesson.strip()[:200],  # Truncate
                        'source': name
                    })
        except:
            pass

    return lessons

def analyze_self_modifications():
    """Main analysis function."""

    # Track all modifications
    modifications = []
    by_file = defaultdict(list)
    by_agent = defaultdict(list)
    by_type = defaultdict(list)

    # Current prompt metrics
    prompt_drift = {}

    # Process each self-defining file
    for name, info in SELF_DEFINING_FILES.items():
        filepath = info['path']

        # Get current metrics if it's a prompt
        if info['type'] == 'agent_prompt':
            metrics = get_prompt_metrics(filepath)
            if metrics:
                agent_name = filepath.replace('actors/', '').replace('/prompt.md', '')
                prompt_drift[agent_name] = {
                    'current': metrics,
                    'trend': 'stable'  # Will be calculated from history
                }

        # Get commits for this file
        commits = get_git_log_for_file(filepath, since_days=30)

        for commit in commits:
            # Get diff stats
            diff_stats = get_file_diff(commit['full_hash'], filepath)

            # Get actual diff (truncated)
            diff_content = get_full_diff(commit['full_hash'], filepath)

            # Extract agent
            agent = extract_agent_from_commit(commit['message'])

            # Analyze change type
            change_types = analyze_change_type(filepath, diff_content, commit['message'])

            # Calculate risk
            risk_score = calculate_risk_score(info, diff_stats, change_types)

            modification = {
                'id': f"{commit['hash']}-{filepath.replace('/', '-')[:30]}",
                'file': filepath,
                'file_type': info['type'],
                'file_description': info['description'],
                'file_risk_level': info['risk'],
                'commit_hash': commit['hash'],
                'date': commit['date'],
                'time': commit['time'],
                'agent': agent,
                'message': commit['message'],
                'additions': diff_stats['additions'],
                'deletions': diff_stats['deletions'],
                'net_change': diff_stats['net_change'],
                'change_types': change_types,
                'risk_score': risk_score,
                'diff_preview': diff_content[:500] if diff_content else ''
            }

            modifications.append(modification)
            by_file[filepath].append(modification)
            by_agent[agent].append(modification)
            for ct in change_types:
                by_type[ct].append(modification)

    # Sort modifications by date descending
    modifications.sort(key=lambda x: f"{x['date']} {x['time']}", reverse=True)

    # Calculate stability score (inverse of modification frequency)
    total_changes = len(modifications)
    recent_changes = sum(1 for m in modifications if m['date'] >= (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d'))

    if recent_changes == 0:
        stability_score = 100
    elif recent_changes <= 5:
        stability_score = 90
    elif recent_changes <= 10:
        stability_score = 75
    elif recent_changes <= 20:
        stability_score = 60
    else:
        stability_score = max(30, 100 - recent_changes * 2)

    # Count by risk level
    risk_counts = {
        'critical': sum(1 for m in modifications if m['file_risk_level'] == 'critical'),
        'high': sum(1 for m in modifications if m['file_risk_level'] == 'high'),
        'medium': sum(1 for m in modifications if m['file_risk_level'] == 'medium'),
        'low': sum(1 for m in modifications if m['file_risk_level'] == 'low')
    }

    # Identify risky changes (risk_score > 70)
    risky_changes = [m for m in modifications if m['risk_score'] > 70]

    # Get lessons learned
    lessons = extract_lessons_learned()

    # Calculate agent self-modification stats
    agent_stats = {}
    for agent, mods in by_agent.items():
        if agent == 'unknown':
            continue
        agent_stats[agent] = {
            'total_changes': len(mods),
            'files_modified': len(set(m['file'] for m in mods)),
            'avg_risk_score': round(sum(m['risk_score'] for m in mods) / len(mods), 1) if mods else 0,
            'most_changed_file': max(set(m['file'] for m in mods), key=lambda f: sum(1 for m2 in mods if m2['file'] == f)) if mods else None
        }

    # File-level stats
    file_stats = {}
    for filepath, mods in by_file.items():
        file_stats[filepath] = {
            'change_count': len(mods),
            'agents_involved': list(set(m['agent'] for m in mods if m['agent'] != 'unknown')),
            'total_additions': sum(m['additions'] for m in mods),
            'total_deletions': sum(m['deletions'] for m in mods),
            'avg_risk_score': round(sum(m['risk_score'] for m in mods) / len(mods), 1) if mods else 0,
            'last_modified': mods[0]['date'] if mods else None
        }

    # Sort file_stats by change_count
    file_stats = dict(sorted(file_stats.items(), key=lambda x: x[1]['change_count'], reverse=True))

    # Generate recommendations
    recommendations = []

    # Check for frequently changing files
    for filepath, stats in file_stats.items():
        if stats['change_count'] > 5:
            info = SELF_DEFINING_FILES.get(filepath, {})
            if info.get('risk') == 'critical':
                recommendations.append({
                    'id': f'frequent_critical_{filepath[:20]}',
                    'priority': 'high',
                    'title': f'Frequent changes to critical file: {filepath}',
                    'description': f'This critical file has been modified {stats["change_count"]} times in the last 30 days. Consider whether these changes are necessary.',
                    'file': filepath
                })

    # Check for agents modifying their own prompts
    for mod in modifications:
        if mod['file'].endswith('prompt.md'):
            agent_in_file = mod['file'].replace('actors/', '').replace('/prompt.md', '')
            if mod['agent'] == agent_in_file:
                recommendations.append({
                    'id': f'self_prompt_mod_{mod["commit_hash"]}',
                    'priority': 'medium',
                    'title': f'Agent modified own prompt: {mod["agent"]}',
                    'description': f'{mod["agent"]} agent modified its own prompt.md file. Review to ensure the change is appropriate.',
                    'file': mod['file'],
                    'date': mod['date']
                })

    # Deduplicate recommendations
    seen_titles = set()
    unique_recommendations = []
    for rec in recommendations:
        if rec['title'] not in seen_titles:
            seen_titles.add(rec['title'])
            unique_recommendations.append(rec)

    # Calculate overall governance status
    if stability_score >= 85 and risk_counts['critical'] <= 2:
        governance_status = 'healthy'
        governance_message = 'System configuration is stable with controlled self-modifications.'
    elif stability_score >= 60 and risk_counts['critical'] <= 5:
        governance_status = 'monitoring'
        governance_message = 'System is actively evolving. Monitor critical file changes.'
    else:
        governance_status = 'attention'
        governance_message = 'High frequency of self-modifications detected. Review changes for stability.'

    # Build output
    output = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'summary': {
            'stability_score': stability_score,
            'governance_status': governance_status,
            'governance_message': governance_message,
            'total_modifications': total_changes,
            'modifications_this_week': recent_changes,
            'tracked_files': len(SELF_DEFINING_FILES),
            'risk_counts': risk_counts,
            'risky_changes_count': len(risky_changes)
        },
        'modifications': modifications[:50],  # Last 50 modifications
        'risky_changes': risky_changes[:10],  # Top 10 risky changes
        'by_agent': agent_stats,
        'by_file': file_stats,
        'prompt_drift': prompt_drift,
        'lessons_learned': lessons[:20],  # Last 20 lessons
        'recommendations': unique_recommendations[:10],
        'tracked_files': {k: v for k, v in SELF_DEFINING_FILES.items()}
    }

    # Write output
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Self-audit data written to {OUTPUT_FILE}")
    print(f"Stability score: {stability_score}/100 ({governance_status})")
    print(f"Total modifications tracked: {total_changes}")

if __name__ == '__main__':
    analyze_self_modifications()
PYTHON_SCRIPT

echo "Self-audit update complete"
