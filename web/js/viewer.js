// viewer.js — pdf.js rendering wrapper.
// Renders all pages of a loaded PDF into #pdf-pages, one <canvas> per page,
// and exposes zoom / fit-width controls.
//
// LAYOUT GOTCHA (see developer prompt rule 8): #pdf-pages lives inside
// .pdf-viewer-inner (a flex-direction:column box). Never append full-width
// siblings directly to .pdf-viewer-container — it is flex-direction:row and a
// flex-shrink:0 child would collapse the page column to 0 width.

import * as pdfjsLib from '../lib/pdf.min.mjs';
import { EventBus, Events } from './event-bus.js';

// The worker must be served as a real module (.mjs MIME handled by nginx).
pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('../lib/pdf.worker.min.mjs', import.meta.url).href;

const MIN_SCALE = 0.25;
const MAX_SCALE = 4.0;

let pdfDoc = null;          // current pdfjs document
let currentScale = 1.25;    // render scale
let pagesEl = null;         // #pdf-pages container
let loadingEl = null;       // #viewer-loading overlay
let renderToken = 0;        // guards against overlapping re-renders

// Per-page USER rotation delta in degrees (multiples of 90, normalized to
// [0,360)), keyed by 1-based page number. This is the rotation the user applied
// ON TOP OF the page's intrinsic /Rotate (pdf.js `page.rotate`); the render loop
// adds the two. Reset whenever a document is loaded or cleared. Owned here (not
// in pages.js) because only the render loop can apply it — pages.js drives it
// through the rotatePage/rotateAll API below. (TASK-328)
const pageRotations = new Map();

/** Normalize any degree value into [0,360). */
function normalizeDeg(d) {
    return (((d % 360) + 360) % 360);
}

/** User-applied rotation delta (deg) for a 1-based page; 0 if none. */
export function getPageRotation(pageNum) {
    return pageRotations.get(pageNum) || 0;
}

function ensurePagesEl() {
    if (!pagesEl) pagesEl = document.getElementById('pdf-pages');
    return pagesEl;
}

// --- Loading overlay (TASK-318) -------------------------------------------
// A single reusable overlay (#viewer-loading) shown while a document is being
// parsed/rendered. Toggled via the [hidden] attribute so it leaves the a11y
// tree when hidden. Coexists with the TASK-316 supersede guard: only the
// winning render hides it (a superseded render bails before appending), and a
// newer render re-shows it, so a stale render can never strand the spinner.

function ensureLoadingEl() {
    if (!loadingEl) loadingEl = document.getElementById('viewer-loading');
    return loadingEl;
}

function setLoadingLabel(text) {
    const el = ensureLoadingEl();
    if (!el) return;
    const labelEl = el.querySelector('.viewer-loading__label');
    if (labelEl) labelEl.textContent = text;
}

function showLoading(label = 'Loading PDF…') {
    const el = ensureLoadingEl();
    if (!el) return;
    el.classList.remove('viewer-loading--error');
    setLoadingLabel(label);
    el.hidden = false;
}

function showLoadError(message = "Couldn't render this PDF.") {
    const el = ensureLoadingEl();
    if (!el) return;
    el.classList.add('viewer-loading--error');
    setLoadingLabel(message);
    el.hidden = false;
}

function hideLoading() {
    const el = ensureLoadingEl();
    if (el) el.hidden = true;
}

/**
 * Load a PDF from an ArrayBuffer / Uint8Array and render it.
 * @param {ArrayBuffer|Uint8Array} data
 * @param {string} [name]
 */
export async function loadDocument(data, name = 'document.pdf') {
    // Show the loading overlay up front so the parse step (which can be slow on
    // this small box) is covered, not just the page render.
    showLoading('Loading PDF…');
    try {
        // pdf.js may detach the buffer; hand it a private copy.
        const bytes = data instanceof Uint8Array ? data.slice() : new Uint8Array(data.slice(0));
        const doc = await pdfjsLib.getDocument({ data: bytes }).promise;
        pdfDoc = doc;
        pageRotations.clear(); // a new document starts at its intrinsic orientation
        EventBus.emit(Events.PDF_LOADED, { doc, name, numPages: doc.numPages });
        await renderAll();
        return doc;
    } catch (err) {
        // Leave a readable message instead of a stuck spinner / blank viewport.
        showLoadError("Couldn't render this PDF.");
        throw err;
    }
}

