#!/bin/bash
# update-decisions.sh - Extract and analyze AI decision patterns from agent logs
# Created by developer2 agent for TASK-054
# This script parses agent conversation data to extract decision points,
# categorize them, and calculate decision quality metrics.

set -e

# Configuration
CHAT_JSON="/var/www/cronloop.techtools.cz/api/agent-chat.json"
TIMELINE_JSON="/var/www/cronloop.techtools.cz/api/timeline.json"
OUTPUT_JSON="/var/www/cronloop.techtools.cz/api/decisions.json"
LOGS_DIR="/home/novakj/actors"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Starting decision extraction..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Python3 is required but not installed"
    exit 1
fi

# Python script to extract and analyze decisions
python3 << 'PYTHON_SCRIPT'
import json
import os
import re
from datetime import datetime
from collections import defaultdict

# Configuration
CHAT_JSON = "/var/www/cronloop.techtools.cz/api/agent-chat.json"
TIMELINE_JSON = "/var/www/cronloop.techtools.cz/api/timeline.json"
OUTPUT_JSON = "/var/www/cronloop.techtools.cz/api/decisions.json"

# Agent configuration
AGENT_CONFIG = {
    'idea-maker': {'name': 'Idea Maker', 'emoji': '💡', 'color': '#eab308'},
    'project-manager': {'name': 'Project Manager', 'emoji': '📋', 'color': '#a855f7'},
    'developer': {'name': 'Developer', 'emoji': '👨‍💻', 'color': '#3b82f6'},
    'developer2': {'name': 'Developer 2', 'emoji': '👩‍💻', 'color': '#06b6d4'},
    'tester': {'name': 'Tester', 'emoji': '🧪', 'color': '#22c55e'},
    'security': {'name': 'Security', 'emoji': '🛡️', 'color': '#ef4444'},
    'supervisor': {'name': 'Supervisor', 'emoji': '👁️', 'color': '#64748b'}
}

# Decision categories
CATEGORIES = [
    'task-interpretation',
    'tool-selection',
    'file-targeting',
    'code-approach',
    'error-handling'
]

