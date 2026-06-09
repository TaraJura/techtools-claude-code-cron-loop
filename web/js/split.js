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

let rangesInput = null;
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
    [rangesInput, startInput, endInput, extractBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Sanitised base name (no extension, no unsafe chars) for download filenames. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
}

/** Build a safe download filename for a contiguous From/To range. */
function buildFileName(start, end) {
    const range = start === end ? `page_${start}` : `pages_${start}-${end}`;
    return `${baseName()}_${range}.pdf`;
}

/** Build a safe download filename for a page-list / multi-range extraction. */
function buildListFileName(pages) {
    if (pages.length === 1) return `${baseName()}_page_${pages[0]}.pdf`;
    return `${baseName()}_pages.pdf`;
}

/**
 * Parse a page-list / multi-range expression like "1-3, 5, 8-10" into an
 * ordered list of 1-based page numbers. Returns { pages } on success or
 * { error } with a specific message naming the problem. Duplicates are kept
 * (a page listed twice is copied twice); empty tokens (e.g. "1,,3") are
 * tolerated and skipped.
 */
function parsePageList(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (!trimmed) return { error: 'Enter pages to extract, e.g. 1-3, 5.' };

    const pages = [];
    for (const raw of trimmed.split(',')) {
        const token = raw.trim();
        if (!token) continue; // tolerate stray/empty commas

        if (/^\d+$/.test(token)) {
            const n = parseInt(token, 10);
            if (n < 1) return { error: `"${token}" is not a valid page or range.` };
            if (n > max) return { error: `Page ${n} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
            pages.push(n);
            continue;
        }

        const m = token.match(/^(\d+)\s*-\s*(\d+)$/);
        if (!m) return { error: `"${token}" is not a valid page or range.` };
        const a = parseInt(m[1], 10);
        const b = parseInt(m[2], 10);
        if (a < 1 || b < 1 || a > b) return { error: `"${token}" is not a valid page or range.` };
        if (a > max || b > max) {
            return { error: `Page ${Math.max(a, b)} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
        }
        for (let i = a; i <= b; i++) pages.push(i);
    }

    if (pages.length === 0) return { error: 'Enter pages to extract, e.g. 1-3, 5.' };
    return { pages };
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
    // The page-list / multi-range input is the primary control. When it has
    // content, parse it; otherwise fall back to the contiguous From/To range
    // (preserves the original TASK-315 behaviour).
    const listExpr = rangesInput ? rangesInput.value.trim() : '';
    let pages;       // ordered 1-based page numbers to extract
    let fileName;
    if (listExpr) {
        const parsed = parsePageList(listExpr, numPages);
        if (parsed.error) {
            setStatus(parsed.error, true);
            return;
        }
        pages = parsed.pages;
        fileName = buildListFileName(pages);
    } else {
        const range = readRange();
        if (!range) return;
        pages = [];
        for (let i = range.start; i <= range.end; i++) pages.push(i);
        fileName = buildFileName(range.start, range.end);
    }

    setStatus('Extracting…');
    if (extractBtn) extractBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // copyPages expects 0-based indices; preserve the requested order.
        const indices = pages.map((p) => p - 1);
        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((p) => outPdf.addPage(p));

        const outBytes = await outPdf.save();
        downloadBytes(outBytes, fileName);

        const count = pages.length;
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
    if (rangesInput) rangesInput.value = '';
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (rangesInput) rangesInput.value = '';
    if (startInput) startInput.value = '1';
    if (endInput) endInput.value = '1';
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initSplit() {
    rangesInput = document.getElementById('split-ranges');
    startInput = document.getElementById('split-start');
    endInput = document.getElementById('split-end');
    extractBtn = document.getElementById('split-extract');
    statusEl = document.getElementById('split-status');

    // Pressing Enter in the page-list input triggers extraction.
    if (rangesInput) {
        rangesInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                extractRange();
            }
        });
    }

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('split.extract', {
        title: 'Extract page range',
        run: () => extractRange(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
