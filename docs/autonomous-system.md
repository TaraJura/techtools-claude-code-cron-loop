# Autonomous Claude Code Ecosystem

> **IMPORTANT**: This entire server is maintained autonomously by Claude Code with full sudo permissions. Everything you see here - every file, script, web page, and configuration - is created, maintained, and evolved by an AI system running in crontab.

## What This System Is

This is a **fully autonomous, self-maintaining, self-improving AI ecosystem**:

| Aspect | Description |
|--------|-------------|
| **Core Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | Runs via crontab every 30 minutes |
| **Permissions** | Full sudo access to the entire server |
| **Goal** | Build, maintain, and improve itself + a web app showcasing the ecosystem |
| **Human Intervention** | Zero required for normal operation |

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTONOMOUS CLAUDE CODE ECOSYSTEM                         │
│                                                                             │
│  ┌─────────────┐                                                            │
│  │   CRONTAB   │  Every 30 minutes, triggers the orchestrator               │
│  └──────┬──────┘                                                            │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CLAUDE CODE (with sudo)                          │   │
│  │                                                                     │   │
│  │  • Reads tasks from tasks.md                                        │   │
│  │  • Executes 6 specialized AI agents                                 │   │
│  │  • Writes code, configs, documentation                              │   │
│  │  • Manages web application                                          │   │
│  │  • Commits changes to GitHub                                        │   │
│  │  • Repairs and improves itself                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    OUTPUTS                                          │   │
│  │                                                                     │   │
│  │  • Web Dashboard: https://cronloop.techtools.cz                     │   │
│  │  • 27 HTML pages, 24 API endpoints                                  │   │
│  │  • Automated commits to GitHub                                      │   │
│  │  • Self-documenting logs and metrics                                │   │
│  │  • Updated instructions (learns from mistakes)                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. Full Autonomy
- **No human intervention required** for normal operation
- System runs 24/7, 365 days a year
- Makes its own decisions about what to build and how

### 2. Self-Repair
- Detects when something breaks
- Automatically recovers from failures
- Restores corrupted files from git
- Restarts failed services

### 3. Self-Improvement
- Learns from every mistake
- Updates its own instructions to prevent repeat errors
- Evolves to become more capable over time
- Documents lessons learned in changelogs

### 4. Full Transparency
- Everything visible via web dashboard
- All logs accessible
- All code committed to GitHub
- Nothing hidden

## Permissions Architecture

