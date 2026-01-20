#!/bin/bash
# update-timeline.sh - Generate agent tool operation timeline data
# Parses agent logs to extract and visualize tool calls and file operations

OUTPUT_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$OUTPUT_DIR/timeline.json"
ACTORS_DIR="/home/novakj/actors"

python3 << 'PYTHON_SCRIPT'
import os
import json
import re
from datetime import datetime, timedelta
from pathlib import Path

ACTORS_DIR = "/home/novakj/actors"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/timeline.json"

# Agent definitions
AGENTS = [
    {"id": "idea-maker", "name": "Idea Maker", "color": "#eab308", "emoji": "?"},
    {"id": "project-manager", "name": "Project Manager", "color": "#a855f7", "emoji": "?"},
    {"id": "developer", "name": "Developer", "color": "#3b82f6", "emoji": "??"},
    {"id": "developer2", "name": "Developer 2", "color": "#06b6d4", "emoji": "??"},
    {"id": "tester", "name": "Tester", "color": "#22c55e", "emoji": "?"},
    {"id": "security", "name": "Security", "color": "#ef4444", "emoji": "?"},
]

def parse_log_file(filepath):
    """Parse an agent log file and extract operations."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except Exception as e:
        return None

    # Extract metadata from header
    actor_match = re.search(r'Actor: (\S+)', content)
    started_match = re.search(r'Started: (.+?)(?:\n|$)', content)
    completed_match = re.search(r'Completed: (.+?)(?:\n|$)', content)

    if not actor_match or not started_match:
        return None

    actor = actor_match.group(1)
    started_str = started_match.group(1).strip()
    completed_str = completed_match.group(1).strip() if completed_match else None

    # Parse timestamps
    try:
        started = datetime.strptime(started_str, "%a %b %d %H:%M:%S %Z %Y")
    except:
        try:
            started = datetime.strptime(started_str, "%a %b %d %H:%M:%S UTC %Y")
        except:
            return None

    completed = None
    duration = None
    if completed_str:
        try:
            completed = datetime.strptime(completed_str, "%a %b %d %H:%M:%S %Z %Y")
            duration = (completed - started).total_seconds()
        except:
            try:
                completed = datetime.strptime(completed_str, "%a %b %d %H:%M:%S UTC %Y")
                duration = (completed - started).total_seconds()
            except:
                pass

    # Extract operations from content
    operations = []

    # Extract file operations - files created
    files_created = []
    created_patterns = [
        r'Created[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'created[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'\*\*Created\*\*[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'Files? Created[:\s\*]*[`\'"]([^`\'"]+)[`\'"]',
        r'create mode \d+ ([^\n]+)',
    ]
    for pattern in created_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            if match and len(match) < 200 and '/' in match:
                files_created.append(match.strip())
                operations.append({
                    "tool": "write",
                    "action": "Created",
                    "path": match.strip(),
                    "timestamp": started.isoformat()
                })

    # Extract file operations - files modified
    files_modified = []
    modified_patterns = [
        r'Modified[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'modified[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'Updated[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'Edited[:\s]+[`\'"]([^`\'"]+)[`\'"]',
    ]
    for pattern in modified_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            if match and len(match) < 200 and '/' in match:
                files_modified.append(match.strip())
                operations.append({
                    "tool": "edit",
                    "action": "Modified",
                    "path": match.strip(),
                    "timestamp": started.isoformat()
                })

    # Extract bash commands
    bash_patterns = [
        r'Running[:\s]+`([^`]+)`',
        r'Executed[:\s]+`([^`]+)`',
        r'Command[:\s]+`([^`]+)`',
        r'sudo ([^\n]+)',
    ]
    for pattern in bash_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            if match and len(match) < 200:
                operations.append({
                    "tool": "bash",
                    "action": "Executed",
                    "path": match.strip(),
                    "timestamp": started.isoformat()
                })

    # Extract read operations
    read_patterns = [
        r'Read[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'Reading[:\s]+[`\'"]([^`\'"]+)[`\'"]',
        r'checked[:\s]+[`\'"]([^`\'"]+)[`\'"]',
    ]
    for pattern in read_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            if match and len(match) < 200 and '/' in match:
                operations.append({
                    "tool": "read",
                    "action": "Read",
                    "path": match.strip(),
                    "timestamp": started.isoformat()
                })

    # Extract task references
    task_refs = list(set(re.findall(r'TASK-\d+', content)))

    # Extract summary
    summary_match = re.search(r'Running .+? agent\.\.\.\n(.+?)(?:========|$)', content, re.DOTALL)
    summary = ""
    if summary_match:
        text = summary_match.group(1).strip()
        # Get first meaningful line
        lines = [l.strip() for l in text.split('\n') if l.strip() and not l.startswith('#')]
        if lines:
            summary = lines[0][:150]

    # Deduplicate operations
    seen = set()
    unique_ops = []
    for op in operations:
        key = f"{op['tool']}:{op['path']}"
        if key not in seen:
            seen.add(key)
            unique_ops.append(op)

    # Deduplicate file lists
    files_created = list(set(files_created))
    files_modified = list(set(files_modified))

    return {
        "id": f"{actor}_{os.path.basename(filepath)}",
        "agent": actor,
        "timestamp": started.isoformat(),
        "duration": duration,
        "summary": summary,
        "tasks": task_refs,
        "operations": unique_ops[:50],  # Limit operations per session
        "filesCreated": files_created[:20],
        "filesModified": files_modified[:20],
        "filename": os.path.basename(filepath)
    }


def build_timeline():
    """Build timeline data from all agent logs."""
    sessions = []

    # Collect logs from all agents
    for agent in AGENTS:
        log_dir = Path(ACTORS_DIR) / agent["id"] / "logs"
        if not log_dir.exists():
            continue

        # Get last 50 logs per agent
        for log_file in sorted(log_dir.glob("*.log"))[-50:]:
            entry = parse_log_file(log_file)
            if entry:
                entry["agentName"] = agent["name"]
                entry["agentColor"] = agent["color"]
                entry["agentEmoji"] = agent["emoji"]
                sessions.append(entry)

    # Sort by timestamp (newest first)
    sessions.sort(key=lambda x: x["timestamp"], reverse=True)

    # Calculate statistics
    stats = {
        "totalSessions": len(sessions),
        "totalOperations": sum(len(s.get("operations", [])) for s in sessions),
        "operationsByType": {},
        "operationsByAgent": {},
        "mostTouchedFiles": {},
    }

    for session in sessions:
        agent = session["agent"]
        stats["operationsByAgent"][agent] = stats["operationsByAgent"].get(agent, 0) + 1

        for op in session.get("operations", []):
            tool = op.get("tool", "unknown")
            stats["operationsByType"][tool] = stats["operationsByType"].get(tool, 0) + 1

            path = op.get("path", "")
            if path:
                stats["mostTouchedFiles"][path] = stats["mostTouchedFiles"].get(path, 0) + 1

        for f in session.get("filesCreated", []):
            stats["mostTouchedFiles"][f] = stats["mostTouchedFiles"].get(f, 0) + 1
        for f in session.get("filesModified", []):
            stats["mostTouchedFiles"][f] = stats["mostTouchedFiles"].get(f, 0) + 1

    # Sort and limit most touched files
    sorted_files = sorted(stats["mostTouchedFiles"].items(), key=lambda x: x[1], reverse=True)[:20]
    stats["mostTouchedFiles"] = dict(sorted_files)

    return {
        "generated": datetime.now().isoformat(),
        "sessions": sessions[:100],  # Limit to last 100 sessions
        "stats": stats,
        "agents": AGENTS
    }


def main():
    timeline = build_timeline()

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(timeline, f, indent=2)

    print(f"Generated timeline data: {timeline['stats']['totalSessions']} sessions, {timeline['stats']['totalOperations']} operations")


if __name__ == "__main__":
    main()
PYTHON_SCRIPT

echo "Timeline data updated: $OUTPUT_FILE"
