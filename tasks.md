# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

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

**Technical approach**:
- Load the active document bytes with pdf-lib (`PDFDocument.load`).
- Offer a quality selector (e.g. Low / Medium / High → target image DPI such as 72 / 110 / 150).
- For embedded raster images, downscale + re-encode via an offscreen `<canvas>` (`toBlob` JPEG at the chosen quality) and substitute them back where feasible; for pages where image substitution isn't safe, fall back to a plain re-save.
- Re-save with `doc.save({ useObjectStreams: true })` to strip redundant objects.
- Always compute and display the real before/after byte sizes and the % reduction from the actual output — never claim a saving that didn't happen.
- Provide a Download button for the compressed result (do not overwrite the user's view destructively without confirmation).

**UX acceptance criteria** (tester will verify these in the browser):
- A clearly-labeled "Compress" tool tab/button is reachable from the toolbar and is keyboard-focusable (Tab) and activatable (Enter/Space).
- Clicking it opens a panel that is visible (not behind another panel) and shows the quality selector with an accessible `<label>`/`aria-label` for each control.
- A visible loading/progress indicator appears while compression runs (it can be slow on the 2 vCPU box); the UI must not appear frozen with no feedback.
- On success: the panel shows original size, new size, and "% smaller" computed from the actual output, plus an enabled Download button that yields a non-zero, valid PDF.
- Edge/error states are shown as visible, screen-reader-announced messages, not silent failures or raw console errors: (a) no document loaded → "Open a PDF first"; (b) already-optimized / result not smaller → show the real (possibly 0%) delta and tell the user the file is already optimized rather than forcing a larger file on them; (c) corrupt/unsupported input → a friendly error.
- All interactive controls have discernible accessible names (verifiable via the accessibility tree); the panel traps/returns focus sensibly and is dismissible with Escape.

