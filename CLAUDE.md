# CLAUDE.md - System Instructions

> **This is the core instruction file.** Keep it lean. Details are in `docs/`.

## Critical Rules

1. **PRIMARY FOCUS**: Build the CronLoop web app at `/var/www/cronloop.techtools.cz`
2. **WEB INTEGRATION**: Every tool/script must be visible in the web interface
3. **STABILITY FIRST**: Never break core files (this file, tasks.md, orchestrator scripts)
4. **DOCUMENT CHANGES**: Log significant changes to `logs/changelog.md`
5. **SELF-IMPROVEMENT**: Learn from every mistake - update instructions to prevent repeating errors

## Self-Improvement Protocol (CRITICAL)

> **This system simulates a full development cycle and MUST improve itself over time.**

### The Core Principle

When ANY agent encounters an error, bug, failure, or suboptimal outcome:

1. **Identify the root cause** - What went wrong and why?
2. **Fix the immediate issue** - Resolve the current problem
3. **Update instructions** - Modify the relevant files to prevent recurrence:
   - `CLAUDE.md` - For system-wide rules
   - `actors/<agent>/prompt.md` - For agent-specific behavior
   - `docs/*.md` - For detailed procedures
4. **Log the learning** - Document what was learned in `logs/changelog.md`

### What Triggers Self-Improvement

| Trigger | Action |
|---------|--------|
| Task marked FAILED by tester | Developer updates own prompt with lesson learned |
| Security vulnerability found | Security agent adds rule to `security-guide.md` |
| Same error occurs twice | Add explicit prevention rule to relevant prompt |
| Agent produces duplicate work | Strengthen deduplication checks in prompt |
| Build/deploy failure | Document fix in `engine-guide.md` |
| Performance degradation | Add optimization rules |
| Any repeated mistake | **MANDATORY** instruction update |

### How to Update Instructions

```markdown
## Example: Adding a lesson learned to a prompt

### Before (agent keeps making same mistake):
- Create web features

### After (agent learned from failure):
- Create web features
- **LEARNED**: Always check if similar feature exists before creating (TASK-042 duplicate incident)
```

### Self-Improvement Checklist

When fixing any issue, ask:
- [ ] Could this have been prevented with better instructions?
- [ ] Which agent/file should be updated?
- [ ] Is this a pattern that might recur?
- [ ] Have I added a specific rule to prevent this?

### Tracking Improvements

Log instruction updates to `logs/changelog.md`:
```
## 2026-01-20
- [SELF-IMPROVEMENT] Updated developer prompt: Added rule to check for existing features before implementation (learned from TASK-042 duplicate)
```

### The Goal

**Build better products over time** by continuously refining:
- Agent prompts (smarter behavior)
- System rules (fewer edge cases)
- Documentation (clearer procedures)
- Error handling (faster recovery)

> **Every mistake is an opportunity to make the system permanently smarter.**

## Documentation Architecture

```
/home/novakj/
├── CLAUDE.md              <- YOU ARE HERE (core rules only)
├── tasks.md               <- Task board (read/write)
├── docs/
│   ├── server-config.md   <- Static server info, paths, software
│   ├── security-guide.md  <- Security rules and checklists
│   └── engine-guide.md    <- Self-healing protocols, recovery
├── status/
│   ├── system.json        <- Current system status (OVERWRITE, don't append)
│   └── security.json      <- Current security state (OVERWRITE, don't append)
└── logs/
    ├── changelog.md       <- Recent changes (last 7 days)
    └── archive/           <- Monthly changelog archives
```

## How to Use This Architecture

### Reading Documentation
- **Start here** (CLAUDE.md) for core rules
- **Read `docs/server-config.md`** for server details, paths, installed software
- **Read `docs/security-guide.md`** for security rules and checklists
- **Read `docs/engine-guide.md`** for recovery procedures and self-healing

### Updating Status (IMPORTANT)
Status files are **OVERWRITTEN**, not appended:
```bash
# CORRECT: Overwrite the entire file with current state
echo '{"status": "ok", "timestamp": "..."}' > status/system.json

# WRONG: Do NOT append
echo '{"status": "ok"}' >> status/system.json  # NO!
```

### Logging Changes
Log to `logs/changelog.md` ONLY for:
- New features or bug fixes
- Security incidents (not routine checks)
- Infrastructure changes
- Significant events (>50% metric changes)

**DO NOT log:**
- "All checks passed" messages
- Routine status updates (use status/*.json)
- Repetitive information

## Actor Quick Reference

| Actor | Role | Runs |
|-------|------|------|
| idea-maker | Generate feature ideas | 1st |
| project-manager | Assign tasks | 2nd |
| developer | Implement tasks | 3rd |
| developer2 | Implement tasks (parallel) | 4th |
| tester | Verify work | 5th |
| security | Security review | 6th (last) |

**Execution**: Every 30 minutes via cron

## Core Protected Files

Never delete or corrupt these:
- `/home/novakj/CLAUDE.md`
- `/home/novakj/tasks.md`
- `/home/novakj/scripts/cron-orchestrator.sh`
- `/home/novakj/scripts/run-actor.sh`
- `/home/novakj/actors/*/prompt.md`

**Recovery**: `git checkout HEAD -- <file>`

## Quick Health Check

```bash
# Check core files exist
ls -la CLAUDE.md tasks.md scripts/*.sh

# Check disk space
df -h / | awk 'NR==2 {print $5}'

# Check cron
systemctl is-active cron

# Check git
git status
```

## Decision Tree

```
START
  |
  +-- Disk >80%? --> Run cleanup first
  +-- Core files missing? --> Restore from git, STOP
  +-- tasks.md corrupt? --> Restore from git
  +-- Emergency in logs? --> Fix it first
  |
  +-- Normal operation:
      - idea-maker: 1 idea (if backlog <30)
      - PM: assign 1 task (to developer or developer2)
      - developer: complete 1 task (assigned to developer)
      - developer2: complete 1 task (assigned to developer2)
      - tester: verify 1 task
      - security: update status/security.json
```

## Web Application

- **URL**: https://cronloop.techtools.cz
- **Root**: `/var/www/cronloop.techtools.cz`
- **Stack**: HTML/CSS/JS + Nginx + SSL

## GitHub

https://github.com/TaraJura/techtools-claude-code-cron-loop

---

*For detailed documentation, see the `docs/` directory.*
