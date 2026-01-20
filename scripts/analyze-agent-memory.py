#!/usr/bin/env python3
"""
Analyze agent memory patterns by parsing Claude Code JSONL conversation logs.
Tracks which files each agent reads and their reading patterns over time.
"""

import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict
import re

# Agent detection patterns based on system prompts
AGENT_PATTERNS = {
    'idea-maker': ['Idea Maker', 'idea-maker', 'Feature ideation', 'Generate feature ideas'],
    'project-manager': ['Project Manager', 'project-manager', 'Task assignment', 'Assign tasks'],
    'developer': ['Developer Agent', 'developer agent', 'Primary feature implementation', 'Assigned: developer'],
    'developer2': ['developer2', 'Developer 2', 'Secondary feature implementation', 'Assigned: developer2'],
    'tester': ['Tester', 'tester', 'Quality assurance', 'verification'],
    'security': ['Security', 'security', 'Security review', 'vulnerability'],
    'supervisor': ['Supervisor', 'supervisor', 'ecosystem oversight', 'Monitors all agents']
}

# File categories for classification
FILE_CATEGORIES = {
    'core': ['CLAUDE.md', 'tasks.md', 'README.md'],
    'docs': ['.md', '/docs/'],
    'config': ['.json', '.yml', '.yaml', '.env', '.sh'],
    'web': ['.html', '.css', '.js', '/var/www/'],
    'logs': ['.log', '/logs/', 'cron.log'],
    'prompts': ['prompt.md', '/actors/'],
    'status': ['/status/', 'system.json', 'security.json'],
    'api': ['/api/']
}

def detect_agent(session_content):
    """Detect which agent a session belongs to based on prompt content."""
    if not session_content:
        return None

    content_lower = session_content.lower()

    # Check for specific agent markers
    for agent, patterns in AGENT_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in content_lower:
                # Special case: distinguish developer from developer2
                if agent == 'developer' and 'developer2' in content_lower:
                    continue
                if agent == 'developer' and 'assigned: developer2' in content_lower:
                    continue
                return agent

    return None

def categorize_file(file_path):
    """Categorize a file based on its path."""
    file_path_lower = file_path.lower()

    for category, patterns in FILE_CATEGORIES.items():
        for pattern in patterns:
            if pattern in file_path_lower:
                return category

    return 'other'

def parse_jsonl_file(filepath):
    """Parse a JSONL file and extract Read tool calls with their context."""
    reads = []
    session_prompt = ""

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    entry = json.loads(line.strip())

                    # Extract the initial prompt for agent detection
                    if entry.get('type') == 'user' and not session_prompt:
                        msg = entry.get('message', {})
                        content = msg.get('content', '')
                        if isinstance(content, str):
                            session_prompt = content[:5000]  # First 5000 chars

                    # Look for Read tool calls in assistant messages
                    if entry.get('type') == 'assistant':
                        msg = entry.get('message', {})
                        content = msg.get('content', [])

                        if isinstance(content, list):
                            for block in content:
                                if isinstance(block, dict) and block.get('type') == 'tool_use':
                                    if block.get('name') == 'Read':
                                        input_data = block.get('input', {})
                                        file_path = input_data.get('file_path', '')
                                        if file_path:
                                            timestamp = entry.get('timestamp', '')
                                            reads.append({
                                                'file_path': file_path,
                                                'timestamp': timestamp,
                                                'category': categorize_file(file_path)
                                            })

                except json.JSONDecodeError:
                    continue

    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
        return None, []

    agent = detect_agent(session_prompt)
    return agent, reads

def analyze_sessions():
    """Analyze all session files and aggregate data by agent."""
    sessions_dir = '/home/novakj/.claude/projects/-home-novakj/'

    agent_data = defaultdict(lambda: {
        'total_reads': 0,
        'unique_files': set(),
        'file_frequencies': defaultdict(int),
        'category_counts': defaultdict(int),
        'first_reads': {},
        'recent_reads': [],
        'sessions_analyzed': 0,
        'hourly_activity': defaultdict(int)
    })

    # Get all JSONL files sorted by modification time (newest first)
    jsonl_files = glob.glob(os.path.join(sessions_dir, '*.jsonl'))
    jsonl_files.sort(key=os.path.getmtime, reverse=True)

    # Limit to recent sessions for performance
    jsonl_files = jsonl_files[:200]

    for filepath in jsonl_files:
        agent, reads = parse_jsonl_file(filepath)

        if agent and reads:
            data = agent_data[agent]
            data['sessions_analyzed'] += 1

            for read in reads:
                file_path = read['file_path']
                timestamp = read['timestamp']
                category = read['category']

                data['total_reads'] += 1
                data['unique_files'].add(file_path)
                data['file_frequencies'][file_path] += 1
                data['category_counts'][category] += 1

                # Track first read time for each file
                if file_path not in data['first_reads']:
                    data['first_reads'][file_path] = timestamp

                # Track recent reads
                data['recent_reads'].append({
                    'file': file_path,
                    'time': timestamp
                })

                # Hourly activity
                if timestamp:
                    try:
                        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        hour = dt.hour
                        data['hourly_activity'][hour] += 1
                    except:
                        pass

    return agent_data

