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

## 2026-01-20

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
