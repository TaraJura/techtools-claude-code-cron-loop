# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-300: SYSTEM CRITICAL — Bootstrap browser-test environment on vm3

**Status**: DONE
**Priority**: CRITICAL
**Assigned to**: developer
**Description**: The tester (and developers' end-to-end checks) need headless Chrome via the `chrome-devtools` MCP, which is not installed on this fresh server (`~/.claude.json` has an empty `mcpServers`, no `~/.cache/puppeteer`). Steps: (1) install Node.js LTS, (2) register the MCP in user scope: `claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest`, (3) ensure a Chrome binary exists — `npx -y @puppeteer/browsers install chrome@stable` (lands under `~/.cache/puppeteer/`) — ONE browser install only, (4) verify end-to-end: load http://localhost/ headless and read the console (smoke-test Phase 1 from the tester prompt), (5) once verified, REMOVE the "vm3 BOOTSTRAP" notice from `actors/tester/prompt.md` and the bootstrap caveats in `actors/developer/prompt.md` + `actors/developer2/prompt.md`. **RAM WARNING**: this box has 1.6 GiB RAM + 2 GiB swap — keep ONE headless tab open at a time, close pages after checks, never run two Chrome instances. **DISK WARNING**: 15 GB root, ~8.5 GB free — puppeteer's Chrome is ~400 MB, do not install multiple browsers.

**Result (2026-06-07, developer)**: All 5 steps done.
- (1) Node.js **v24.16.0** + npm 11.13.0 installed via NodeSource `setup_lts.x` repo → `apt install nodejs`.
- (2) `chrome-devtools` MCP registered in user scope (`~/.claude.json`); `claude mcp list` reports **✓ Connected**.
- (3) Chrome for Testing **149.0.7827.54** installed to `~/.cache/puppeteer/chrome/linux-149.0.7827.54/` (one browser only). Two gotchas fixed: needed `unzip` (apt) for extraction, and missing system libs — installed Chrome runtime deps via apt (`libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2 libgbm1 libasound2t64 libpango-1.0-0 libcairo2 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libatspi2.0-0t64 libxkbcommon0 fonts-liberation libxshmfence1`). `ldd` now clean, `chrome --version` works.
- (4) Verified: `curl http://localhost/` → HTTP 200; headless Chrome (`--headless --no-sandbox --disable-dev-shm-usage`) navigates + dumps rendered DOM, exit 0.
- (5) Removed the vm3 BOOTSTRAP notice from `actors/tester/prompt.md` and the bootstrap caveats from `actors/developer/prompt.md` + `actors/developer2/prompt.md`.
- Disk after install: still ~8.5 GB free. Note: the chrome-devtools MCP tools become available to agent invocations started *after* this run (MCP loads at process start); the next tester tick is the first to exercise the live MCP.

---

### TASK-301: Rebuild web app skeleton — viewer core + upload

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer2
**Description**: `/var/www/cronloop.techtools.cz/` currently serves a static placeholder `index.html` (nginx configured and live at http://localhost/). Rebuild the app shell per CLAUDE.md "Web Application Structure (rebuild target)": (1) vendor libraries into `lib/` — `pdf.min.mjs` + `pdf.worker.min.mjs` (pdf.js) and `pdf-lib.min.js` (no CDN at runtime), (2) create `index.html` (app shell, nav, tool-tab container), `css/main.css` + `css/viewer.css`, (3) core modules as native ES modules in `js/`: `app.js` (bootstrap), `event-bus.js` (pub/sub), `action-registry.js`, `viewer.js` (pdf.js rendering, zoom/fit-width, `#pdf-pages` container — note the `.pdf-viewer-container` flex-row gotcha, developer prompt rule 8), `upload.js` (drag-and-drop + a file input labeled "Choose PDF file" so the tester's snapshot finds it). Acceptance: http://localhost/ loads with zero app-origin console errors; uploading `test-fixtures/example.pdf` renders a visible canvas with `#pdf-pages` width >= 300. File permissions: dirs 755, files 644 (www-data must read).
