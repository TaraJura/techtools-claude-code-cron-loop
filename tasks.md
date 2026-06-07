# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-300: SYSTEM CRITICAL — Bootstrap browser-test environment on vm3

**Status**: TODO
**Priority**: CRITICAL
**Assigned to**: developer
**Description**: The tester (and developers' end-to-end checks) need headless Chrome via the `chrome-devtools` MCP, which is not installed on this fresh server (`~/.claude.json` has an empty `mcpServers`, no `~/.cache/puppeteer`). Steps: (1) install Node.js LTS, (2) register the MCP in user scope: `claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest`, (3) ensure a Chrome binary exists — `npx -y @puppeteer/browsers install chrome@stable` (lands under `~/.cache/puppeteer/`) — ONE browser install only, (4) verify end-to-end: load http://localhost/ headless and read the console (smoke-test Phase 1 from the tester prompt), (5) once verified, REMOVE the "vm3 BOOTSTRAP" notice from `actors/tester/prompt.md` and the bootstrap caveats in `actors/developer/prompt.md` + `actors/developer2/prompt.md`. **RAM WARNING**: this box has 1.6 GiB RAM + 2 GiB swap — keep ONE headless tab open at a time, close pages after checks, never run two Chrome instances. **DISK WARNING**: 15 GB root, ~8.5 GB free — puppeteer's Chrome is ~400 MB, do not install multiple browsers.

---

### TASK-301: Rebuild web app skeleton — viewer core + upload

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer2
**Description**: `/var/www/cronloop.techtools.cz/` currently serves a static placeholder `index.html` (nginx configured and live at http://localhost/). Rebuild the app shell per CLAUDE.md "Web Application Structure (rebuild target)": (1) vendor libraries into `lib/` — `pdf.min.mjs` + `pdf.worker.min.mjs` (pdf.js) and `pdf-lib.min.js` (no CDN at runtime), (2) create `index.html` (app shell, nav, tool-tab container), `css/main.css` + `css/viewer.css`, (3) core modules as native ES modules in `js/`: `app.js` (bootstrap), `event-bus.js` (pub/sub), `action-registry.js`, `viewer.js` (pdf.js rendering, zoom/fit-width, `#pdf-pages` container — note the `.pdf-viewer-container` flex-row gotcha, developer prompt rule 8), `upload.js` (drag-and-drop + a file input labeled "Choose PDF file" so the tester's snapshot finds it). Acceptance: http://localhost/ loads with zero app-origin console errors; uploading `test-fixtures/example.pdf` renders a visible canvas with `#pdf-pages` width >= 300. File permissions: dirs 755, files 644 (www-data must read).
