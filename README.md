# CronLoop - Multi-Agent AI System

An autonomous multi-agent system powered by **Claude Code** running on a cron schedule. Five AI agents collaborate through a shared task board, building and maintaining a web dashboard while automatically committing all changes to GitHub.

**Live Dashboard**: [https://cronloop.techtools.cz](https://cronloop.techtools.cz)

**GitHub Repository**: [TaraJura/techtools-claude-code-cron-loop](https://github.com/TaraJura/techtools-claude-code-cron-loop)

## System Overview

| Component | Details |
|-----------|---------|
| **Agents** | 5 autonomous AI agents (idea-maker, project-manager, developer, tester, security) |
| **Execution** | Every 30 minutes via cron |
| **Web App** | 24 HTML pages, PWA-enabled, dark theme dashboard |
| **API** | 22 JSON endpoints for real-time data |
| **Commits** | 245+ auto-commits |
| **Tasks** | 85 tasks in the backlog |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CRON ORCHESTRATOR (*/30 * * * *)                      │
│                                                                                 │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐ │
│  │IDEA MAKER │──▶│    PM     │──▶│ DEVELOPER │──▶│  TESTER   │──▶│ SECURITY  │ │
│  │           │   │           │   │           │   │           │   │           │ │
│  │ Generate  │   │ Assign    │   │ Implement │   │ Verify    │   │ Security  │ │
│  │ ideas     │   │ tasks     │   │ features  │   │ work      │   │ review    │ │
│  └───────────┘   └───────────┘   └───────────┘   └───────────┘   └───────────┘ │
│        │               │               │               │               │        │
│        └───────────────┴───────────────┴───────────────┴───────────────┘        │
│                                        │                                        │
│                                 ┌──────▼──────┐                                 │
│                                 │  tasks.md   │  ◀── Shared Task Board          │
│                                 └──────┬──────┘                                 │
│                                        │                                        │
│                                 ┌──────▼──────┐                                 │
│                                 │   GitHub    │  ◀── Auto-commit after each     │
│                                 └─────────────┘      agent run                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Agents

| Agent | Role | Description |
|-------|------|-------------|
| **idea-maker** | Ideation | Generates new feature ideas for the web app backlog |
| **project-manager** | Planning | Assigns tasks from backlog to developer, manages priorities |
| **developer** | Implementation | Builds web app features in `/var/www/cronloop.techtools.cz` |
| **tester** | Quality Assurance | Verifies completed work on the live site |
| **security** | Security Review | Reviews code for vulnerabilities, monitors SSH attacks |

Each agent has a dedicated prompt file at `actors/<agent>/prompt.md` defining its behavior.

## Web Application

**URL**: https://cronloop.techtools.cz
**Web Root**: `/var/www/cronloop.techtools.cz`
**Stack**: HTML, CSS, JavaScript (PWA)

### Dashboard Pages (24 total)

| Page | Description |
|------|-------------|
| `index.html` | Main dashboard with system overview, agent status, real-time metrics |
| `agents.html` | Detailed view of all 5 agents and their configurations |
| `tasks.html` | Task board viewer showing backlog, in-progress, completed |
| `logs.html` | Browse agent execution logs by date and agent |
| `health.html` | System health metrics (CPU, memory, disk, services) |
| `security.html` | Security status, SSH attack monitoring, protection status |
| `changelog.html` | Git commit history with filtering and search |
| `schedule.html` | Cron job schedule visualization and execution timeline |
| `costs.html` | Claude API token usage and cost tracking |
| `trends.html` | Long-term metric trends and patterns |
| `forecast.html` | Predictive analytics for system resources |
| `uptime.html` | Service uptime monitoring and history |
| `architecture.html` | Visual diagram of agent relationships and data flow |
| `workflow.html` | Task lifecycle and agent workflow status |
| `api-stats.html` | API endpoint usage statistics |
| `error-patterns.html` | Error analysis and pattern detection |
| `backups.html` | Backup status and history |
| `secrets-audit.html` | Security audit for exposed secrets |
| `dependencies.html` | System dependency health monitoring |
| `digest.html` | Daily/weekly system digest summary |
| `search.html` | Global search across logs, tasks, and commits |
| `settings.html` | Dashboard configuration and preferences |
| `terminal.html` | Web-based terminal interface (read-only) |
| `playbooks.html` | Runbook documentation for common operations |

### API Endpoints (`/api/`)

22 JSON files providing real-time data:

| Endpoint | Data |
|----------|------|
| `agent-status.json` | Current status of all agents |
| `agents-config.json` | Agent configurations and prompts |
| `system-metrics.json` | CPU, memory, disk metrics (updated every minute) |
| `changelog.json` | Parsed git commit history |
| `costs.json` | Token usage and cost data |
| `schedule.json` | Cron execution schedule |
| `error-patterns.json` | Analyzed error patterns |
| `workflow.json` | Task workflow status |
| `dependencies.json` | Dependency health data |
| `backup-status.json` | Backup job status |
| `secrets-audit.json` | Security audit results |
| `uptime-history.json` | Historical uptime data |
| `metrics-history.json` | Historical system metrics |
| `logs-index.json` | Index of available log files |

### CGI Scripts (`/cgi-bin/`)

| Script | Function |
|--------|----------|
| `terminal.cgi` | Web terminal command execution (whitelisted commands) |
| `execute.cgi` | Execute playbook actions |
| `action.cgi` | Queue and manage system actions |

### PWA Features

- Installable as native app
- Offline-capable with service worker (`sw.js`)
- Custom icons in `/icons/`
- App manifest (`manifest.json`)

## Project Structure

```
/home/novakj/
├── CLAUDE.md              # Core system rules and instructions
├── README.md              # This file
├── tasks.md               # Shared task board (85 tasks)
│
├── docs/                  # Detailed documentation
│   ├── server-config.md   # Server specs, paths, software
│   ├── security-guide.md  # Security rules and checklists
│   └── engine-guide.md    # Self-healing protocols
│
├── status/                # Current state (overwritten each cycle)
│   ├── system.json        # System health status
│   └── security.json      # Security review findings
│
├── logs/                  # Execution logs
│   ├── changelog.md       # Recent changes
│   ├── metrics.log        # System metrics log
│   ├── maintenance.log    # Hourly maintenance log
│   └── archive/           # Archived logs
│
├── actors/                # Agent configurations
│   ├── idea-maker/
│   │   └── prompt.md      # Agent behavior instructions
│   ├── project-manager/
│   ├── developer/
│   ├── tester/
│   ├── security/
│   └── cron.log           # Orchestrator execution log
│
├── scripts/               # 26 automation scripts
│   ├── cron-orchestrator.sh    # Main orchestrator (runs all agents)
│   ├── run-actor.sh            # Run individual agent
│   ├── update-metrics.sh       # Update system metrics
│   ├── update-schedule.sh      # Update schedule display
│   ├── update-changelog.sh     # Parse git history
│   ├── update-costs.sh         # Track API costs
│   ├── update-workflow.sh      # Track task workflow
│   ├── analyze-errors.sh       # Error pattern analysis
│   ├── maintenance.sh          # Hourly maintenance
│   ├── cleanup.sh              # Daily cleanup
│   ├── health-check.sh         # Health monitoring
│   ├── secrets-audit.sh        # Security scanning
│   └── ...more scripts
│
├── backups/               # Configuration backups
└── projects/              # Additional projects

/var/www/cronloop.techtools.cz/   # Web application root
├── index.html             # Main dashboard
├── api/                   # JSON data endpoints
├── cgi-bin/               # CGI scripts
├── logs/                  # Web-accessible logs
├── icons/                 # PWA icons
├── manifest.json          # PWA manifest
└── sw.js                  # Service worker
```

## Scheduled Tasks (Cron)

| Schedule | Script | Description |
|----------|--------|-------------|
| `*/30 * * * *` | `cron-orchestrator.sh` | Run all 5 agents sequentially |
| `* * * * *` | `update-metrics.sh` | Update system metrics JSON |
| `0 * * * *` | `maintenance.sh` | Hourly maintenance and health checks |
| `0 3 * * *` | `cleanup.sh` | Daily cleanup of old logs |
| `*/5 * * * *` | `analyze-errors.sh` | Error pattern analysis |
| `*/5 * * * *` | `update-workflow.sh` | Workflow metrics |
| `*/10 * * * *` | `update-changelog.sh` | Git history parsing |
| `*/10 * * * *` | `update-costs.sh` | Cost tracking |
| `*/10 * * * *` | `update-dependencies.sh` | Dependency health |

## Task Lifecycle

```
┌──────────┐    ┌──────────┐    ┌─────────────┐    ┌──────────────┐    ┌──────────┐
│   TODO   │───▶│IN_PROGRESS│───▶│    DONE     │───▶│   VERIFIED   │───▶│ ARCHIVED │
│          │    │           │    │             │    │              │    │          │
│ PM sets  │    │ Developer │    │ Developer   │    │ Tester       │    │ Cleanup  │
│          │    │ starts    │    │ completes   │    │ approves     │    │          │
└──────────┘    └──────────┘    └─────────────┘    └──────────────┘    └──────────┘
                                       │
                                       ▼ (if issues)
                                ┌──────────┐
                                │  FAILED  │ ──▶ Back to IN_PROGRESS
                                └──────────┘
```

## Server Specifications

| Resource | Value |
|----------|-------|
| **Hostname** | vps-2d421d2a |
| **OS** | Ubuntu 25.04 (Plucky Puffin) |
| **Kernel** | Linux 6.14.0-34-generic |
| **CPU** | 4 cores |
| **RAM** | 7.6 GB |
| **Disk** | 72 GB (68 GB available) |
| **Web Server** | Nginx 1.26.3 |
| **SSL** | Let's Encrypt (expires 2026-04-19) |
| **Claude Code** | v2.1.12 |
| **Git** | 2.48.1 |

## Security

- **Nginx blocks** sensitive paths: `.git`, `.env`, `*.sh`, `*.py`, `*.log`, `*.md`
- **SSH monitoring**: ~285 failed attempts/hour from ~259 unique IPs
- **File permissions**: SSH keys (600), SSH dir (700), configs (664)
- **Security agent**: Runs last in cycle, reviews code and configs
- **No secrets in git**: Verified clean history

## Quick Commands

```bash
# Run all agents manually
./scripts/cron-orchestrator.sh

# Run a specific agent
./scripts/run-actor.sh developer

# Check system status
./scripts/status.sh

# View current security status
cat status/security.json | jq .

# View agent execution log
tail -f actors/cron.log

# Check cron jobs
crontab -l

# View recent commits
git log --oneline -10
```

## Key Design Principles

1. **Web-First**: Every feature must be accessible via browser at https://cronloop.techtools.cz
2. **Autonomous**: Agents run without human intervention every 30 minutes
3. **Self-Documenting**: Status files, logs, and dashboards provide full visibility
4. **Self-Healing**: Maintenance scripts clean up and recover from issues
5. **Version Controlled**: All changes auto-committed to GitHub
6. **Status Overwrites**: Status files are overwritten (not appended) to prevent growth

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Core system rules for all agents |
| [docs/server-config.md](docs/server-config.md) | Server configuration details |
| [docs/security-guide.md](docs/security-guide.md) | Security guidelines and checklists |
| [docs/engine-guide.md](docs/engine-guide.md) | Self-healing and recovery procedures |
| [tasks.md](tasks.md) | Current task board |
| [logs/changelog.md](logs/changelog.md) | Recent changes log |

## Contributing

This system is fully autonomous. To add features:

1. Add a task to the **Backlog** section in `tasks.md`
2. Wait for the **project-manager** agent to assign it
3. The **developer** agent will implement it
4. The **tester** agent will verify it
5. The **security** agent will review it

Or manually implement and commit - the agents will adapt.

---

*Managed autonomously by Claude Code as DevOps + Senior Developer*
*System operational since January 2026*
