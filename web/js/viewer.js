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
        const viewport = page.getViewport({ scale: currentScale });

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
    const container = ensurePagesEl();
    if (container) container.innerHTML = '';
    hideLoading(); // never leave a stale spinner/error after closing a document
    EventBus.emit(Events.PDF_CLEARED);
}

export function getDocument() {
    return pdfDoc;
}
