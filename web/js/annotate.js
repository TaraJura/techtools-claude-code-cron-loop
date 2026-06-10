// annotate.js — text markup: highlight, underline, strikethrough (TASK-314, TASK-325).
//
// Markup module for the rebuilt editor. Puts the viewer into one of three
// markup "tools" (highlight / underline / strikethrough); while a tool is
// armed, selecting text over the pdf.js text layer and releasing the mouse
// records a markup annotation over exactly the selected glyphs:
//   - highlight    → a semi-transparent yellow box (mix-blend multiply)
//   - underline    → an opaque line along the bottom of the glyphs
//   - strikethrough→ an opaque line through the middle of the glyphs
// Only one tool is armed at a time (arming one disarms the others).
//
// Annotations are stored in memory as page-relative *normalized* fractions
// ({x,y,w,h} in 0..1 of the page box) so they survive zoom / fit-width
// re-renders and any responsive resizing — we render them with CSS percentages,
// so a page box of any size keeps them aligned to the text.
//
// Decoupled by design: it never touches viewer.js's render core. viewer.js
// renders the selectable text layer (a generic capability); this module only
// listens on the EventBus and reads/writes DOM under each `.pdf-page`. The
// foundation (tool toggle, normalized-coord overlays, per-item select/remove)
// is shared across all three markup styles — and reusable by sticky-notes later.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import * as Viewer from './viewer.js';

const MIN_FRACTION = 0.001; // ignore zero/▪-size rects

// Per-tool defaults. Highlight stays translucent (blended via multiply); the
// line tools use opaque "pen" colours so the stroke reads clearly.
const TOOLS = {
    highlight: { color: 'rgba(255, 235, 0, 0.4)', label: 'Highlight', noun: 'highlight' },
    underline: { color: '#2563eb', label: 'Underline', noun: 'underline' },
    strike: { color: '#dc2626', label: 'Strikethrough', noun: 'strikethrough' },
};

let annotations = []; // [{ id, page, type, color, rects: [{x,y,w,h}] }]
let activeTool = null; // 'highlight' | 'underline' | 'strike' | null
let selectedId = null;
let nextId = 1;

let toggleBtns = {};    // { highlight: el, underline: el, strike: el }
let statusEl = null;    // #highlight-status (aria-live)
let viewerInner = null; // .pdf-viewer-inner (mouseup / click target)

function cacheEls() {
    toggleBtns = {
        highlight: document.getElementById('highlight-toggle'),
        underline: document.getElementById('underline-toggle'),
        strike: document.getElementById('strike-toggle'),
    };
    statusEl = document.getElementById('highlight-status');
    viewerInner = document.querySelector('.pdf-viewer-inner');
}

function setStatus(text) {
    if (statusEl) statusEl.textContent = text;
}

function updateButtons() {
    for (const [tool, btn] of Object.entries(toggleBtns)) {
        if (!btn) continue;
        const on = activeTool === tool;
        btn.setAttribute('aria-pressed', String(on));
        btn.classList.toggle('active', on);
    }
}

// --- Coordinate helpers -----------------------------------------------------

/** The .pdf-page element under a client rect's centre, if any. */
function pageElForRect(r) {
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const el = document.elementFromPoint(cx, cy);
    return el ? el.closest('.pdf-page') : null;
}

/** Convert a viewport-space client rect into page-relative 0..1 fractions. */
function normalizeRect(r, pageEl) {
    const pr = pageEl.getBoundingClientRect();
    if (pr.width <= 0 || pr.height <= 0) return null;
    const x = (r.left - pr.left) / pr.width;
    const y = (r.top - pr.top) / pr.height;
    const w = r.width / pr.width;
    const h = r.height / pr.height;
    if (w < MIN_FRACTION || h < MIN_FRACTION) return null;
    // Clamp into the page so a slightly-overhanging rect can't escape the box.
    return {
        x: Math.min(Math.max(x, 0), 1),
        y: Math.min(Math.max(y, 0), 1),
        w: Math.min(w, 1),
        h: Math.min(h, 1),
    };
}

// --- Rendering --------------------------------------------------------------

