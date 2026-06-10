# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-328: Rotate pages — 90° rotation with download (`pages.js`)

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer

**Implementation note (developer, 2026-06-10)**: New module `js/pages.js` ("Rotate" tool tab, `data-panel="pages"`) wired via `action-registry.js` + `app.js`. Rotation STATE + visual apply live in `viewer.js` (`pageRotations` Map, `rotatePage`/`rotateAll`/`getPageRotation`); the existing TASK-316-hardened `renderAll()` adds the user delta to each page's intrinsic `page.rotate` and passes the total into `getViewport({ scale, rotation })` — no forked render loop. New `PAGES_ROTATED` event on `event-bus.js`; `thumbnails.js` re-renders just the affected thumbnail(s) at the new orientation. Controls: Rotate left ⟲ / right ⟳ (current page), Rotate all left/right, Download rotated PDF — all real `<button>`s with descriptive `aria-label`, disabled+`aria-disabled` when no doc. Keyboard `[` / `]` rotate the current page (registered in the shortcuts help overlay, "Pages" group). Download bakes rotation with pdf-lib (`page.setRotation(degrees(orig+delta))`) → `rotated-<name>.pdf`. **Browser-verified (chrome-devtools MCP, example.pdf)**: upload renders (#pdf-pages 1905px, 1 canvas); rotate-right swaps canvas 765×990→990×765 with no page duplication and thumbnail follows; download = 23795-byte valid %PDF with page rotation baked = 90°; rotate-all + `]` cumulative rotations correct; close re-disables controls; **zero console errors/warnings** throughout. Awaiting tester re-verification.
**Description**: Add page rotation, a core PDF operation that is not yet implemented (no `pages.js` / rotate module exists, though zoom/fit-width already live in `viewer.js`). Users frequently receive scanned or photographed PDFs with sideways/upside-down pages and need to correct orientation.

**Technical approach**:
- New module `js/pages.js` registered via `action-registry.js`, wired into the toolbar like the existing view/annotate panels.
- Maintain a per-page rotation state (0/90/180/270, multiples of 90) in memory. Apply it visually by passing `rotation` into the pdf.js `getViewport({ scale, rotation })` call path in `viewer.js` (extend the existing render loop — do **not** fork it; reuse the TASK-316-hardened single render path so rapid clicks don't duplicate pages). Emit a `PAGES_ROTATED` event on `event-bus.js` so `thumbnails.js` re-renders the affected thumbnail.
- Provide **Rotate current page** (left/right) and **Rotate all pages** (left/right) actions.
- Download: bake the rotation into a real PDF with **pdf-lib** — load the original bytes, for each page call `page.setRotation(degrees(existingRotation + delta))` normalized to [0,360), and trigger a Blob download (`rotated-<originalname>.pdf`). Reuse whatever download/save helper `merge.js`/`split.js` already use rather than introducing a new one; if none is shared, factor a small `download(blob, filename)` helper.

**UX acceptance criteria** (tester must verify all in the real browser):
- Visible toolbar buttons: "Rotate left" (⟲) and "Rotate right" (⟳) for the current page, plus a "Rotate all" control. Each is a real `<button>` with a descriptive `aria-label` (e.g. `aria-label="Rotate current page 90° clockwise"`).
- All rotation controls are **keyboard reachable** (Tab order) and operable with Enter/Space; focus ring is visible. Document a shortcut (e.g. `[` / `]` for rotate left/right of the current page) and register it in the keyboard-shortcuts help overlay.
- After clicking rotate, the page visibly rotates in the viewer **and** its thumbnail updates to match within ~1s; the page count is unchanged (no duplicated/blank pages) and no new console errors appear.
- A "Download rotated PDF" action produces a non-zero-byte file whose pages open at the corrected orientation in a fresh viewer load.
- Error/empty state: if no document is loaded, the rotate buttons are disabled (`disabled` + `aria-disabled="true"`) or clicking shows a clear notification ("Open a PDF first") via the existing `notifications.js`, never a silent no-op or a thrown exception.

---

### TASK-329: Page numbers — stamp page numbers onto every page with download (`page-numbers.js`)

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2

**Implementation note (developer2, 2026-06-10)**: New self-contained module `js/page-numbers.js` ("Numbering" tool tab, `data-panel="pagenum"`), wired via `action-registry.js` (`pagenum.apply`) + `app.js` (`initPageNumbers`). Mirrors the isolated watermark.js pattern exactly: talks to the rest of the app only through `EventBus` (PDF_LOADED / PDF_CLEARED) and the ActionRegistry; never touches the viewer render core, `.pdf-viewer-container` layout, upload validation, or any sibling tool module. Reads the open document bytes via pdf.js `doc.getData()`, stamps numbers with pdf-lib (`embedFont(Helvetica)` + `drawText`) onto a fresh copy, and triggers a client-side Blob download (`<base>_numbered.pdf`) — the viewer document is never mutated and nothing is uploaded. Controls: Position (6 options: bottom/top × left/center/right), Format (`1` / `Page 1` / `1 / N` / `Page 1 of N`), Start at (number ≥ 0), Apply & download. All inputs `disabled` until a PDF is open; status line via `role="status" aria-live="polite"`. User text only ever reaches pdf-lib `drawText` and `textContent` (no innerHTML — XSS-safe). No changes to the viewer/upload/layout pipeline, so no `#pdf-pages` geometry risk.

**Description**: Add page numbering — a common PDF prep operation (legal, print, collation) not yet implemented. Complements the existing watermark / rotate / split tools. Pure client-side via pdf-lib; no server involvement.

**UX acceptance criteria** (tester verifies in the real browser):
- A "Numbering" tool tab opens a panel with Position, Format, and Start-at controls plus an "Apply & download" button — all real form controls with `<label>`/`aria-label`, keyboard reachable, visible focus ring.
- Controls are disabled until a PDF is loaded; with no document, clicking shows a clear "Load a PDF first." status, never a thrown exception.
- After loading example.pdf and clicking Apply, a non-zero-byte `*_numbered.pdf` downloads whose pages carry the page number at the chosen corner; page count is unchanged; no new console errors.
- Switching format/position changes the stamped output accordingly; "Start at" offsets the first page's number.
- No regression: `#pdf-pages` still renders width ≥ 300 with a visible canvas after upload (this module does not touch the viewer).
