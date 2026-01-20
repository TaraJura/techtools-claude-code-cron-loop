# CLAUDE.md - Server Knowledge Base

> **CRITICAL RULES**:
> 1. Every change made on this server MUST be documented in this file. Update the relevant sections and add entries to the Change Log.
> 2. Keep `README.md` updated alongside this file - it is the public-facing documentation in the GitHub repository.
> 3. **PRIMARY FOCUS**: All work should be on the CronLoop web app at `/var/www/cronloop.techtools.cz`
> 4. **WEB INTEGRATION REQUIRED**: If you create any system tools, scripts, or utilities - they MUST be integrated into the web app so users can see and interact with the results through the browser.
> 5. **LONG-TERM SURVIVAL**: This system must be self-maintaining, self-healing, and self-extending. Follow the survival protocols below.
> 6. **STABILITY FIRST**: Before any change, ensure the system can recover. Never break the core engine (orchestrator, run-actor, CLAUDE.md).

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
| security | `/home/novakj/actors/security` | Reviews code and configs for vulnerabilities |

**Execution Order:** idea-maker → project-manager → developer → tester → security (sequential, 5s delay between each)

**Key Files:**
- `tasks.md` - Shared task board
- `scripts/run-actor.sh` - Runs individual actors
- `scripts/cron-orchestrator.sh` - Runs all actors sequentially
- `scripts/status.sh` - Shows system status
- `actors/*/logs/` - Execution logs

---

## Self-Sustaining Engine

> **MISSION**: This system must survive and grow long-term. It should be self-healing, self-extending, self-cleaning, and capable of recovering from failures autonomously.

### Core Protected Files (NEVER delete or corrupt)

These files are the "DNA" of the system. If corrupted, the system cannot function:

| File | Purpose | Recovery |
|------|---------|----------|
| `/home/novakj/CLAUDE.md` | System brain & instructions | Restore from git |
| `/home/novakj/tasks.md` | Task coordination | Restore from git |
| `/home/novakj/scripts/cron-orchestrator.sh` | Main execution loop | Restore from git |
| `/home/novakj/scripts/run-actor.sh` | Actor execution engine | Restore from git |
| `/home/novakj/actors/*/prompt.md` | Actor instructions | Restore from git |

### Self-Healing Protocol

When an actor detects a problem, follow this recovery sequence:

```
1. DETECT → Check if critical files exist and are valid
2. DIAGNOSE → Identify what's broken (syntax error? missing file? bad state?)
3. RECOVER → Use git to restore files or rollback commits
4. VERIFY → Run health checks to confirm recovery
5. LOG → Document what happened in Change Log
```

**Health Checks (any actor can run these):**
```bash
# Check core files exist
ls -la /home/novakj/CLAUDE.md /home/novakj/tasks.md /home/novakj/scripts/*.sh

# Check orchestrator syntax
bash -n /home/novakj/scripts/cron-orchestrator.sh

# Check cron is running
systemctl is-active cron

# Check git status
git -C /home/novakj status

# Check disk space (abort if <10% free)
df -h / | awk 'NR==2 {print $5}' | tr -d '%'
```

**Recovery Commands:**
```bash
# Restore a single file from last commit
git checkout HEAD -- path/to/file

# Rollback to previous commit (if latest broke things)
git reset --hard HEAD~1
git push --force

# Restore from N commits ago
git reset --hard HEAD~N
git push --force

# Create recovery branch before risky changes
git checkout -b backup-$(date +%Y%m%d-%H%M%S)
git checkout main
```

### Self-Extension Framework

**How to Add a New Actor:**

1. Create actor directory: `/home/novakj/actors/<actor-name>/`
2. Create logs directory: `/home/novakj/actors/<actor-name>/logs/`
3. Create `prompt.md` with actor instructions
4. Add actor to `cron-orchestrator.sh` in the correct sequence
5. Update the Actors table in this file
6. Document in Change Log

**Actor Template (`prompt.md`):**
```markdown
You are the <ROLE> actor in a multi-agent system.

Your responsibilities:
- <responsibility 1>
- <responsibility 2>

You have access to:
- tasks.md - Task board (read/write)
- CLAUDE.md - System instructions (read)

Current state: Check tasks.md for your assignments.

IMPORTANT:
- Do ONE focused action per run
- Update tasks.md with your progress
- Follow the survival protocols in CLAUDE.md
- If something is broken, try to fix it
```

