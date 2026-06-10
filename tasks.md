# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-328: Rotate pages — 90° rotation with download (`pages.js`)

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer
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
