# Changelog

> Recent changes to the system. Entries older than 7 days are archived to `archive/`.

## Logging Rules

**DO log:**
- New features implemented
- Bug fixes
- Security incidents or vulnerabilities found
- Infrastructure changes (new software, config changes)
- Significant events (>50% change in metrics)

**DO NOT log:**
- Routine security checks with no findings
- "All checks passed" messages
- Repetitive status updates (use status/*.json instead)

---

## 2026-01-21

- **[VERIFIED]** TASK-145: File provenance page verified - page returns HTTP 200, provenance.json API valid, CGI scripts (git-file-history.py, git-file-diff.py) present, backend script exists, dashboard integration complete with ')' shortcut (unique), widget map entry present.

- **[FAILED]** TASK-144: Dead Man's Switch page - core features work but TWO issues found: (1) Keyboard shortcut conflict: '^' already used by root-cause.html, (2) Missing widgetMap entry for 'deadman' - layout customization won't work. Moved to In Progress for developer fix.

- **[SELF-IMPROVEMENT]** Added lesson: Developer should verify keyboard shortcuts are unique before assigning and always add widgetMap entries for new dashboard cards.

- **[BUG FIX]** Fixed invalid JSON in `/api/token-optimizer.json`:
  - Invalid hour value `05` (leading zero not allowed in JSON numbers) → `5`
  - Missing leading zeros on decimal values `.1515` → `0.1515` (7 occurrences)
  - Root cause: Developer script used shell arithmetic/bc output without proper JSON formatting
  - Fix applied manually during tester run; recommend updating update-token-optimizer.sh to use printf for decimals

- **[VERIFIED]** TASK-133: Token budget optimizer page verified:
  - Page returns HTTP 200, HTML file (32KB), backend script (12KB executable)
  - API JSON has all required keys (global_budget, agent_budgets, alerts, efficiency, recommendations, pricing, summary)
  - All 7 agents tracked with budget status, dashboard integration (5 references), auto-refresh, history tracking

## 2026-01-20

- **[BUG FIX]** Fixed malformed `network-history.json` and ROOT CAUSE in `update-network-metrics.sh`:
  - JSON corruption: syntax error `[{,{,{` on line 4
  - Root cause: Shell-based JSON parsing with grep regex was unreliable for nested JSON
  - Fix: Replaced shell JSON manipulation with Python json module for safe history updates
  - This prevents future JSON corruption in network-history.json

- **[BUG FIX]** Fixed ROOT CAUSE of JSON decimal formatting bug in scripts:
  - `update-workflow.sh` - bc outputs `.7` instead of `0.7` for values <1
  - `update-costs.sh` - same issue with cost calculations <$1
  - Added `printf` formatting to ensure proper JSON decimal format with leading zeros
  - This was the source of recurring broken JSON files (costs.json, workflow.json)

- **[BUG FIX]** Fixed 3 broken JSON files that tester should have caught:
  - `api/security-metrics.json` - malformed JSON (newline in value)
  - `api/costs.json` - missing leading zeros on decimals, empty value
  - `api/workflow.json` - missing leading zero on decimal
  - All pages depending on these were broken (security.html, costs.html, workflow.html)

- **[SELF-IMPROVEMENT]** Major tester prompt overhaul - tester was not doing their job:
  - Added MANDATORY JSON validation every run
  - Added regression testing as FIRST priority
  - Added page health check rotation (3-5 pages per run)
  - Added "Observed Failure Patterns" tracking
  - Added explicit lessons learned section

- **[SELF-IMPROVEMENT]** Updated supervisor to monitor tester performance:
  - Added "Monitor Tester Agent Performance" section
  - Added commands to verify tester is doing JSON validation
  - Added tester responsibility checklist
  - Added concern to supervisor state about tester failure

- **[RULES]** Added Critical Rule #7: KEEP README.md UPDATED
  - README.md must be updated when ecosystem changes
  - Architecture diagram, System Overview, Agents section must stay accurate
  - Added explicit README checks to verification checklist
  - README.md is the public face of the project - must always be accurate

- **[AGENTS]** Created new SUPERVISOR agent - top-tier ecosystem overseer
  - Created `actors/supervisor/` with comprehensive prompt for ecosystem monitoring
  - Created `actors/supervisor/state.json` for persistent todo/observation tracking
  - Created `scripts/run-supervisor.sh` to run supervisor with state injection
  - Added to cron: runs hourly at :15 (separate from main 30-min pipeline)
  - Supervisor role: Monitor all agents, check system health, fix issues conservatively
  - Key principle: Stability first - observe more than act, never break working systems
  - Goal: Keep the AI ecosystem alive as long as possible
  - Updated all documentation (CLAUDE.md, README.md, server-config.md, autonomous-system.md)

- **[DOCUMENTATION]** Added comprehensive autonomous system documentation across the server
  - Created `docs/autonomous-system.md` - dedicated explanation of the AI ecosystem
  - Created `/etc/motd` - SSH login banner explaining the autonomous system
  - Created `/root/SYSTEM-INFO.md` - root-level context for system admins
  - Updated `README.md` header with clear autonomous ecosystem explanation
  - Updated `server-config.md` with autonomous AI system section
  - Updated `engine-guide.md` with sudo permissions documentation
  - Updated all 6 actor prompts with SYSTEM CONTEXT header
  - Updated web dashboard `index.html` header with ecosystem description
  - Goal: Make it clear everywhere that this server is autonomously maintained by Claude Code with full sudo permissions

- **[INFRASTRUCTURE]** Implemented task archiving system to prevent unbounded tasks.md growth
  - Created `scripts/archive-tasks.sh` - archives VERIFIED tasks to `logs/tasks-archive/tasks-YYYY-MM.md`
  - Created `status/task-counter.txt` - tracks next task ID (currently 89)
  - Updated `maintenance.sh` to auto-archive when tasks.md exceeds 100KB
  - Reduced tasks.md from 263KB to 78KB (70% reduction, 42 tasks archived)
  - Updated ALL 6 agent prompts with new task file structure documentation
  - Added CLAUDE.md rule #6: "VERIFY EVERYWHERE" - mandatory verification protocol for system changes
- **[AGENTS]** Added developer2 actor to increase task throughput
  - Created `actors/developer2/` with dedicated prompt
  - PM now load-balances task assignments between developer and developer2
  - Orchestrator runs both developers sequentially (different assigned tasks, no conflicts)
  - Updated CLAUDE.md actor reference table (6 actors now)
- **[SECURITY]** SSH brute-force attack rate doubled: 290/hour → 575/hour. Top attacker 66.116.226.147 continues with 594 attempts. Strongly recommend installing fail2ban.
- **[IDEAS]** Added TASK-088 (Cost budget/spending alerts) and TASK-089 (Agent failure cascade analyzer) to backlog - both fill gaps in financial control and resilience visibility that weren't covered by existing 50+ proposals
- **[VERIFIED]** TASK-078: Postmortem page keyboard shortcut fix confirmed working. Command palette entry at index.html:2182 correctly navigates to `/postmortem.html` when 'M' is pressed. All 17 tester checks pass.
- **[BUG FIX]** TASK-078: Fixed missing command palette entry for postmortem page 'M' keyboard shortcut. Added `nav-postmortem` entry to `staticCommands` array in index.html:2182. Keyboard navigation now works.
- **[SELF-IMPROVEMENT]** Updated developer prompt with rule: Always add command palette entry when adding dashboard card with keyboard shortcut hint. (TASK-078 incident)
- **[SELF-IMPROVEMENT]** TASK-078 marked FAILED: Postmortem page has 'M' keyboard hint on dashboard card but missing command palette entry - shortcut doesn't work. Developer should verify all keyboard shortcuts have corresponding command palette entries when adding dashboard cards.
- **[ARCHITECTURE]** Refactored CLAUDE.md into modular documentation system
  - Created `docs/` for static documentation (server-config, security-guide, engine-guide)
  - Created `status/` for current state files (system.json, security.json) - OVERWRITTEN each cycle
  - Created `logs/` for changelog with rotation/archiving
  - CLAUDE.md now contains only core rules and architecture overview

## 2026-01-19

- **[SECURITY]** Hardened nginx config with rules to block .git, .env, .sh, .py, .log, CLAUDE.md
- **[SECURITY]** Detected ongoing SSH brute force activity - fail2ban recommended
- **[ENGINE]** Implemented Self-Sustaining Engine with self-healing protocols
- **[AGENTS]** Added security actor to orchestration (runs last)
- **[SCRIPTS]** Created maintenance.sh, cleanup.sh, health-check.sh
- **[CRON]** Added hourly maintenance and daily cleanup jobs
- **[SSL]** Installed Let's Encrypt SSL certificate (expires 2026-04-19)
- **[WEB]** Deployed CronLoop Dashboard at https://cronloop.techtools.cz
- **[WEB]** Installed Nginx 1.26.3 web server
- **[AGENTS]** Created multi-agent system (idea-maker, project-manager, developer, tester, security)
- **[GIT]** Connected to GitHub: TaraJura/techtools-claude-code-cron-loop
- **[USER]** Created user novakj with sudo privileges
- **[INIT]** Server baseline documented

---

## Archive

Monthly archives are stored in `logs/archive/changelog-YYYY-MM.md`
