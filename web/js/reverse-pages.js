// reverse-pages.js — Reverse page order (flip the open PDF back-to-front).
//
// A single-click operation: builds a brand-new PDF whose pages are in the exact
// reverse of the open document (last page first … first page last) and
// downloads it. The natural missing member of the page-tools family
// (rotate pages.js, delete delete-pages.js, extract extract-pages.js,
// split split.js, interleave interleave.js). The standard fix for a stack
// scanned upside-down / back-to-front, or for converting a right-to-left
// binding to left-to-right. Runs entirely client-side with pdf-lib; the open
// viewer document is never mutated and nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout
// (prompt rule 8). The raw PDF bytes come from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let reverseBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (reverseBtn) reverseBtn.disabled = !enabled;
}

/** Sanitised base name (no extension, no unsafe chars) for download filenames. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
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

/** Reverse the page order of the open document and download the result. */
async function reversePages() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[reverse-pages] window.PDFLib unavailable');
        return;
    }

    setStatus('Reversing…');
    if (reverseBtn) reverseBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // copyPages expects 0-based indices, in descending order n-1 … 0 so the
        // last source page becomes the first output page. A 1-page document
        // yields [0] and reverses to itself — still a valid 1-page download.
        const indices = [];
        for (let i = numPages - 1; i >= 0; i--) indices.push(i);
        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((p) => outPdf.addPage(p));

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_reversed.pdf`;
        downloadBytes(outBytes, fileName);

        if (numPages === 1) {
            setStatus('1 page — order unchanged.');
        } else {
            setStatus(`Reversed ${numPages} pages → ${fileName}`);
        }
    } catch (err) {
        console.error('[reverse-pages] reverse failed:', err);
        setStatus('Failed to reverse pages. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to reverse pages.', error: err });
    } finally {
        if (reverseBtn) reverseBtn.disabled = numPages === 0;
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Open a PDF first.');
}

export function initReversePages() {
    reverseBtn = document.getElementById('reverse-run');
    statusEl = document.getElementById('reverse-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    ActionRegistry.register('reverse.run', {
        title: 'Reverse pages',
        run: () => reversePages(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
