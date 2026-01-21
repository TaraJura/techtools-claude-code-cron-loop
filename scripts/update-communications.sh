#!/bin/bash
# update-communications.sh - Analyze inter-agent communication and information flow
# Parses agent logs and tasks.md to track what data each agent reads, writes,
# and how information flows between agents in the pipeline

OUTPUT_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$OUTPUT_DIR/communications.json"
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"

python3 << 'PYTHON_SCRIPT'
import os
import json
import re
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

ACTORS_DIR = "/home/novakj/actors"
OUTPUT_FILE = "/var/www/cronloop.techtools.cz/api/communications.json"
TASKS_FILE = "/home/novakj/tasks.md"
CHANGELOG_FILE = "/var/www/cronloop.techtools.cz/api/changelog.json"

# Agent definitions in pipeline order
AGENTS = [
    {"id": "idea-maker", "name": "Idea Maker", "role": "idea_generator", "color": "#eab308", "emoji": "💡", "order": 1},
    {"id": "project-manager", "name": "Project Manager", "role": "task_assigner", "color": "#a855f7", "emoji": "📋", "order": 2},
    {"id": "developer", "name": "Developer", "role": "implementer", "color": "#3b82f6", "emoji": "👨‍💻", "order": 3},
    {"id": "developer2", "name": "Developer 2", "role": "implementer", "color": "#06b6d4", "emoji": "👩‍💻", "order": 4},
    {"id": "tester", "name": "Tester", "role": "verifier", "color": "#22c55e", "emoji": "🧪", "order": 5},
    {"id": "security", "name": "Security", "role": "auditor", "color": "#ef4444", "emoji": "🔒", "order": 6},
]

AGENT_LOOKUP = {a["id"]: a for a in AGENTS}

# Information types that agents read/write
INFO_TYPES = {
    "task_id": "Task ID (TASK-XXX)",
    "task_title": "Task Title",
    "task_description": "Task Description",
    "task_status": "Task Status",
    "task_priority": "Priority Level",
    "assigned_to": "Assignment Info",
    "implementation_notes": "Implementation Notes",
    "test_results": "Test Results",
    "files_changed": "Files Changed",
    "developer_notes": "Developer Notes",
    "tester_feedback": "Tester Feedback"
}

