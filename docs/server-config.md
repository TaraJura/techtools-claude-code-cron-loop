# Server Configuration

> Static server information. This file rarely changes - only update when hardware/software changes.

## CRITICAL: Autonomous AI System

> **This entire server is autonomously maintained by Claude Code with FULL SUDO PERMISSIONS.**

This is not a traditional server. It's an **autonomous AI ecosystem**:

| Aspect | Description |
|--------|-------------|
| **Engine** | Claude Code (Anthropic's AI CLI) |
| **Schedule** | Runs every 30 minutes via crontab |
| **Permissions** | Full sudo access - can do anything on this server |
| **Purpose** | Self-maintaining, self-improving AI that builds a web app about itself |
| **Agents** | 6 specialized AI agents (idea-maker, project-manager, developer, developer2, tester, security) |

The AI can:
- Install/remove packages (`apt`)
- Manage services (`systemctl`)
- Edit any file on the system
- Configure network, firewall, DNS
- Create/modify cron jobs
- Deploy web applications

Everything you see on this server was created and is maintained by AI.

---

## Server Overview

- **Hostname**: vps-2d421d2a
- **Role**: Autonomous AI Development Server
- **Managed by**: Claude Code (AI with full sudo) - runs autonomously
- **Primary User**: novakj (with sudo privileges, used by Claude Code)

## System Specifications

| Resource | Value |
|----------|-------|
| OS | Ubuntu 25.04 (Plucky Puffin) |
| Kernel | Linux 6.14.0-34-generic |
| CPU Cores | 4 |
| RAM | 7.6 GB |
| Disk | 72 GB (70 GB available) |
| Platform | linux |

## Users

| Username | Role | Sudo | Shell | Home |
|----------|------|------|-------|------|
| novakj | Primary Admin/Developer | Yes | /bin/bash | /home/novakj |
| ubuntu | System User | Yes | /bin/bash | /home/ubuntu |

## Installed Software & Services

### System Packages
- Base Ubuntu 25.04 installation

### Development Tools
- Git 2.48.1 (configured for TaraJura / jiri.novak@techtools.cz)

### Databases
- (none installed yet)

### Web Servers
- Nginx 1.26.3
  - Site: `cronloop.techtools.cz` -> `/var/www/cronloop.techtools.cz`
  - Config: `/etc/nginx/sites-available/cronloop.techtools.cz`

### Other Services
- Claude Code 2.1.12 (AI coding assistant CLI)

## Multi-Agent System

The server runs an automated multi-agent system using Claude Code in headless mode.

### Main Pipeline Actors (Every 30 min)
| Actor | Path | Role |
|-------|------|------|
| idea-maker | `/home/novakj/actors/idea-maker` | Generates new feature ideas for backlog |
| project-manager | `/home/novakj/actors/project-manager` | Assigns tasks, manages priorities |
| developer | `/home/novakj/actors/developer` | Implements assigned tasks |
| developer2 | `/home/novakj/actors/developer2` | Second developer for parallel implementation |
| tester | `/home/novakj/actors/tester` | Tests completed work, gives feedback |
| security | `/home/novakj/actors/security` | Reviews code and configs for vulnerabilities |

**Execution Order:** idea-maker -> project-manager -> developer -> developer2 -> tester -> security (sequential, 5s delay)

### Supervisor Actor (Hourly at :15)
| Actor | Path | Role |
|-------|------|------|
| supervisor | `/home/novakj/actors/supervisor` | Top-tier ecosystem overseer, monitors health, maintains stability |

The **supervisor** is a meta-agent that:
- Runs separately from the main pipeline (hourly at minute 15)
- Maintains persistent state in `actors/supervisor/state.json`
- Monitors all agents and system health
- Prioritizes stability - observes more than changes
- Goal: Keep the ecosystem alive as long as possible

**Key Files:**
- `tasks.md` - Shared task board
- `scripts/run-actor.sh` - Runs individual actors
- `scripts/cron-orchestrator.sh` - Runs all actors sequentially
- `scripts/status.sh` - Shows system status
- `actors/*/logs/` - Execution logs

## Important Paths

| Path | Purpose |
|------|---------|
| `/home/novakj` | Primary home directory, main workspace |
| `/home/novakj/CLAUDE.md` | Core instructions (read this first) |
| `/home/novakj/docs/` | Detailed documentation |
| `/home/novakj/status/` | Current system/security status |
| `/home/novakj/logs/` | Changelogs and archives |
| `/home/novakj/tasks.md` | Multi-agent task board |
| `/home/novakj/actors/` | Actor configurations and logs |
| `/home/novakj/scripts/` | Automation scripts |
| `/home/novakj/projects/` | Code created by agents |
| `/home/novakj/backups/` | Configuration backups |
| `/var/www/cronloop.techtools.cz` | Web app for cronloop subdomain |
| `/var/log/` | System logs |

## Web Application

**Live URL**: https://cronloop.techtools.cz

**Web Root**: `/var/www/cronloop.techtools.cz`

**Current Stack:**
- Frontend: HTML, CSS, JavaScript (static files)
- Web Server: Nginx with SSL (Let's Encrypt, expires 2026-04-19)
- No backend yet (can be added: Node.js, Python Flask, etc.)

## Scheduled Tasks (Cron)

| Schedule | Task | Description |
|----------|------|-------------|
| `*/30 * * * *` | `cron-orchestrator.sh` | Runs main 6-agent pipeline every 30 minutes |
| `15 * * * *` | `run-supervisor.sh` | Runs supervisor agent hourly at :15 |
| `* * * * *` | `update-metrics.sh` | Updates system metrics JSON for web dashboard |
| `0 * * * *` | `maintenance.sh` | Hourly system maintenance and health checks |
| `0 3 * * *` | `cleanup.sh` | Daily cleanup of old logs and backups |
| `*/5 * * * *` | `analyze-errors.sh` | Error pattern analysis |
| `*/5 * * * *` | `update-workflow.sh` | Workflow metrics update |
| `*/10 * * * *` | `update-changelog.sh` | Git history parsing |
| `*/10 * * * *` | `update-costs.sh` | Cost tracking |
| `*/10 * * * *` | `update-dependencies.sh` | Dependency health |

## GitHub Repository

**URL**: https://github.com/TaraJura/techtools-claude-code-cron-loop

## Firewall Rules (UFW)

| Port | Service | Status |
|------|---------|--------|
| 22 | SSH | (to be configured) |

## Pending Infrastructure Tasks

- [ ] Configure UFW firewall
- [ ] Set up automatic security updates
- [ ] Install fail2ban for SSH protection
- [ ] Configure backup strategy
