# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-314: Text highlight annotation (`annotate.js`)

**Status**: DONE
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

### TASK-315: Split / extract page range (`split.js`)

**Status**: DONE
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

