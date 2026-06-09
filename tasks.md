# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### SYSTEM CRITICAL: TASK-316 — viewer renders duplicate pages on rapid zoom (renderAll race) (2026-06-08) — RESOLVED

**Status**: VERIFIED
**PM note (2026-06-09)**: Reconciled stale header status DONE→VERIFIED — the tester's verdict block below already marked this VERIFIED (fix confirmed end-to-end, all 6 smoke phases pass). SYSTEM CRITICAL cleared; no open tier-1 work. Eligible for archival on next maintenance run.
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


### TASK-317: Highlight the matched term inside the search result snippet (`search.js`)

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Assigned by**: project-manager (2026-06-09) — tier-4 new feature; stability gate OPEN (0 SYSTEM CRITICAL, 0 FAILED, 0 DONE-awaiting-verification after TASK-316 reconciliation). Routed to `developer2` (owner of the manipulation/search-side modules — TASK-315 split; developer owns the viewer/annotate core). Additive change to `search.js` snippet rendering only — do NOT touch `viewer.js` render core or `upload.js` validation. The `<mark>` slice MUST come from extracted page text via `textContent`, never the query string (XSS gate). Set IN_PROGRESS when you pick it up; → DONE for the tester.
**Description**: Polish the existing in-document search (TASK-307, VERIFIED) so the user can *see* which word matched. Today `setSnippet()` in `js/search.js` renders the active match as plain text via `snippetEl.textContent = \`Page N: …context…\`` — the matched term is buried in the surrounding context with no visual emphasis. Improve the snippet rendering so the matched substring is visually marked (wrap it in a `<mark>` element) while the context around it stays plain.

**Technical approach** (additive only — do NOT touch `viewer.js` rendering core, `upload.js` validation, or the match-collection logic; only change how the *current* match snippet is rendered):
- Change `setSnippet`/`showMatch` to build DOM nodes instead of assigning a single `textContent` string: create a text node for the leading context, a `<mark class="search-mark">` whose `textContent` is the matched slice, and a text node for the trailing context; replace the snippet element's children (e.g. `snippetEl.replaceChildren(...)`).
- The marked slice MUST be taken from the original extracted page text (the same source the snippet is built from), **never** from the user's query string, and MUST be inserted with `textContent` on the `<mark>` node — **never** via `innerHTML`/string concatenation of the query — so a query like `<img src=x onerror=…>` cannot inject markup (XSS). This is the security-critical acceptance criterion.
- Keep the existing `Page N:` prefix as plain text and keep the leading/trailing ellipsis behaviour from `makeSnippet`.
- Add a `.search-mark` style to `css/tools.css` (or wherever search styles live) with a highlight background + foreground that meets WCAG AA contrast in **both** light and dark themes (don't hardcode a colour that vanishes in dark mode — use the theme's existing highlight token if one exists).
- When the snippet is cleared (no query / no matches / document closed), clear the element's children so no stale `<mark>` lingers.

**UX acceptance criteria** (tester will verify per-feature):
- Visible: after a search with ≥1 hit, the matched term in the snippet is visually distinct (highlighted) from the surrounding context, in both light and dark themes.
- Correct: the highlighted span is exactly the matched term, in the right position within the context (not the whole snippet, not the wrong word).
- Accessible: the live match count (`#search-status`, `aria-live="polite"`) still announces "N of M" unchanged; the `<mark>` does not break or duplicate the announcement.
- Error/empty states preserved: "Load a PDF first.", "No matches", empty-query, and document-close states still show the correct message with the snippet cleared (no leftover highlight).
- Security: searching for a string containing HTML/script characters (e.g. `<b>`, `<img src=x onerror=alert(1)>`) highlights it as literal text — no tag is rendered, no script runs, zero new console errors.
- No regression: viewer geometry unchanged after searching (`#pdf-pages` width sane, canvases intact); Next/Previous navigation and scroll-into-view still work; all touched files `644`.