def build_output(agent_data):
    """Build the JSON output structure."""
    output = {
        'generated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'agents': {}
    }

    # Core files that should be read by most agents
    core_files = set(['CLAUDE.md', '/home/novakj/CLAUDE.md', '/home/novakj/tasks.md', 'tasks.md'])

    # Cross-agent file overlap analysis
    all_files = defaultdict(list)

    for agent, data in agent_data.items():
        # Sort files by frequency
        top_files = sorted(
            data['file_frequencies'].items(),
            key=lambda x: x[1],
            reverse=True
        )[:20]

        # Detect expertise areas based on most-read categories
        category_list = sorted(
            data['category_counts'].items(),
            key=lambda x: x[1],
            reverse=True
        )

        # Recent reads (last 50)
        recent = sorted(
            data['recent_reads'],
            key=lambda x: x['time'] if x['time'] else '',
            reverse=True
        )[:50]

        # Build file overlap data
        for file_path in data['unique_files']:
            all_files[file_path].append(agent)

        # Knowledge gaps - check if core files are being read
        knowledge_gaps = []
        if 'CLAUDE.md' not in str(data['unique_files']) and '/home/novakj/CLAUDE.md' not in str(data['unique_files']):
            knowledge_gaps.append('CLAUDE.md (core instructions)')
        if 'tasks.md' not in str(data['unique_files']) and '/home/novakj/tasks.md' not in str(data['unique_files']):
            if agent not in ['security', 'supervisor']:  # These may not need tasks.md
                knowledge_gaps.append('tasks.md (task board)')

        output['agents'][agent] = {
            'total_reads': data['total_reads'],
            'unique_files_count': len(data['unique_files']),
            'sessions_analyzed': data['sessions_analyzed'],
            'top_files': [
                {
                    'path': path,
                    'reads': count,
                    'category': categorize_file(path)
                }
                for path, count in top_files
            ],
            'expertise_areas': [
                {
                    'category': cat,
                    'read_count': count,
                    'percentage': round(count / data['total_reads'] * 100, 1) if data['total_reads'] > 0 else 0
                }
                for cat, count in category_list[:6]
            ],
            'recent_reads': [
                {'file': r['file'], 'time': r['time'][:19] if r['time'] else 'unknown'}
                for r in recent[:20]
            ],
            'hourly_activity': {str(h): c for h, c in sorted(data['hourly_activity'].items())},
            'knowledge_gaps': knowledge_gaps,
            'first_reads_count': len(data['first_reads'])
        }

    # Cross-agent overlap analysis
    shared_files = []
    agent_only_files = defaultdict(list)

    for file_path, agents in all_files.items():
        if len(agents) > 1:
            shared_files.append({
                'file': file_path,
                'agents': agents,
                'category': categorize_file(file_path)
            })
        elif len(agents) == 1:
            agent_only_files[agents[0]].append(file_path)

    output['cross_agent_analysis'] = {
        'shared_knowledge': sorted(shared_files, key=lambda x: len(x['agents']), reverse=True)[:30],
        'agent_specific_knowledge': {
            agent: paths[:10]
            for agent, paths in agent_only_files.items()
        },
        'total_unique_files': len(all_files)
    }

    return output

def main():
    print("Analyzing agent memory patterns...")

    agent_data = analyze_sessions()

    if not agent_data:
        print("No agent sessions found")
        # Create empty output
        output = {
            'generated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            'agents': {},
            'cross_agent_analysis': {
                'shared_knowledge': [],
                'agent_specific_knowledge': {},
                'total_unique_files': 0
            },
            'note': 'No session data available yet'
        }
    else:
        print(f"Found data for agents: {list(agent_data.keys())}")
        output = build_output(agent_data)

    # Write output
    output_path = '/var/www/cronloop.techtools.cz/api/agent-memory.json'
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Output written to {output_path}")

    # Summary
    for agent, data in agent_data.items():
        print(f"  {agent}: {data['total_reads']} reads, {len(data['unique_files'])} unique files")

if __name__ == '__main__':
    main()
