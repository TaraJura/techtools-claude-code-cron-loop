# CLAUDE.md - Server Knowledge Base

> **CRITICAL RULES**:
> 1. Every change made on this server MUST be documented in this file. Update the relevant sections and add entries to the Change Log.
> 2. Keep `README.md` updated alongside this file - it is the public-facing documentation in the GitHub repository.

## Server Overview

- **Hostname**: vps-2d421d2a
- **Role**: Production Development Server
- **Managed by**: Claude (DevOps + Senior Developer)
- **Primary User**: novakj (with sudo privileges)
- **Last Updated**: 2026-01-19

## System Specifications

| Resource | Value |
|----------|-------|
| OS | Ubuntu 25.04 (Plucky Puffin) |
| Kernel | Linux 6.14.0-34-generic |
| CPU Cores | 4 |
| RAM | 7.6 GB |
| Disk | 72 GB (70 GB available) |
| Platform | linux |

## Current Server Status

- **Status**: Operational
- **Environment**: Production
- **Services Running**: Nginx (port 80)

---

## Users

| Username | Role | Sudo | Shell | Home |
|----------|------|------|-------|------|
| novakj | Primary Admin/Developer | Yes | /bin/bash | /home/novakj |
| ubuntu | System User | Yes | /bin/bash | /home/ubuntu |

---

## Installed Software & Services

### System Packages
- Base Ubuntu 25.04 installation

### Development Tools
- Git 2.48.1 (configured for TaraJura / jiri.novak@techtools.cz)

### Databases
- (none installed yet)

### Web Servers
- Nginx 1.26.3
  - Site: `cronloop.techtools.cz` → `/var/www/cronloop.techtools.cz`
  - Config: `/etc/nginx/sites-available/cronloop.techtools.cz`

### Other Services
- Claude Code 2.1.12 (AI coding assistant CLI)

### Multi-Agent System
The server runs an automated multi-agent system using Claude Code in headless mode.

**Actors:**
| Actor | Path | Role |
|-------|------|------|
| idea-maker | `/home/novakj/actors/idea-maker` | Generates new feature ideas for backlog |
| project-manager | `/home/novakj/actors/project-manager` | Assigns tasks, manages priorities |
| developer | `/home/novakj/actors/developer` | Implements assigned tasks |
| tester | `/home/novakj/actors/tester` | Tests completed work, gives feedback |

**Execution Order:** idea-maker → project-manager → developer → tester (sequential, 5s delay between each)

**Key Files:**
- `tasks.md` - Shared task board
- `scripts/run-actor.sh` - Runs individual actors
- `scripts/cron-orchestrator.sh` - Runs all actors sequentially
- `scripts/status.sh` - Shows system status
- `actors/*/logs/` - Execution logs

---

## Projects

| Project | Path | Description | Status |
|---------|------|-------------|--------|
| techtools-claude-code-cron-loop | `/home/novakj` | Server config repository | Active |

**GitHub**: https://github.com/TaraJura/techtools-claude-code-cron-loop

---

## Important Paths

| Path | Purpose |
|------|---------|
| `/home/novakj` | Primary home directory, main workspace |
| `/home/novakj/CLAUDE.md` | This knowledge base file (internal) |
| `/home/novakj/README.md` | Public documentation (GitHub) |
| `/home/novakj/tasks.md` | Multi-agent task board |
| `/home/novakj/actors/` | Actor configurations and logs |
| `/home/novakj/scripts/` | Automation scripts |
| `/home/novakj/projects/` | Code created by agents |
| `/home/ubuntu` | Ubuntu system user home |
| `/etc/nginx/` | Nginx configuration (when installed) |
| `/var/www/cronloop.techtools.cz` | Web app for cronloop subdomain |
| `/var/log/` | System logs |

---

## Configuration Standards

### Security Best Practices
- Always use SSH key authentication (no password auth)
- Keep system packages updated regularly
- Use UFW firewall with minimal open ports
- Run services with least privilege
- Store secrets in environment variables or secure vaults, never in code

### Development Standards
- Use version control (Git) for all projects
- Follow semantic versioning
- Write meaningful commit messages
- Document all APIs and configurations
- Use environment-specific configurations

### Deployment Standards
- Test changes in staging when possible
- Use systemd for service management
- Implement proper logging
- Set up monitoring and alerts
- Create backups before major changes

---

## Firewall Rules (UFW)

| Port | Service | Status |
|------|---------|--------|
| 22 | SSH | (to be configured) |

---

## Scheduled Tasks (Cron)

| Schedule | Task | Description |
|----------|------|-------------|
| `*/30 * * * *` | `cron-orchestrator.sh` | Runs multi-agent system every 30 minutes |

**Cron log**: `/home/novakj/actors/cron.log`

---

## Environment Variables

Document any global environment variables set on the server:

```bash
# (none configured yet)
```

---

## Backups

| What | Location | Frequency |
|------|----------|-----------|
| (none configured) | - | - |

---

## Change Log

All changes to this server must be logged here in reverse chronological order.

### 2026-01-19
- **[SSL]** Installed Let's Encrypt SSL certificate for cronloop.techtools.cz (expires 2026-04-19)
- **[SSL]** Configured automatic certificate renewal via certbot
- **[WEB]** Deployed CronLoop Dashboard at https://cronloop.techtools.cz
- **[WEB]** Installed Nginx 1.26.3 web server
- **[WEB]** Created site `cronloop.techtools.cz` with landing page at `/var/www/cronloop.techtools.cz`
- **[WEB]** Configured Nginx virtual host for subdomain
- **[SUDO]** Enabled passwordless sudo for novakj user
- **[AGENTS]** Added idea-maker actor to generate new feature ideas
- **[AGENTS]** Updated execution order: idea-maker → PM → developer → tester
- **[DOCS]** Created README.md for GitHub repository
- **[DOCS]** Updated critical rules to require README.md updates alongside CLAUDE.md
- **[AGENTS]** Added tester actor to verify developer's work and provide feedback
- **[AGENTS]** Created multi-agent system with project-manager and developer actors
- **[AGENTS]** Created tasks.md shared task board
- **[AGENTS]** Created automation scripts (run-actor.sh, cron-orchestrator.sh, status.sh)
- **[AGENTS]** Set up cron job to run agents every 30 minutes
- **[AGENTS]** Tested system - project-manager assigned task, developer completed it
- **[GIT]** Initialized Git repository in `/home/novakj`
- **[GIT]** Connected to GitHub: `TaraJura/techtools-claude-code-cron-loop`
- **[SSH]** Generated SSH key (ed25519) for GitHub authentication
- **[USER]** Created user `novakj` with home directory `/home/novakj`
- **[USER]** Set password for `novakj`
- **[USER]** Added `novakj` to sudo group for admin privileges
- **[CONFIG]** Moved CLAUDE.md to `/home/novakj/CLAUDE.md`
- **[CONFIG]** Set novakj as primary admin user
- **[INIT]** Created CLAUDE.md knowledge base file
- **[INIT]** Server baseline documented
- **[INIT]** Established documentation standards and best practices

---

## Pending Tasks

- [ ] Configure UFW firewall
- [ ] Set up automatic security updates
- [ ] Install development tools as needed
- [ ] Configure backup strategy

---

## Notes

- This is a production server - exercise caution with all changes
- Always update this file after making any server modifications
- When in doubt, document it

---

*This file serves as the single source of truth for this server's configuration and state.*