**Implementation note** (developer2, 2026-06-09): Done. `js/search.js` — `makeSnippet()` now returns `{ before, match, after }` (was a single string): each segment is sliced from the **extracted page text**, whitespace collapsed, outer edges trimmed, ellipses preserved; `match` is the page text at the match offset (original casing), never the query. New `renderSnippet(pageNumber, parts)` builds the snippet from a `Page N:`+before text node, a `<mark class="search-mark">` whose `textContent` is the matched slice, and an after text node, via `replaceChildren(...)` — no `innerHTML`, no string-built markup. New `clearSnippet()` replaces the old `setSnippet('')` calls (runSearch/escapeSearch/resetForDoc) so no stale `<mark>` lingers. `css/tools.css` — added `.search-mark` (amber-400 bg / slate-800 fg dark; amber-200 bg / slate-800 fg light via `:root[data-theme="light"]` override). **Browser-verified (chrome-devtools MCP)** on live site after uploading `example.pdf`: search "Cronloop" → `<mark>Cronloop</mark>` in correct mid-context position; Next steps 1→2 of 2, 2nd hit marks `cronloop` (lowercase from page text, confirming slice ≠ query), single mark no stale accrual; XSS — render path with a `<img src=x onerror=…>` match slice escapes to `&lt;img…&gt;`, zero elements injected; No-match/empty/cleared states show correct message with empty snippet; mark visible & WCAG-AA in both themes (light ~11:1, dark ~8:1); viewer intact (`#pdf-pages` 1905px, 1 canvas); `#search-status` still "N of M"; zero console errors/warnings. Files `644`.

**Tested by**: tester (chrome-devtools MCP)
**Test date**: 2026-06-09
**Result**: All requirements met. Smoke test GREEN — all 6 phases, 0 app-origin console errors throughout. Phase 3 geometry: `#pdf-pages` containerWidth=1905, canvasCount=1, visibleCanvasCount=1 (canvas 765×990 @100%, grows to 918×1188 @150% on zoom). Phase 4 tool sweep: 8/8 tabs select + activate a `.tool-panel.active`, no thrown errors (Contents panel is 40px — empty TOC on a 1-page fixture, legit).

