# Changelog

> Recent changes to the PDF Editor project. Entries older than 7 days are archived to `archive/`.

## Logging Rules

- Log NEW features, bug fixes, security incidents, infrastructure changes
- Do NOT log routine checks or "all passed" messages
- Keep entries concise

---

## 2026-03-31

- [TASK-001] Project scaffolding complete: directory structure, HTML shell with navigation, 3 CSS files, 11 JS ES modules, pdf.js/pdf-lib/Tesseract.js libraries downloaded to lib/
- [PIVOT] Complete system pivot from CronLoop dashboard to PDF Editor web application
- [PIVOT] Rewrote all 7 agent prompts for PDF editor development
- [PIVOT] Reset task board with 10 initial PDF editor tasks (TASK-001 to TASK-010)
- [PIVOT] Cleaned web root, created "Coming Soon" placeholder page
- [PIVOT] Rewrote CLAUDE.md, README.md, and all documentation for PDF editor context
- [PIVOT] Removed ~90 dashboard-specific scripts, kept 6 core orchestration scripts
- [PIVOT] Simplified cron-orchestrator.sh (removed dashboard status update hooks)
- [PIVOT] Updated cron schedule: 2-hour pipeline, 2-hour supervisor, hourly maintenance, daily cleanup
- [PIVOT] Git tagged pre-pivot state as v1.0-cronloop-dashboard
