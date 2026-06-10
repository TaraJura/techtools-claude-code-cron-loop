// page-numbers.js — Stamp page numbers onto every page of the open PDF.
//
// Lets the user add page numbers (configurable corner, format, and start
// value) to all pages of the currently open document and download the result
// as a brand-new PDF, entirely client-side (pdf-lib). The document in the
// viewer is never modified; nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, split.js, merge.js, watermark.js, search.js, pages.js, or
// annotate.js. The raw PDF bytes come from pdf.js' own `doc.getData()` so we
// don't reach into viewer.js' private buffer. No user-controlled string ever
// reaches innerHTML — only pdf-lib `drawText` and `textContent` (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const FONT_SIZE = 11;     // page-number text size, points
const MARGIN = 28;        // distance from page edge, points (~0.39in)

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let positionSel = null;
let formatSel = null;
let startInput = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [positionSel, formatSel, startInput, applyBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Read & clamp the "start at" control to a non-negative integer. */
function readStart() {
    const n = parseInt(startInput && startInput.value, 10);
    if (!Number.isFinite(n) || n < 0) return 1;
    return Math.min(n, 1000000);
}

/** Build the label text for page `index` (0-based) given total `total`. */
function formatLabel(fmt, index, total, start) {
    const n = start + index;
    switch (fmt) {
        case 'page-n':       return `Page ${n}`;
        case 'n-of-total':   return `${n} / ${total}`;
        case 'page-n-of-t':  return `Page ${n} of ${total}`;
        case 'plain':
        default:             return String(n);
    }
}

/** Compute the {x, y} baseline for the label on a page of the given size. */
function placement(position, pageW, pageH, textW) {
    const isTop = position.startsWith('top');
    const y = isTop ? pageH - MARGIN - FONT_SIZE : MARGIN;
    let x;
    if (position.endsWith('left')) {
        x = MARGIN;
    } else if (position.endsWith('right')) {
        x = pageW - MARGIN - textW;
    } else { // center
        x = (pageW - textW) / 2;
    }
    // Never let the text run off the left edge on very narrow pages.
    return { x: Math.max(2, x), y: Math.max(2, y) };
}

/** Build a safe download filename for the numbered output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_numbered.pdf`;
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

/** Stamp page numbers onto every page of `pdf` (pdf-lib doc). */
async function stampNumbers(PDFLib, pdf, position, fmt, start) {
    const { StandardFonts, rgb } = PDFLib;
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const color = rgb(0.25, 0.25, 0.25);
    const pages = pdf.getPages();
    const total = pages.length;

    pages.forEach((page, i) => {
        const { width, height } = page.getSize();
        const label = formatLabel(fmt, i, total, start);
        const textW = font.widthOfTextAtSize(label, FONT_SIZE);
        const { x, y } = placement(position, width, height, textW);
        page.drawText(label, { x, y, size: FONT_SIZE, font, color });
    });
}

/** Apply page numbers to a copy of the open PDF and download it. */
async function applyPageNumbers() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[page-numbers] window.PDFLib unavailable');
        return;
    }
    const position = (positionSel && positionSel.value) || 'bottom-center';
    const fmt = (formatSel && formatSel.value) || 'plain';
    const start = readStart();

    setStatus('Adding page numbers…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        await stampNumbers(PDFLib, pdf, position, fmt, start);

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = pdf.getPageCount();
        setStatus(`Numbered ${n} page${n === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[page-numbers] apply failed:', err);
        setStatus('Failed to add page numbers. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to add page numbers.', error: err });
    } finally {
        if (applyBtn) applyBtn.disabled = !(currentDoc && numPages > 0);
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    setEnabled(numPages > 0);
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Choose options and apply.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initPageNumbers() {
    positionSel = document.getElementById('pagenum-position');
    formatSel = document.getElementById('pagenum-format');
    startInput = document.getElementById('pagenum-start');
    applyBtn = document.getElementById('pagenum-apply');
    statusEl = document.getElementById('pagenum-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('pagenum.apply', {
        title: 'Add page numbers',
        run: () => applyPageNumbers(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