def load_json(filepath):
    """Load JSON file safely"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Warning: Could not load {filepath}: {e}")
        return None

def extract_task_interpretation(content, summary, tasks):
    """Extract task interpretation decision"""
    if summary and len(summary) > 10:
        return summary[:100] + ('...' if len(summary) > 100 else '')

    lines = [l.strip() for l in content.split('\n') if l.strip()]
    for line in lines:
        if 'TASK-' in line or 'implement' in line.lower() or 'complete' in line.lower():
            return line[:100] + ('...' if len(line) > 100 else '')

    return 'Interpreted task requirements'

def extract_reasoning(content, decision_type):
    """Extract reasoning from content"""
    patterns = [
        r'because\s+(.+?)(?:\.|$)',
        r'since\s+(.+?)(?:\.|$)',
        r'to\s+(.+?)(?:\.|$)',
        r'in order to\s+(.+?)(?:\.|$)'
    ]

    for pattern in patterns:
        match = re.search(pattern, content, re.IGNORECASE)
        if match:
            return match.group(1)[:150]

    return None

def calculate_confidence(content, decision_type):
    """Calculate confidence score based on language patterns"""
    high_confidence = ['definitely', 'certainly', 'clearly', 'obviously', 'must', 'should']
    medium_confidence = ['probably', 'likely', 'seems', 'appears']
    low_confidence = ['might', 'could', 'possibly', 'maybe', 'perhaps']

    content_lower = content.lower()
    score = 70  # Base confidence

    for word in high_confidence:
        if word in content_lower:
            score += 10
    for word in low_confidence:
        if word in content_lower:
            score -= 15

    return max(20, min(100, score))

def determine_outcome(message):
    """Determine the outcome of a decision"""
    content = (message.get('content') or '').lower()
    test_results = message.get('test_results', [])

    # Check test results
    for result in test_results:
        if result.get('result') == 'pass':
            return 'success'
        if result.get('result') == 'fail':
            return 'failure'

    # Check content for outcome indicators
    if any(word in content for word in ['completed', 'success', 'verified', 'pass']):
        return 'success'
    if any(word in content for word in ['failed', 'error', 'failure']):
        return 'failure'

    return 'unknown'

def extract_decisions_from_message(message):
    """Extract all decisions from a single message"""
    decisions = []
    content = message.get('content', '')
    summary = message.get('summary', '')
    tasks = message.get('tasks', [])
    files_created = message.get('files_created', [])
    files_modified = message.get('files_modified', [])
    agent = message.get('agent', 'unknown')
    timestamp = message.get('timestamp', '')
    msg_id = message.get('id', str(hash(timestamp + agent)))

    # Task interpretation decisions
    if tasks or 'task' in content.lower() or 'implement' in content.lower():
        task_match = re.search(r'TASK-(\d+)', content, re.IGNORECASE)
        if task_match or tasks:
            decisions.append({
                'id': f"{msg_id}_task",
                'agent': agent,
                'timestamp': timestamp,
                'category': 'task-interpretation',
                'summary': extract_task_interpretation(content, summary, tasks),
                'reasoning': extract_reasoning(content, 'task'),
                'confidence': calculate_confidence(content, 'task'),
                'taskId': f"TASK-{task_match.group(1)}" if task_match else (tasks[0] if tasks else None),
                'outcome': determine_outcome(message)
            })

    # Tool selection decisions
    tool_patterns = [
        (r'Read|read the file|reading', 'Read'),
        (r'Edit|edited|editing|modified', 'Edit'),
        (r'Write|wrote|writing|created', 'Write'),
        (r'Bash|command|running|executed', 'Bash'),
        (r'Grep|search|searching|found', 'Grep'),
        (r'Glob|files matching|pattern', 'Glob')
    ]

    for pattern, tool in tool_patterns:
        if re.search(pattern, content, re.IGNORECASE):
            decisions.append({
                'id': f"{msg_id}_tool_{tool}",
                'agent': agent,
                'timestamp': timestamp,
                'category': 'tool-selection',
                'summary': f"Used {tool} tool",
                'reasoning': f"Selected {tool} for this operation",
                'confidence': calculate_confidence(content, 'tool'),
                'tool': tool,
                'taskId': tasks[0] if tasks else None,
                'outcome': determine_outcome(message)
            })
            break  # Only one tool decision per message

    # File targeting decisions
    all_files = files_created + files_modified
    if all_files:
        file_names = [f.split('/')[-1] for f in all_files[:2]]
        file_summary = ', '.join(file_names)
        if len(all_files) > 2:
            file_summary += '...'

        decisions.append({
            'id': f"{msg_id}_files",
            'agent': agent,
            'timestamp': timestamp,
            'category': 'file-targeting',
            'summary': f"Targeted {len(all_files)} file(s): {file_summary}",
            'reasoning': f"Targeted {len(all_files)} file(s) for modification",
            'confidence': calculate_confidence(content, 'file'),
            'files': all_files,
            'filesCreated': files_created,
            'filesModified': files_modified,
            'taskId': tasks[0] if tasks else None,
            'outcome': determine_outcome(message)
        })

    # Code approach decisions
    approach_keywords = ['approach', 'implement', 'strategy', 'design']
    if any(kw in content.lower() for kw in approach_keywords):
        approach_patterns = [
            r'approach[:\s]+(.+?)(?:\.|$)',
            r'strategy[:\s]+(.+?)(?:\.|$)',
            r'implement(?:ing|ed)?\s+(.+?)(?:\.|$)'
        ]

        approach_summary = 'Applied implementation approach'
        for pattern in approach_patterns:
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                approach_summary = match.group(1)[:100]
                break

        decisions.append({
            'id': f"{msg_id}_approach",
            'agent': agent,
            'timestamp': timestamp,
            'category': 'code-approach',
            'summary': approach_summary,
            'reasoning': extract_reasoning(content, 'approach'),
            'confidence': calculate_confidence(content, 'approach'),
            'taskId': tasks[0] if tasks else None,
            'outcome': determine_outcome(message)
        })

    # Error handling decisions
    error_keywords = ['error', 'failed', 'fix', 'retry']
    if any(kw in content.lower() for kw in error_keywords):
        error_summary = 'Handled error condition'
        if 'retry' in content.lower():
            error_summary = 'Retried operation after error'
        elif 'fix' in content.lower():
            error_summary = 'Applied fix for encountered error'
        elif 'recover' in content.lower():
            error_summary = 'Recovered from error condition'

        decisions.append({
            'id': f"{msg_id}_error",
            'agent': agent,
            'timestamp': timestamp,
            'category': 'error-handling',
            'summary': error_summary,
            'reasoning': extract_reasoning(content, 'error'),
            'confidence': calculate_confidence(content, 'error'),
            'taskId': tasks[0] if tasks else None,
            'outcome': determine_outcome(message)
        })

    return decisions

def calculate_stats(decisions):
    """Calculate aggregate statistics"""
    total = len(decisions)
    if total == 0:
        return {
            'totalDecisions': 0,
            'avgConfidence': 0,
            'successRate': 0,
            'tasksAnalyzed': 0,
            'errorDecisions': 0
        }

    avg_confidence = sum(d.get('confidence', 70) for d in decisions) // total
    success_count = sum(1 for d in decisions if d.get('outcome') == 'success')
    success_rate = (success_count * 100) // total
    unique_tasks = len(set(d.get('taskId') for d in decisions if d.get('taskId')))
    error_decisions = sum(1 for d in decisions if d.get('category') == 'error-handling')

    return {
        'totalDecisions': total,
        'avgConfidence': avg_confidence,
        'successRate': success_rate,
        'tasksAnalyzed': unique_tasks,
        'errorDecisions': error_decisions
    }

def calculate_patterns(decisions):
    """Calculate decision patterns"""
    patterns = defaultdict(int)

    for decision in decisions:
        category = decision.get('category', 'unknown')
        patterns[category] += 1

    return sorted([
        {'name': cat.replace('-', ' ').title(), 'count': count}
        for cat, count in patterns.items()
    ], key=lambda x: x['count'], reverse=True)[:6]

def calculate_tool_preferences(decisions):
    """Calculate tool usage preferences"""
    tools = defaultdict(int)

    for decision in decisions:
        tool = decision.get('tool')
        if tool:
            tools[tool] += 1

    total = sum(tools.values()) or 1

    tool_icons = {
        'Read': '📖',
        'Edit': '✏️',
        'Write': '📝',
        'Bash': '💻',
        'Grep': '🔍',
        'Glob': '📂'
    }

    return sorted([
        {
            'name': tool,
            'count': count,
            'percentage': (count * 100) // total,
            'icon': tool_icons.get(tool, '🔧')
        }
        for tool, count in tools.items()
    ], key=lambda x: x['count'], reverse=True)

def calculate_agent_comparison(decisions):
    """Calculate per-agent statistics"""
    agents = defaultdict(lambda: {'decisions': 0, 'successCount': 0, 'totalConfidence': 0})

    for decision in decisions:
        agent = decision.get('agent', 'unknown')
        agents[agent]['decisions'] += 1
        if decision.get('outcome') == 'success':
            agents[agent]['successCount'] += 1
        agents[agent]['totalConfidence'] += decision.get('confidence', 70)

    return sorted([
        {
            'agent': agent,
            'decisions': data['decisions'],
            'successRate': (data['successCount'] * 100) // data['decisions'] if data['decisions'] > 0 else 0,
            'avgConfidence': data['totalConfidence'] // data['decisions'] if data['decisions'] > 0 else 0
        }
        for agent, data in agents.items()
    ], key=lambda x: x['decisions'], reverse=True)

def main():
    all_decisions = []

    # Load chat data
    chat_data = load_json(CHAT_JSON)
    if chat_data:
        for conversation in chat_data.get('conversations', []):
            for message in conversation.get('messages', []):
                decisions = extract_decisions_from_message(message)
                all_decisions.extend(decisions)

    # Load timeline data for additional tool usage
    timeline_data = load_json(TIMELINE_JSON)
    if timeline_data:
        for session in timeline_data.get('sessions', []):
            operations = session.get('operations', [])
            if operations:
                for op in operations:
                    tool = op.get('tool', '').capitalize()
                    if tool and tool in ['Read', 'Edit', 'Write', 'Bash', 'Grep', 'Glob']:
                        session_tasks = session.get('tasks', [])
                        decision = {
                            'id': f"{session.get('id', '')}_{op.get('timestamp', '')}_{tool}",
                            'agent': session.get('agent', 'unknown'),
                            'timestamp': session.get('timestamp', ''),
                            'category': 'tool-selection',
                            'summary': f"Used {tool} on {op.get('path', 'file').split('/')[-1]}",
                            'reasoning': f"{op.get('action', 'Operated on')} {op.get('path', 'file')}",
                            'confidence': 85,
                            'tool': tool,
                            'taskId': session_tasks[0] if session_tasks else None,
                            'outcome': 'unknown'
                        }
                        all_decisions.append(decision)

    # Remove duplicates by ID
    seen_ids = set()
    unique_decisions = []
    for d in all_decisions:
        if d['id'] not in seen_ids:
            seen_ids.add(d['id'])
            unique_decisions.append(d)

    # Sort by timestamp descending
    unique_decisions.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

    # Calculate analytics
    stats = calculate_stats(unique_decisions)
    patterns = calculate_patterns(unique_decisions)
    tool_preferences = calculate_tool_preferences(unique_decisions)
    agent_comparison = calculate_agent_comparison(unique_decisions)

    # Build output
    output = {
        'generated': datetime.now().isoformat(),
        'stats': stats,
        'patterns': patterns,
        'toolPreferences': tool_preferences,
        'agentComparison': agent_comparison,
        'decisions': unique_decisions
    }

    # Write output
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Decision extraction completed: {len(unique_decisions)} decisions")
    print(f"Stats: {stats['totalDecisions']} decisions, {stats['avgConfidence']}% avg confidence, {stats['successRate']}% success rate")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

echo -e "${GREEN}Decision extraction complete.${NC}"
echo "Output written to: $OUTPUT_JSON"
