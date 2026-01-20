# Self-Sustaining Engine Guide

> Documentation for the self-healing, self-extending, and self-maintaining system.

## CRITICAL: Claude Code Has Full Sudo Access

> **This system runs with FULL SUDO PERMISSIONS on the server.**

Claude Code operates as user `novakj` with complete sudo access:

| Capability | Access Level |
|------------|--------------|
| File system | Full read/write everywhere |
| Services | Start/stop/restart any service |
| Packages | Install/remove via apt |
| Network | Configure firewall, DNS, nginx |
| Cron | Create/modify scheduled tasks |
| Users | Create/modify (though typically not needed) |
| Root access | Full via sudo |

### Why Full Permissions?

The system needs to:
1. **Self-repair** - Restart failed services, restore configs
2. **Self-extend** - Install new tools, add cron jobs
3. **Manage web server** - Configure nginx, SSL certificates
4. **Deploy code** - Write to /var/www, update configs
5. **Monitor everything** - Access system logs, metrics

### Permission Examples

```bash
# Things Claude Code can and does do:
sudo systemctl restart nginx
sudo apt install jq
sudo certbot renew
sudo tee /etc/nginx/sites-available/...
sudo ufw allow 80
```

---

## Mission

This system must survive and grow long-term. It should be self-healing, self-extending, self-cleaning, and capable of recovering from failures autonomously.

## Core Protected Files (NEVER delete or corrupt)

These files are the "DNA" of the system. If corrupted, the system cannot function:

| File | Purpose | Recovery |
|------|---------|----------|
| `/home/novakj/CLAUDE.md` | System brain & instructions | Restore from git |
| `/home/novakj/tasks.md` | Task coordination | Restore from git |
| `/home/novakj/scripts/cron-orchestrator.sh` | Main execution loop | Restore from git |
| `/home/novakj/scripts/run-actor.sh` | Actor execution engine | Restore from git |
| `/home/novakj/actors/*/prompt.md` | Actor instructions | Restore from git |

## Self-Healing Protocol

When an actor detects a problem, follow this recovery sequence:

```
1. DETECT -> Check if critical files exist and are valid
2. DIAGNOSE -> Identify what's broken (syntax error? missing file? bad state?)
3. RECOVER -> Use git to restore files or rollback commits
4. VERIFY -> Run health checks to confirm recovery
5. LOG -> Document what happened in logs/changelog.md
```

### Health Checks (any actor can run these)
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

### Recovery Commands
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

## Self-Extension Framework

### How to Add a New Actor

1. Create actor directory: `/home/novakj/actors/<actor-name>/`
2. Create logs directory: `/home/novakj/actors/<actor-name>/logs/`
3. Create `prompt.md` with actor instructions
4. Add actor to `cron-orchestrator.sh` in the correct sequence
5. Update the Actors table in `docs/server-config.md`
6. Log the change in `logs/changelog.md`

### Actor Template (`prompt.md`)
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

### How to Add a New Cron Task

1. Add entry to crontab: `crontab -e`
2. Update "Scheduled Tasks" table in `docs/server-config.md`
3. Log the change in `logs/changelog.md`

### Safe Cron Patterns
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

## Self-Maintenance Protocols

### Log Cleanup Rules
- Delete logs older than 7 days from `actors/*/logs/`
- Keep last 1000 cron.log entries (rotate the rest)
- Archive changelogs monthly to `logs/archive/`

### Cleanup Commands (safe to run)
```bash
# Delete actor logs older than 7 days
find /home/novakj/actors/*/logs/ -name "*.log" -mtime +7 -delete

# Rotate cron.log (keep last 1000 lines)
tail -n 1000 /home/novakj/actors/cron.log > /tmp/cron.log.tmp && mv /tmp/cron.log.tmp /home/novakj/actors/cron.log

# Clean git garbage
git -C /home/novakj gc --auto

# Archive old changelog entries (run monthly)
# Move entries older than current month to logs/archive/changelog-YYYY-MM.md
```

### Code Quality Triggers (when to refactor)
- tasks.md has more than 50 completed tasks -> Archive completed to `tasks-archive.md`
- A script exceeds 500 lines -> Split into modules
- Same code pattern appears 3+ times -> Extract to shared function
- Error rate exceeds 20% in logs -> Investigate and fix root cause

## Survival & Recovery Mechanisms

### LEVEL 1: Minor Issues (self-fix)
- Missing file -> `git checkout HEAD -- <file>`
- Syntax error -> Fix and commit
- Failed task -> Retry or mark as blocked

### LEVEL 2: Moderate Issues (rollback)
- Multiple failures -> `git reset --hard HEAD~1`
- Broken web app -> Restore from last working commit
- Corrupted tasks.md -> Restore and re-run PM

### LEVEL 3: Critical Issues (emergency)
- Core files missing -> Full restore from git remote
- Disk full -> Run cleanup scripts, delete logs
- Cron broken -> Check `systemctl status cron`, restart if needed

### Emergency Recovery Sequence
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

## System Limits & Guardrails

### Hard Limits (NEVER exceed)
| Resource | Limit | Action if exceeded |
|----------|-------|-------------------|
| Disk usage | 80% | Stop creating, run cleanup |
| Log files | 7 days old | Auto-delete |
| Backlog tasks | 30 items | Stop idea-maker, clear old ones |
| Completed tasks | 50 items | Archive to tasks-archive.md |
| Git commits/day | 100 | Reduce cron frequency |
| Script size | 500 lines | Refactor/split |

### Runaway Prevention
- If an actor runs for >10 minutes, it will timeout
- If same error appears 5+ times in logs, stop and investigate
- If disk is >90% full, emergency cleanup before any work
- If tasks.md is corrupted, restore immediately before continuing

### Actor Constraints
- Each actor gets ONE action per cron cycle
- Actors must not conflict (sequential execution)
- Actors must update tasks.md after completing work
- Actors must check system health before risky operations

## Decision Tree for Agents

```
START
  |
  +-- Is disk >80% full?
  |   YES -> Run cleanup first, then continue
  |   NO  -> Continue
  |
  +-- Are core files valid?
  |   NO  -> STOP. Run recovery. Log issue.
  |   YES -> Continue
  |
  +-- Is tasks.md readable?
  |   NO  -> Restore from git, then continue
  |   YES -> Continue
  |
  +-- Is there an emergency in logs?
  |   YES -> Fix emergency first
  |   NO  -> Normal operation
  |
  +-- NORMAL OPERATION
      +-- idea-maker: Generate 1 idea if backlog <30
      +-- project-manager: Assign 1 task if queue empty
      +-- developer: Complete 1 task
      +-- tester: Verify 1 completed task
      +-- security: Update security status
```

## Monitoring & Alerts

### Key Metrics to Watch
- Disk usage: `df -h /`
- Memory usage: `free -h`
- Cron status: `systemctl is-active cron`
- Last successful run: Check latest log timestamp
- Git sync status: `git status`

### Web Dashboard Integration
All health metrics are visible at: https://cronloop.techtools.cz/health.html

### Log Locations
- Cron orchestrator: `/home/novakj/actors/cron.log`
- Actor logs: `/home/novakj/actors/*/logs/YYYYMMDD_HHMMSS.log`
- System logs: `/var/log/syslog`, `/var/log/auth.log`

## Backup Strategy

- Git is the primary backup (all code is on GitHub)
- Run `config-backup.sh` weekly for system configs
- Keep last 5 backups in `/home/novakj/backups/`
- Critical data: CLAUDE.md, tasks.md, actor prompts
