// annotate.js — text highlight annotation (TASK-314).
//
// First markup module for the rebuilt editor. Puts the viewer into a "highlight"
// mode; while active, selecting text over the pdf.js text layer and releasing
// the mouse paints a semi-transparent yellow box over exactly the selected
// glyphs. Highlights are stored in memory as page-relative *normalized*
// fractions ({x,y,w,h} in 0..1 of the page box) so they survive zoom /
// fit-width re-renders and any responsive resizing — we render them with CSS
// percentages, so a page box of any size keeps them aligned to the text.
//
// Decoupled by design: it never touches viewer.js's render core. viewer.js
// renders the selectable text layer (a generic capability); this module only
// listens on the EventBus and reads/writes DOM under each `.pdf-page`. The
// foundation (mode toggle, normalized-coord overlays, per-item removal) is
// meant to be reused by underline / strikethrough / sticky-notes later.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import * as Viewer from './viewer.js';

const DEFAULT_COLOR = 'rgba(255, 235, 0, 0.4)'; // highlighter yellow (blended via mix-blend-mode: multiply)
const MIN_FRACTION = 0.001;                      // ignore zero/▪-size rects

let highlights = [];     // [{ id, page, color, rects: [{x,y,w,h}] }]
let highlightMode = false;
let selectedId = null;
let nextId = 1;

let toggleBtn = null;    // #highlight-toggle
let statusEl = null;     // #highlight-status (aria-live)
let viewerInner = null;  // .pdf-viewer-inner (mouseup / click target)

function cacheEls() {
    toggleBtn = document.getElementById('highlight-toggle');
    statusEl = document.getElementById('highlight-status');
    viewerInner = document.querySelector('.pdf-viewer-inner');
}

function setStatus(text) {
    if (statusEl) statusEl.textContent = text;
}

function updateButton() {
    if (!toggleBtn) return;
    toggleBtn.setAttribute('aria-pressed', String(highlightMode));
    toggleBtn.classList.toggle('active', highlightMode);
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

/** Get (creating if needed) the highlight overlay layer for a page element. */
function ensurePageLayer(pageEl) {
    let layer = pageEl.querySelector(':scope > .annotation-layer');
    if (!layer) {
        layer = document.createElement('div');
        layer.className = 'annotation-layer';
        pageEl.appendChild(layer);
    }
    return layer;
}

/** Re-paint every page's highlights from the in-memory store. Idempotent. */
function renderHighlights() {
    document.querySelectorAll('.pdf-page').forEach((pageEl) => {
        const layer = ensurePageLayer(pageEl);
        layer.innerHTML = '';
        const pageNum = Number(pageEl.dataset.pageNumber);
        highlights
            .filter((h) => h.page === pageNum)
            .forEach((h) => {
                h.rects.forEach((rc, i) => {
                    const div = document.createElement('div');
                    div.className = 'hl-rect' + (h.id === selectedId ? ' selected' : '');
                    div.style.left = `${rc.x * 100}%`;
                    div.style.top = `${rc.y * 100}%`;
                    div.style.width = `${rc.w * 100}%`;
                    div.style.height = `${rc.h * 100}%`;
                    div.style.background = h.color;
                    div.dataset.hid = String(h.id);
                    div.addEventListener('click', (ev) => {
                        ev.stopPropagation();
                        selectHighlight(h.id);
                    });
                    layer.appendChild(div);

                    // Remove affordance: a small × anchored to the first rect of
                    // the currently-selected highlight.
                    if (h.id === selectedId && i === 0) {
                        const btn = document.createElement('button');
                        btn.type = 'button';
                        btn.className = 'hl-remove';
                        btn.setAttribute('aria-label', 'Remove highlight');
                        btn.textContent = '×';
                        btn.style.left = `${rc.x * 100}%`;
                        btn.style.top = `${rc.y * 100}%`;
                        btn.addEventListener('click', (ev) => {
                            ev.stopPropagation();
                            removeHighlight(h.id);
                        });
                        layer.appendChild(btn);
                    }
                });
            });
    });
}

// --- Mutations --------------------------------------------------------------

function selectHighlight(id) {
    selectedId = id;
    renderHighlights();
}

function deselect() {
    if (selectedId === null) return;
    selectedId = null;
    renderHighlights();
}

function removeHighlight(id) {
    highlights = highlights.filter((h) => h.id !== id);
    if (selectedId === id) selectedId = null;
    renderHighlights();
}

function clearAll() {
    highlights = [];
    selectedId = null;
    renderHighlights();
    if (Viewer.getDocument()) setStatus('All highlights cleared.');
}

/** Turn the loaded selection into one highlight per page it touches. */
function captureSelection() {
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

    for (const [pageNum, pageRects] of byPage) {
        highlights.push({ id: nextId++, page: pageNum, color: DEFAULT_COLOR, rects: pageRects });
    }
    sel.removeAllRanges();
    renderHighlights();
}

// --- Mode -------------------------------------------------------------------

function toggleHighlight() {
    // Turning ON with no document: explain, don't throw, stay off.
    if (!highlightMode && !Viewer.getDocument()) {
        setStatus('Load a PDF first.');
        updateButton();
        return;
    }
    highlightMode = !highlightMode;
    document.body.classList.toggle('highlight-mode', highlightMode);
    updateButton();
    setStatus(highlightMode ? 'Highlight mode on — select text to highlight.' : '');
    if (!highlightMode) deselect();
}

function exitMode() {
    highlightMode = false;
    document.body.classList.remove('highlight-mode');
    updateButton();
}

// --- Init -------------------------------------------------------------------

export function initAnnotate() {
    cacheEls();
    updateButton();

    ActionRegistry.register('annotate.toggleHighlight', {
        title: 'Highlight text',
        run: () => toggleHighlight(),
    });
    ActionRegistry.register('annotate.clearAll', {
        title: 'Clear highlights',
        run: () => clearAll(),
    });

    // Capture a finished selection only while in highlight mode.
    if (viewerInner) {
        viewerInner.addEventListener('mouseup', () => {
            if (highlightMode) captureSelection();
        });
        // Clicking empty viewer space deselects the active highlight.
        viewerInner.addEventListener('click', (e) => {
            if (!e.target.closest('.hl-rect') && !e.target.closest('.hl-remove')) {
                deselect();
            }
        });
    }

    // Delete / Backspace removes the selected highlight (unless typing in a field).
    document.addEventListener('keydown', (e) => {
        if (selectedId === null) return;
        if (e.key !== 'Delete' && e.key !== 'Backspace') return;
        const a = document.activeElement;
        if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA' || a.isContentEditable)) return;
        e.preventDefault();
        removeHighlight(selectedId);
    });

    // Re-paint highlights every time the viewer re-renders (zoom / fit-width).
    EventBus.on(Events.PDF_RENDERED, () => renderHighlights());

    // New document → start fresh.
    EventBus.on(Events.PDF_LOADED, () => {
        highlights = [];
        selectedId = null;
        setStatus(highlightMode ? 'Highlight mode on — select text to highlight.' : '');
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        highlights = [];
        selectedId = null;
        exitMode();
        setStatus('');
    });
}

export default initAnnotate;
