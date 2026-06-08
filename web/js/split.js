// split.js — Split / Extract page range.
//
// Lets the user pull a contiguous page range out of the open PDF and download
// it as a brand-new PDF, entirely client-side (pdf-lib). The original document
// in the viewer is never modified; nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout. The
// raw PDF bytes come from pdf.js' own `doc.getData()` so we don't have to reach
// into viewer.js' private buffer.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let startInput = null;
let endInput = null;
let extractBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [startInput, endInput, extractBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Build a safe download filename for the extracted range. */
function buildFileName(start, end) {
    // Strip any extension off the source name, drop unsafe chars, then suffix.
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    const range = start === end ? `page_${start}` : `pages_${start}-${end}`;
    return `${base}_${range}.pdf`;
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

/**
 * Read the start/end inputs and return a validated { start, end } (1-based,
 * inclusive) or null after showing an error message.
 */
function readRange() {
    const start = parseInt(startInput && startInput.value, 10);
    const end = parseInt(endInput && endInput.value, 10);
    if (!Number.isInteger(start) || !Number.isInteger(end)) {
        setStatus('Enter a valid page range.', true);
        return null;
    }
    if (start < 1 || end < 1 || start > numPages || end > numPages) {
        setStatus(`Pages must be between 1 and ${numPages}.`, true);
        return null;
    }
    if (start > end) {
        setStatus('Start page must not be after the end page.', true);
        return null;
    }
    return { start, end };
}

/** Extract the chosen range into a new PDF and download it. */
async function extractRange() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[split] window.PDFLib unavailable');
        return;
    }
    const range = readRange();
    if (!range) return;
    const { start, end } = range;

    setStatus('Extracting…');
    if (extractBtn) extractBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // copyPages expects 0-based indices; build the inclusive range.
        const indices = [];
        for (let i = start - 1; i <= end - 1; i++) indices.push(i);
        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((p) => outPdf.addPage(p));

        const outBytes = await outPdf.save();
        const fileName = buildFileName(start, end);
        downloadBytes(outBytes, fileName);

        const count = end - start + 1;
        setStatus(`Extracted ${count} page${count === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[split] extract failed:', err);
        setStatus('Failed to extract pages. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to extract pages.', error: err });
    } finally {
        if (extractBtn) extractBtn.disabled = false;
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (startInput) {
        startInput.max = String(numPages);
        startInput.value = '1';
    }
    if (endInput) {
        endInput.max = String(numPages);
        endInput.value = String(numPages);
    }
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (startInput) startInput.value = '1';
    if (endInput) endInput.value = '1';
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initSplit() {
    startInput = document.getElementById('split-start');
    endInput = document.getElementById('split-end');
    extractBtn = document.getElementById('split-extract');
    statusEl = document.getElementById('split-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('split.extract', {
        title: 'Extract page range',
        run: () => extractRange(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