def parse_log_file(filepath):
    """Parse an agent log file and extract communication info."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception:
        return None

    # Extract metadata
    actor_match = re.search(r'Actor: (\S+)', content)
    started_match = re.search(r'Started: (.+?)(?:\n|$)', content)

    if not actor_match or not started_match:
        return None

    actor = actor_match.group(1)
    started_str = started_match.group(1).strip()

    # Parse timestamp
    try:
        started = datetime.strptime(started_str, "%a %b %d %H:%M:%S %Z %Y")
    except:
        try:
            started = datetime.strptime(started_str, "%a %b %d %H:%M:%S UTC %Y")
        except:
            return None

    # Extract task references
    tasks_found = list(set(re.findall(r'TASK-\d+', content)))

    # Analyze what agent read from tasks.md
    reads = analyze_reads(actor, content)

    # Analyze what agent wrote to tasks.md
    writes = analyze_writes(actor, content)

    # Extract key actions/decisions
    actions = extract_actions(actor, content)

    # Find communication patterns
    patterns = find_communication_patterns(actor, content)

    return {
        "agent": actor,
        "timestamp": started.isoformat(),
        "tasks": tasks_found,
        "reads": reads,
        "writes": writes,
        "actions": actions,
        "patterns": patterns,
        "content_length": len(content),
        "filename": os.path.basename(filepath)
    }

def analyze_reads(agent, content):
    """Analyze what information the agent read."""
    reads = []

    # Common read patterns
    if re.search(r'Read.*tasks\.md|tasks\.md.*read', content, re.IGNORECASE):
        reads.append({"type": "task_board", "source": "tasks.md"})

    # Task-specific reads
    task_reads = re.findall(r'(?:reading|checking|found|looking at)\s+(TASK-\d+)', content, re.IGNORECASE)
    for task in set(task_reads):
        reads.append({"type": "task_details", "source": task})

    # Status reads
    if re.search(r'Status:\s*(TODO|IN_PROGRESS|DONE|VERIFIED|FAILED)', content):
        reads.append({"type": "task_status", "source": "tasks.md"})

    # Assignment reads
    if re.search(r'Assigned:\s*\w+', content):
        reads.append({"type": "assignment", "source": "tasks.md"})

    # Notes/feedback reads
    if re.search(r'(?:Developer|Tester|Implementation)\s*Notes?:', content, re.IGNORECASE):
        reads.append({"type": "notes", "source": "tasks.md"})

    return reads

def analyze_writes(agent, content):
    """Analyze what information the agent wrote."""
    writes = []

    # Task creation (idea-maker)
    if agent == "idea-maker":
        new_tasks = re.findall(r'###\s*(TASK-\d+)', content)
        for task in new_tasks:
            writes.append({"type": "new_task", "target": task, "fields": ["task_id", "title", "description", "priority"]})

    # Task assignment (project-manager)
    if agent == "project-manager":
        assignments = re.findall(r'(TASK-\d+).*?Assigned:\s*(developer\d?)', content, re.IGNORECASE)
        for task, assignee in assignments:
            writes.append({"type": "assignment", "target": task, "fields": ["assigned_to", "status"]})

    # Implementation notes (developer/developer2)
    if agent in ["developer", "developer2"]:
        # Status updates
        if re.search(r'Status:\s*IN_PROGRESS|Status:\s*DONE', content, re.IGNORECASE):
            writes.append({"type": "status_update", "target": "tasks.md", "fields": ["status"]})
        # Developer notes
        if re.search(r'(?:Developer|Implementation)\s*Notes?:', content, re.IGNORECASE):
            writes.append({"type": "dev_notes", "target": "tasks.md", "fields": ["developer_notes", "files_changed"]})

    # Test results (tester)
    if agent == "tester":
        if re.search(r'(?:PASS|FAIL|VERIFIED)', content, re.IGNORECASE):
            writes.append({"type": "test_results", "target": "tasks.md", "fields": ["tester_feedback", "status"]})

    # Security review (security)
    if agent == "security":
        if re.search(r'security\s*(?:review|check|audit)', content, re.IGNORECASE):
            writes.append({"type": "security_review", "target": "status/security.json", "fields": ["security_status"]})

    return writes

def extract_actions(agent, content):
    """Extract key actions performed by the agent."""
    actions = []

    # Task-related actions
    if agent == "idea-maker":
        ideas = re.findall(r'(?:created|added|proposed)\s+(?:idea|task)\s*(TASK-\d+)?', content, re.IGNORECASE)
        if ideas:
            actions.append({"action": "created_ideas", "count": len(ideas)})

    if agent == "project-manager":
        assigns = re.findall(r'(?:assigned|assigning)\s+(TASK-\d+)', content, re.IGNORECASE)
        if assigns:
            actions.append({"action": "assigned_tasks", "count": len(assigns), "tasks": list(set(assigns))})

    if agent in ["developer", "developer2"]:
        # Implementation actions
        impl = re.findall(r'(?:implemented|created|completed|built)\s+([^\n]+)', content, re.IGNORECASE)
        if impl:
            actions.append({"action": "implemented", "details": impl[0][:100] if impl else ""})

        # File changes
        files = re.findall(r'(?:created|modified|updated)\s+[`"]([^`"]+\.(?:html|js|css|sh|py|json))[`"]', content, re.IGNORECASE)
        if files:
            actions.append({"action": "changed_files", "count": len(files), "files": files[:5]})

    if agent == "tester":
        passes = len(re.findall(r'PASS|VERIFIED', content, re.IGNORECASE))
        fails = len(re.findall(r'FAIL', content, re.IGNORECASE))
        if passes or fails:
            actions.append({"action": "tested", "passed": passes, "failed": fails})

    return actions

def find_communication_patterns(agent, content):
    """Find communication patterns and potential issues."""
    patterns = []

    # Missing information patterns
    if re.search(r'(?:missing|unclear|not specified|need more)', content, re.IGNORECASE):
        patterns.append({"type": "missing_info", "severity": "warning"})

    # Vague descriptions
    if re.search(r'(?:vague|ambiguous|not clear)', content, re.IGNORECASE):
        patterns.append({"type": "vague_spec", "severity": "warning"})

    # Retry patterns
    retries = len(re.findall(r'(?:retry|retrying|try again|attempt)', content, re.IGNORECASE))
    if retries > 2:
        patterns.append({"type": "multiple_retries", "count": retries, "severity": "warning"})

    # Reference to previous agent's work
    refs = re.findall(r'(?:idea-maker|project-manager|developer|tester|security)\s+(?:said|noted|mentioned|specified)', content, re.IGNORECASE)
    if refs:
        patterns.append({"type": "agent_reference", "count": len(refs)})

    return patterns

def build_task_timeline():
    """Build a timeline of task state changes across agents."""
    timelines = defaultdict(list)

    # Process all agent logs
    for agent in AGENTS:
        log_dir = Path(ACTORS_DIR) / agent["id"] / "logs"
        if not log_dir.exists():
            continue

        for log_file in sorted(log_dir.glob("*.log"))[-50:]:  # Last 50 logs per agent
            entry = parse_log_file(log_file)
            if entry:
                for task in entry["tasks"]:
                    timelines[task].append({
                        "agent": entry["agent"],
                        "agent_name": AGENT_LOOKUP[entry["agent"]]["name"],
                        "agent_emoji": AGENT_LOOKUP[entry["agent"]]["emoji"],
                        "timestamp": entry["timestamp"],
                        "reads": entry["reads"],
                        "writes": entry["writes"],
                        "actions": entry["actions"],
                        "patterns": entry["patterns"]
                    })

    # Sort each task's timeline
    for task in timelines:
        timelines[task].sort(key=lambda x: x["timestamp"])

    return dict(timelines)

def analyze_handoffs(task_timelines):
    """Analyze information flow between agents for each task."""
    handoff_analysis = []

    for task_id, timeline in task_timelines.items():
        if len(timeline) < 2:
            continue

        task_handoffs = []
        for i in range(1, len(timeline)):
            prev = timeline[i-1]
            curr = timeline[i]

            # Calculate time between touches
            prev_time = datetime.fromisoformat(prev["timestamp"])
            curr_time = datetime.fromisoformat(curr["timestamp"])
            delay_minutes = (curr_time - prev_time).total_seconds() / 60

            # Calculate information transfer quality
            info_passed = []
            info_missing = []

            # Check what prev wrote vs what curr read
            prev_writes = [w["type"] for w in prev.get("writes", [])]
            curr_reads = [r["type"] for r in curr.get("reads", [])]

            # Standard info flow expectations
            expected_flow = {
                "idea-maker": ["task_board", "task_details"],
                "project-manager": ["assignment", "task_status"],
                "developer": ["dev_notes", "status_update"],
                "developer2": ["dev_notes", "status_update"],
                "tester": ["test_results"],
                "security": ["security_review"]
            }

            # Calculate signal clarity
            if prev_writes:
                info_passed = prev_writes

            # Detect patterns
            patterns = []
            if curr.get("patterns"):
                patterns = curr["patterns"]

            # Calculate clarity score (0-100)
            clarity_score = 100
            if not prev_writes:
                clarity_score -= 30
            if any(p.get("type") == "missing_info" for p in patterns):
                clarity_score -= 25
            if any(p.get("type") == "vague_spec" for p in patterns):
                clarity_score -= 20
            if any(p.get("type") == "multiple_retries" for p in patterns):
                clarity_score -= 15

            task_handoffs.append({
                "from_agent": prev["agent"],
                "from_name": prev["agent_name"],
                "from_emoji": prev["agent_emoji"],
                "to_agent": curr["agent"],
                "to_name": curr["agent_name"],
                "to_emoji": curr["agent_emoji"],
                "delay_minutes": round(delay_minutes, 1),
                "info_passed": info_passed,
                "patterns": patterns,
                "clarity_score": max(0, clarity_score)
            })

        if task_handoffs:
            avg_clarity = sum(h["clarity_score"] for h in task_handoffs) / len(task_handoffs)
            handoff_analysis.append({
                "task_id": task_id,
                "handoff_count": len(task_handoffs),
                "avg_clarity": round(avg_clarity, 1),
                "handoffs": task_handoffs
            })

    # Sort by most recent
    handoff_analysis.sort(key=lambda x: x.get("handoffs", [{}])[-1].get("delay_minutes", 0) if x.get("handoffs") else 0)

    return handoff_analysis

def calculate_agent_stats(task_timelines):
    """Calculate communication stats per agent."""
    stats = {}

    for agent in AGENTS:
        agent_id = agent["id"]
        stats[agent_id] = {
            "name": agent["name"],
            "emoji": agent["emoji"],
            "color": agent["color"],
            "tasks_touched": 0,
            "avg_reads_per_task": 0,
            "avg_writes_per_task": 0,
            "common_patterns": [],
            "signal_clarity_given": 0,  # How clear is info this agent provides
            "signal_clarity_received": 0  # How clear is info this agent receives
        }

    # Aggregate stats from timelines
    agent_reads = defaultdict(list)
    agent_writes = defaultdict(list)
    agent_patterns = defaultdict(list)

    for task_id, timeline in task_timelines.items():
        for entry in timeline:
            agent_id = entry["agent"]
            agent_reads[agent_id].append(len(entry.get("reads", [])))
            agent_writes[agent_id].append(len(entry.get("writes", [])))
            agent_patterns[agent_id].extend([p.get("type") for p in entry.get("patterns", [])])

    # Calculate averages
    for agent_id in stats:
        reads = agent_reads.get(agent_id, [])
        writes = agent_writes.get(agent_id, [])
        patterns = agent_patterns.get(agent_id, [])

        stats[agent_id]["tasks_touched"] = len(reads)
        if reads:
            stats[agent_id]["avg_reads_per_task"] = round(sum(reads) / len(reads), 1)
        if writes:
            stats[agent_id]["avg_writes_per_task"] = round(sum(writes) / len(writes), 1)

        # Find common patterns
        pattern_counts = defaultdict(int)
        for p in patterns:
            pattern_counts[p] += 1
        stats[agent_id]["common_patterns"] = sorted(
            [{"type": k, "count": v} for k, v in pattern_counts.items()],
            key=lambda x: x["count"],
            reverse=True
        )[:3]

    return stats

def generate_recommendations(handoff_analysis, agent_stats):
    """Generate recommendations for improving communication."""
    recommendations = []

    # Find agents with low clarity scores
    for agent_id, stats in agent_stats.items():
        if stats["avg_writes_per_task"] < 0.5 and stats["tasks_touched"] > 5:
            recommendations.append({
                "type": "low_output",
                "severity": "medium",
                "agent": agent_id,
                "message": f"{stats['name']} produces little documented output. Consider adding logging of key decisions."
            })

    # Find handoffs with consistently low clarity
    low_clarity_handoffs = defaultdict(list)
    for analysis in handoff_analysis:
        for handoff in analysis.get("handoffs", []):
            if handoff["clarity_score"] < 70:
                key = f"{handoff['from_agent']}->{handoff['to_agent']}"
                low_clarity_handoffs[key].append(handoff["clarity_score"])

    for key, scores in low_clarity_handoffs.items():
        if len(scores) >= 3:
            avg_score = sum(scores) / len(scores)
            from_agent, to_agent = key.split("->")
            from_name = AGENT_LOOKUP.get(from_agent, {}).get("name", from_agent)
            to_name = AGENT_LOOKUP.get(to_agent, {}).get("name", to_agent)
            recommendations.append({
                "type": "poor_handoff",
                "severity": "high" if avg_score < 50 else "medium",
                "from_agent": from_agent,
                "to_agent": to_agent,
                "message": f"{from_name} → {to_name} handoffs have low clarity ({avg_score:.0f}%). Consider adding more context in task notes."
            })

    # Check for missing info patterns
    for agent_id, stats in agent_stats.items():
        missing_count = sum(1 for p in stats["common_patterns"] if p["type"] == "missing_info")
        if missing_count > 0:
            recommendations.append({
                "type": "missing_info",
                "severity": "medium",
                "agent": agent_id,
                "message": f"{stats['name']} often reports missing information. Upstream agents should provide more context."
            })

    return recommendations

def main():
    # Build task timelines
    task_timelines = build_task_timeline()

    # Analyze handoffs
    handoff_analysis = analyze_handoffs(task_timelines)

    # Calculate agent stats
    agent_stats = calculate_agent_stats(task_timelines)

    # Generate recommendations
    recommendations = generate_recommendations(handoff_analysis, agent_stats)

    # Calculate overall metrics
    total_handoffs = sum(a["handoff_count"] for a in handoff_analysis)
    avg_clarity = 0
    if handoff_analysis:
        clarity_scores = [h["clarity_score"] for a in handoff_analysis for h in a.get("handoffs", [])]
        if clarity_scores:
            avg_clarity = sum(clarity_scores) / len(clarity_scores)

    # Build output
    output = {
        "timestamp": datetime.now().isoformat(),
        "summary": {
            "tasks_analyzed": len(task_timelines),
            "total_handoffs": total_handoffs,
            "avg_clarity_score": round(avg_clarity, 1),
            "active_agents": len([a for a in agent_stats.values() if a["tasks_touched"] > 0]),
            "recommendations_count": len(recommendations)
        },
        "agent_stats": agent_stats,
        "handoff_analysis": handoff_analysis[:30],  # Most recent 30 tasks
        "task_timelines": {k: v for k, v in list(task_timelines.items())[:20]},  # Most recent 20
        "recommendations": recommendations,
        "info_types": INFO_TYPES,
        "agents": AGENTS
    }

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Generated communications data: {len(task_timelines)} tasks, {total_handoffs} handoffs, {avg_clarity:.1f}% avg clarity")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

echo "Agent communications data updated: $OUTPUT_FILE"
