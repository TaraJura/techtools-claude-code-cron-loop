# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-344: Compress PDF (reduce file size)

**Status**: DONE
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

