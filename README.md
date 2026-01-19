# Multi-Agent AI System with Claude Code

An autonomous multi-agent system powered by Claude Code running on a cron schedule. Agents collaborate through a shared task board, automatically committing all changes to GitHub.

## Architecture

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   PROJECT MANAGER   │ --> │     DEVELOPER       │ --> │       TESTER        │
│                     │     │                     │     │                     │
│ • Assigns tasks     │     │ • Implements code   │     │ • Runs tests        │
│ • Sets priorities   │     │ • Updates status    │     │ • Verifies work     │
│                     │     │   to DONE           │     │ • Adds feedback     │
│                     │     │                     │     │ • VERIFIED or FAILED│
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
         │                           │                           │
         └───────────────────────────┴───────────────────────────┘
                                     │
                              ┌──────▼──────┐
                              │  tasks.md   │
                              │ (shared)    │
                              └─────────────┘
```

## Agents

| Agent | Role | Prompt |
|-------|------|--------|
| **project-manager** | Assigns tasks, manages priorities, reviews backlog | [prompt.md](actors/project-manager/prompt.md) |
| **developer** | Implements assigned tasks, writes code | [prompt.md](actors/developer/prompt.md) |
| **tester** | Tests completed work, provides feedback | [prompt.md](actors/tester/prompt.md) |

## Task Lifecycle

| Status | Set By | Description |
|--------|--------|-------------|
| `TODO` | Project Manager | Task is ready and assigned |
| `IN_PROGRESS` | Developer | Work has started |
| `DONE` | Developer | Implementation complete |
| `VERIFIED` | Tester | Tests passed |
| `FAILED` | Tester | Tests failed, needs fix |

## Directory Structure

```
/home/novakj/
├── CLAUDE.md              # Server knowledge base (critical rules)
├── README.md              # This file
├── tasks.md               # Shared task board
├── actors/
│   ├── project-manager/
│   │   ├── prompt.md      # PM instructions
│   │   └── logs/          # Execution logs
│   ├── developer/
│   │   ├── prompt.md      # Developer instructions
│   │   └── logs/          # Execution logs
│   └── tester/
│       ├── prompt.md      # Tester instructions
│       └── logs/          # Execution logs
├── scripts/
│   ├── run-actor.sh       # Run a single actor
│   ├── cron-orchestrator.sh  # Run all actors in sequence
│   └── status.sh          # View system status
└── projects/              # Code created by agents
    └── hello.py           # Example: first completed task
```

## Execution Schedule

- **Cron**: Every 30 minutes (`*/30 * * * *`)
- **Order**: project-manager → developer → tester (5s delay between each)
- **Auto-commit**: All changes pushed to GitHub after each agent runs

## Quick Commands

```bash
# Run all agents now
./scripts/cron-orchestrator.sh

# Run a single agent
./scripts/run-actor.sh project-manager
./scripts/run-actor.sh developer
./scripts/run-actor.sh tester

# Check system status and recent logs
./scripts/status.sh

# View cron schedule
crontab -l
```

## How It Works

1. **Cron triggers** `cron-orchestrator.sh` every 30 minutes
2. **Project Manager** reads `tasks.md`, assigns tasks from backlog
3. **Developer** picks up assigned tasks, implements them in `/projects`
4. **Tester** verifies completed work, adds feedback
5. **Auto-commit** after each agent: changes pushed to GitHub
6. **Logs** saved to `actors/*/logs/` with timestamps

## Configuration

Agents run Claude Code in headless mode with `--dangerously-skip-permissions` for autonomous execution.

Each agent has its own prompt file defining:
- Responsibilities
- Rules and constraints
- Workflow steps
- Output format

## Logs

Each agent creates timestamped logs:
- `actors/project-manager/logs/YYYYMMDD_HHMMSS.log`
- `actors/developer/logs/YYYYMMDD_HHMMSS.log`
- `actors/tester/logs/YYYYMMDD_HHMMSS.log`
- `actors/cron.log` - Orchestrator output

## Server Info

- **Hostname**: vps-2d421d2a
- **OS**: Ubuntu 25.04
- **Claude Code**: v2.1.12
- **Primary User**: novakj

## Documentation

- [CLAUDE.md](CLAUDE.md) - Full server knowledge base and change log
- [tasks.md](tasks.md) - Current task board

---

*This system is managed by Claude Code as DevOps + Senior Developer*