/** Re-render every page at the current scale. */
export async function renderAll() {
    const container = ensurePagesEl();
    if (!container || !pdfDoc) return;

    const token = ++renderToken;
    container.innerHTML = '';
    container.setAttribute('aria-busy', 'true');

    for (let pageNum = 1; pageNum <= pdfDoc.numPages; pageNum++) {
        if (token !== renderToken) return; // a newer render superseded us
        const page = await pdfDoc.getPage(pageNum);
        // getPage() suspends — a newer render may have started (and cleared the
        // container) while we awaited. Re-check BEFORE building/appending any DOM,
        // otherwise this stale render leaks a duplicate page wrapper + canvas
        // (the root cause of TASK-316: rapid zoom accumulating duplicate pages).
        if (token !== renderToken) return;
        // Total rotation = page's intrinsic /Rotate + the user's applied delta.
        // pdf.js's `rotation` viewport option is ABSOLUTE (it defaults to
        // page.rotate when omitted), so we must add them ourselves. (TASK-328)
        const rotation = normalizeDeg((page.rotate || 0) + getPageRotation(pageNum));
        const viewport = page.getViewport({ scale: currentScale, rotation });

        const pageWrap = document.createElement('div');
        pageWrap.className = 'pdf-page';
        pageWrap.dataset.pageNumber = String(pageNum);
        // Give the page an explicit CSS-pixel box so the (absolutely-positioned)
        // text layer and any annotation overlays line up with the canvas, and
        // expose the render scale for pdf.js's text layer (it sizes glyph spans
        // with calc(var(--scale-factor) * …)).
        const cssW = Math.floor(viewport.width);
        const cssH = Math.floor(viewport.height);
        pageWrap.style.width = `${cssW}px`;
        pageWrap.style.height = `${cssH}px`;
        pageWrap.style.setProperty('--scale-factor', String(currentScale));

        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        // Account for high-DPI screens for crisp text, but cap to protect the
        // 1.6 GiB-RAM box from huge backing stores.
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        canvas.width = Math.floor(viewport.width * dpr);
        canvas.height = Math.floor(viewport.height * dpr);
        canvas.style.width = `${cssW}px`;
        canvas.style.height = `${cssH}px`;

        // Selectable text layer (transparent) on top of the canvas. Annotation
        // tools (highlight, etc.) rely on window.getSelection() returning real
        // range rects, which only works when this layer is rendered.
        const textLayerDiv = document.createElement('div');
        textLayerDiv.className = 'textLayer';

        pageWrap.appendChild(canvas);
        pageWrap.appendChild(textLayerDiv);
        // Final guard right before mutating the live container: if a newer render
        // superseded us at any point above, bail without appending (defensive —
        // there is no await between the getPage check and here today, but this
        // keeps the append safe if an await is ever introduced).
        if (token !== renderToken) return;
        container.appendChild(pageWrap);

        // First page is on screen — drop the loading overlay. Only the winning
        // render reaches this point (superseded renders bail at the guards
        // above), so a stale render can never strand or prematurely hide it.
        if (pageNum === 1) hideLoading();

        await page.render({
            canvasContext: ctx,
            viewport,
            transform: dpr !== 1 ? [dpr, 0, 0, dpr, 0, 0] : null,
        }).promise;

        // Render the text layer after the canvas. Failure here must never abort
        // the page render — selection just won't be available for that page.
        try {
            const textContent = await page.getTextContent();
            if (token !== renderToken) return; // superseded mid-extraction
            const textLayer = new pdfjsLib.TextLayer({
                textContentSource: textContent,
                container: textLayerDiv,
                viewport,
            });
            await textLayer.render();
        } catch (err) {
            console.warn(`[viewer] text layer failed for page ${pageNum}:`, err);
        }
    }

    container.removeAttribute('aria-busy');
    if (token === renderToken) {
        EventBus.emit(Events.PDF_RENDERED, { numPages: pdfDoc.numPages });
    }
}

function clampScale(s) {
    return Math.max(MIN_SCALE, Math.min(MAX_SCALE, s));
}

export async function setScale(scale) {
    currentScale = clampScale(scale);
    EventBus.emit(Events.ZOOM_CHANGED, { scale: currentScale });
    await renderAll();
}

export function getScale() {
    return currentScale;
}

export async function zoomIn() {
    return setScale(currentScale + 0.25);
}

export async function zoomOut() {
    return setScale(currentScale - 0.25);
}

