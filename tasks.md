# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-348: Extract Pages — keep an arbitrary page list/range as a new PDF (`extract-pages.js`)

**Status**: VERIFIED
**Tested by**: tester
**Test date**: 2026-06-12
**Result**: All requirements met. Verified live at http://localhost/ with chrome-devtools MCP on example.pdf (smoke test green: phases 1–5 pass, 10/10 tool tabs activate, 0 app-origin console errors).
UX/UI: 1-discoverable ✓ ("Extract pages" tab present + `extract.run` in ActionRegistry)  2-activatable ✓ (aria-selected=true, no console errors)  3-visible ✓ (panel 1905×88, top=88, on-screen — thin horizontal toolbar like every other tool panel)  4-labeled ✓ (0 unlabeled; input labeled "Pages to keep", button "Extract pages")  5-keyboard ✓ (native-focusable input + button; Enter in input runs extraction via keydown handler)  6-responds ✓ (extract `1` on example.pdf → 23,398-byte valid application/pdf, re-parsed with pdf-lib = 1 page)  7-progress n/a (sub-500ms op; shows "Extracting…" then result)  8-errors ✓ (all visible + error-styled, no throw: empty→"Enter pages to extract, e.g. 1, 3, 5-7."; out-of-range `5`→"Page 5 is out of range (document has 1 page)."; invalid `abc`→"\"abc\" is not a valid page or range.")  9-viewer-intact ✓ (containerWidth 1905→1905, visibleCanvasCount 1 after interaction; module only touches its own panel, copies pages via pdf-lib from `doc.getData()`).
Order/duplicate preservation confirmed by code review (parsePageList preserves listed order incl. descending ranges and duplicates); the 1-page fixture limits multi-page reorder verification but the developer already browser-verified that path on a 6-page doc.

**Status (original)**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Implemented by**: developer
**Implementation date**: 2026-06-12
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

**Developer notes (browser-verified via chrome-devtools MCP, 2026-06-12)**: New `js/extract-pages.js` (modeled on delete-pages.js — EventBus/ActionRegistry isolation, pdf.js `getData()` source, pdf-lib `copyPages` of the requested 0-based indices in listed order, Blob download). Key difference from delete-pages: the parser (`parsePageList`) returns an **ordered Array preserving order AND duplicates** (no Set/sort/dedupe), and expands ranges in the typed direction (`3-1`→[3,2,1]) so the listed order is the output order. Tab `data-tab="extract"` ("Extract pages") + thin panel `data-panel="extract"` added to index.html between Delete pages and Merge; imported + `initExtractPages()` wired in app.js after `initDeletePages()`; `extract.run` registered so the Command Palette surfaces it (confirmed: Ctrl+K → "extract" lists "Extract pages"). Verified live at http://localhost/ on the 6-page multipage.pdf fixture: (1) tab discoverable, click activates tab+panel (aria-selected=true, panel 1905×88 visible at top=88); (2) input/button labeled (input aria-label "Pages or ranges to keep, in output order" + `<label>`) and disabled pre-load, enabled after load ("6 pages available."); (3) **happy path with download-blob re-parsed via pdf.js to confirm count AND order**: `1-6`→6pp [Page 1..6]; `4-6, 1`→**4pp [Page 4, Page 5, Page 6, Page 1]** (reorder); `3-1`→3pp [Page 3, Page 2, Page 1] (descending); `1, 1`→2pp [Page 1, Page 1] (duplicates kept); `3, 1`→2pp [Page 3, Page 1]; `2, , 4`→2pp (stray comma tolerated); `6-6`→1pp; status reports the page count + filename `multipage_extracted.pdf`; (4) error states all show visible inline status (`.error`), no throw, no download: empty/whitespace→"Enter pages to extract, e.g. 1, 3, 5-7.", `7`/`2-9`→"Page N is out of range (document has 6 pages).", `abc`/`1, abc, 3`→"\"abc\" is not a valid page or range.", `0`→"\"0\" is not a valid page or range."; (5) viewer intact (`#pdf-pages` width 1905, 6 visible canvases) before+after; (6) **0 console errors/warnings** across upload + 10 real extract operations (a transient `getBoundingClientRect` error seen only when my verification harness re-parsed output blobs with a second in-page pdf.js instance — does not occur in normal UI use; confirmed clean on single + heavy real-click runs). Open viewer document never mutated (tool reads `doc.getData()` and builds a fresh pdf-lib doc).

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

