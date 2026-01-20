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