/** Get (creating if needed) the markup overlay layer for a page element. */
function ensurePageLayer(pageEl) {
    let layer = pageEl.querySelector(':scope > .annotation-layer');
    if (!layer) {
        layer = document.createElement('div');
        layer.className = 'annotation-layer';
        pageEl.appendChild(layer);
    }
    return layer;
}

/** Build one mark element for a normalized rect of an annotation. */
function buildMark(ann, rc) {
    const div = document.createElement('div');
    div.className = `hl-rect hl-rect--${ann.type}` + (ann.id === selectedId ? ' selected' : '');
    div.style.left = `${rc.x * 100}%`;
    div.style.top = `${rc.y * 100}%`;
    div.style.width = `${rc.w * 100}%`;
    div.style.height = `${rc.h * 100}%`;
    div.style.setProperty('--mark-color', ann.color);
    div.dataset.hid = String(ann.id);
    // Highlight fills the box directly; line tools draw a child line so the
    // box itself stays a transparent hit target.
    if (ann.type === 'highlight') {
        div.style.background = ann.color;
    } else {
        const line = document.createElement('div');
        line.className = 'mark-line';
        div.appendChild(line);
    }
    div.addEventListener('click', (ev) => {
        ev.stopPropagation();
        selectAnnotation(ann.id);
    });
    return div;
}

/** Re-paint every page's annotations from the in-memory store. Idempotent. */
function renderAnnotations() {
    document.querySelectorAll('.pdf-page').forEach((pageEl) => {
        const layer = ensurePageLayer(pageEl);
        layer.innerHTML = '';
        const pageNum = Number(pageEl.dataset.pageNumber);
        annotations
            .filter((a) => a.page === pageNum)
            .forEach((ann) => {
                ann.rects.forEach((rc, i) => {
                    layer.appendChild(buildMark(ann, rc));

                    // Remove affordance: a small × anchored to the first rect of
                    // the currently-selected annotation.
                    if (ann.id === selectedId && i === 0) {
                        const noun = (TOOLS[ann.type] || {}).noun || 'annotation';
                        const btn = document.createElement('button');
                        btn.type = 'button';
                        btn.className = 'hl-remove';
                        btn.setAttribute('aria-label', `Remove ${noun}`);
                        btn.textContent = '×';
                        btn.style.left = `${rc.x * 100}%`;
                        btn.style.top = `${rc.y * 100}%`;
                        btn.addEventListener('click', (ev) => {
                            ev.stopPropagation();
                            removeAnnotation(ann.id);
                        });
                        layer.appendChild(btn);
                    }
                });
            });
    });
}

// --- Mutations --------------------------------------------------------------

function selectAnnotation(id) {
    selectedId = id;
    renderAnnotations();
}

function deselect() {
    if (selectedId === null) return;
    selectedId = null;
    renderAnnotations();
}

function removeAnnotation(id) {
    annotations = annotations.filter((a) => a.id !== id);
    if (selectedId === id) selectedId = null;
    renderAnnotations();
    EventBus.emit(Events.ANNOTATIONS_CHANGED, {});
}

function clearAll() {
    annotations = [];
    selectedId = null;
    renderAnnotations();
    EventBus.emit(Events.ANNOTATIONS_CHANGED, {});
    if (Viewer.getDocument()) setStatus('All annotations cleared.');
}

/** Turn the loaded selection into one annotation per page it touches. */
function captureSelection() {
    if (!activeTool) return;
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return;

    const range = sel.getRangeAt(0);
    const rects = Array.from(range.getClientRects());
    if (!rects.length) return;

    const byPage = new Map(); // pageNumber -> [normalized rects]
    for (const r of rects) {
        if (r.width <= 0 || r.height <= 0) continue;
        const pageEl = pageElForRect(r);
        if (!pageEl) continue;
        const norm = normalizeRect(r, pageEl);
        if (!norm) continue;
        const pageNum = Number(pageEl.dataset.pageNumber);
        if (!byPage.has(pageNum)) byPage.set(pageNum, []);
        byPage.get(pageNum).push(norm);
    }

    if (byPage.size === 0) return; // empty / zero-size selection — ignore silently

    const color = TOOLS[activeTool].color;
    for (const [pageNum, pageRects] of byPage) {
        annotations.push({ id: nextId++, page: pageNum, type: activeTool, color, rects: pageRects });
    }
    sel.removeAllRanges();
    renderAnnotations();
    EventBus.emit(Events.ANNOTATIONS_CHANGED, {});
}

