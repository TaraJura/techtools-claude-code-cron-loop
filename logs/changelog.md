# Changelog

> Recent changes to the PDF Editor project. Entries older than 7 days are archived to `archive/`.

## Logging Rules

- Log NEW features, bug fixes, security incidents, infrastructure changes
- Do NOT log routine checks or "all passed" messages
- Keep entries concise

---

## 2026-04-01

- [TASK-020] Fixed crop tool bugs: (1) CRITICAL — changed `[...mb]`/`[...cb]` array spread to `{ ...mb }`/`{ ...cb }` object spread on line 684, fixing `TypeError: mb is not iterable` crash in applyCropAndDownload(). (2) Implemented proper undo that rebuilds the PDF with original mediaBox/cropBox values and downloads the uncropped version, replacing the previous no-op that only reset the UI overlay.
- [TASK-021] Page numbers & headers/footers: implemented page-numbers.js with full header/footer tool under the Pages tab. Supports page number formats ("1", "Page 1", "Page 1 of N", Roman numerals), custom text with placeholders ({page}, {total}, {date}, {filename}), 6-position grid (top/bottom x left/center/right), font family (Helvetica/TimesRoman/Courier), font size (8-24pt), color picker, configurable margin, page range selection (all/skip first/custom), and live canvas preview. Uses pdf-lib drawText() for embedding. Output as -numbered.pdf. All 21 DOM IDs match, CSS styles defined, responsive layout. HTTP 200 from live site.
- [TASK-010] Digital signatures: implemented signatures.js (~550 lines) with three creation modes — draw on canvas (with color/thickness controls, touch support, auto-trim whitespace), type with 4 font choices (cursive/serif/sans/mono with live preview), and upload image (PNG/JPG/WebP with drag-and-drop). Signatures placed on PDF pages with drag-to-reposition and corner-resize handles. PDF embedding via pdf-lib embedPng/embedJpg with correct coordinate transformation. Integrated into main download flow in annotate.js. Output as -signed.pdf. Full keyboard accessibility (Delete to remove, focus indicators). Responsive CSS. All files serve HTTP 200.

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
