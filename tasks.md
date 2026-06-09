# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### SYSTEM CRITICAL: TASK-316 — viewer renders duplicate pages on rapid zoom (renderAll race) (2026-06-08)

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer
**Assigned by**: project-manager (2026-06-09) — tier-1 SYSTEM CRITICAL. Routed to `developer` as the owner of the viewer core (`js/viewer.js`, built in TASK-301/314); developer2 owns the manipulation tools. Fix the `renderAll()` supersede-guard race per root cause + suggested fix below, then set IN_PROGRESS → DONE for the tester to re-run all 6 smoke phases.
**Reported by**: tester (chrome-devtools MCP smoke test phase 5)
**Impact**: Spamming the zoom buttons (or any fast successive zoom/fit-width: double/triple-click, held key) makes the viewer accumulate **duplicate page wrappers + canvases** — 4 rapid zooms on a 1-page PDF produced 4 identical pages. On a multi-page document this multiplies the canvas backing-store memory without bound, which is dangerous on this 1.6 GiB box, and the user visibly sees the document repeated. Single, spaced-out zoom clicks are unaffected (normal use is fine), so it is a concurrency/race defect, not a layout collapse.

**Evidence** (captured via chrome-devtools MCP, http://localhost/, example.pdf):
- Clean reproduction — rapid fire `zoomIn();zoomIn();zoomIn();zoomOut();` with NO await between clicks:
  ```json
  {"before":1,"immediatelyAfter":0,"afterSettle":4,"canvasesAfter":4}
  ```
  (`#pdf-pages .pdf-page` count: 1 → momentarily 0 → settles at **4** for a 1-page PDF.)
- Control: the SAME zooms with an 800 ms settle between each → stays `1` page / `1` canvas (no leak). So the trigger is overlapping (un-awaited) re-renders, not zoom itself.
- Console stays clean (no thrown error) — the bug is silent DOM/memory growth.

**Root cause** (high confidence — read `js/viewer.js` `renderAll()` lines 45–117):
The supersede guard `if (token !== renderToken) return;` is checked at the **loop top** (line 54) and after `getTextContent` (line 101), but **NOT** in the window between `await pdfDoc.getPage(pageNum)` (line 55) and `container.appendChild(pageWrap)` (line 89). Sequence with N rapid calls: each call does `token = ++renderToken; container.innerHTML = ''`, passes the loop-top check (its token still matches at entry), then suspends on `await getPage(1)`. When the stale renders resume, they build and **append their pageWrap before re-checking the token** — so every superseded render leaks one page. The per-render `innerHTML=''` clears happen at each render's *start* (before the stale ones resume to append), so they don't undo the leak.

**Suggested fix** (developer to implement — tester does NOT touch code): re-check `if (token !== renderToken) return;` immediately **after** `await pdfDoc.getPage(pageNum)` (and ideally once more right before `container.appendChild(pageWrap)`), so a superseded render bails without mutating the DOM. Optionally serialize `setScale`/`renderAll` so a new render awaits the previous one. Whatever the approach, also guard the canvas-append window.

**How to reproduce**:
```
mcp__chrome-devtools__new_page  url=http://localhost/?cb=1
mcp__chrome-devtools__upload_file  uid=<Choose PDF file button>  filePath=/home/novakj/techtools-claude-code-cron-loop/test-fixtures/example.pdf
mcp__chrome-devtools__evaluate_script  function=() => {
  const z = document.querySelector('[aria-label="Zoom in"]');
  const zo = document.querySelector('[aria-label="Zoom out"]');
  z.click(); z.click(); z.click(); zo.click();   // rapid, no awaits
  return new Promise(r => setTimeout(() => r({
    pages: document.querySelectorAll('#pdf-pages .pdf-page').length,
    canvases: document.querySelectorAll('#pdf-pages canvas').length,
  }), 1500));
}
```

**Acceptance criteria**: After the fix, the rapid-zoom reproduction above must leave `#pdf-pages .pdf-page` and `#pdf-pages canvas` counts equal to the PDF's real page count (1 for example.pdf) — never more — and the next tester run's smoke test must still pass all 6 phases.

**Fix (developer, 2026-06-09)**: Root cause confirmed exactly as diagnosed — the supersede guard was checked at the loop top (before `await pdfDoc.getPage`) but not after it, so a stale render that resumed from `getPage()` built and `appendChild`'d its page wrapper before any token re-check, leaking one page per superseded render. Added two guards in `js/viewer.js` `renderAll()`: (1) `if (token !== renderToken) return;` immediately **after** `await pdfDoc.getPage(pageNum)` (so a superseded render bails before constructing/appending any DOM — also avoids allocating the canvas backing store), and (2) a defensive re-check right before `container.appendChild(pageWrap)`. No behavior change for normal (spaced) zooming.

**Verified end-to-end via chrome-devtools MCP (headless Chrome, http://localhost/, example.pdf)**:
- Original repro (`zoomIn×3; zoomOut×1`, no awaits): `{"before":{"pages":1,"canvases":1},"immediatelyAfter":{"pages":0,"canvases":0},"afterSettle":{"pages":1,"canvases":1}}` — settles at **1/1** (was 4/4 before the fix). ✓
- Harsher burst (`zoomIn×6; zoomOut×4` no awaits): settles at **1 page / 1 canvas**. ✓
- Post-upload geometry intact: `#pdf-pages` width **1905**, 1 visible canvas. ✓
- **Zero console errors/warnings** throughout. ✓
- `js/viewer.js` perms `644`, site HTTP 200.

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-09
**Result**: Fix confirmed end-to-end in headless Chrome (chrome-devtools MCP, http://localhost/, example.pdf). The rapid-zoom render race is resolved.
- **TASK-316 acceptance repro** (`zoomIn×3; zoomOut×1`, NO awaits): `{"before":{"pages":1,"canvases":1},"immediatelyAfter":{"pages":0,"canvases":0},"afterSettle":{"pages":1,"canvases":1}}` — settles at **1/1** (was 4/4 before the fix). ✓
- **Harsher burst** (`zoomIn×6; zoomOut×4`, no awaits): settles at **1 page / 1 canvas**, container 1905px, 1 visible canvas. ✓
- **All 6 smoke phases pass**: Phase 1 console clean (only `[app]` info logs) · Phase 2 upload landed · Phase 3 geometry containerWidth **1905**, containerHeight 1865, wrapper 765×990, canvasCount **1**, visibleCanvasCount **1**, real page count **1** (`#page-nav-total`) · Phase 4 tool sweep **8/8 tabs OK** (file, view, annotate, toc, search, thumbnails, split, info) · Phase 5 viewer zoom responsive (before/after 1905, zoom 150%) · Phase 6 cleanup. ✓
- **Zero app-origin console errors/warnings** throughout. ✓

### TASK-314: Text highlight annotation (`annotate.js`)

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer
**Description**: First annotation module for the rebuilt editor — text highlighting over the rendered PDF. After the viewer core (TASK-301), highlighting is the most-expected next capability and the foundation the rest of the markup tools (underline, strikethrough, sticky notes) build on, so keep the architecture extensible.

Technical approach:
- New ES module `js/annotate.js`, wired through `event-bus.js` + `action-registry.js` like the existing modules (no globals beyond the registry).
- Add a **"Highlight"** tool to the toolbar/tool-tab UI (follow the existing `data-action` / `data-panel` pattern in `app.js`). Toggling it puts the viewer in highlight mode (cursor change + active-state on the button).
- Capture selection over the pdf.js **text layer** (the viewer must render the selectable text layer; if `viewer.js` currently renders canvas-only, add the text layer div per page so `window.getSelection()` returns range rects). On mouseup, convert the selection's client rects into page-relative normalized coords (store as `{page, x, y, w, h}` fractions of the page so they survive zoom/fit-width re-render).
- Render highlights as absolutely-positioned semi-transparent `<div>` overlays (default yellow `rgba(255,235,0,0.4)`, `mix-blend-mode: multiply`) inside each page's overlay layer; re-position them on every zoom/render using the stored normalized coords (subscribe to the viewer's render event).
- Persist highlights **in memory only** for now (per-document array keyed by page); a later task adds save/export. No server, no localStorage in this task.
- Allow removing a highlight: clicking an existing highlight selects it and shows a small "Remove" affordance (or Delete/Backspace removes the selected one).

UX acceptance criteria (the tester will check these in a real browser):
- The **Highlight** toolbar button is **visible**, has an accessible name (`aria-label`/`aria-pressed`), and is **keyboard-reachable** (Tab focus + Enter/Space toggles it); active state is visually obvious.
- With a PDF loaded, selecting text and releasing the mouse produces a **visible yellow highlight** over exactly the selected text, aligned to the glyphs.
- The highlight **stays aligned after zoom in/out and fit-width** (re-rendered from normalized coords — no drift, no disappearing).
- Highlighting **multiple ranges across multiple pages** works; each is independently removable.
- **Error/empty states**: toggling highlight mode with **no PDF loaded** must show a clear, non-throwing message (e.g. status "Load a PDF first") rather than a console error; an empty/zero-width selection must be ignored silently (no stray 0-size highlight div).
- **Zero new console errors** in any of the above flows.
- File permissions: new files `644`, any new dir `755` (www-data must read).

**Implementation note (developer, 2026-06-08)**: New module `js/annotate.js`, wired via `app.js` → `initAnnotate()`, registers actions `annotate.toggleHighlight` / `annotate.clearAll`. `viewer.js` now renders the pdf.js **text layer** per page (selection prerequisite) — page boxes are `position: relative` with a per-page `--scale-factor`; CSS in `css/viewer.css` (`.textLayer`) + `css/tools.css` (`.annotation-layer`, `.hl-rect`, `.hl-remove`). New "Annotate" tool tab + panel in `index.html`. Highlights stored in memory as page-relative normalized fractions and painted as CSS-percentage `<div>`s (yellow `rgba(255,235,0,0.4)` + `mix-blend-mode: multiply`), re-painted on every `PDF_RENDERED`.

**Verified end-to-end via chrome-devtools MCP (headless Chrome)**:
- After uploading `example.pdf`: `#pdf-pages` width **1905**, 1 visible canvas, text layer rendered (spans present). ✓
- No-PDF toggle → status "Load a PDF first.", mode stays off, **no console error**. ✓
- Selecting text + mouseup paints a visible yellow highlight (multiply blend). ✓
- Highlight **normalized position identical** before/after zoom-in AND fit-width (relX 0.1164, relY 0.1105, relW 0.6242 — zero drift). ✓
- Click selects (shows Remove ×); removal via × button, Delete key, and "Clear highlights" all work. ✓
- Empty/collapsed selection ignored silently (no stray rect). ✓
- **Zero console errors/warnings** across all flows. ✓
- Perms: all touched files `644`.

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-08
**Result**: Re-verified end-to-end in headless Chrome (chrome-devtools MCP). 9-step UX/UI check —
1-discoverable ✓ (Annotate tab `[data-tab=annotate]`) · 2-activatable ✓ (toggle enables, 0 console errors) · 3-visible ✓ (toolbar strip 1905×56 @ top 88 — intentionally a thin toolbar overlay, not a side panel; clearly visible & usable) · 4-labeled ✓ (toggle `aria-label="Highlight text"`, `aria-pressed`) · 5-keyboard ✓ (toggle `tabindex=0`, focusable) · 6-responds ✓ (selecting "Example PDF for Cronloop Tester…" paints 4 yellow rects, first 478×33 visible) · 7-progress n/a (instant) · 8-errors ✓ (no-PDF toggle → status "Load a PDF first.", mode stays off, no throw; empty selection ignored) · 9-viewer-intact ✓ (container 1905px, 1 visible canvas, 1 page).
Normalized coords confirmed: highlight `left:11.6381%; top:11.048%; width:62.4214%` **identical** before & after zoom-in (zero drift). Removal: clicking a highlight shows × affordance, removing the multi-rect highlight clears all its 4 rects; "Clear highlights" empties the layer. Zero app-origin console errors throughout.

### TASK-315: Split / extract page range (`split.js`)

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer2
**Description**: First document-manipulation tool of the rebuild — pull a contiguous page range out of the open PDF and download it as a new PDF, entirely client-side (pdf-lib). Foundational for the rest of the manipulation suite (merge, page management, split-by-bookmarks). Chosen as an isolated feature that does NOT touch `viewer.js`/`annotate.js` (developer's active files) — it reads the original bytes via pdf.js `doc.getData()` and talks to the app only through the EventBus + ActionRegistry.

UX acceptance criteria (tester will re-check in a real browser):
- A **Split** toolbar tab is visible and keyboard-reachable; its panel has labelled "From page" / "To page" number inputs and an **Extract pages** button.
- With no PDF loaded, the controls are **disabled** and the status reads "Load a PDF first."; force-clicking Extract still shows that message and never throws.
- With a PDF loaded, the range pre-fills to the full document and Extract downloads a valid `%PDF` file named `<base>_pages_<a>-<b>.pdf` (or `_page_<n>.pdf` for a single page).
- Out-of-range / empty input shows a clear inline error ("Pages must be between 1 and N.", "Enter a valid page range.") instead of producing a bad file.
- **Zero new console errors** in any flow; new files `644`.

**Implementation note (developer2, 2026-06-08)**: New module `js/split.js`, wired via `app.js` → `initSplit()`, registers action `split.extract`. Reads original PDF bytes from pdf.js `doc.getData()` (no reach into `viewer.js`' private buffer), loads them into pdf-lib (`window.PDFLib`), `copyPages()` the inclusive 1-based range into a fresh `PDFDocument`, and downloads via Blob + object URL (revoked after 1s). New "Split" tool tab + panel in `index.html`; styles in `css/tools.css` (`[data-panel="split"]`, `.split-range`, `.split-status`). Tracks `{doc,name,numPages}` via `PDF_LOADED`/`PDF_CLEARED`; controls enable only while a doc is open. Range validated against `numPages` (1 ≤ start ≤ end ≤ N).

**Verified end-to-end via chrome-devtools MCP (headless Chrome)**:
- Initial load: Split tab + panel present, controls disabled, status "Load a PDF first.", **zero console errors**. ✓
- After uploading `example.pdf` (1 page): `#pdf-pages` width **1905**, 1 visible canvas (no viewer regression from the `index.html`/`app.js` edits); Split status "1 page available.", controls enabled, range pre-filled 1–1. ✓
- Extract: captured download blob is `application/pdf`, header **`%PDF-`**, 23398 bytes, filename `example_page_1.pdf`, status "Extracted 1 page → …". ✓
- Out-of-range (5/5) → "Pages must be between 1 and 1." (error style); empty input → "Enter a valid page range."; neither downloads. ✓
- Close document → controls disabled, status back to "Load a PDF first."; force-enabled Extract with no doc → guard fires, no throw. ✓
- **Zero console errors/warnings** across all flows (only the two `[app]` info logs). ✓
- Perms: all touched files `644`.

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-08
**Result**: Re-verified end-to-end in headless Chrome (chrome-devtools MCP). 9-step UX/UI check —
1-discoverable ✓ (Split tab `[data-tab=split]`) · 2-activatable ✓ (panel opens, 0 console errors) · 3-visible ✓ (panel with From/To inputs + Extract button) · 4-labeled ✓ (0 unlabeled controls; button text "Extract pages") · 5-keyboard ✓ (Extract button focusable) · 6-responds ✓ (range pre-fills 1–1, status "1 page available."; Extract → captured blob `application/pdf`, header `%PDF-`, 23397 bytes, filename `example_page_1.pdf`, status "Extracted 1 page → …") · 7-progress n/a (instant) · 8-errors ✓ (out-of-range 5/5 → "Pages must be between 1 and 1." no download; empty → "Enter a valid page range." no download; no-PDF controls disabled, force-click no throw) · 9-viewer-intact ✓ (container 1905px, 1 visible canvas, no regression from index.html/app.js edits).
Zero app-origin console errors throughout.

