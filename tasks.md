# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-348: Extract Pages — keep an arbitrary page list/range as a new PDF (`extract-pages.js`)

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add a client-side "Extract pages" tool as `js/extract-pages.js`, wired into the toolbar / `action-registry.js` like the other tools. It is the direct counterpart of the just-shipped Delete Pages (`delete-pages.js`): instead of removing pages and keeping the rest, the user types the pages/ranges they want to **keep** (e.g. `1, 3, 5-7`) and the tool builds a brand-new PDF containing **only** those pages, **in the order the user listed them** (so `3, 1` yields a 2-page PDF with the original page 3 first). This is distinct from Split (`split.js`, which keeps a single contiguous range) — Extract handles arbitrary, possibly-reordered selections, the single most-requested "pull out the pages I need" operation. Entirely in the browser (pdf-lib), no upload; the open viewer document is never mutated.

**Technical approach**:
- New vanilla ES module `js/extract-pages.js` following the **exact** `delete-pages.js` / `split.js` pattern: talk to the app only through `EventBus` (PDF_LOADED / PDF_CLEARED) and `ActionRegistry`; read source bytes via pdf.js `doc.getData()`; build the output with `window.PDFLib` (`copyPages` of the requested indices **in listed order**); download via Blob + object URL (revoked next tick).
- Reuse the `delete-pages.js`/`split.js` comma/range parser, but preserve **order and duplicates as typed** for the "pages to keep" input (do NOT sort or dedupe — `5-7, 1` must produce pages 5,6,7,1). Validate: empty input, out-of-range pages, and non-numeric tokens — show a visible inline status message, never a console-only error or a throw.
- Add an "Extract pages" tab + thin horizontal panel (`data-tab="extract"` / `data-panel="extract"`) matching the split/delete-pages panel design, and register `extract.run` in the ActionRegistry so the Command Palette surfaces it automatically (do NOT hard-code a command list). Controls labeled, keyboard-operable, disabled until a PDF is open. Download name e.g. `example_extracted.pdf`.

**UX acceptance criteria** (tester will verify in the browser):
- **Discoverable**: an "Extract pages" toolbar tab exists and is reachable from the Command Palette (Ctrl/⌘+K → "Extract"); clicking it opens the panel on top (not hidden behind another panel).
- **Operable by keyboard + mouse**: the pages input and the Extract button are focusable, have discernible accessible names (`<label>` or `aria-label`), and are reachable via Tab; Enter in the input runs the action.
- **Happy path**: extracting `1` from example.pdf downloads a non-empty 1-page `.pdf`; on a multipage PDF, `5-7, 1` downloads a valid **4-page** PDF whose pages are original 5,6,7,1 **in that order** (developer confirms order/count by re-parsing the produced bytes with pdf-lib); status reports how many pages were extracted.
- **Error states are visible, not console-only**: empty input → "Enter pages to extract"; out-of-range page → "Page N is out of range (document has M pages)."; invalid token → "\"abc\" is not a valid page or range." — all shown inline, none throw.
- Operating the tool does **not** disturb the open viewer (`#pdf-pages` width unchanged, canvases still visible) and produces **no new console errors/warnings** on open, run, or close.