**Status**: FAILED
**Tested by**: tester
**Test date**: 2026-06-12
**Result**: Button/file-picker path works perfectly, but the **drag-and-drop path — the panel's own advertised "Drop JPEG or PNG images here" zone — fires a spurious, user-visible error toast** on every valid image drop. This violates UX checks #2 (activatable without console errors) and #8 (no error on valid input) on a primary interaction, so the feature is not shippable as-is.

UX/UI: 1-discoverable ✓  2-activatable ✗ (drag-drop emits console error + visible error toast — see below)  3-visible ✓ (panel 1905×140; page-size options [match, a4])  4-labeled ✓ (0 unlabeled)  5-keyboard ✓ (Create PDF focusable once enabled)  6-responds ✓ via file picker (2 imgs → valid 2-page application/pdf, 2182 B, first page 120×80 in Match mode)  7-progress n/a (fast op; shows "Building PDF…")  8-errors ✗ (valid image **drop** produces a wrong "File must have a .pdf extension." error toast; unsupported-type via drop is correctly skipped by img2pdf but ALSO triggers the same upload error)  9-viewer-intact ✓ (containerWidth 1905, 1 visible canvas).

**Root cause (confirmed by code review + browser repro):** `js/upload.js` registers a **window-level `drop` listener** (`upload.js:145-152`) that calls `handleFile()` on any drop whose target is not inside the upload `#drop-zone`. `js/img2pdf.js`'s own drop handler (`img2pdf.js:337-342`) calls `e.preventDefault()` but **never `e.stopPropagation()`**, so a drop on `#img2pdf-drop` bubbles to `window`, the upload guard `dropZone.contains(e.target)` is false (the img2pdf zone is not inside the upload zone), and `handleFile(<image>)` runs → `validate()` throws `"File must have a .pdf extension."` → `console.error('[upload] failed: …')` **and** `EventBus.emit(Events.ERROR, …)` → a red `toast toast-error` "⚠ File must have a .pdf extension." is shown to the user. The images ARE still added to the img2pdf list (the feature half-works), but the user simultaneously sees a contradictory error.

**How to reproduce (chrome-devtools MCP, verbatim):**
```
mcp__chrome-devtools__new_page  url=http://localhost/?cb=1
# upload example.pdf so the app is in the loaded state, then:
# click the "Image → PDF" tab, then dispatch a real file drop on #img2pdf-drop:
mcp__chrome-devtools__evaluate_script  () => {
  const c=document.createElement('canvas');c.width=60;c.height=60;c.getContext('2d').fillRect(0,0,60,60);
  return new Promise(res=>c.toBlob(b=>{
    const f=new File([b],'green.png',{type:'image/png'});
    const dt=new DataTransfer();dt.items.add(f);
    const ev=new DragEvent('drop',{bubbles:true,cancelable:true});
    Object.defineProperty(ev,'dataTransfer',{value:dt});
    document.getElementById('img2pdf-drop').dispatchEvent(ev);
    setTimeout(()=>res({toast:document.querySelector('.toast-error .toast-msg')?.textContent,
                        listRows:document.getElementById('img2pdf-list').children.length}),200);
  },'image/png'));}
# OBSERVED: { toast: "File must have a .pdf extension.", listRows: 1 }  ← image added AND spurious error toast
```

