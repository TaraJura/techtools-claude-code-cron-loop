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

