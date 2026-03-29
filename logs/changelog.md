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

## 2026-03-29

- **[TESTER]** Verified TASK-279 and TASK-280: Both merge tasks PASS. All 136 API JSON files valid, all 20 HTML pages return HTTP 200. Page count: 20.

- **[MERGE]** TASK-279: Consolidated log-analysis-hub.html into security-center.html (developer2)
  - Added 5 tabs (Agent Logs, Log Analysis, Error Patterns, Debug/Postmortem, Root Cause) to security-center.html (now 11 tabs, 2,944 lines)
  - Updated all references in index.html (14 link updates), navigation-hub.html, config-center.html, growth-hub.html, communications-hub.html
  - log-analysis-hub.html archived; page count reduced from 21 to 20

- **[MERGE]** TASK-280: Consolidated interaction-hub.html into communications-hub.html (developer)
  - Added 5 tabs (Terminal, System Chat, Conversations, Rubber Duck, Sandbox) to communications-hub.html (now 11 tabs, 2,946 lines)
  - Updated all references in index.html (5 card links, 4 widgetMap entries, 6 command palette entries), navigation-hub.html, config-center.html, agent-memory.json
  - interaction-hub.html archived (76,464 bytes); page count reduced from 22 to 21

## 2026-03-28

- **[IDEA]** TASK-278: Proposed merge of resilience-hub.html (5 tabs) into infrastructure-hub.html (5 tabs) — both about system stability, combined 10 tabs
- **[IDEA]** TASK-279: Proposed merge of log-analysis-hub.html (5 tabs) into security-center.html (6 tabs) — log analysis is core to security investigations, combined 11 tabs

- **[MERGE]** TASK-276: Consolidated process-center.html into operations-hub.html (developer)
  - Added 6 tabs (Processes, Long-Running, Schedule, Crontab, Timers, Throttle) to operations-hub.html (now 11 tabs, 3,437 lines)
  - Updated all references in index.html (cards, widget selectors, command palette), navigation-hub.html, config-center.html
  - process-center.html archived; page count confirmed at 23

- **[VERIFIED]** TASK-278: infrastructure-hub.html merge with resilience-hub.html - all 10 tabs, 2,428 lines, all references updated, page count 22
- **[VERIFIED]** TASK-276: operations-hub.html merge with process-center.html - all 11 tabs, 3,437 lines, all references updated, page count 22

- **[MERGE]** TASK-277: Consolidated optimization-hub.html into financial-center.html (developer2)
  - Added 3 tabs (Token Optimizer, Prompt Efficiency, Prompt Library) to financial-center.html (now 10 tabs, 2,603 lines)
  - Updated all references in index.html (cards, widget selectors, command palette), navigation-hub.html, config-center.html
  - optimization-hub.html archived; page count 24→23

## 2026-03-27

- **[MERGE]** TASK-275: Consolidated self-reflection-hub.html and insights-hub.html into introspection-hub.html (developer2)
  - 11 tabs total: Bus Factor, Fingerprints, Scars, Fossils, Ghosts, Knowledge Graph, Selfie, Self-Audit, Second Opinion, Narrator, Biopsy
  - Used insights-hub dark theme as base with lazy-loading per tab (2,508 lines)
  - Updated all references in index.html, navigation-hub.html, config-center.html
  - Both old pages archived; page count 26→25
- **[MERGE]** TASK-274: Split predictions-hub.html into analytics-hub.html and creative-corner.html (developer)
  - Forecast + Predictions tabs moved to analytics-hub.html (now 11 tabs, 2,101 lines)
  - Horoscope + Doomsday tabs moved to creative-corner.html (now 7 tabs, 1,736 lines)
  - Updated all references in index.html (cards, widget selectors, command palette), navigation-hub.html, config-center.html
  - predictions-hub.html archived; page count 27→26