Claude Code runs with full system access:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERMISSION LEVELS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  USER: novakj (primary user, runs Claude Code)                  │
│    │                                                            │
│    ├── sudo access (can do anything as root)                    │
│    │                                                            │
│    ├── Full file system access                                  │
│    │   • /home/novakj/* (workspace)                             │
│    │   • /var/www/* (web files)                                 │
│    │   • /etc/* (system configs)                                │
│    │   • /var/log/* (system logs)                               │
│    │                                                            │
│    ├── Service management                                       │
│    │   • systemctl start/stop/restart                           │
│    │   • nginx, cron, ssh, etc.                                 │
│    │                                                            │
│    ├── Package management                                       │
│    │   • apt install/remove                                     │
│    │   • System updates                                         │
│    │                                                            │
│    └── Network access                                           │
│        • External API calls                                     │
│        • GitHub operations                                      │
│        • Web server management                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## The Six AI Agents

The system runs 6 specialized Claude Code instances (agents):

| Order | Agent | Purpose |
|-------|-------|---------|
| 1 | **idea-maker** | Generates new feature ideas for the backlog |
| 2 | **project-manager** | Assigns tasks to developers, manages priorities |
| 3 | **developer** | Implements features, writes code |
| 4 | **developer2** | Second developer for parallel implementation |
| 5 | **tester** | Verifies completed work, reports failures |
| 6 | **security** | Reviews for vulnerabilities, monitors threats |

Each agent runs sequentially with 5-second delays between them.

## Self-Repair Capabilities

The system can automatically fix:

| Problem | Auto-Recovery |
|---------|---------------|
| Corrupted files | Restore from git |
| Failed services | Restart via systemctl |
| Disk space issues | Run cleanup scripts |
| Broken configs | Roll back to working version |
| Git conflicts | Auto-resolve or reset |
| Runaway processes | Kill and restart |

## Self-Improvement Loop

```
   ┌────────────────────────────────────────┐
   │         ERROR OR FAILURE OCCURS        │
   └────────────────────┬───────────────────┘
                        │
                        ▼
   ┌────────────────────────────────────────┐
   │      IDENTIFY ROOT CAUSE               │
   │      (What went wrong and why?)        │
   └────────────────────┬───────────────────┘
                        │
                        ▼
   ┌────────────────────────────────────────┐
   │      FIX THE IMMEDIATE ISSUE           │
   │      (Resolve current problem)         │
   └────────────────────┬───────────────────┘
                        │
                        ▼
   ┌────────────────────────────────────────┐
   │      UPDATE INSTRUCTIONS               │
   │      (CLAUDE.md, prompts, docs)        │
   │      to prevent recurrence             │
   └────────────────────┬───────────────────┘
                        │
                        ▼
   ┌────────────────────────────────────────┐
   │      SYSTEM IS NOW SMARTER             │
   │      (Won't make same mistake again)   │
   └────────────────────────────────────────┘
```

## Files That Control the System

| File | Purpose | Location |
|------|---------|----------|
| `CLAUDE.md` | Core brain/instructions | `/home/novakj/CLAUDE.md` |
| `tasks.md` | Shared task board | `/home/novakj/tasks.md` |
| Agent prompts | Individual agent behavior | `/home/novakj/actors/*/prompt.md` |
| Orchestrator | Main execution script | `/home/novakj/scripts/cron-orchestrator.sh` |
| Status files | Current system state | `/home/novakj/status/*.json` |

## What The Web App Shows

The ecosystem creates and maintains a web dashboard at https://cronloop.techtools.cz that displays:

- Real-time system metrics (CPU, memory, disk)
- Agent status and execution logs
- Task board with all backlog items
- Security monitoring and SSH attack stats
- API token costs and budgets
- Git commit history
- Error patterns and trends
- Much more (27 pages total)

## Interacting With The System

### To Add New Work
Add a task to the **Backlog** in `tasks.md` - the agents will automatically pick it up, implement it, test it, and deploy it.

### To Change System Behavior
Edit the relevant files:
- `CLAUDE.md` for system-wide rules
- `actors/<agent>/prompt.md` for specific agent behavior
- `docs/*.md` for detailed procedures

### To Monitor The System
- Visit https://cronloop.techtools.cz
- Check `/home/novakj/status/*.json` for current state
- View logs in `/home/novakj/actors/*/logs/`
- Run `./scripts/status.sh` for quick health check

## Safety Guardrails

Despite having sudo, the system has built-in limits:

| Guardrail | Limit |
|-----------|-------|
| Disk usage | Stop if >80% full |
| Backlog size | Max 30 pending tasks |
| Log retention | 7 days (auto-cleanup) |
| Git commits | Max 100/day |
| Script size | Max 500 lines (then refactor) |
| Execution time | 10 min timeout per agent |

## Emergency Recovery

If something goes catastrophically wrong:

```bash
# 1. Restore from git
git fetch origin
git reset --hard origin/main

# 2. Verify core files
ls -la CLAUDE.md tasks.md scripts/*.sh

# 3. Restart cron
sudo systemctl restart cron

# 4. Check status
./scripts/status.sh
```

## Why This Architecture?

1. **Demonstrates AI autonomy** - Shows what AI can do without human supervision
2. **Self-documenting** - Creates its own dashboard to explain itself
3. **Resilient** - Recovers from failures automatically
4. **Evolving** - Gets smarter over time through self-improvement
5. **Transparent** - Everything logged and visible
6. **Real production system** - Not a demo, actual working infrastructure

---

> **This document itself was created and is maintained by Claude Code.**
>
> The machine maintains itself. Welcome to the future.
