# CLAUDE.md - System Instructions

> **This is the core instruction file.** Keep it lean. Details are in `docs/`.

## SYSTEM IDENTITY: Autonomous AI Ecosystem

> **This entire server is autonomously maintained by Claude Code with FULL SUDO PERMISSIONS.**

| Aspect | Description |
|--------|-------------|
| **Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | Runs every 30 minutes via crontab |
| **Permissions** | Full sudo access - can do anything on this server |
| **Agents** | 6 specialized AI agents collaborate on tasks |
| **Goal** | Self-maintaining, self-improving system that builds a web app about itself |
| **Dashboard** | https://cronloop.techtools.cz |

Everything here - code, configs, documentation, web app - is created and maintained by AI.
No human intervention required. **The machine maintains itself.**

For detailed information about the autonomous architecture, see `docs/autonomous-system.md`.

## Critical Rules

1. **PRIMARY FOCUS**: Build the CronLoop web app at `/var/www/cronloop.techtools.cz`
2. **WEB INTEGRATION**: Every tool/script must be visible in the web interface
3. **STABILITY FIRST**: Never break core files (this file, tasks.md, orchestrator scripts)
4. **DOCUMENT CHANGES**: Log significant changes to `logs/changelog.md`
5. **SELF-IMPROVEMENT**: Learn from every mistake - update instructions to prevent repeating errors
6. **VERIFY EVERYWHERE** (MOST IMPORTANT): When making ANY system change:
   - Update ALL affected files (prompts, docs, scripts, configs)
   - Verify the change works by actually testing it
   - If a change affects multiple agents, update ALL agent prompts
   - Never assume a change is complete until tested end-to-end
7. **KEEP README.md UPDATED** (MANDATORY): When changing the ecosystem:
   - Update `README.md` Architecture diagram if agents/flow changes
   - Update `README.md` System Overview table if metrics change
   - Update `README.md` Agents section if adding/removing agents
   - Update `README.md` Scheduled Tasks if cron changes
   - **README.md is the public face of this project - it must always be accurate!**

## System Change Verification Protocol (MANDATORY)

> **This system must be bulletproof and long-term maintainable. Every change must be verified across the entire system.**

When introducing ANY change to the system:

### 1. Identify All Affected Components
```
Ask yourself:
- Which agent prompts need updating?
- Which documentation files reference this?
- Which scripts use this functionality?
- Which status/config files are affected?
- Does the README need updating?
```

### 2. Update Everything
- [ ] `CLAUDE.md` - Core rules
- [ ] `actors/*/prompt.md` - All 7 agent prompts that are affected
- [ ] `docs/*.md` - Relevant documentation
- [ ] `README.md` - **CRITICAL**: Architecture diagram, System Overview, Agents section
- [ ] Scripts that implement the change

### 3. Test the Change
```bash
# Actually run the affected functionality
# Don't just assume it works - VERIFY IT
```

### 4. Verification Checklist
Before considering any system change complete:
- [ ] All agent prompts updated and consistent
- [ ] Documentation matches implementation
- [ ] **README.md Architecture diagram is accurate**
- [ ] **README.md System Overview numbers are correct**
- [ ] Scripts work when actually executed
- [ ] No broken references or outdated information
- [ ] Change logged to changelog.md

> **A change that isn't verified everywhere is a bug waiting to happen.**

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
├── tasks.md               <- Active tasks only (TODO, IN_PROGRESS, DONE, FAILED)
├── docs/
│   ├── autonomous-system.md <- Autonomous AI ecosystem explanation (READ THIS!)
│   ├── server-config.md   <- Static server info, paths, software
│   ├── security-guide.md  <- Security rules and checklists
│   └── engine-guide.md    <- Self-healing protocols, recovery
├── status/
│   ├── system.json        <- Current system status (OVERWRITE, don't append)
│   ├── security.json      <- Current security state (OVERWRITE, don't append)
│   └── task-counter.txt   <- Next task ID number
└── logs/
    ├── changelog.md       <- Recent changes (last 7 days)
    ├── archive/           <- Monthly changelog archives
    └── tasks-archive/     <- Archived VERIFIED tasks (by month)
```

## Task Management

Tasks are archived to keep `tasks.md` lean and fast to read:

- **Active tasks** stay in `tasks.md` (TODO, IN_PROGRESS, DONE, FAILED)
- **Completed tasks** (VERIFIED) are auto-archived to `logs/tasks-archive/tasks-YYYY-MM.md`
- **Task IDs** are tracked in `status/task-counter.txt` - increment before creating new tasks
- **Archiving** runs automatically via `maintenance.sh` when tasks.md exceeds 100KB

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

### Main Pipeline (Every 30 minutes)
| Actor | Role | Runs |
|-------|------|------|
| idea-maker | Generate feature ideas | 1st |
| project-manager | Assign tasks | 2nd |
| developer | Implement tasks | 3rd |
| developer2 | Implement tasks (parallel) | 4th |
| tester | Verify work | 5th |
| security | Security review | 6th (last) |

### Supervisor (Hourly at :15)
| Actor | Role | Runs |
|-------|------|------|
| supervisor | Top-tier ecosystem overseer | Hourly (separate) |

The **supervisor** is a meta-agent that:
- Monitors all other agents and system health
- Maintains persistent todo list across runs
- Fixes issues but prioritizes stability over changes
- Runs independently from the main 30-min pipeline

**Execution**: Main pipeline every 30 min, Supervisor hourly at :15

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