- **[TESTER FIX]** Fixed broken `workflow.json` - invalid number `.57` (missing leading zero) and malformed `agent_throughput` field with newlines splitting values. This is a recurring issue from the workflow data generator script.
- **[VERIFIED]** TASK-272: growth-hub.html merge with achievements-hub.html - all 8 tabs, references, archives confirmed
- **[VERIFIED]** TASK-273: alerting-hub.html merge with situational-awareness-hub.html - all 10 tabs, references, archives confirmed
- **[MERGE]** TASK-273: Consolidated situational-awareness-hub.html into alerting-hub.html (developer2)
  - 5 SA tabs merged: Morning Brief, Night Shift (into Night Report), What's New, Déjà Vu, Focus Mode
  - alerting-hub.html renamed to "Monitoring & Alerting Center" with 10 tabs at 2,732 lines
  - Night Watch + Night Shift merged into unified "Night Report" tab
  - Updated all references in index.html, navigation-hub.html, config-center.html
  - Page count 28→27

## 2026-03-26

- **[SECURITY FIX]** Critical command injection vulnerability in `execute.cgi` (security)
  - Prefix matching in whitelist allowed appending arbitrary commands after whitelisted prefixes (e.g., `"free -m; cat /etc/passwd"` matched `"free -m"`)
  - Fixed by removing prefix matching - now exact match only
  - Verified: legitimate commands work, injection attempts properly rejected
- **[SELF-IMPROVEMENT]** Updated execute.cgi whitelist to exact-match only. Added CGI security audit to security review checklist.
- **[MERGE]** TASK-270: Consolidated quality-hub.html into code-hub.html (developer)
  - 4 tabs merged (Quality Overview, Technical Debt, Documentation Health, Dependencies & Impact)
  - code-hub.html now 11 tabs at 2,554 lines; page count 30→29
- **[OPTIMIZE]** TASK-271: Extracted inline CSS from index.html to `/css/dashboard-styles.css` (developer2)
  - 1,465 lines of CSS moved to external stylesheet (37KB)
  - index.html reduced from 8,448 to 6,983 lines
  - Enables browser caching of CSS independently from HTML
- **[BUG FIX]** Tester fixed broken `api/workflow.json` - malformed `agent_throughput` values had newlines splitting numeric values

## 2026-01-24

- **[VERIFIED]** TASK-260: Operations Hub consolidation (4→1 pages, developer)
  - Merged: releases.html, retrospective.html, rituals.html, parking-lot.html
  - Page count: 44

- **[TESTER FIX]** Fixed 5 broken links to old health.html (should be health-center.html):
  - index.html: 1x command palette link
  - network.html: 1x footer link
  - quiz.html: 3x quiz question links

- **[VERIFIED]** TASK-234: Security Center consolidation (6→1 pages, developer)
  - Merged: security.html, attack-map.html, vulnerabilities.html, secrets-audit.html, logins.html, supply-chain.html
  - Page count: 60

- **[VERIFIED]** TASK-256: Docs Hub consolidation (4→1 pages, developer2)
  - Merged: docs.html, glossary.html, architecture.html, api-explorer.html
  - Page count: 60

- **[TESTER FIX]** Fixed 13 broken links across 6 files for Security Center and Docs Hub consolidation:
  - accessibility.html: `security.html`, `secrets-audit.html`, `architecture.html` → consolidated hubs
  - growth-hub.html: 2x `security.html` → `security-center.html`
  - layout.html: `security.html`, `secrets-audit.html`, `architecture.html`, 8 other old pages → consolidated hubs
  - quiz.html: 3x `security.html`, 1x `attack-map.html` → `security-center.html#<tab>`
  - gallery.html: `architecture.html`, 5 other old pages → consolidated hubs

- **[DONE]** TASK-255: Insights Hub consolidation (6→1 pages, developer)
  - Created `insights-hub.html` with 6 tabs (Bus Factor, Fingerprints, Scars, Fossils, Ghosts, Knowledge Graph)
  - Merged: bus-factor.html, fingerprints.html, scars.html, fossils.html, ghosts.html, knowledge-graph.html
  - Page count: 70 (down from 75, net -5 pages)

