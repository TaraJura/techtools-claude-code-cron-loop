# CronLoop2 - Autonomous AI Ecosystem Blueprint

> **Summary for fresh deployment of the CronLoop autonomous AI system**

## What Is This?

CronLoop is an **autonomous AI ecosystem** where Claude Code (Anthropic's CLI tool) runs on a cron schedule to maintain, improve, and build software without human intervention.

**The core idea**: Multiple specialized AI agents collaborate on tasks, simulating a full software development team that runs 24/7.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CRON SCHEDULER (Linux)                       │
│                   Triggers every 2 hours                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR SCRIPT                         │
│              Runs agents in sequence via Claude Code            │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │ Agent 1 │    →     │ Agent 2 │    →     │ Agent N │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │    tasks.md     │
                    │  (shared state) │
                    └─────────────────┘
```

## The Agent Pipeline

Agents run sequentially, each with a specific role:

| Order | Agent | Role | Description |
|-------|-------|------|-------------|
| 1 | **idea-maker** | Product Owner | Generates feature ideas, adds to backlog |
| 2 | **project-manager** | Scrum Master | Prioritizes and assigns tasks to developers |
| 3 | **developer** | Engineer #1 | Implements assigned tasks |
| 4 | **developer2** | Engineer #2 | Implements tasks in parallel |
| 5 | **tester** | QA Engineer | Verifies completed work, marks DONE or FAILED |
| 6 | **security** | Security Analyst | Scans for vulnerabilities, maintains security |

**Supervisor** (runs separately): Meta-agent that monitors ecosystem health and fixes issues.

## Task Lifecycle

```
TODO → IN_PROGRESS → DONE → VERIFIED (archived)
                  ↘ FAILED → back to TODO with notes
```

Tasks flow through `tasks.md` - the single source of truth:

```markdown
## TODO
- [ ] TASK-001: Implement feature X [priority: high] [assigned: developer]

## IN_PROGRESS
- [ ] TASK-002: Build component Y [assigned: developer2]

## DONE
- [x] TASK-003: Create API endpoint [completed: 2026-01-23]

## FAILED
- [ ] TASK-004: Fix bug Z [reason: tests failing, needs review]
```

## Directory Structure

```
/home/user/cronloop2/
├── CLAUDE.md              # Core instructions (this becomes your main file)
├── tasks.md               # Active tasks (TODO, IN_PROGRESS, DONE, FAILED)
├── actors/
│   ├── idea-maker/
│   │   └── prompt.md      # Agent-specific instructions
│   ├── project-manager/
│   │   └── prompt.md
│   ├── developer/
│   │   └── prompt.md
│   ├── developer2/
│   │   └── prompt.md
│   ├── tester/
│   │   └── prompt.md
│   ├── security/
│   │   └── prompt.md
│   └── supervisor/
│       └── prompt.md
├── scripts/
│   ├── cron-orchestrator.sh   # Main cron entry point
│   ├── run-actor.sh           # Runs individual agents
│   └── maintenance.sh         # Cleanup, archiving
├── docs/
│   ├── server-config.md       # Server details
│   ├── security-guide.md      # Security protocols
│   └── engine-guide.md        # Recovery procedures
├── status/
│   ├── system.json            # Current system state
│   ├── security.json          # Security scan results
│   └── task-counter.txt       # Next task ID
└── logs/
    ├── changelog.md           # Recent changes
    ├── workflow.log           # Execution logs
    └── tasks-archive/         # Completed tasks archive
```

## How Agents Work

Each agent:
1. Reads `CLAUDE.md` for system rules
2. Reads its own `prompt.md` for role-specific instructions
3. Reads `tasks.md` for current state
4. Performs its job (create/assign/implement/verify tasks)
5. Updates `tasks.md` with results
6. Commits changes to git

**Agent prompt structure** (`actors/<name>/prompt.md`):
```markdown
# Agent Name

## Role
What this agent does

## Instructions
1. Step-by-step workflow
2. What to read/write
3. Constraints and rules

## Output
What this agent produces
```

## Cron Configuration

```bash
# Main pipeline - every 2 hours
0 */2 * * * /path/to/scripts/cron-orchestrator.sh >> /path/to/logs/cron.log 2>&1

# Supervisor - every 2 hours at :15 (offset from main)
15 */2 * * * /path/to/scripts/run-actor.sh supervisor >> /path/to/logs/supervisor.log 2>&1
```

## Core Scripts

### cron-orchestrator.sh
```bash
#!/bin/bash
# Runs all agents in sequence
AGENTS="idea-maker project-manager developer developer2 tester security"

for agent in $AGENTS; do
    ./run-actor.sh "$agent"
    sleep 5
done
```

### run-actor.sh
```bash
#!/bin/bash
# Runs a single agent with Claude Code
AGENT=$1
PROMPT_FILE="actors/$AGENT/prompt.md"

claude --print "$(cat $PROMPT_FILE)"
git add -A && git commit -m "[$AGENT] Auto-commit $(date)"
```

## Self-Improvement Protocol

**Critical feature**: The system learns from mistakes.

When any error occurs:
1. **Fix** the immediate issue
2. **Update** the relevant prompt/instructions to prevent recurrence
3. **Log** the learning to changelog.md

Example prompt update:
```markdown
# Before (keeps failing)
- Implement features

# After (learned from failure)
- Implement features
- **LEARNED**: Always run tests before marking DONE (TASK-042 incident)
```

## Status Files

Status files are **OVERWRITTEN** (not appended):

```json
// status/system.json
{
  "timestamp": "2026-01-23T14:30:00Z",
  "status": "healthy",
  "last_run": "security",
  "tasks_pending": 5,
  "tasks_completed_today": 3
}
```

## Key Principles

1. **Single Source of Truth**: `tasks.md` is the only task database
2. **Immutable Core**: Never corrupt CLAUDE.md, tasks.md, or orchestrator scripts
3. **Git Everything**: All changes are committed for history/recovery
4. **Self-Healing**: System can recover from git if files are corrupted
5. **Continuous Improvement**: Every mistake improves the instructions
6. **Agent Isolation**: Each agent has one job, does it well

## Getting Started (Fresh Instance)

1. Create the directory structure above
2. Write `CLAUDE.md` with your core rules
3. Create agent prompts in `actors/*/prompt.md`
4. Initialize `tasks.md` with initial backlog
5. Set up cron jobs
6. Let it run

## What To Build

The ecosystem can build anything. The original CronLoop built a web dashboard showing its own metrics. You could:
- Build a different web app
- Create CLI tools
- Generate documentation
- Maintain infrastructure
- Whatever you define in the task backlog

## Communication Between Instances

If cronloop1 and cronloop2 need to collaborate:
- Shared git repo
- Shared task file
- API endpoints
- Message queue
- Or simply: human relays information between instances

---

**This is the pure ecosystem blueprint.** No accumulated cruft, no existing web app, no legacy decisions. Start fresh and build something great.
