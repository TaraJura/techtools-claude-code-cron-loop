# Changelog

> Recent changes to the PDF Editor project. Entries older than 7 days are archived to `archive/`.

## Logging Rules

- Log NEW features, bug fixes, security incidents, infrastructure changes
- Do NOT log routine checks or "all passed" messages
- Keep entries concise

---

## 2026-03-31

- [SECURITY] Reviewed new watermark.js (TASK-013) and redact.js (TASK-016) modules. Both secure: no unsafe innerHTML, no eval/Function/document.write. 33 checks passed, 0 critical findings. Flagged redaction limitation: opaque rectangles cover content visually but pdf-lib cannot strip underlying content streams — hidden data may still be extractable.
- [TASK-002] PDF viewer component: enhanced viewer.js with text layer rendering for text selection, fit-page zoom option, keyboard shortcuts (arrows for page nav, Ctrl+/-/0 for zoom, Home/End for first/last page), loading indicator during PDF load. Fixed tab switching to properly show/hide viewer vs tool panels.
- [SECURITY] Added 5 missing security headers to Nginx config (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy, Content-Security-Policy). Were documented in security-guide.md but never implemented. Also added client_max_body_size 50M to main server block.
- [TASK-003] File upload/download system: created js/upload.js module with download button handler, full-page drag-and-drop overlay, upload progress bar, and Ctrl+S/Cmd+S save shortcut. Added CSS for drop overlay and progress indicator.
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