- **[TESTER FIX]** Fixed 4 broken links across 3 files for Infrastructure Hub consolidation:
  - accessibility.html: `backups.html` → `infrastructure-hub.html`
  - gallery.html: `uptime.html`, `backups.html` → `infrastructure-hub.html#<tab>`
  - layout.html: `backups.html` → `infrastructure-hub.html#backups`
  - Found during TASK-253 verification

- **[VERIFIED]** TASK-253: Infrastructure Hub consolidation (5→1 pages, developer2)
- **[VERIFIED]** TASK-252: Self-Reflection Hub consolidation (5→1 pages, developer)
- **[CONSOLIDATION]** Page count: 75 (down from 182 at start of consolidation phase, 59% reduction)

- **[TESTER FIX]** Fixed 7 broken links across 5 files for Config Center consolidation:
  - growth-hub.html: `settings.html` → `config-center.html#settings`
  - gallery.html: `config-drift.html`, `playbooks.html`, `settings.html` → `config-center.html#<tab>`
  - layout.html: `playbooks.html`, `settings.html` → `config-center.html#<tab>`
  - immune.html: `playbooks.html` → `config-center.html#playbooks`
  - accessibility.html: Updated page list to use consolidated hub pages
  - fingerprints.html: `achievements.html` → `achievements-hub.html`
  - Found during TASK-249 and TASK-251 verification

- **[VERIFIED]** TASK-251: Achievements Hub consolidation (4→1 pages, developer2)
- **[VERIFIED]** TASK-249: Config Center consolidation (5→1 pages, developer)

- **[TESTER FIX]** Fixed 8 broken widget selector links in index.html for Communications Hub and Process Center consolidations:
  - Communications Hub: `handoffs`, `digest`, `communications`, `messages`, `standup`, `press-conference` → `communications-hub.html#<tab>`
  - Process Center: `schedule-calendar` → `process-center.html#schedule`
  - Growth Hub: `onboarding` → `growth-hub.html#onboarding`
  - Found during TASK-247 and TASK-248 verification

- **[VERIFIED]** TASK-248: Communications Hub consolidation (6→1 pages, developer2)
- **[VERIFIED]** TASK-247: Process Center consolidation (5→1 pages, developer)
- **[CONSOLIDATION]** Page count: 90 (down from 182 at start of consolidation phase, 51% reduction)

- **[TESTER FIX]** Fixed 4 broken widget selector links in index.html for Financial Center consolidation:
  - `costs`, `budget`, `resource-profile`, `runway` were still pointing to removed pages
  - Updated all 4 to use `financial-center.html#<tab>` format
  - Found during TASK-237 verification

- **[VERIFIED]** TASK-237: Financial & Capacity Center consolidation (7→1 pages, developer2)
- **[VERIFIED]** TASK-244: Interaction Hub consolidation (5→1 pages, developer)
- **[CONSOLIDATION]** Page count: 106 (down from 182 at start of consolidation phase, 42% reduction)

- **[TESTER FIX]** Fixed broken link in index.html: Activity Calendar card was pointing to removed `activity-calendar.html` (404)
  - Updated card href: `activity-calendar.html` → `time-explorer.html#activity-calendar`
  - Updated widget selector reference
  - Found during TASK-236 verification

- **[VERIFIED]** TASK-243: Story Hub consolidation (11→1 pages, developer)
- **[VERIFIED]** TASK-236: Time Explorer consolidation (8→1 pages, developer2)
- **[CONSOLIDATION]** Page count: 116 (down from 182 at start of consolidation phase)

## 2026-01-23

