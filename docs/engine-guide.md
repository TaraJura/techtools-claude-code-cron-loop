# Self-Sustaining Engine Guide — PDF Editor Factory

> Documentation for the self-healing, self-maintaining orchestration system that builds the PDF Editor.

## Overview

The engine is the infrastructure that keeps the AI agents running. It consists of:
- **Cron scheduler** — triggers agent runs on schedule
- **Orchestrator** — runs agents in sequence, handles locking
- **Maintenance** — hourly health checks and cleanup
- **Cleanup** — daily log rotation and garbage collection
- **Health check** — on-demand system diagnostics

## Claude Code Has Full Sudo Access

The system runs with full sudo permissions. This means agents CAN:
- Install packages
- Modify Nginx configuration
- Restart services
- Create/delete files anywhere

**With great power comes great responsibility.** Agents must be conservative.

## Script Reference

| Script | Schedule | Purpose |
|--------|----------|---------|
| `cron-orchestrator.sh` | Every 2 hours | Run all 6 main pipeline agents sequentially |
| `run-actor.sh` | Called by orchestrator | Execute a single agent with its prompt |
| `run-supervisor.sh` | Every 2 hours at :15 | Run supervisor agent with persistent state |
| `maintenance.sh` | Every hour | Disk checks, log rotation, core file validation |
| `cleanup.sh` | Daily at 3 AM | Delete old logs, git gc, disk report |
| `health-check.sh` | On demand | Full system diagnostic |

## Agent Execution Flow

```
cron-orchestrator.sh
    ├── Check lock file (prevent concurrent runs)
    ├── git pull --rebase
    ├── run-actor.sh idea-maker
    ├── sleep 5
    ├── run-actor.sh project-manager
    ├── sleep 5
    ├── run-actor.sh developer
    ├── sleep 5
    ├── run-actor.sh developer2
    ├── sleep 5
    ├── run-actor.sh tester
    ├── sleep 5
    ├── run-actor.sh security
    └── Clean up lock file

run-actor.sh <agent>
    ├── Read actors/<agent>/prompt.md
    ├── Execute: claude -p "<prompt>"
    ├── Log output to actors/<agent>/logs/<timestamp>.log
    ├── git add -A && git commit && git push
    └── Done
```

## Recovery Procedures

### Core File Missing
```bash
# Restore from git
git checkout HEAD -- CLAUDE.md tasks.md scripts/*.sh actors/*/prompt.md
```

### Orchestrator Stuck (Lock File)
```bash
# Check if process is actually running
cat /tmp/agent-orchestrator.lock
ps -p $(cat /tmp/agent-orchestrator.lock)

# If process is dead, remove lock
rm /tmp/agent-orchestrator.lock
```

### Disk Full
```bash
# Emergency cleanup
find /home/novakj/actors/*/logs/ -name "*.log" -mtime +1 -delete
find /home/novakj/logs/ -name "*.log" -mtime +7 -delete
git gc --aggressive
```

### Nginx Down
```bash
sudo systemctl restart nginx
sudo systemctl status nginx
```

### Cron Not Running
```bash
sudo systemctl restart cron
crontab -l  # Verify jobs are listed
```

### Git Conflicts
```bash
cd /home/novakj
git stash
git pull --rebase
git stash pop
# If conflict persists:
git checkout --theirs .
git add -A
git commit -m "Resolve merge conflict"
```

### Web App Broken
```bash
# Check if index.html exists
ls -la /var/www/cronloop.techtools.cz/index.html

# Check Nginx is serving
curl -s -o /dev/null -w "%{http_code}" https://cronloop.techtools.cz/

# Check Nginx error log
sudo tail -20 /var/log/nginx/error.log
```

## Self-Healing Capabilities

The maintenance script automatically:
1. Checks disk usage and cleans if >80%
2. Validates core file existence (restores from git if missing)
3. Verifies script syntax (restores from git if broken)
4. Ensures cron service is running
5. Rotates oversized logs
6. Archives completed tasks when tasks.md grows too large

## Monitoring

| What | How | Alert threshold |
|------|-----|-----------------|
| Disk usage | `df -h /` | >80% warning, >90% critical |
| Memory | `free -h` | >80% warning, >90% critical |
| Cron service | `systemctl is-active cron` | Not active |
| Nginx service | `systemctl is-active nginx` | Not active |
| Core files | `ls` check | Any missing |
| Git status | `git status` | Uncommitted changes after agent run |
| Backlog size | `grep -c TODO tasks.md` | >30 tasks |
