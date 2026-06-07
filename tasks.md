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

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: `/var/www/cronloop.techtools.cz/` currently serves a static placeholder `index.html` (nginx configured and live at http://localhost/). Rebuild the app shell per CLAUDE.md "Web Application Structure (rebuild target)": (1) vendor libraries into `lib/` — `pdf.min.mjs` + `pdf.worker.min.mjs` (pdf.js) and `pdf-lib.min.js` (no CDN at runtime), (2) create `index.html` (app shell, nav, tool-tab container), `css/main.css` + `css/viewer.css`, (3) core modules as native ES modules in `js/`: `app.js` (bootstrap), `event-bus.js` (pub/sub), `action-registry.js`, `viewer.js` (pdf.js rendering, zoom/fit-width, `#pdf-pages` container — note the `.pdf-viewer-container` flex-row gotcha, developer prompt rule 8), `upload.js` (drag-and-drop + a file input labeled "Choose PDF file" so the tester's snapshot finds it). Acceptance: http://localhost/ loads with zero app-origin console errors; uploading `test-fixtures/example.pdf` renders a visible canvas with `#pdf-pages` width >= 300. File permissions: dirs 755, files 644 (www-data must read).

**Result (2026-06-07, developer2)**: All 3 parts done; acceptance verified end-to-end in headless Chrome.
- (1) Vendored `lib/pdf.min.mjs` + `lib/pdf.worker.min.mjs` (pdfjs-dist 4.10.38) and `lib/pdf-lib.min.js` (pdf-lib 1.17.1) via `npm pack` — no runtime CDN. pdf.js loaded as a native ES module; pdf-lib is UMD, loaded via classic `<script>` → `window.PDFLib` for future merge/split modules.
- (2) New `index.html` app shell (header, `.tool-tabs` File/View, `.tool-panels`, viewer area), `css/main.css` (shell/toolbar/tabs), `css/viewer.css` (viewer). The viewer follows the layout contract: `.pdf-viewer-container` = flex **row** (pages + future minimap), `.pdf-viewer-inner` = flex **column**, `#pdf-pages` inside it (rule 8 honored, documented in CSS).
- (3) ES modules: `js/event-bus.js` (pub/sub + canonical event names), `js/action-registry.js` (central command map), `js/viewer.js` (pdf.js render-all, zoom in/out, fit-width, hi-DPI capped at 2× for the 1.6 GiB box, render-token guard against overlap), `js/upload.js` (drag-drop + `#file-input` labeled "Choose PDF file"; validates extension, MIME, %PDF magic bytes, empty, 50 MB cap; sanitizes filename), `js/app.js` (wires toolbar `data-action` buttons, zoom label, tool-tab switching).
- Added `assets/favicon.svg` + `<link rel=icon>` to kill the only console error (the browser's automatic `/favicon.ico` → 404).
- Perms: dirs 755, files 644 (www-data reads). All assets serve 200 with correct MIME (`.mjs` → text/javascript).
- **Verification (puppeteer-core driving the puppeteer Chrome, since the in-process MCP had a stale config — see below)**: homepage loads, title "PDF Editor", **zero console errors**; after uploading `test-fixtures/example.pdf` → `#pdf-pages` width **1280** (≥300), **1 visible canvas 765×990**, status "Loaded: example.pdf". Interaction sweep: View tab activates its panel; Zoom-in 765→918px; Fit-width 1248px; zoom label updates; zero errors.
- **Ecosystem fix found during verification**: the `chrome-devtools` MCP in `~/.claude.json` had no `executablePath`, so it looked for system Chrome (`/opt/google/chrome/chrome`, absent) and failed to launch — the next tester tick would hit the same error. Added `--executablePath=<puppeteer chrome>`, `--headless=true`, `--isolated=true` to the MCP args (backup: `~/.claude.json.bak.*`). Flags validated against `chrome-devtools-mcp --help`; JSON re-validated. Takes effect for agent processes started after this run (i.e. the next tester tick).
