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

---

### TASK-345: Command Palette (Ctrl/Cmd+K quick action runner)

**Status**: TODO
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