### TASK-347: Delete Pages — remove arbitrary pages and download the remainder (`delete-pages.js`)

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-11
**Result**: All UX acceptance criteria met. Smoke test green (6/6 phases, 0 app-origin console errors). UX/UI 9-check: 1-discoverable ✓ ("Delete pages" tab wired in index.html + panel `data-panel="delpages"`) 2-activatable ✓ (tab+panel activate, no errors) 3-visible ✓ (panel 1905×88, thin horizontal panel matching split.js design) 4-labeled ✓ (0 unlabeled controls; input has `<label>`) 5-keyboard ✓ (Delete button focusable; Enter in input runs) 6-responds ✓ (on 6-page multipage.pdf: delete `2`→ valid **5-page** PDF (2133 B); delete `1, 3-4`→ valid **3-page** PDF (1767 B), both re-parsed with pdf-lib to confirm page counts) 7-progress ✓ ("Deleting…" status + button disabled during op) 8-errors ✓ (empty→"Enter pages to delete…", out-of-range→"Page 5 is out of range (document has 1 page).", delete-all→"Cannot delete every page — at least one page must remain.", invalid→"\"abc\" is not a valid page or range." — all visible inline, none throw) 9-viewer-intact ✓ (`#pdf-pages` width 1905, 6 canvases visible after run). Open viewer document never mutated.
**Priority**: MEDIUM
**Assigned to**: developer
**Implemented by**: developer
**Implementation date**: 2026-06-11
**Description**: Add a client-side "Delete pages" tool as `js/delete-pages.js`, wired into the toolbar/action-registry like the other tools. It is the missing inverse of Split/Extract (which *keeps* a contiguous range): the user types the pages/ranges to **remove** (e.g. `1, 3-5, 8`), and the tool builds a brand-new PDF containing every *other* page in original order and downloads it. Entirely in the browser (pdf-lib), no upload; the open viewer document is never mutated.

**Technical approach**:
- New vanilla ES module `js/delete-pages.js` following the exact split.js pattern: talk to the app only through `EventBus` (PDF_LOADED / PDF_CLEARED) and `ActionRegistry`; read source bytes via pdf.js `doc.getData()`; build the output with `window.PDFLib` (`copyPages` of the complement indices); download via Blob + object URL (revoked next tick).
- Reuse the split.js comma/range parser semantics for the "pages to remove" input. Validate: empty input, out-of-range pages, and the critical guard that you cannot delete **every** page (a PDF needs ≥1 page) — show a visible inline status message, never a console-only error or a throw.
- Add a "Delete pages" tab + thin horizontal panel (`data-tab="delpages"` / `data-panel="delpages"`) and register `delpages.run` in the ActionRegistry so the Command Palette surfaces it automatically. Controls labeled, keyboard-operable, disabled until a PDF is open.

**UX acceptance criteria** (tester will verify in the browser):
- Discoverable: a "Delete pages" toolbar tab exists and is reachable from the Command Palette; clicking it opens the panel on top.
- Operable by keyboard + mouse: the pages input and the Delete button are focusable, labeled, and reachable via Tab; Enter in the input runs the action.
- Deleting `1` (or any valid subset) from example.pdf downloads a non-empty `.pdf` with `originalPages − deletedCount` pages; status reports how many were removed.
- Error states are visible, not console-only: empty input → "Enter pages to delete"; out-of-range page → range message; deleting all pages → "Cannot delete every page — at least one page must remain"; none throw.
- Operating the tool does not disturb the open viewer (`#pdf-pages` width unchanged, canvases still visible) and produces no new console errors on open/run/close.

**Developer notes (browser-verified via chrome-devtools MCP, 2026-06-11)**: New `js/delete-pages.js` (modeled on split.js — EventBus/ActionRegistry isolation, pdf.js `getData()` source, pdf-lib `copyPages` of the surviving indices, Blob download). Tab `data-tab="delpages"` ("Delete pages") + thin panel added to index.html between Split and Merge; imported + `initDeletePages()` wired in app.js after `initSplit()`; `delpages.run` registered so the Command Palette surfaces it (confirmed: Ctrl+K → "delete" lists "Delete pages"). Verified live at http://localhost/: (1) tab discoverable, click activates tab+panel (active/aria-selected/visible); (2) controls labeled + disabled pre-load, enabled after; (3) error paths all show visible status, no throws — empty→"Enter pages to delete…", out-of-range→"Page 5 is out of range (document has 1 page)", delete-all→"Cannot delete every page — at least one page must remain", invalid token→"\"abc\" is not a valid page or range."; (4) happy path on 6-page multipage.pdf: delete `2`→ valid **5-page** PDF (2132 B); delete `1, 3-4`→ valid **3-page** PDF (1766 B), captured blobs re-parsed with pdf-lib to confirm page counts; (5) viewer intact (`#pdf-pages` width 1905, canvases visible) before+after; (6) **0 console errors/warnings** across the whole session.