/** Fit the first page to the available container width. */
export async function fitWidth() {
    const container = ensurePagesEl();
    if (!container || !pdfDoc) return;
    const page = await pdfDoc.getPage(1);
    const unscaled = page.getViewport({ scale: 1 });
    // Leave room for padding/scrollbar.
    const avail = container.clientWidth - 32;
    if (avail > 0) {
        await setScale(clampScale(avail / unscaled.width));
    }
}

export function clear() {
    pdfDoc = null;
    pageRotations.clear();
    const container = ensurePagesEl();
    if (container) container.innerHTML = '';
    hideLoading(); // never leave a stale spinner/error after closing a document
    EventBus.emit(Events.PDF_CLEARED);
}

// --- Page rotation (TASK-328) ---------------------------------------------
// Rotate by multiples of 90°. State lives in `pageRotations`; the render loop
// above applies it. Both helpers re-render through the single TASK-316-hardened
// renderAll() path (never a forked loop) and emit PAGES_ROTATED so thumbnails.js
// re-renders the affected previews. No-ops (never throw) when no doc is open.

/**
 * Rotate one 1-based page by `deltaDeg` (a multiple of 90; +90 = clockwise).
 * @returns {Promise<void>}
 */
export async function rotatePage(pageNum, deltaDeg) {
    if (!pdfDoc) return;
    if (!Number.isInteger(pageNum) || pageNum < 1 || pageNum > pdfDoc.numPages) return;
    pageRotations.set(pageNum, normalizeDeg(getPageRotation(pageNum) + deltaDeg));
    await renderAll();
    EventBus.emit(Events.PAGES_ROTATED, { pages: [pageNum] });
}

/** Rotate every page by `deltaDeg` (a multiple of 90; +90 = clockwise). */
export async function rotateAll(deltaDeg) {
    if (!pdfDoc) return;
    const pages = [];
    for (let p = 1; p <= pdfDoc.numPages; p++) {
        pageRotations.set(p, normalizeDeg(getPageRotation(p) + deltaDeg));
        pages.push(p);
    }
    await renderAll();
    EventBus.emit(Events.PAGES_ROTATED, { pages, all: true });
}

export function getDocument() {
    return pdfDoc;
}

// --- Keyboard zoom + viewport scroll (TASK-320) ---------------------------
// Navigation keys (Arrow / Page Up / Page Down / Home / End) are owned by
// page-nav.js (TASK-303), which binds its OWN keydown to this same
// .pdf-viewer-inner scroll container. We deliberately do NOT re-handle them
// here — that would double-fire. This handler adds only what page-nav lacks:
// keyboard zoom (+ / = / - / 0, reusing the TASK-316-hardened zoom path, never
// duplicating it) and Space / Shift+Space viewport scrolling. It is bound on
// the scroll container (not window) so it can never fire from a tool-panel
// input, and it is a no-op (never throws) when no document is open.

let keysScrollEl = null;

function isTypingTarget(t) {
    return !!(t && t.closest && t.closest('input,textarea,[contenteditable],.tool-panel'));
}

function onViewerKeyDown(e) {
    if (!pdfDoc) return;                       // no-doc safety: do nothing, never throw
    if (e.ctrlKey || e.metaKey || e.altKey) return; // leave native/app combos (e.g. Ctrl+0 browser zoom)
    if (isTypingTarget(e.target)) return;      // scoped: never hijack typing

    switch (e.key) {
        case '+':
        case '=':                              // unshifted key that yields "+"
            e.preventDefault();
            zoomIn();
            break;
        case '-':
        case '_':
            e.preventDefault();
            zoomOut();
            break;
        case '0':
            e.preventDefault();
            fitWidth();
            break;
        case ' ':                              // Space / Shift+Space: scroll one viewport
        case 'Spacebar':                       // legacy key name (older Firefox/IE)
            if (!keysScrollEl) return;
            e.preventDefault();
            keysScrollEl.scrollBy({
                top: e.shiftKey ? -keysScrollEl.clientHeight : keysScrollEl.clientHeight,
                behavior: 'smooth',
            });
            break;
        default:
            break;                             // Arrow/Page/Home/End → page-nav.js
    }
}

/** Wire keyboard zoom + viewport scroll on the viewer scroll container. */
export function initViewerKeys() {
    if (keysScrollEl) return;                  // idempotent
    keysScrollEl = document.querySelector('.pdf-viewer-inner');
    if (keysScrollEl) keysScrollEl.addEventListener('keydown', onViewerKeyDown);
}