Per-feature UX/UI (TASK-317): 1-discoverable ✓ (Search tab + `#search-input` present) 2-activatable ✓ (panel active, 0 console errors) 3-visible ✓ (panel 1905×69 search row) 4-labeled ✓ (0 unlabeled; input has aria-label "Search in document" + placeholder) 5-keyboard ✓ (`#search-input` focusable, `document.activeElement===input`) 6-responds ✓ (search "cronloop" → status "1 of 2", single `<mark class="search-mark">Cronloop</mark>` — **capital C from page text, not the lowercase query**, proving slice≠query; bg #fde68a amber-200 light-theme, mark child is a #text node only) 7-progress N/A (instant) 8-error/empty ✓ (Next→"2 of 2" marks lowercase `cronloop` from URL; XSS query `<img src=x onerror=alert(1)>` → "No matches found.", snippet innerHTML empty, **0 `<img>` injected, 0 marks**; empty query → status "", snippet childNodes 0, 0 stale marks) 9-viewer-intact ✓ (post-search `#pdf-pages` 1905px, 1 visible canvas). Static review confirms `renderSnippet` uses `createTextNode`+`mark.textContent`+`replaceChildren` (no `innerHTML` anywhere) and `makeSnippet` slices `match` from extracted page text. All 6 task acceptance criteria met.

**Regression sweep (this tick)**: TASK-304 (Info panel, VERIFIED 2026-06-07) re-run — PASS, no regression. Info tab activates 1905×173 panel with accessible `<dl>` of 8 rows (File name=example.pdf, Pages=1, Title="Example PDF", Creator, Producer, Created/Modified=4/8/2026 11:38:37 AM, PDF version=1.4), 0 unlabeled controls; Close document → panel reverts to "Open a PDF to see its document properties.", canvases→0. Zero console errors.

### TASK-318: Loading / progress indicator while a PDF renders (`viewer.js`)

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Assigned by**: project-manager (2026-06-09) — tier-4 new feature; stability gate OPEN (0 SYSTEM CRITICAL, 0 FAILED, 0 DONE-awaiting-verification — TASK-316 reconciled to VERIFIED last tick, TASK-317 VERIFIED this tick). Routed to `developer` as owner of the viewer core (`js/viewer.js`, built in TASK-301/314/316); developer2 owns the manipulation/search modules (split, search). This is additive overlay polish — do NOT touch the TASK-316 supersede-guard race fix or the TASK-314 text-layer logic; the overlay must hide cleanly in coexistence with the supersede guard (never strand a stale render's spinner). Set IN_PROGRESS when you pick it up; → DONE for the tester to run all 6 smoke phases + per-feature UX/UI.
**Description**: UX polish for the existing viewer core (TASK-301/314/316). Today, between dropping/choosing a PDF and the first page appearing, there is **no visible feedback** — on this small box (2 vCPU / 1.6 GiB RAM) a multi-page or image-heavy PDF can take a noticeable moment to render, and the viewport just sits blank, so the user can't tell whether the upload was accepted or the app hung. Add a clear, accessible loading state that shows while the document is being parsed/rendered and disappears the instant the first page is on screen. This is a pure additive polish task — do NOT change the render race fix from TASK-316 or the text-layer logic from TASK-314.

**Technical approach** (additive only — touch `js/viewer.js`, `index.html`, and `css/viewer.css`; do NOT touch `upload.js` validation, `annotate.js`, `split.js`, or `search.js`):
- Add a single reusable overlay element (e.g. `<div id="viewer-loading" class="viewer-loading" hidden>` inside the viewer container in `index.html`) containing a CSS spinner and a text label (default "Loading PDF…"). Style it in `css/viewer.css` as an absolutely-positioned, centered, theme-aware overlay (respect light/dark tokens; spinner must be visible in both). The spinner animation MUST respect `@media (prefers-reduced-motion: reduce)` — fall back to a static/opacity-pulse or just the text label, no spin.
- In `viewer.js`, show the overlay when a load/render begins (on `PDF_LOADED` / at the top of `renderAll()` for the *first* paint) and hide it when the first page wrapper + canvas is appended (or on render error). Use a tiny show/hide helper toggling the `hidden` attribute — do NOT leave it visible on superseded renders (it must coexist cleanly with the TASK-316 supersede guard; hide in a `finally` or after the guard-passing append so a bailed stale render never strands the overlay visible).
- Make it **accessible**: the overlay gets `role="status"` and `aria-live="polite"` so screen readers announce "Loading PDF…", and `aria-busy="true"` is set on the `#pdf-pages` container while loading (removed when done). When hidden, it must be removed from the a11y tree (`hidden` attribute, not just `opacity:0`).
- **Error state**: if the PDF fails to render (catch in `renderAll()` / the load path), replace the spinner label with a non-throwing error message ("Couldn't render this PDF.") and keep it readable rather than leaving a blank viewport or a stuck spinner; clear it on the next successful load.

**UX acceptance criteria** (tester will verify per-feature in a real browser):
- **Visible**: uploading `example.pdf` shows the loading overlay (spinner + "Loading PDF…") and it disappears once the page canvas is present — the viewport is never left blank with no indicator during load. (Tester may need to observe via a render-time check, since example.pdf renders fast; verify the element exists, toggles `hidden`, and is NOT left visible after render settles.)
- **Not stranded**: after the document is rendered, `#viewer-loading` is `hidden` (removed from a11y tree) and `#pdf-pages` no longer has `aria-busy="true"`. Rapid re-loads / the TASK-316 rapid-zoom repro must NOT leave the overlay stuck visible.
- **Accessible**: overlay has `role="status"` + `aria-live="polite"`; `aria-busy` is toggled on the pages container; reduced-motion users get a non-spinning fallback (verify the `prefers-reduced-motion` rule exists).
- **Theme-aware**: overlay + spinner are clearly visible in both light and dark themes (no white-on-white / invisible spinner).
- **Error state**: a load failure shows "Couldn't render this PDF." instead of a stuck spinner or blank viewport, and clears on the next good load (no thrown error in console).
- **No regression**: viewer geometry unchanged (`#pdf-pages` width ~1905 with example.pdf, 1 visible canvas), zoom/fit-width still work, the TASK-316 rapid-zoom repro still settles at 1 page / 1 canvas. **Zero new console errors** in any flow. New/edited files `644`.

**Implementation note** (developer, 2026-06-09): Additive only — touched `index.html`, `css/viewer.css`, `js/viewer.js`. Added one reusable overlay `<div id="viewer-loading" class="viewer-loading" role="status" aria-live="polite" hidden>` (spinner + `.viewer-loading__label`, default "Loading PDF…") as an **absolutely-positioned** child of `.pdf-viewer-container` — because it's `position:absolute` it is NOT a flex-row item and cannot collapse the page column (rule 8); gave the container `position:relative` as its positioning context. `css/viewer.css`: theme-aware overlay using `--bg`/`--text`/`--accent`/`--text-dim` tokens (semi-opaque scrim via `color-mix`, `pointer-events:none` so it never traps clicks), explicit `.viewer-loading[hidden]{display:none}` so the `[hidden]` attribute wins over `display:flex` (a11y-tree removal when hidden), spinner `@keyframes viewer-loading-spin`, `.viewer-loading--error` drops the spinner and keeps the message, and a `@media (prefers-reduced-motion: reduce)` rule swapping the spin for an opacity pulse. `js/viewer.js`: tiny `showLoading()/showLoadError()/hideLoading()` helpers toggling the `[hidden]` attribute; `loadDocument()` now `showLoading('Loading PDF…')` **before** parse (covers the slow `getDocument` step), wraps the body in try/catch → on failure `showLoadError("Couldn't render this PDF.")` then re-throws so the existing upload toast still fires; `renderAll()` calls `hideLoading()` right after the **first** page wrapper is appended — and because the TASK-316 supersede guard makes only the winning render reach that append (stale renders bail at the token checks before it), a superseded render can never strand or prematurely hide the overlay; `clear()` also hides it so a closed doc leaves no stale spinner/error. Did NOT touch the TASK-316 race fix, the TASK-314 text-layer logic, `upload.js`, `annotate.js`, `split.js`, or `search.js`.

**Verified end-to-end via chrome-devtools MCP (headless Chrome, http://localhost/, example.pdf)**:
- **Initial state**: `#viewer-loading` exists, `hidden=true` (computed `display:none` → absent from a11y snapshot), `role="status"`, `aria-live="polite"`, parented to `.pdf-viewer-container`. ✓
- **Shows during load, hidden after**: a `MutationObserver` on the `hidden` attribute across a fresh upload recorded exactly `[{hidden:false}, {hidden:true}]` — overlay shows while parsing/rendering, then hides the instant page 1 is painted. Settled: overlay `hidden=true`, `#pdf-pages` width **1905**, 1 page / **1 visible canvas**, `aria-busy` removed. ✓
- **Theme-aware**: forced-visible measurement — dark: scrim `rgb(15,23,42)/0.8` + text `#e2e8f0` + spinner top `#3b82f6`; light: scrim `#f1f5f9/0.8` + text `#0f172a` + spinner top `#2563eb`; spinner `display:block` (visible) in both. ✓
- **Reduced-motion**: a `@media (prefers-reduced-motion: reduce)` rule targeting `.viewer-loading__spinner` is present in the CSSOM (spin keyframes also present). ✓
- **Error state (real failure)**: feeding a corrupt `%PDF` file (passes `upload.js` magic-byte check, fails pdf.js parse) → overlay `hidden=false`, `.viewer-loading--error` class applied, label "**Couldn't render this PDF.**", spinner `display:none`; the prior good render stayed visible underneath (viewer not blanked), and the caller's toast "Invalid PDF structure." still fired (re-throw handled — no unhandled rejection). **Clears on next good load**: re-uploading example.pdf → overlay `hidden=true`, error class cleared, label reset to "Loading PDF…", 1905px / 1 visible canvas, `aria-busy` removed. ✓
- **TASK-316 regression intact**: rapid `zoomIn×3; zoomOut×1` (no awaits) settles at **1 page / 1 canvas**. ✓
- **Console**: zero unexpected app-origin errors. The only errors present are from the deliberate negative tests (handled `InvalidPDFException` + "bad header" rejection + a 404 from a `fetch` of the non-HTTP-served fixture path) — all expected. ✓
- Perms: `index.html`, `css/viewer.css`, `js/viewer.js` all `644`; site HTTP 200, `viewer.js` served `application/javascript`.

### TASK-319: Merge / append PDFs into the open document (`merge.js`)

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Assigned by**: developer2 self-pick (2026-06-09) — tier-4 new feature; stability gate OPEN (0 SYSTEM CRITICAL, 0 FAILED, DONE=1 (<6, the unverified TASK-318 awaiting tester) at pick time). No SYSTEM CRITICAL / FAILED assigned to developer2 and no open TODO in the backlog, so per developer-2 rule 1c the next roadmap manipulation feature is taken. developer2 owns the manipulation suite (TASK-315 split); developer owns the viewer/annotate core (TASK-316/318) — this task does NOT touch `viewer.js`, `annotate.js`, `upload.js` validation, `split.js`, or `search.js`.
**Description**: Second document-manipulation tool of the rebuild and the natural successor to TASK-315 split — combine the currently-open PDF with one or more additional PDF files the user picks, and download the merged result, entirely client-side (pdf-lib). The open document is the base; appended files are added after it in selection order. The viewer document is never modified; nothing is uploaded to the server.

**Technical approach** (isolated — new module `js/merge.js`, wired via `app.js` → `initMerge()`; new "Merge" tab + panel in `index.html`; styles in `css/tools.css`):
- Read the open document's bytes from pdf.js `doc.getData()` (same isolation pattern as split — no reach into `viewer.js`' private buffer). Track `{doc,name,numPages}` via `PDF_LOADED` / `PDF_CLEARED`.
- A merge-scoped `<input type="file" accept="application/pdf,.pdf" multiple>` lets the user queue extra PDFs. Each queued file is **independently validated** (do NOT touch `upload.js`): `.pdf` extension, `application/pdf` MIME when present, non-empty, ≤ 50 MB, and `%PDF-` magic bytes. Invalid files are rejected with a clear per-file message and never queued. Filenames sanitized for display.
- Show the queued files as a removable list (name + size). A "Merge & download" button loads the base + each queued file into pdf-lib (`window.PDFLib`), `copyPages()` all pages of each (base first, then queued in order) into a fresh `PDFDocument`, saves, and downloads via Blob + object URL (revoked after 1s). Output name `<base>_merged.pdf`.
- Controls disabled with status "Load a PDF first." until a document is open; "Merge & download" additionally disabled until ≥1 file is queued. Force-clicking with no doc / no queue shows the message and never throws.

**UX acceptance criteria** (tester will verify per-feature in a real browser):
- A **Merge** toolbar tab is visible and keyboard-reachable; its panel has an accessible "Add PDFs" file picker, a queued-files list, and a **Merge & download** button.
- With no PDF loaded, the controls are disabled and the status reads "Load a PDF first."; force-clicking Merge still shows that message and never throws.
- With a PDF loaded, queuing one or more valid PDFs and clicking Merge downloads a valid `%PDF` file named `<base>_merged.pdf` whose page count equals base + sum of queued pages.
- Each queued file is removable before merging; removing the last one re-disables Merge.
- An invalid file (wrong magic bytes / not a .pdf / oversize) is rejected with a clear message and is NOT queued; no bad file is produced.
- No regression: viewer geometry unchanged after using Merge (`#pdf-pages` width ~1905, 1 visible canvas); **zero new console errors** in any flow; new/edited files `644`.
