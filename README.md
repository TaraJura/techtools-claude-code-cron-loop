# CronLoop - Multi-Agent AI System

An autonomous multi-agent system powered by **Claude Code** running on a cron schedule. Five AI agents collaborate through a shared task board, building and maintaining a web dashboard while automatically committing all changes to GitHub.

**Live Dashboard**: [https://cronloop.techtools.cz](https://cronloop.techtools.cz)

**GitHub Repository**: [TaraJura/techtools-claude-code-cron-loop](https://github.com/TaraJura/techtools-claude-code-cron-loop)

## System Overview

| Component | Details |
|-----------|---------|
| **Agents** | 6 autonomous AI agents (idea-maker, project-manager, developer, developer2, tester, security) |
| **Execution** | Every 30 minutes via cron |
| **Web App** | 27 HTML pages, PWA-enabled, dark theme dashboard |
| **API** | 24 JSON endpoints for real-time data |
| **Commits** | 269+ auto-commits |
| **Tasks** | 91 tasks in the backlog |

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────────────────────────┐
│                              CRON ORCHESTRATOR (*/30 * * * *)                                 │
│                                                                                               │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐  ┌──────────┐ │
│  │IDEA MAKER │──▶│    PM     │──▶│ DEVELOPER │──▶│DEVELOPER2 │──▶│  TESTER   │─▶│ SECURITY │ │
│  │           │   │           │   │           │   │           │   │           │  │          │ │
│  │ Generate  │   │ Assign    │   │ Implement │   │ Implement │   │ Verify    │  │ Security │ │
│  │ ideas     │   │ tasks     │   │ features  │   │ features  │   │ work      │  │ review   │ │
│  └───────────┘   └───────────┘   └───────────┘   └───────────┘   └───────────┘  └──────────┘ │
│        │               │               │               │               │              │       │
│        └───────────────┴───────────────┴───────────────┴───────────────┴──────────────┘       │
│                                              │                                                │
│                                       ┌──────▼──────┐                                         │
│                                       │  tasks.md   │  ◀── Shared Task Board                  │
│                                       └──────┬──────┘                                         │
│                                              │                                                │
│                                       ┌──────▼──────┐                                         │
│                                       │   GitHub    │  ◀── Auto-commit after each             │
│                                       └─────────────┘      agent run                          │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
```

## How Data Flows (No Traditional Backend!)

This system has **no API server, no database, no Node.js/PHP/Python backend**. It uses a simple but effective architecture:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────┐                                                               │
│   │    CRON     │  Runs scripts every 1-30 minutes                              │
│   └──────┬──────┘                                                               │
│          │                                                                      │
│          ▼                                                                      │
│   ┌─────────────────────────────────────────┐                                   │
│   │     SHELL SCRIPTS (Bash + Python)       │                                   │
│   │     /home/novakj/scripts/               │                                   │
│   │                                         │                                   │
│   │  • update-metrics.sh    (every 1 min)   │                                   │
│   │  • update-costs.sh      (every 10 min)  │                                   │
│   │  • analyze-errors.sh    (every 5 min)   │                                   │
│   │  • cron-orchestrator.sh (every 30 min)  │                                   │
│   └──────┬──────────────────────────────────┘                                   │
│          │                                                                      │
│          │  Write JSON directly to web directory                                │
│          ▼                                                                      │
│   ┌─────────────────────────────────────────┐                                   │
│   │     STATIC JSON FILES                   │                                   │
│   │     /var/www/cronloop.techtools.cz/api/ │                                   │
│   │                                         │                                   │
│   │  • system-metrics.json                  │                                   │
│   │  • agent-status.json                    │                                   │
│   │  • costs.json                           │                                   │
│   │  • changelog.json                       │                                   │
│   │  • ...22 more JSON files                │                                   │
│   └──────┬──────────────────────────────────┘                                   │
│          │                                                                      │
│          │  Nginx serves as static files                                        │
│          ▼                                                                      │
│   ┌─────────────────────────────────────────┐                                   │
│   │     NGINX WEB SERVER                    │                                   │
│   │     (serves static HTML/CSS/JS/JSON)    │                                   │
│   └──────┬──────────────────────────────────┘                                   │
│          │                                                                      │
│          │  HTTP/HTTPS                                                          │
│          ▼                                                                      │
│   ┌─────────────────────────────────────────┐                                   │
│   │     BROWSER                             │                                   │
│   │                                         │                                   │
│   │  1. Load index.html (static)            │                                   │
│   │  2. JavaScript fetches /api/*.json      │                                   │
│   │  3. Render data in the UI               │                                   │
│   │  4. Auto-refresh every few seconds      │                                   │
│   └─────────────────────────────────────────┘                                   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Tech Stack Summary

| Layer | Technology | Description |
|-------|------------|-------------|
| **Scheduler** | Cron | Runs scripts on schedule (every 1-30 min) |
| **Data Generation** | Bash + Python | Shell scripts with embedded Python for JSON |
| **Data Storage** | JSON Files | Static `.json` files in `/var/www/.../api/` |
| **Web Server** | Nginx | Serves static files, handles SSL, routes CGI |
| **Frontend** | HTML/CSS/JS | PWA with vanilla JavaScript, fetches JSON |
| **Interactive** | CGI (Bash) | `/cgi-bin/*.cgi` for actions like health checks |

### Why No Traditional Backend?

1. **Zero complexity** - No database, no app server, no deployment pipeline
2. **Extremely resilient** - Static files survive crashes, no state to corrupt
3. **Full observability** - All data is in readable JSON files
4. **Git-native** - Everything is text files, perfect for version control
5. **Self-sufficient** - Only depends on Nginx, cron, and bash

### Example Data Flow

When you see CPU metrics on the dashboard:

```
1. Cron runs update-metrics.sh every minute
2. Script collects CPU/memory/disk data
3. Python (in bash) writes to /var/www/.../api/system-metrics.json
4. Browser's JavaScript fetches /api/system-metrics.json
5. Dashboard displays the metrics
```

## Agents

| Agent | Role | Description |
|-------|------|-------------|
| **idea-maker** | Ideation | Generates new feature ideas for the web app backlog |
| **project-manager** | Planning | Assigns tasks from backlog to developer or developer2, manages priorities |
| **developer** | Implementation | Builds web app features in `/var/www/cronloop.techtools.cz` |
| **developer2** | Implementation | Second developer agent for parallel task execution |
| **tester** | Quality Assurance | Verifies completed work on the live site |
| **security** | Security Review | Reviews code for vulnerabilities, monitors SSH attacks |

Each agent has a dedicated prompt file at `actors/<agent>/prompt.md` defining its behavior.

## Web Application

**URL**: https://cronloop.techtools.cz
**Web Root**: `/var/www/cronloop.techtools.cz`
**Stack**: HTML, CSS, JavaScript (PWA)

### Dashboard Pages (27 total)

| Page | Description |
|------|-------------|
| `index.html` | Main dashboard with system overview, agent status, real-time metrics |
| `agents.html` | Detailed view of all 6 agents and their configurations |
| `tasks.html` | Task board viewer showing backlog, in-progress, completed |
| `logs.html` | Browse agent execution logs by date and agent |
| `health.html` | System health metrics (CPU, memory, disk, services) |
| `security.html` | Security status, SSH attack monitoring, protection status |
| `changelog.html` | Git commit history with filtering and search |
| `schedule.html` | Cron job schedule visualization and execution timeline |
| `costs.html` | Claude API token usage and cost tracking |
| `budget.html` | Token budget tracking and spending limits |
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
| `onboarding.html` | Getting started guide and system overview |
| `postmortem.html` | Incident postmortem reports and analysis |

### API Endpoints (`/api/`)

24 JSON files providing real-time data:

| Endpoint | Data |
|----------|------|
| `agent-status.json` | Current status of all agents |
| `agents-config.json` | Agent configurations and prompts |
| `system-metrics.json` | CPU, memory, disk metrics (updated every minute) |
| `changelog.json` | Parsed git commit history |
| `costs.json` | Token usage and cost data |
| `costs-history.json` | Historical cost tracking data |
| `budget.json` | Token budget and spending limits |
| `budget-history.json` | Historical budget data |
| `schedule.json` | Cron execution schedule |
| `error-patterns.json` | Analyzed error patterns |
| `workflow.json` | Task workflow status |
| `dependencies.json` | Dependency health data |
| `dependencies-history.json` | Historical dependency status |
| `backup-status.json` | Backup job status |
| `secrets-audit.json` | Security audit results |
| `security-metrics.json` | Security-related metrics |
| `uptime-history.json` | Historical uptime data |
| `metrics-history.json` | Historical system metrics |
| `logs-index.json` | Index of available log files |
| `api-stats.json` | API endpoint usage statistics |
| `api-stats-history.json` | Historical API stats |
| `action-queue.json` | Queued system actions |
| `action-status.json` | Action execution status |
| `postmortems.json` | Incident postmortem data |

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
├── tasks.md               # Shared task board (91 tasks)
│
├── docs/                  # Detailed documentation
│   ├── server-config.md   # Server specs, paths, software
│   ├── security-guide.md  # Security rules and checklists
│   └── engine-guide.md    # Self-healing protocols
│
├── status/                # Current state (overwritten each cycle)
│   ├── system.json        # System health status
│   ├── security.json      # Security review findings
│   └── task-counter.txt   # Next task ID number
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
│   ├── developer2/
│   ├── tester/
│   ├── security/
│   └── cron.log           # Orchestrator execution log
│
├── scripts/               # 27 automation scripts
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
│   ├── update-budget.sh        # Token budget tracking
│   ├── update-postmortems.sh   # Incident postmortem updates
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
| `*/30 * * * *` | `cron-orchestrator.sh` | Run all 6 agents sequentially |
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
│ PM sets  │    │ Developer │    │ Developer   │    │ Tester       │    │ Auto     │
│          │    │ starts    │    │ completes   │    │ approves     │    │ archive  │
└──────────┘    └──────────┘    └─────────────┘    └──────────────┘    └──────────┘
                                       │                                     │
                                       ▼ (if issues)                         │
                                ┌──────────┐                                 │
                                │  FAILED  │ ──▶ Back to IN_PROGRESS         │
                                └──────────┘                                 │
                                                                             ▼
                                                              logs/tasks-archive/tasks-YYYY-MM.md
```

### Task File Management

To prevent unlimited growth, tasks are automatically archived:

| File | Contents | Size Target |
|------|----------|-------------|
| `tasks.md` | Active tasks (TODO, IN_PROGRESS, DONE, FAILED) | <100KB |
| `logs/tasks-archive/tasks-YYYY-MM.md` | Completed VERIFIED tasks | Monthly archives |
| `status/task-counter.txt` | Next task ID number | Single number |

**Archiving**: Runs automatically via `maintenance.sh` when `tasks.md` exceeds 100KB.

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
7. **Self-Improving**: System learns from mistakes and updates its own instructions

## Self-Improvement System

The system is designed to **get smarter over time** by learning from every mistake:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   ERROR     │────▶│  IDENTIFY   │────▶│    FIX      │────▶│   UPDATE    │
│   OCCURS    │     │  ROOT CAUSE │     │   ISSUE     │     │INSTRUCTIONS │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                   │
                                                                   ▼
                                                          ┌─────────────┐
                                                          │  SYSTEM IS  │
                                                          │   SMARTER   │
                                                          └─────────────┘
```

### How It Works

| Event | System Response |
|-------|-----------------|
| Task fails testing | Developer updates its prompt with lesson learned |
| Security vulnerability | Security agent adds prevention rule |
| Duplicate work created | Strengthen deduplication checks in prompts |
| Same error twice | **Mandatory** instruction update to prevent recurrence |
| Build failure | Document fix in engine-guide.md |

### What Gets Updated

- `CLAUDE.md` - System-wide rules
- `actors/<agent>/prompt.md` - Agent-specific behavior
- `docs/*.md` - Detailed procedures

### Tracking Improvements

All self-improvements are logged:
```
[SELF-IMPROVEMENT] Updated developer prompt: Added rule to verify feature doesn't exist (learned from TASK-042)
```

> **Every mistake makes the system permanently smarter.**

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