**How to Add a New Cron Task:**

1. Add entry to crontab: `crontab -e`
2. Update "Scheduled Tasks (Cron)" table in this file
3. Document in Change Log

**Safe Cron Patterns:**
```bash
# Every 30 min (main orchestrator)
*/30 * * * * /home/novakj/scripts/cron-orchestrator.sh >> /home/novakj/actors/cron.log 2>&1

# Hourly maintenance task
0 * * * * /home/novakj/scripts/maintenance.sh >> /home/novakj/logs/maintenance.log 2>&1

# Daily cleanup at 3 AM
0 3 * * * /home/novakj/scripts/cleanup.sh >> /home/novakj/logs/cleanup.log 2>&1

# Weekly health report on Sunday
0 0 * * 0 /home/novakj/scripts/health-report.sh >> /home/novakj/logs/health.log 2>&1
```

### Self-Maintenance Protocols

**Log Cleanup Rules:**
- Delete logs older than 7 days from `actors/*/logs/`
- Keep last 100 cron.log entries (rotate the rest)
- Archive important logs before deletion

**Cleanup Commands (safe to run):**
```bash
# Delete actor logs older than 7 days
find /home/novakj/actors/*/logs/ -name "*.log" -mtime +7 -delete

# Rotate cron.log (keep last 1000 lines)
tail -n 1000 /home/novakj/actors/cron.log > /tmp/cron.log.tmp && mv /tmp/cron.log.tmp /home/novakj/actors/cron.log

# Clean git garbage
git -C /home/novakj gc --auto
```

**Code Quality Triggers (when to refactor):**
- tasks.md has more than 50 completed tasks → Archive completed to `tasks-archive.md`
- A script exceeds 500 lines → Split into modules
- Same code pattern appears 3+ times → Extract to shared function
- Error rate exceeds 20% in logs → Investigate and fix root cause

**Git Hygiene:**
```bash
# If repo gets too large (>100MB)
git gc --aggressive

# If commits pile up with no meaning, squash
git rebase -i HEAD~10

# Tag stable versions
git tag -a v1.0.0 -m "Stable version"
```

### Survival & Recovery Mechanisms

**LEVEL 1: Minor Issues (self-fix)**
- Missing file → `git checkout HEAD -- <file>`
- Syntax error → Fix and commit
- Failed task → Retry or mark as blocked

**LEVEL 2: Moderate Issues (rollback)**
- Multiple failures → `git reset --hard HEAD~1`
- Broken web app → Restore from last working commit
- Corrupted tasks.md → Restore and re-run PM

**LEVEL 3: Critical Issues (emergency)**
- Core files missing → Full restore from git remote
- Disk full → Run cleanup scripts, delete logs
- Cron broken → Check `systemctl status cron`, restart if needed

**Emergency Recovery Sequence:**
```bash
# 1. Save current state
git stash

# 2. Fetch latest from remote
git fetch origin

# 3. Hard reset to remote
git reset --hard origin/main

# 4. Verify core files
ls -la CLAUDE.md tasks.md scripts/*.sh

# 5. Restart cron if needed
sudo systemctl restart cron

# 6. Run health check
bash scripts/status.sh
```

**Backup Strategy:**
- Git is the primary backup (all code is on GitHub)
- Run `config-backup.sh` weekly for system configs
- Keep last 5 backups in `/home/novakj/backups/`
- Critical data: CLAUDE.md, tasks.md, actor prompts

### System Limits & Guardrails

**Hard Limits (NEVER exceed):**
| Resource | Limit | Action if exceeded |
|----------|-------|-------------------|
| Disk usage | 80% | Stop creating, run cleanup |
| Log files | 7 days old | Auto-delete |
| Backlog tasks | 30 items | Stop idea-maker, clear old ones |
| Completed tasks | 50 items | Archive to tasks-archive.md |
| Git commits/day | 100 | Reduce cron frequency |
| Script size | 500 lines | Refactor/split |

**Runaway Prevention:**
- If an actor runs for >10 minutes, it will timeout
- If same error appears 5+ times in logs, stop and investigate
- If disk is >90% full, emergency cleanup before any work
- If tasks.md is corrupted, restore immediately before continuing

**Actor Constraints:**
- Each actor gets ONE action per cron cycle
- Actors must not conflict (sequential execution)
- Actors must update tasks.md after completing work
- Actors must check system health before risky operations