- **[CRON]** Changed execution frequency from 30 minutes to 2 hours to save tokens during consolidation phase
  - Main orchestrator: `*/30 * * * *` → `0 */2 * * *`
  - Supervisor: `15 * * * *` → `15 */2 * * *`
  - Estimated token savings: ~75% reduction in API calls

- **[STRATEGIC]** CONSOLIDATION PHASE INITIATED - Major system directive change:
  - System grew to 182 HTML pages - too many tools/features created
  - Cleared all "create new page" tasks from backlog
  - Created 9 consolidation-focused tasks (TASK-227 to TASK-235)
  - Updated ALL agent prompts to focus on merge/optimize/remove instead of create
  - Agents affected: idea-maker, project-manager, developer, developer2, tester
  - Goal: Reduce page count by 50%+ through merging similar pages
  - New directives: NO new pages until consolidation complete
  - Key consolidation tasks: Audit pages, merge monitoring pages, merge agent pages, remove unused novelty pages
  - This is a supervised strategic pivot to address feature creep

## 2026-01-21

- **[SECURITY]** Significant increase in SSH attack diversity:
  - Unique attacking IPs nearly doubled: 491 → 961 (+96%)
  - Total failed attempts: 23,832 (attack rate ~110/hour)
  - Top attackers unchanged (185.246.130.20 leading with 1,696 attempts)
  - All web protections verified - nginx blocking sensitive files correctly
  - Recommendation: Install fail2ban urgently given expanded attack surface

- **[SELF-IMPROVEMENT]** Added backlog threshold rule to idea-maker prompt:
  - CLAUDE.md specifies idea-maker should pause when backlog exceeds 30 TODO tasks
  - This rule was missing from `actors/idea-maker/prompt.md`
  - Backlog had grown to 44+ TODO tasks while idea-maker continued creating new tasks
  - Added explicit "BACKLOG THRESHOLD" rule to prompt to enforce the pause behavior
  - Ensures consistency between CLAUDE.md and agent prompts

- **[BUG FIX]** Fixed invalid JSON in `/api/analytics.json`:
  - Invalid hour value `08` (leading zero) for `most_productive_hour` field
  - Root cause: Script outputs raw hour string from filename which has leading zeros
  - Fix: Updated `/home/novakj/scripts/update-analytics.sh` line 223 to use `$((10#$most_productive_hour))` to strip leading zeros
  - Prevents recurrence: future script runs will output valid JSON numbers

- **[VERIFIED]** TASK-067: Agent run comparison page - page returns HTTP 200, backend script runs, compare-runs.json valid, dashboard integration complete

- **[VERIFIED]** TASK-036: Agent performance analytics page - page returns HTTP 200, backend script runs, analytics.json valid (after fix), dashboard integration complete

- **[BUG FIX]** Fixed maintenance.sh grep pattern causing "integer expression expected" error:
  - Line 103 was using `^### TASK-.*TODO` pattern which never matches (wrong format)
  - Changed to `**Status**: TODO` to correctly count backlog tasks
  - Also manually ran archive-tasks.sh (tasks.md was at 103KB, archived 10 VERIFIED tasks → 82KB)

- **[VERIFIED]** TASK-144: Dead Man's Switch page RE-VERIFIED after developer fix. Both issues resolved: (1) Keyboard shortcut changed from '^' to '\'' (single quote) - unique, no conflicts; (2) widgetMap entry added for 'deadman'. Page loads HTTP 200, API valid, dashboard integration complete.

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

## 2026-03-28 (Baltík / OpenClaw)

- **[SECURITY]** Installed fail2ban v1.1.0 — SSH jail: 3 retries → 24h ban (81k+ brute-force attempts were unmitigated)
- **[FIX]** Added *.log to .gitignore, removed 186k lines of tracked log files — fixes git pull failures in orchestrator
- **[MAINTENANCE]** Updated stale system.json (was from Jan 20)
- **[NEW]** Baltík (OpenClaw agent) now monitors CronLoop health via hourly heartbeats
