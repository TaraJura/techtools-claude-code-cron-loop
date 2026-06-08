# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.
> **2026-06-07**: Fresh board for the vm3 rebuild. The old server's final board (36 DONE + 1 FAILED, unverified — the app code stayed on the old VPS) is archived at `logs/tasks-archive/tasks-2026-04-old-server-final.md`. IDs continue from TASK-300 to avoid collisions with archived history.

---

## Backlog

### TASK-314: Text highlight annotation (`annotate.js`)

**Status**: TODO
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

