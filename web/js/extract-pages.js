// extract-pages.js — Extract pages (keep an arbitrary, possibly-reordered set).
//
// The direct counterpart of delete-pages.js: instead of naming the pages to
// REMOVE, the user names the pages/ranges to KEEP (e.g. "1, 3, 5-7") and we
// build a brand-new PDF containing ONLY those pages, IN THE ORDER THE USER
// LISTED THEM (so "3, 1" yields a 2-page PDF with the original page 3 first).
// Unlike split.js (a single contiguous range), this handles arbitrary,
// reordered, even repeated selections. Runs entirely client-side with pdf-lib;
// the open viewer document is never mutated and nothing is uploaded.
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

let keepInput = null;
let extractBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [keepInput, extractBtn].forEach((el) => {
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

/**
 * Parse a page-list / multi-range expression like "1, 3, 5-7" into an ORDERED
 * Array of 1-based page numbers to keep. Unlike delete-pages' parser this
 * preserves order AND duplicates exactly as typed — "5-7, 1" → [5,6,7,1] and
 * "1, 1" → [1,1] — because for Extract the listed order is the output order.
 * A descending range like "5-3" expands descending → [5,4,3]. Returns
 * { pages: number[] } on success or { error } with a specific message naming
 * the problem. Empty tokens (e.g. "1,,3") are tolerated and skipped.
 */
function parsePageList(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (!trimmed) return { error: 'Enter pages to extract, e.g. 1, 3, 5-7.' };

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
        if (a < 1 || b < 1) return { error: `"${token}" is not a valid page or range.` };
        if (a > max || b > max) {
            return { error: `Page ${Math.max(a, b)} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
        }
        // Preserve direction: "5-7" → 5,6,7 ; "7-5" → 7,6,5.
        if (a <= b) {
            for (let i = a; i <= b; i++) pages.push(i);
        } else {
            for (let i = a; i >= b; i--) pages.push(i);
        }
    }

    if (pages.length === 0) return { error: 'Enter pages to extract, e.g. 1, 3, 5-7.' };
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

/** Keep only the chosen pages, in listed order, and download the result. */
async function extractPages() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[extract-pages] window.PDFLib unavailable');
        return;
    }

    const parsed = parsePageList(keepInput ? keepInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const keep = parsed.pages; // ordered, may contain duplicates

    setStatus('Extracting…');
    if (extractBtn) extractBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // copyPages expects 0-based indices; preserve the exact listed order.
        const indices = keep.map((p) => p - 1);
        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((p) => outPdf.addPage(p));

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_extracted.pdf`;
        downloadBytes(outBytes, fileName);

        setStatus(
            `Extracted ${keep.length} page${keep.length === 1 ? '' : 's'} → ${fileName}`
        );
    } catch (err) {
        console.error('[extract-pages] extract failed:', err);
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
    if (keepInput) keepInput.value = '';
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (keepInput) keepInput.value = '';
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initExtractPages() {
    keepInput = document.getElementById('extract-input');
    extractBtn = document.getElementById('extract-run');
    statusEl = document.getElementById('extract-status');

    // Pressing Enter in the input triggers the extraction.
    if (keepInput) {
        keepInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                extractPages();
            }
        });
    }

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('extract.run', {
        title: 'Extract pages',
        run: () => extractPages(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
