# Multi-Agent AI System with Claude Code

An autonomous multi-agent system powered by Claude Code running on a cron schedule. Agents collaborate through a shared task board, automatically committing all changes to GitHub.

## Architecture

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ IDEA MAKER  │-->│     PM      │-->│  DEVELOPER  │-->│   TESTER    │-->│  SECURITY   │
│             │   │             │   │             │   │             │   │             │
│ Creates new │   │ Assigns     │   │ Implements  │   │ Verifies    │   │ Security    │
│ ideas       │   │ tasks       │   │ code        │   │ work        │   │ review      │
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
        │                │                │                │                │
        └────────────────┴────────────────┴────────────────┴────────────────┘
                                          │
                                   ┌──────▼──────┐
                                   │  tasks.md   │
                                   │  (shared)   │
                                   └─────────────┘
```

## Agents

| Agent | Role | Prompt |
|-------|------|--------|
| **idea-maker** | Generates new feature ideas | [prompt.md](actors/idea-maker/prompt.md) |
| **project-manager** | Assigns tasks, manages priorities | [prompt.md](actors/project-manager/prompt.md) |
| **developer** | Implements assigned tasks | [prompt.md](actors/developer/prompt.md) |
| **tester** | Tests completed work | [prompt.md](actors/tester/prompt.md) |
| **security** | Security reviews | [prompt.md](actors/security/prompt.md) |

## Documentation Structure

```
/home/novakj/
├── CLAUDE.md              # Core rules only (~130 lines)
├── README.md              # This file
├── tasks.md               # Shared task board
│
├── docs/                  # Detailed documentation
│   ├── server-config.md   # Server specs, paths, software
│   ├── security-guide.md  # Security rules and checklists
│   └── engine-guide.md    # Self-healing protocols
│
├── status/                # Current state (OVERWRITTEN each cycle)
│   ├── system.json        # System health status
│   └── security.json      # Security review status
│
├── logs/                  # Change history
│   ├── changelog.md       # Recent changes (last 7 days)
│   └── archive/           # Monthly archives
│
├── actors/                # Agent configurations
│   ├── idea-maker/
│   ├── project-manager/
│   ├── developer/
│   ├── tester/
│   └── security/
│
├── scripts/               # Automation scripts
│   ├── run-actor.sh
│   ├── cron-orchestrator.sh
│   └── status.sh
│
└── projects/              # Code created by agents
```

## Key Design Principles

1. **CLAUDE.md is lean** - Only core rules, ~130 lines (not 800+)
2. **Status files are OVERWRITTEN** - Current state only, no endless appending
3. **Changelog is rotated** - 7 days active, then archived
4. **Docs are on-demand** - Detailed guides loaded when needed

## Task Lifecycle

| Status | Set By | Description |
|--------|--------|-------------|
| `TODO` | Project Manager | Task is ready and assigned |
| `IN_PROGRESS` | Developer | Work has started |
| `DONE` | Developer | Implementation complete |
| `VERIFIED` | Tester | Tests passed |
| `FAILED` | Tester | Tests failed, needs fix |

## Execution Schedule

- **Cron**: Every 30 minutes (`*/30 * * * *`)
- **Order**: idea-maker -> PM -> developer -> tester -> security
- **Auto-commit**: Changes pushed to GitHub after each agent

## Quick Commands

```bash
# Run all agents now
./scripts/cron-orchestrator.sh

# Run a single agent
./scripts/run-actor.sh developer

# Check system status
./scripts/status.sh

# View current security status
cat status/security.json | jq .

# View recent changes
cat logs/changelog.md
```

## Web Application

**Live Site**: [https://cronloop.techtools.cz](https://cronloop.techtools.cz)

This is the **main project** that all agents work on. Every feature must be accessible via the web browser.

**Web Root**: `/var/www/cronloop.techtools.cz`

## Server Info

- **Hostname**: vps-2d421d2a
- **OS**: Ubuntu 25.04
- **Claude Code**: v2.1.12
- **Web Server**: Nginx 1.26.3
- **Primary User**: novakj

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Core system rules |
| [docs/server-config.md](docs/server-config.md) | Server configuration |
| [docs/security-guide.md](docs/security-guide.md) | Security guidelines |
| [docs/engine-guide.md](docs/engine-guide.md) | Self-healing engine |
| [tasks.md](tasks.md) | Current task board |
| [logs/changelog.md](logs/changelog.md) | Recent changes |

---

*This system is managed by Claude Code as DevOps + Senior Developer*
