#!/bin/bash
# update-agent-chat.sh - Generate agent collaboration chat data
# Parses agent logs and reconstructs the "conversation" between agents

OUTPUT_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$OUTPUT_DIR/agent-chat.json"
ACTORS_DIR="/home/novakj/actors"

python3 << 'PYTHON_SCRIPT'
import os
import json
import re
from datetime import datetime
from pathlib import Path

ACTORS_DIR = "/home/novakj/actors"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/agent-chat.json"

# Agent definitions in pipeline order
AGENTS = [
    {"id": "idea-maker", "name": "Idea Maker", "role": "idea_generator", "color": "#eab308", "emoji": "💡"},
    {"id": "project-manager", "name": "Project Manager", "role": "task_assigner", "color": "#a855f7", "emoji": "📋"},
    {"id": "developer", "name": "Developer", "role": "implementer", "color": "#3b82f6", "emoji": "👨‍💻"},
    {"id": "developer2", "name": "Developer 2", "role": "implementer", "color": "#06b6d4", "emoji": "👩‍💻"},
    {"id": "tester", "name": "Tester", "role": "verifier", "color": "#22c55e", "emoji": "🧪"},
    {"id": "security", "name": "Security", "role": "auditor", "color": "#ef4444", "emoji": "🔒"},
]

def parse_log_file(filepath):
    """Parse an agent log file and extract key information."""
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
    if completed_str:
        try:
            completed = datetime.strptime(completed_str, "%a %b %d %H:%M:%S %Z %Y")
        except:
            try:
                completed = datetime.strptime(completed_str, "%a %b %d %H:%M:%S UTC %Y")
            except:
                pass

    # Extract the main content (between "Running X agent..." and completion line)
    content_match = re.search(
        r'Running .+? agent\.\.\.\n(.+?)(?:========|$)',
        content,
        re.DOTALL
    )

    main_content = content_match.group(1).strip() if content_match else ""

    # Extract task references
    task_refs = list(set(re.findall(r'TASK-\d+', content)))

    # Extract key information based on agent type
    summary = extract_summary(actor, main_content)

    # Extract files created/modified
    files_created = re.findall(r'(?:Created|created|Files? Created).*?[`"]([^`"]+)[`"]', content)
    files_modified = re.findall(r'(?:Modified|modified|Updated).*?[`"]([^`"]+)[`"]', content)

    # Extract verification results for tester
    test_results = []
    if actor == "tester":
        pass_matches = re.findall(r'(TASK-\d+).*?(?:PASS|VERIFIED)', content, re.IGNORECASE)
        fail_matches = re.findall(r'(TASK-\d+).*?(?:FAIL|FAILED)', content, re.IGNORECASE)
        test_results = [{"task": t, "result": "pass"} for t in pass_matches]
        test_results.extend([{"task": t, "result": "fail"} for t in fail_matches])

    return {
        "actor": actor,
        "started": started.isoformat(),
        "completed": completed.isoformat() if completed else None,
        "duration_seconds": (completed - started).total_seconds() if completed else None,
        "tasks": task_refs,
        "summary": summary,
        "content": main_content[:2000],  # Truncate for JSON size
        "files_created": files_created[:10],
        "files_modified": files_modified[:10],
        "test_results": test_results,
        "filename": os.path.basename(filepath)
    }

def extract_summary(actor, content):
    """Extract a one-line summary based on agent type."""
    lines = content.split('\n')

    if actor == "idea-maker":
        # Look for new ideas added
        ideas = re.findall(r'\*\*TASK-\d+: ([^*]+)\*\*', content)
        if ideas:
            return f"Generated {len(ideas)} new task idea(s): {ideas[0][:50]}..."
        return "Generated new task ideas"

    elif actor == "project-manager":
        # Look for task assignments
        assignments = re.findall(r'(TASK-\d+).*?(?:to|Assigned).*?(developer\d?)', content, re.IGNORECASE)
        if assignments:
            return f"Assigned {len(assignments)} task(s) to developers"
        return "Managed task assignments"

    elif actor in ["developer", "developer2"]:
        # Look for completed task
        completed = re.search(r'completed\s+\*\*(TASK-\d+[^*]*)\*\*', content, re.IGNORECASE)
        if completed:
            return f"Completed {completed.group(1)[:60]}..."
        implemented = re.search(r'(?:Implemented|Created|Built)\s+([^\n]+)', content)
        if implemented:
            return implemented.group(1)[:80]
        return "Worked on implementation tasks"

    elif actor == "tester":
        # Count pass/fail
        passes = len(re.findall(r'PASS|VERIFIED', content, re.IGNORECASE))
        fails = len(re.findall(r'FAIL(?:ED)?', content, re.IGNORECASE))
        if passes or fails:
            return f"Verified tasks: {passes} passed, {fails} failed"
        return "Ran verification tests"

    elif actor == "security":
        # Look for security findings
        issues = len(re.findall(r'(?:issue|vulnerability|warning)', content, re.IGNORECASE))
        if issues:
            return f"Found {issues} security consideration(s)"
        return "Completed security review"

    return "Completed run"

