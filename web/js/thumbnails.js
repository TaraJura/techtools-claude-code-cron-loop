// thumbnails.js — Page thumbnails navigator.
//
// Renders a small clickable preview of every page in the open PDF into the
// "Pages" tool panel. Clicking (or Enter/Space on) a thumbnail scrolls the
// matching .pdf-page[data-page-number] into view.
//
// Purely additive: subscribes to EventBus document events only. It never
// touches the viewer rendering core or the .pdf-viewer-container flex-row
// layout (developer prompt rule 8). Thumbnails render sequentially and a
// render token guards against overlap when a new document loads, keeping the
// memory footprint small on the 1.6 GiB-RAM box.

import { EventBus, Events } from './event-bus.js';

const THUMB_WIDTH = 120; // CSS px target width for each thumbnail canvas

let listEl = null;
let renderToken = 0; // bumped on each (re)render so a stale loop can bail out

function ensureListEl() {
    if (!listEl) listEl = document.getElementById('thumbnails-list');
    return listEl;
}

function setPlaceholder(text) {
    const el = ensureListEl();
    if (!el) return;
    el.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'thumbnails-empty';
    p.textContent = text;
    el.appendChild(p);
}

/** Scroll the rendered page with this 1-based number into view. */
function goToPage(pageNum) {
    const page = document.querySelector(`.pdf-page[data-page-number="${pageNum}"]`);
    if (page) page.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/** Build the (empty) button shell for one page; the canvas is filled in later. */
function createThumbButton(pageNum) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'thumbnail';
    btn.dataset.pageNumber = String(pageNum);
    btn.setAttribute('aria-label', `Go to page ${pageNum}`);

    const canvas = document.createElement('canvas');
    canvas.className = 'thumbnail-canvas';
    btn.appendChild(canvas);

    const label = document.createElement('span');
    label.className = 'thumbnail-num';
    label.textContent = String(pageNum);
    btn.appendChild(label);

    btn.addEventListener('click', () => goToPage(pageNum));
    return { btn, canvas };
}

async function renderThumbnails({ doc, numPages }) {
    const el = ensureListEl();
    if (!el || !doc) return;

    const token = ++renderToken;
    const total = numPages != null ? numPages : doc.numPages;

    el.innerHTML = '';
    el.setAttribute('aria-busy', 'true');

    for (let pageNum = 1; pageNum <= total; pageNum++) {
        if (token !== renderToken) return; // a newer document superseded us

        const { btn, canvas } = createThumbButton(pageNum);
        el.appendChild(btn);

        try {
            const page = await doc.getPage(pageNum);
            if (token !== renderToken) return;

            const base = page.getViewport({ scale: 1 });
            const scale = THUMB_WIDTH / base.width;
            const viewport = page.getViewport({ scale });

            // Render at device-pixel resolution (capped) for crisp previews,
            // but keep the CSS size small to bound memory.
            const dpr = Math.min(window.devicePixelRatio || 1, 2);
            canvas.width = Math.floor(viewport.width * dpr);
            canvas.height = Math.floor(viewport.height * dpr);
            canvas.style.width = `${Math.floor(viewport.width)}px`;
            canvas.style.height = `${Math.floor(viewport.height)}px`;

            await page.render({
                canvasContext: canvas.getContext('2d'),
                viewport,
                transform: dpr !== 1 ? [dpr, 0, 0, dpr, 0, 0] : null,
            }).promise;
        } catch (err) {
            // A single failed page must not abort the rest of the strip.
            console.warn(`[thumbnails] page ${pageNum} render failed:`, err);
        }
    }

    if (token === renderToken) el.removeAttribute('aria-busy');
}

export function initThumbnails() {
    setPlaceholder('Open a PDF to see page thumbnails.');

    EventBus.on(Events.PDF_LOADED, (payload) => {
        renderThumbnails(payload);
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        renderToken++; // cancel any in-flight render loop
        setPlaceholder('Open a PDF to see page thumbnails.');
    });
}