// --- Tool arming ------------------------------------------------------------

function setTool(tool) {
    // Arming a tool with no document: explain, don't throw, stay disarmed.
    if (activeTool !== tool && !Viewer.getDocument()) {
        setStatus('Load a PDF first.');
        updateButtons();
        return;
    }
    // Toggle off if re-clicking the armed tool; otherwise switch to it.
    activeTool = activeTool === tool ? null : tool;
    document.body.classList.toggle('highlight-mode', activeTool !== null);
    updateButtons();
    setStatus(activeTool ? `${TOOLS[activeTool].label} mode on — select text to mark.` : '');
    if (!activeTool) deselect();
}

function disarm() {
    activeTool = null;
    document.body.classList.remove('highlight-mode');
    updateButtons();
}

// --- Init -------------------------------------------------------------------

export function initAnnotate() {
    cacheEls();
    updateButtons();

    ActionRegistry.register('annotate.toggleHighlight', {
        title: 'Highlight text',
        run: () => setTool('highlight'),
    });
    ActionRegistry.register('annotate.toggleUnderline', {
        title: 'Underline text',
        run: () => setTool('underline'),
    });
    ActionRegistry.register('annotate.toggleStrikethrough', {
        title: 'Strikethrough text',
        run: () => setTool('strike'),
    });
    ActionRegistry.register('annotate.clearAll', {
        title: 'Clear annotations',
        run: () => clearAll(),
    });

    // Capture a finished selection only while a tool is armed.
    if (viewerInner) {
        viewerInner.addEventListener('mouseup', () => {
            if (activeTool) captureSelection();
        });
        // Clicking empty viewer space deselects the active annotation.
        viewerInner.addEventListener('click', (e) => {
            if (!e.target.closest('.hl-rect') && !e.target.closest('.hl-remove')) {
                deselect();
            }
        });
    }

    // Delete / Backspace removes the selected annotation (unless typing in a field).
    document.addEventListener('keydown', (e) => {
        if (selectedId === null) return;
        if (e.key !== 'Delete' && e.key !== 'Backspace') return;
        const a = document.activeElement;
        if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA' || a.isContentEditable)) return;
        e.preventDefault();
        removeAnnotation(selectedId);
    });

    // Re-paint annotations every time the viewer re-renders (zoom / fit-width).
    EventBus.on(Events.PDF_RENDERED, () => renderAnnotations());

    // New document → start fresh.
    EventBus.on(Events.PDF_LOADED, () => {
        annotations = [];
        selectedId = null;
        setStatus(activeTool ? `${TOOLS[activeTool].label} mode on — select text to mark.` : '');
        EventBus.emit(Events.ANNOTATIONS_CHANGED, {});
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        annotations = [];
        selectedId = null;
        disarm();
        setStatus('');
        EventBus.emit(Events.ANNOTATIONS_CHANGED, {});
    });
}

/**
 * Read-only snapshot of the current markups for summary/overview consumers
 * (e.g. annotation-summary.js). Returns plain objects — never the live store —
 * so callers can sort/iterate without mutating annotation state. Each item:
 * `{ id, page, type, label }` where `label` is the human-readable tool name.
 */
export function getAnnotations() {
    return annotations.map((a) => ({
        id: a.id,
        page: a.page,
        type: a.type,
        label: (TOOLS[a.type] || {}).label || a.type,
    }));
}

/**
 * Select a markup by id and scroll its page into view. Used by the annotation
 * summary panel to jump to a markup. Reuses the existing select path (which
 * paints the `.selected` style + remove handle); no-op for unknown ids.
 */
export function focusAnnotation(id) {
    const ann = annotations.find((a) => a.id === id);
    if (!ann) return;
    selectAnnotation(ann.id);
    const pageEl = document.querySelector(`.pdf-page[data-page-number="${ann.page}"]`);
    if (pageEl) pageEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

export default initAnnotate;