def build_conversations():
    """Build conversation threads from agent logs grouped by 30-minute pipeline runs."""
    all_entries = []

    # Collect all log entries from all agents
    for agent in AGENTS:
        log_dir = Path(ACTORS_DIR) / agent["id"] / "logs"
        if not log_dir.exists():
            continue

        for log_file in sorted(log_dir.glob("*.log"))[-100:]:  # Last 100 logs per agent
            entry = parse_log_file(log_file)
            if entry:
                entry["agent_info"] = agent
                all_entries.append(entry)

    # Sort all entries by timestamp
    all_entries.sort(key=lambda x: x["started"])

    # Group entries into 30-minute pipeline runs
    conversations = []
    current_conversation = None

    for entry in all_entries:
        entry_time = datetime.fromisoformat(entry["started"])

        # Check if this belongs to current conversation (within 45 minutes of start)
        if current_conversation:
            conv_start = datetime.fromisoformat(current_conversation["started"])
            time_diff = (entry_time - conv_start).total_seconds() / 60

            if time_diff > 45:  # New conversation
                if current_conversation["messages"]:
                    conversations.append(current_conversation)
                current_conversation = None

        if current_conversation is None:
            # Start new conversation
            current_conversation = {
                "id": entry_time.strftime("%Y%m%d_%H%M"),
                "started": entry["started"],
                "messages": [],
                "tasks_discussed": set(),
                "participants": set()
            }

        # Add message to conversation
        message = {
            "id": f"{entry['actor']}_{entry['filename']}",
            "agent": entry["actor"],
            "agent_name": entry["agent_info"]["name"],
            "agent_color": entry["agent_info"]["color"],
            "agent_emoji": entry["agent_info"]["emoji"],
            "timestamp": entry["started"],
            "duration": entry["duration_seconds"],
            "summary": entry["summary"],
            "content": entry["content"],
            "tasks": entry["tasks"],
            "files_created": entry["files_created"],
            "files_modified": entry["files_modified"],
            "test_results": entry["test_results"]
        }

        current_conversation["messages"].append(message)
        current_conversation["tasks_discussed"].update(entry["tasks"])
        current_conversation["participants"].add(entry["actor"])
        current_conversation["ended"] = entry.get("completed") or entry["started"]

    # Add last conversation
    if current_conversation and current_conversation["messages"]:
        conversations.append(current_conversation)

    # Convert sets to lists for JSON serialization
    for conv in conversations:
        conv["tasks_discussed"] = list(conv["tasks_discussed"])
        conv["participants"] = list(conv["participants"])

    return conversations

def generate_handoff_analysis(conversations):
    """Analyze handoffs between agents."""
    handoffs = []

    for conv in conversations[-20:]:  # Last 20 conversations
        messages = conv["messages"]
        for i in range(1, len(messages)):
            prev = messages[i-1]
            curr = messages[i]

            # Find shared task context
            shared_tasks = set(prev["tasks"]) & set(curr["tasks"])

            handoff = {
                "from_agent": prev["agent"],
                "to_agent": curr["agent"],
                "shared_tasks": list(shared_tasks),
                "timestamp": curr["timestamp"],
                "from_summary": prev["summary"],
                "to_action": curr["summary"]
            }
            handoffs.append(handoff)

    return handoffs

def main():
    conversations = build_conversations()
    handoffs = generate_handoff_analysis(conversations)

    # Calculate statistics
    total_messages = sum(len(c["messages"]) for c in conversations)
    agent_participation = {}
    for conv in conversations:
        for msg in conv["messages"]:
            agent = msg["agent"]
            if agent not in agent_participation:
                agent_participation[agent] = {"count": 0, "total_duration": 0}
            agent_participation[agent]["count"] += 1
            if msg["duration"]:
                agent_participation[agent]["total_duration"] += msg["duration"]

    # Calculate average conversation length
    avg_messages_per_conv = total_messages / len(conversations) if conversations else 0

    output = {
        "generated": datetime.now().isoformat(),
        "stats": {
            "total_conversations": len(conversations),
            "total_messages": total_messages,
            "avg_messages_per_conversation": round(avg_messages_per_conv, 1),
            "agent_participation": agent_participation,
            "unique_tasks_discussed": len(set(t for c in conversations for t in c["tasks_discussed"]))
        },
        "conversations": conversations[-30:],  # Last 30 conversations
        "handoffs": handoffs[-50:],  # Last 50 handoffs
        "agents": AGENTS
    }

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Generated agent chat data: {len(conversations)} conversations, {total_messages} messages")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

echo "Agent chat data updated: $OUTPUT_FILE"