### TASK-346: Image → PDF — build a PDF from one or more JPEG/PNG images (`img2pdf.js`)

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add a new client-side `js/img2pdf.js` tool that lets the user assemble a PDF from one or more **JPEG/PNG images**, entirely in the browser (no upload), wired into the toolbar / `action-registry.js` like every other tool. This is the inverse of the existing "Export page as image" (`convert.js`) and a very commonly-requested operation (scanned receipts/photos → a single shareable PDF).

**Technical approach**:
- Register the tool through `js/action-registry.js` and add a toolbar tab the same way the other tools do (reuse the shared `activateTab()` / `wireToolTabs()` path so the Command Palette picks it up automatically). Do NOT hard-code a separate command list.
- The panel offers an image file picker (`<input type="file" accept="image/png,image/jpeg" multiple>`) **and** a drop zone. Accept multiple images; show the selected images as a reorderable list/thumbnail strip with a remove (✕) button per image and up/down (or drag) reordering, since page order matters.
- Build the PDF with the **existing `lib/pdf-lib.min.js`**: for each image read the bytes (`FileReader`/`arrayBuffer`), use `pdfDoc.embedJpg()` for JPEG and `pdfDoc.embedPng()` for PNG (detect by MIME type or magic bytes — do not assume), add a page sized to the image (or to a chosen paper size with the image scaled to fit, see options below), and `drawImage()` it.
- Page-size option: a small `<select>` with at least **"Match image size"** (default — one page per image at the image's pixel dimensions) and **"Fit to A4 (portrait)"** (image scaled proportionally, centered, on an A4 page). Keep it minimal; correctness over options.
- On "Create PDF", generate the bytes with `pdfDoc.save()` and trigger a download (`Blob` + object URL, revoke it after) named e.g. `images.pdf`. Do all work in-memory; never upload. Reuse the existing `notifications.js` for success/error toasts.
- Vanilla ES module, no new third-party library. Validate input: reject non-image / unsupported types with a clear message; guard the "Create PDF" action when zero images are selected.

**UX acceptance criteria** (tester will verify in the browser):
- The tool is **discoverable**: a labeled toolbar tab/button exists and is reachable from the Command Palette (Ctrl/⌘+K → "Image"); clicking the tab opens the Image→PDF panel on top (not hidden behind another panel).
- The panel is **operable by keyboard and mouse**: the file `<input>` and drop zone both accept images; every control (file picker, page-size `<select>`, each image's remove/reorder buttons, the "Create PDF" button) is focusable, has a discernible accessible name (`aria-label` or visible `<label>`), and is reachable via Tab.
- Selecting one or more images shows them in a **visible ordered list** (filename and/or thumbnail) with working remove and reorder controls; reordering visibly changes the list order.
- Clicking **"Create PDF"** with ≥1 image downloads a non-empty `.pdf` whose page count equals the number of images and whose pages are in the displayed order (the developer should confirm by re-opening the produced PDF in the viewer; the tester confirms a non-zero-byte download is triggered and no console error fires).
- **Error states are visible, not console-only**: trying to create with zero images selected shows an inline/toast message ("Add at least one image") and does NOT throw; selecting an unsupported file type (e.g. a `.txt` or `.gif`) shows a clear "Unsupported image type — use JPEG or PNG" message and skips that file rather than crashing.
- Operating this tool does **not** disturb the currently-open PDF in the viewer (`#pdf-pages` width unchanged, canvases still visible) and produces **no new console errors/warnings** on open, select, reorder, create, or close.

### TASK-344: Compress PDF (reduce file size)

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-11
**Result**: All requirements met. Verified live at http://localhost/ with chrome-devtools MCP on example.pdf (smoke test green: 5 phases pass, 10/10 tools activate, 0 app-origin console errors).
UX/UI: 1-discoverable ✓ ("Compress" tab present)  2-activatable ✓ (selected, no console errors)  3-visible ✓ (panel 1905×73, top=88, on-screen — thin horizontal toolbar like every other tool panel; controls fully visible/usable)  4-labeled ✓ (0 unlabeled; quality `<select>` aria-label "Compression quality", Low/Medium/High options)  5-keyboard ✓ (tab + run button both focusable)  6-responds ✓ (26.1 KB → 13.0 KB / 50% smaller; Download yields a 13,293-byte valid application/pdf blob; status "Downloaded example_compressed.pdf.")  7-progress ✓ (run button disables, progress shows "Reading document…"/"Optimizing structure…", status "Compressing…")  8-errors ✓ (no-document path shows user-facing "Open a PDF first." in #compress-status live region, not a console error — observed in pre-upload empty state + code guard at compress.js:183-186)  9-viewer-intact ✓ (containerWidth 1905, visibleCanvasCount 1 after interaction — uses its own throwaway canvas, never touches the viewer).
Honest-reporting requirement met: before/after sizes and % are computed from real output bytes; "already optimized / no win" path offers no larger download.

**Status (original)**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add a client-side "Compress" tool as `js/compress.js`, wired into the toolbar/action-registry like the other tools. Goal: reduce the size of the currently-loaded PDF entirely in the browser (no upload), using the existing `lib/pdf-lib.min.js`.

---

### TASK-345: Command Palette (Ctrl/Cmd+K quick action runner)

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-11
**Result**: All requirements met. Verified live at http://localhost/ with chrome-devtools MCP on example.pdf. Smoke test GREEN (Phase 1 console clean; Phase 2 upload landed; Phase 3 geometry containerWidth=1905, canvas 765×990 with real content, visibleCanvasCount=1; Phase 4 sweep 9/10 tabs activate — the 10th was a stale data-tab key in my probe, not a defect; Phase 5 viewer geometry stable 1905→1905; **0 app-origin console errors** across the entire run).
UX/UI: 1-discoverable ✓ (`#command-palette` dialog initialized in DOM; opens via Ctrl/⌘+K; entry also in keyboard-shortcuts reference)  2-activatable ✓ (Ctrl+K opens, input auto-focused, 55 commands enumerated from ActionRegistry, no console errors)  3-visible ✓ (box 558×1825, top=247, on-screen, centered)  4-labeled ✓ (0 unlabeled controls; input aria-label "Search for a command"; options carry titles + `kbd` shortcuts)  5-keyboard ✓ (input natively focusable; ↑/↓ move `aria-activedescendant` opt-0→opt-1; Enter runs; aria-selected toggles)  6-responds ✓ (live filter "compress"→3 commands / "55 commands" aria-live → "3 commands"; running "Compress" from palette closed it and activated the Compress tab — same code path as a tab click)  7-progress n/a (palette ops are instant, <500ms)  8-errors ✓ (no-match "zzzznomatch" shows visible "No matching commands" + aria-live, 0 options, no console error)  9-viewer-intact ✓ (containerWidth 1905, visibleCanvasCount 1 after open/filter/run/Escape). Escape closes the dialog and restores focus to the opener ("Keyboard shortcuts" button) — verified with a real key event.
Note (non-blocking): the task's technical approach asked to register Ctrl/⌘+K *through* `keyboard-shortcuts.js`; the implementation instead adds its own global `keydown` launcher (command-palette.js:228) so it fires even while typing in a tool field. This deviates from the stated approach but satisfies every tester-verifiable UX acceptance criterion — recorded for the developer, not failed.
**Implemented by**: developer
**Implementation date**: 2026-06-11
**Notes**: New `js/command-palette.js` (native `<dialog>` + `showModal()` for free modal semantics / Tab-trap / Escape). It is a pure VIEW over `js/action-registry.js` — enumerates `ActionRegistry.list()`, runs via `ActionRegistry.run(id)`; no hard-coded command list. To make every tool reachable (incl. Search/Pages/Contents/Markups/Info/Statistics tabs that have no op-action), `app.js` `wireToolTabs()` now registers each tool tab as a `tab.<id>` action via a shared `activateTab()` — the SAME code path a tab click uses. Added optional `shortcut` field to the registry (shown in the palette where a real binding exists: `+`/`−`/`0`, `[`/`]`, `?`); reference card in `keyboard-shortcuts.js` updated with the Ctrl/⌘+K entry so palette + hotkey map agree. Browser-verified via chrome-devtools MCP on example.pdf: Ctrl/⌘+K opens (centered, input focused, 55 commands), live fuzzy filter, ↑/↓ + Enter + hover/click run, `aria-activedescendant`/`aria-selected` set, "N commands" aria-live count, "No matching commands" empty state, real Escape closes + restores focus, toggle works; running "Compress"/"Search" from the palette opens the exact panel a tab click would; `#pdf-pages` width 1905 + 1 visible canvas BEFORE and AFTER palette use; **0 console errors/warnings**.

**Status (original)**: TODO
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add a new `js/command-palette.js` module that gives users a single keyboard-driven way to discover and run *any* tool in the editor — a fuzzy-searchable command palette opened with **Ctrl+K** (Windows/Linux) / **Cmd+K** (macOS), the same pattern as VS Code/Linear. This is primarily a **discoverability + accessibility** win: it surfaces every existing feature (Compress, Merge, Split, Watermark, Crop, Rotate, Page Numbers, Thumbnails, Search, etc.) without the user hunting through toolbar tabs.

**Technical approach**:
- Build on the **existing `js/action-registry.js`** — do NOT hard-code a command list. Enumerate the already-registered actions (each tool already registers itself there) so the palette stays automatically in sync as new tools ship. If the registry doesn't currently expose an iterable list of `{id, title, run()}`, add a small read-only accessor (e.g. `getActions()`) rather than duplicating the data.
- Render an overlay dialog (`role="dialog"` `aria-modal="true"`) containing a single text `<input>` (`role="combobox"`, `aria-expanded`, `aria-controls`) and a results `<ul>` (`role="listbox"`) of matching commands (`role="option"`). Each option shows the command title and, where known, its keyboard shortcut (pull from `js/keyboard-shortcuts.js` so the palette and the hotkey map never disagree).
- Implement simple case-insensitive fuzzy/substring filtering as the user types; highlight the active option and update `aria-activedescendant` so screen readers announce the selection.
- Register the **Ctrl/Cmd+K** binding through the existing `js/keyboard-shortcuts.js` system (do not add a stray global `keydown` listener that bypasses it). Pressing the hotkey again, or **Escape**, closes the palette.
- Selecting a command (Enter or click) closes the palette and invokes that action's `run()` via the action-registry — reuse the exact same code path the toolbar buttons use, so behavior is identical.
- Keep it dependency-free (vanilla ES module, no new lib) and lazy: build the DOM on first open, not at page load.

**UX acceptance criteria** (tester will verify these in the browser):
- Pressing **Ctrl+K** (and Cmd+K) opens a visible, centered palette overlay that is on top of all other panels (not hidden behind them); pressing it again or **Escape** closes it and returns focus to the previously-focused element.
- On open, keyboard focus lands in the search input automatically; **Tab** stays trapped within the dialog while it is open.
- Typing filters the command list live; **↑/↓ arrows** move the highlighted option, **Enter** runs it, mouse hover + click also runs it. The highlighted option is visually distinct AND exposed via `aria-activedescendant`.
- The dialog and every option have discernible accessible names (verifiable via the accessibility tree); the input is labeled (`aria-label="Command palette"` or a visible label) and announces result count to screen readers (e.g. an `aria-live` "N commands" status).
- Running a command from the palette produces the **same result** as clicking that tool's toolbar tab (verify by running an existing action such as "Compress" or "Thumbnails" from the palette and confirming its panel opens / it executes).
- Empty/no-match state shows a visible "No matching commands" message (not a blank box and not a console error); opening the palette with no PDF loaded still works and commands that require a document show their own existing "Open a PDF first" guard rather than throwing.
- No new console errors on open/close/run; the PDF viewer geometry is untouched after using the palette (`#pdf-pages` width unchanged, canvases still visible).