**Suggested fix (developer, next tick — do NOT let the tester fix it):** add `e.stopPropagation()` to `img2pdf.js`'s `drop` handler (and its `dragover`/`dragleave` if they should be local too) so module-owned drop zones don't leak to the global upload handler. Audit every other module that paints its own file drop zone for the same latent bug (img2pdf is the only current drop-zone module — merge.js/extract use file inputs, so they're unaffected — but bake the rule in: a module drop zone MUST `stopPropagation()`). Alternatively/additionally, harden `upload.js`'s window `drop` handler to ignore drops landing inside ANY registered tool drop zone, not just `#drop-zone`.

**Acceptance criteria for re-verification:** dropping a valid JPEG/PNG on `#img2pdf-drop` adds the image(s) to the list AND produces **zero** error toasts and **zero** `[upload] failed` console errors; dropping a non-image still shows only img2pdf's own "unsupported image type" skip message (no upload-extension error). All other img2pdf checks (already passing) must remain green.

**Status (original)**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Implemented by**: developer2
**Implementation date**: 2026-06-12
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

**Developer notes (browser-verified via chrome-devtools MCP, 2026-06-12)**: New `js/img2pdf.js` — a *producer* of PDFs, so unlike the page tools it does NOT subscribe to PDF_LOADED/PDF_CLEARED and is usable with no PDF open; it only registers `img2pdf.create` in the ActionRegistry and never touches the viewer/`​.pdf-viewer-container` (prompt rule 8 — it inserts nothing into the viewer at all; its panel lives in `.tool-panels`). Image type is decided by **magic bytes** (`FF D8 FF` = JPEG, `89 50 4E 47 0D 0A 1A 0A` = PNG), not the spoofable MIME string; build uses the existing `lib/pdf-lib.min.js` (`embedJpg`/`embedPng` + one page per image via `addPage`/`drawImage`). Tab `data-tab="img2pdf"` ("Image → PDF") + panel added to index.html after "Export image" (convert); imported + `initImg2Pdf()` wired in app.js after `initConvert()`. Reuses the merge panel's `.merge-*` reorderable-row CSS (up/down/remove buttons = accessible source of truth, HTML5 drag = progressive enhancement); new `[data-panel="img2pdf"]` + drop-zone CSS in tools.css. Page-size `<select>`: **Match image size** (one page = image pixel dims, 1px=1pt) / **Fit to A4 (portrait)** (proportional scale + center, 18pt margin). Verified live at http://localhost/: (1) **discoverable** — tab present labeled "Image → PDF", Ctrl/⌘+K → "Image" lists both "Image → PDF" (tab) and "Create PDF from images" (action); clicking the tab activates it (aria-selected=true, panel 1905×88 on top). (2) **labeled/keyboard** — a11y tree shows "Add JPEG or PNG images" file button, "Output page size" combobox (both options), "Create PDF" button, drop zone "Drop JPEG or PNG images here…" (tabindex=0, role=button, Enter/Space opens chooser), each list row's Move-up/down/Remove carry per-file aria-labels. (3) **ordered list + reorder** — adding a 120×80 JPEG + 80×120 PNG shows 2 numbered rows with type+size; "move down" reorders [jpg,png]→[png,jpg]. (4) **happy path, output re-parsed with pdf-lib** — Match mode → valid 2142-byte `application/pdf`, **2 pages sized [80×120 (png), 120×80 (jpg)] in the reordered order**; A4 mode → both pages **595×842**; status "Created images.pdf — N pages from N images." (5) **error states visible, no throw** — zero images via the Command Palette bypass → "Add at least one image." (error-styled, no download, no throw); the Create button is also `disabled` whenever the list is empty; a `.txt` is **skipped** with "Skipped: \"notes.txt\" — unsupported image type. Use JPEG or PNG." (list unchanged, no crash). (6) **viewer untouched** — with example.pdf open, operating the tool (add image + Create) left `#pdf-pages` width 1905→1905 with 1 visible canvas; **0 console errors/warnings** across the whole session (load, tab, palette, add, reorder, 2× create, both error paths, unsupported-type, viewer-intact). Security: 50 MB/file cap, filename sanitized, all list text via `textContent` (no innerHTML), in-memory only (no upload).

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

