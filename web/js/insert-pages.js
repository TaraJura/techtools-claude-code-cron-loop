// insert-pages.js — Insert one or more blank pages into the open PDF.
//
// Lets the user add N blank pages of a chosen size (match the first page, or a
// standard A4 / Letter / Legal sheet) at a chosen position (at the start, at
// the end, or before/after a given page number) and download the result as a
// brand-new PDF, entirely client-side (pdf-lib). The page count of the output
// grows by the number of blank pages inserted; existing page content is never
// modified. The document in the viewer is never mutated; nothing is uploaded.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, or any sibling tool module (crop.js, page-resize.js, split.js,
// merge.js, pages.js, watermark.js, page-numbers.js, bates.js, convert.js).
// The raw PDF bytes come from pdf.js' own `doc.getData()` so we don't reach
// into viewer.js' private buffer. No user-controlled string ever reaches
// innerHTML — only pdf-lib and `textContent` (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

// Standard page sizes in PDF points (72 pt / inch), portrait base.
const PAGE_SIZES = {
    a4: [595.28, 841.89],
    letter: [612, 792],
    legal: [612, 1008],
};
const MAX_INSERT = 50; // cap blank pages per op — protects the small box / memory

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let positionSel = null;
let refPageInput = null;
let countInput = null;
let sizeSel = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [positionSel, refPageInput, countInput, sizeSel, applyBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Read & clamp the "how many pages" control to an integer in [1, MAX_INSERT]. */
function readCount() {
    const raw = parseInt(countInput && countInput.value, 10);
    if (!Number.isFinite(raw) || raw < 1) return 1;
    return Math.min(raw, MAX_INSERT);
}

/** Read & clamp the reference page number (1-based) to [1, numPages]. */
function readRefPage() {
    const raw = parseInt(refPageInput && refPageInput.value, 10);
    if (!Number.isFinite(raw) || raw < 1) return 1;
    return Math.min(raw, Math.max(numPages, 1));
}

/**
 * Resolve the 0-based insertion index from the position selector.
 * `total` is the current page count of the source document.
 */
function resolveIndex(position, total) {
    const ref = readRefPage();
    switch (position) {
        case 'start':  return 0;
        case 'before': return Math.min(Math.max(ref - 1, 0), total);
        case 'after':  return Math.min(ref, total);
        case 'end':
        default:       return total;
    }
}

/** Resolve the [width, height] of a blank page from the size selector. */
function resolveSize(sizeKey, pdf) {
    if (sizeKey === 'match') {
        const first = pdf.getPage(0);
        const { width, height } = first.getSize();
        return [width, height];
    }
    return PAGE_SIZES[sizeKey] || PAGE_SIZES.a4;
}

/** Build a safe download filename for the output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_inserted.pdf`;
}

/** Trigger a browser download for the given bytes. */
function downloadBytes(bytes, fileName) {
    const blob = new Blob([bytes], { type: 'application/pdf' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    a.remove();
    // Revoke on the next tick so the download has a chance to start.
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Insert blank pages into a copy of the open PDF and download it. */
async function applyInsert() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[insert-pages] window.PDFLib unavailable');
        return;
    }

    const count = readCount();
    const position = (positionSel && positionSel.value) || 'end';
    const sizeKey = (sizeSel && sizeSel.value) || 'match';

    setStatus('Inserting blank page' + (count === 1 ? '' : 's') + '…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        const total = pdf.getPageCount();
        const [w, h] = resolveSize(sizeKey, pdf);
        const idx = resolveIndex(position, total);

        // Insert sequentially so the new pages stay contiguous and in order.
        for (let i = 0; i < count; i += 1) {
            pdf.insertPage(idx + i, [w, h]);
        }

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const nowPages = total + count;
        setStatus(
            `Inserted ${count} blank page${count === 1 ? '' : 's'} → ${fileName} `
            + `(now ${nowPages} page${nowPages === 1 ? '' : 's'})`,
        );
    } catch (err) {
        console.error('[insert-pages] apply failed:', err);
        setStatus('Failed to insert pages. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to insert pages.', error: err });
    } finally {
        if (applyBtn) applyBtn.disabled = !(currentDoc && numPages > 0);
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (refPageInput) refPageInput.max = String(Math.max(numPages, 1));
    setEnabled(numPages > 0);
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Choose where to insert.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initInsertPages() {
    positionSel = document.getElementById('insert-position');
    refPageInput = document.getElementById('insert-refpage');
    countInput = document.getElementById('insert-count');
    sizeSel = document.getElementById('insert-size');
    applyBtn = document.getElementById('insert-apply');
    statusEl = document.getElementById('insert-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('insert.apply', {
        title: 'Insert blank pages',
        run: () => applyInsert(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