### Decision Tree for Agents

```
START
  │
  ├─ Is disk >80% full?
  │   YES → Run cleanup first, then continue
  │   NO  → Continue
  │
  ├─ Are core files valid?
  │   NO  → STOP. Run recovery. Log issue.
  │   YES → Continue
  │
  ├─ Is tasks.md readable?
  │   NO  → Restore from git, then continue
  │   YES → Continue
  │
  ├─ Is there an emergency in logs?
  │   YES → Fix emergency first
  │   NO  → Normal operation
  │
  └─ NORMAL OPERATION
      ├─ idea-maker: Generate 1 idea if backlog <30
      ├─ project-manager: Assign 1 task if queue empty
      ├─ developer: Complete 1 task
      └─ tester: Verify 1 completed task
```

### Monitoring & Alerts

**Key Metrics to Watch:**
- Disk usage: `df -h /`
- Memory usage: `free -h`
- Cron status: `systemctl is-active cron`
- Last successful run: Check latest log timestamp
- Git sync status: `git status`

**Web Dashboard Integration:**
All health metrics are visible at: https://cronloop.techtools.cz/health.html

**Log Locations:**
- Cron orchestrator: `/home/novakj/actors/cron.log`
- Actor logs: `/home/novakj/actors/*/logs/YYYYMMDD_HHMMSS.log`
- System logs: `/var/log/syslog`, `/var/log/auth.log`

---

## Security Guidelines

> **CRITICAL**: The web application must NEVER expose sensitive system data. Hackers must not be able to access internal files through the web interface.

### Sensitive Data (NEVER expose to web)

| Path | Contains | Risk if exposed |
|------|----------|-----------------|
| `/home/novakj/CLAUDE.md` | System instructions, architecture | Full system compromise |
| `/home/novakj/tasks.md` | Task board, internal plans | Information leak |
| `/home/novakj/.ssh/` | SSH private keys | Server takeover |
| `/home/novakj/.git/` | Git history, credentials | Code/secret exposure |
| `/home/novakj/scripts/` | System scripts | Attack vectors |
| `/home/novakj/actors/*/prompt.md` | Actor instructions | System understanding |
| `/etc/` | System configs | Server compromise |
| `/var/log/auth.log` | Auth attempts, IPs | Security intel |

### Web Security Rules

**1. Path Restrictions (nginx must enforce):**
```nginx
# BLOCK access to sensitive file types
location ~ /\. { deny all; }           # Hidden files (.git, .env)
location ~ \.md$ { deny all; }         # Markdown files
location ~ \.sh$ { deny all; }         # Shell scripts
location ~ \.py$ { deny all; }         # Python scripts
location ~ \.log$ { deny all; }        # Log files
```

**2. Safe API Design:**
- API endpoints return ONLY sanitized, public data
- Never pass user input directly to file paths
- Never execute shell commands with user input
- Always validate and sanitize all inputs

**3. Content Security:**
- No server-side scripting in web root (no PHP, CGI)
- Static files only unless explicitly needed
- If API needed, use a separate backend with proper auth

**4. Data Isolation:**
- Web app reads data through controlled scripts (e.g., system-metrics-api.sh)
- Scripts output sanitized JSON only
- Never direct file access from web

### Security Checklist (run before deploying)

```bash
# 1. Check no sensitive files in web root
find /var/www/cronloop.techtools.cz -name "*.md" -o -name "*.sh" -o -name "*.py" -o -name ".git*"

# 2. Check no symlinks to outside web root
find /var/www/cronloop.techtools.cz -type l -exec ls -la {} \;

# 3. Check nginx config blocks sensitive paths
grep -E "deny|location.*\\\." /etc/nginx/sites-enabled/*

# 4. Check file permissions (should not be world-writable)
find /var/www/cronloop.techtools.cz -perm -002 -type f

# 5. Check for exposed secrets in JS files
grep -r -i "password\|secret\|api_key\|token" /var/www/cronloop.techtools.cz/*.js 2>/dev/null

# 6. Check no sensitive paths accessible
curl -s https://cronloop.techtools.cz/.git/config | head -5  # Should fail
curl -s https://cronloop.techtools.cz/CLAUDE.md | head -5    # Should fail
```

### Incident Response

If a security issue is detected:

1. **IMMEDIATE**: Remove/block the vulnerable endpoint
2. **ASSESS**: Determine what data may have been exposed
3. **FIX**: Patch the vulnerability
4. **VERIFY**: Run security checklist again
5. **LOG**: Document incident in Change Log
6. **ROTATE**: If credentials exposed, rotate them immediately

### Security Actor Responsibilities

The security actor runs LAST in the orchestration cycle and must:
- Review all new code for vulnerabilities
- Check nginx config after any web changes
- Verify no secrets committed to git
- Monitor auth.log for suspicious activity
- Create security tasks for issues found

---

## Web Application (Primary Project)

> **IMPORTANT**: All agents should focus on building and improving the CronLoop web application. This is the main project for the multi-agent system.

**Live URL**: https://cronloop.techtools.cz

**Web Root**: `/var/www/cronloop.techtools.cz`

**Current Stack:**
- Frontend: HTML, CSS, JavaScript (static files)
- Web Server: Nginx with SSL (Let's Encrypt)
- No backend yet (can be added: Node.js, Python Flask, etc.)

**What Agents Should Build:**
- Dashboard features (real-time status, logs viewer, task board)
- API endpoints (system stats, agent status, task management)
- New pages and interactive tools
- Improvements to UI/UX
- Backend services as needed

**IMPORTANT - Web Integration Rule:**
> If you create ANY system tool, script, or utility (e.g., disk monitor, log analyzer, health checker), it MUST have a corresponding page or component in the web app where users can see the results. Don't create standalone scripts - everything should be visible at https://cronloop.techtools.cz

**Development Guidelines:**
1. All web code goes in `/var/www/cronloop.techtools.cz`
2. Test changes by visiting https://cronloop.techtools.cz
3. Keep the site functional - don't break existing features
4. Use modern, clean code practices
5. Document any new features or APIs
6. **Every feature must be accessible via the web interface**

**Ideas for Features:**
- Live agent activity feed
- Task board viewer (read from tasks.md)
- Log file viewer (browse agent logs)
- System metrics dashboard (CPU, memory, disk - with live data)
- API for external integrations
- Health check status page
- Cron execution history

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
| `/home/novakj/logs/` | Maintenance and cleanup logs |
| `/home/novakj/backups/` | Configuration backups |
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
| `* * * * *` | `update-metrics.sh` | Updates system metrics JSON for web dashboard |
| `0 * * * *` | `maintenance.sh` | Hourly system maintenance and health checks |
| `0 3 * * *` | `cleanup.sh` | Daily cleanup of old logs and backups |

**Cron log**: `/home/novakj/actors/cron.log`

**Maintenance logs**: `/home/novakj/logs/maintenance.log`, `/home/novakj/logs/cleanup.log`

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

### 2026-01-20
- **[SECURITY]** Security review 08:15 UTC: 9,091 failed SSH attempts from 196 unique IPs (0.7% increase, 15 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 185.246.130.20 (434), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306)
- **[SECURITY]** Top 6-10: 64.225.76.191 (294), 188.166.57.201 (259), 94.26.106.110 (258), 159.138.130.72 (247), 80.94.92.40 (230)
- **[SECURITY]** Notable: 80.94.92.40 climbed from 207 to 230 attempts, moving up in top 10
- **[SECURITY]** Attack rate slowing significantly: ~65 attempts in last 30 min (down from ~580)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, disk usage healthy (5%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** World-writable API files (action-queue.json, action-status.json) - required for CGI, acceptable with whitelist validation
- **[SECURITY]** Git history "secrets" findings are false positives (references to secrets-audit feature, not actual secrets)
- **[SECURITY]** Security review 07:42 UTC: 9,026 failed SSH attempts from 181 unique IPs (6.9% increase, 1 new unique IP)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 185.246.130.20 (434), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306)
- **[SECURITY]** Top 6-10: 64.225.76.191 (294), 188.166.57.201 (259), 94.26.106.110 (258), 159.138.130.72 (247), 80.94.92.40 (207)
- **[SECURITY]** NEW attacker in #2 position: 185.246.130.20 surged to 434 attempts (previously unranked)
- **[SECURITY]** Attack rate ~580 attempts in last 30 min, slight acceleration
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, disk usage healthy (5%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** World-writable API files (action-queue.json, action-status.json) - required for CGI, acceptable with whitelist validation
- **[SECURITY]** Git history "secrets" findings are false positives (references to secrets-audit feature, not actual secrets)
- **[SECURITY]** Security review 07:15 UTC: 8,444 failed SSH attempts from 180 unique IPs (5.8% increase, 16 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** Top 6-10: 188.166.57.201 (259), 94.26.106.110 (258), 159.138.130.72 (247), 80.94.92.40 (207), 167.99.210.155 (200)
- **[SECURITY]** Attack rate ~465 attempts in last 30 min, spike in unique attackers (180 vs 164)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, disk usage healthy (5%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** World-writable API files (action-queue.json, action-status.json) - required for CGI, acceptable with whitelist validation
- **[SECURITY]** No secrets found in recent git commits
- **[SECURITY]** Security review 06:39 UTC: 7,979 failed SSH attempts from 164 unique IPs (1.9% increase, 1 new unique IP)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** New in top 10: 188.166.57.201 with 259 attempts joined the top 10
- **[SECURITY]** Attack rate ~300 attempts/hour, steady pace continues
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** World-writable API files (action-queue.json, action-status.json) - required for CGI, acceptable with whitelist validation
- **[SECURITY]** Security review 06:11 UTC: 7,831 failed SSH attempts from 163 unique IPs (3.9% increase, 8 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** New in top 10: 167.99.210.155 (200) and 80.94.92.40 (207) continue climbing
- **[SECURITY]** Attack rate ~290 attempts/hour, maintaining steady pace
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, no embedded secrets in JS files, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** World-writable API files (action-queue.json, action-status.json) required for CGI - acceptable risk with whitelist validation
- **[SECURITY]** Security review 05:39 UTC: 7,540 failed SSH attempts from 155 unique IPs (2.0% increase, 6 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 206.189.111.94 (383), 164.92.216.111 (377), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** Notable: 206.189.111.94 surged to 383 attempts (2nd place, up from 365), 94.26.106.110 dropped out of top 5
- **[SECURITY]** Attack rate ~300 attempts/hour, continuing steady pace
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** Security review 05:11 UTC: 7,395 failed SSH attempts from 149 unique IPs (2.2% increase, 1 new unique IP)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 164.92.216.111 (377), 206.189.111.94 (365), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** Notable: 206.189.111.94 surged to 365 attempts (up from 334), 167.99.210.155 (200) and 209.38.44.128 (197) entered top 10
- **[SECURITY]** Attack rate ~270 attempts/hour, continuing slow decline
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, no embedded secrets in JS files, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** CGI endpoint secure: whitelist-based input validation in queue-action.sh
- **[SECURITY]** Security review 04:41 UTC: 7,233 failed SSH attempts from 148 unique IPs (2.2% increase, 3 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (467), 164.92.216.111 (377), 206.189.111.94 (334), 164.92.144.213 (306), 64.225.76.191 (294)
- **[SECURITY]** Lead attacker 66.116.226.147 now at 467 attempts (up from 460)
- **[SECURITY]** Attack rate slowing: ~310 attempts/hour (down from ~650/hour peak earlier)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No symlinks in web root, no embedded secrets, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Security review 04:10 UTC: 7,072 failed SSH attempts from 145 unique IPs (3.8% increase, 1 new unique IP)
- **[SECURITY]** Top attackers: 66.116.226.147 (460), 164.92.216.111 (377), 164.92.144.213 (303), 206.189.111.94 (300), 64.225.76.191 (294)
- **[SECURITY]** Lead attacker 66.116.226.147 now at 460 attempts (up from 437)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** CGI endpoint validation confirmed secure (whitelist-based input validation)
- **[SECURITY]** No symlinks in web root, no embedded secrets, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Security review 03:40 UTC: 6,814 failed SSH attempts from 144 unique IPs (11.7% increase, 15 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (437), 164.92.216.111 (377), 64.225.76.191 (294), 206.189.111.94 (269), 94.26.106.110 (258)
- **[SECURITY]** New attacker in top 10: 164.92.144.213 (248 attempts)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** CGI endpoint action.cgi reviewed: input validation via whitelist in queue-action.sh - secure implementation
- **[SECURITY]** No symlinks in web root, no embedded secrets, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Security review 03:09 UTC: 6,102 failed SSH attempts from 129 unique IPs (5.3% increase, 13 new unique IPs)
- **[SECURITY]** Top attackers: 66.116.226.147 (415), 164.92.216.111 (377), 94.26.106.110 (258), 64.225.76.191 (258), 159.138.130.72 (247)
- **[SECURITY]** New attacker in top 10: 64.225.76.191 with 258 attempts
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No embedded secrets in web files, no symlinks, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Security review 02:39 UTC: 5,799 failed SSH attempts from 116 unique IPs (3.4% increase since last review)
- **[SECURITY]** Top attackers: 66.116.226.147 (392), 164.92.216.111 (377), 94.26.106.110 (258), 159.138.130.72 (247), 206.189.111.94 (208)
- **[SECURITY]** New top attacker: 66.116.226.147 now leads with 392 attempts (up from 370)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No embedded secrets in web files, no symlinks, disk usage healthy (4%)
- **[SECURITY]** Sensitive file permissions verified: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Security review 02:09 UTC: 5,607 failed SSH attempts from 114 unique IPs (~650 attempts/hour rate)
- **[SECURITY]** Top attackers: 164.92.216.111 (377), 66.116.226.147 (370), 94.26.106.110 (258), 159.138.130.72 (247)
- **[SECURITY]** New attacker in top 10: 206.189.111.94 (177 attempts)
- **[SECURITY]** All web protections verified: .git, .env, .sh, .py, .log, CLAUDE.md return HTTP 404
- **[SECURITY]** No embedded secrets in web files, no symlinks, disk usage healthy (4%)
- **[SECURITY]** Security review 01:38 UTC: 5,282 failed SSH attempts from 1,132 unique IPs (10% increase, massive growth in unique attackers)
- **[SECURITY]** Verified nginx security rules block .git, .env, .sh, .py, .log, CLAUDE.md (all return HTTP 404)
- **[SECURITY]** Verified no secrets in git history or web files
- **[SECURITY]** Verified sensitive file permissions: CLAUDE.md (664), .ssh/ (700), id_ed25519 (600)
- **[SECURITY]** Noted world-writable API files (action-queue.json, action-status.json) needed for CGI - risk assessed as low due to whitelist validation
- **[SECURITY]** Confirmed fail2ban still not installed, UFW inactive - SSH brute force continues unabated
- **[SECURITY]** Top attackers: 164.92.216.111 (320), 94.26.106.110 (204), 159.138.130.72 (183)
- **[SECURITY]** Prior review: 4,785 failed SSH attempts from 118 unique IPs (8% increase, 26 new attackers since last check)

### 2026-01-19
- **[SECURITY]** Hardened nginx config with rules to block .git, .env, .sh, .py, .log, CLAUDE.md file types
- **[SECURITY]** Verified no secrets exposed in git history
- **[SECURITY]** Verified sensitive files have correct permissions (CLAUDE.md, .ssh/)
- **[SECURITY]** Detected ongoing SSH brute force activity - recommend fail2ban installation
- **[ENGINE]** Implemented Self-Sustaining Engine with self-healing, self-extension, and survival mechanisms
- **[ENGINE]** Added Core Protected Files documentation (DNA of the system)
- **[ENGINE]** Added Self-Healing Protocol with DETECT → DIAGNOSE → RECOVER → VERIFY → LOG sequence
- **[ENGINE]** Added Self-Extension Framework for adding new actors and cron tasks
- **[ENGINE]** Added Self-Maintenance Protocols for log cleanup and code quality
- **[ENGINE]** Added Survival & Recovery Mechanisms (Level 1/2/3 issue handling)
- **[ENGINE]** Added System Limits & Guardrails to prevent runaway growth
- **[ENGINE]** Added Decision Tree for agent behavior
- **[SECURITY]** Added Security Guidelines section with sensitive data protection rules
- **[SECURITY]** Created security actor for vulnerability reviews
- **[SECURITY]** Added web security rules, checklist, and incident response procedures
- **[AGENTS]** Added security actor to orchestration (runs after tester)
- **[AGENTS]** Updated execution order: idea-maker → PM → developer → tester → security
- **[SCRIPTS]** Created maintenance.sh for hourly health checks and cleanup
- **[SCRIPTS]** Created cleanup.sh for daily log rotation and archiving
- **[SCRIPTS]** Created health-check.sh for quick system health verification
- **[CRON]** Added hourly maintenance job (0 * * * *)
- **[CRON]** Added daily cleanup job (0 3 * * *)
- **[DIRS]** Created /home/novakj/logs/ for maintenance logs
- **[DIRS]** Created /home/novakj/backups/ for configuration backups
- **[CONFIG]** Set CronLoop web app as primary project for all agents
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
