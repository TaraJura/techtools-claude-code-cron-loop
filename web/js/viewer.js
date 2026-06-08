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
let renderToken = 0;        // guards against overlapping re-renders

function ensurePagesEl() {
    if (!pagesEl) pagesEl = document.getElementById('pdf-pages');
    return pagesEl;
}

/**
 * Load a PDF from an ArrayBuffer / Uint8Array and render it.
 * @param {ArrayBuffer|Uint8Array} data
 * @param {string} [name]
 */
export async function loadDocument(data, name = 'document.pdf') {
    // pdf.js may detach the buffer; hand it a private copy.
    const bytes = data instanceof Uint8Array ? data.slice() : new Uint8Array(data.slice(0));
    const doc = await pdfjsLib.getDocument({ data: bytes }).promise;
    pdfDoc = doc;
    EventBus.emit(Events.PDF_LOADED, { doc, name, numPages: doc.numPages });
    await renderAll();
    return doc;
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
        const viewport = page.getViewport({ scale: currentScale });

        const pageWrap = document.createElement('div');
        pageWrap.className = 'pdf-page';
        pageWrap.dataset.pageNumber = String(pageNum);

        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        // Account for high-DPI screens for crisp text, but cap to protect the
        // 1.6 GiB-RAM box from huge backing stores.
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        canvas.width = Math.floor(viewport.width * dpr);
        canvas.height = Math.floor(viewport.height * dpr);
        canvas.style.width = `${Math.floor(viewport.width)}px`;
        canvas.style.height = `${Math.floor(viewport.height)}px`;

        pageWrap.appendChild(canvas);
        container.appendChild(pageWrap);

        await page.render({
            canvasContext: ctx,
            viewport,
            transform: dpr !== 1 ? [dpr, 0, 0, dpr, 0, 0] : null,
        }).promise;
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
    EventBus.emit(Events.PDF_CLEARED);
}

export function getDocument() {
    return pdfDoc;
}
