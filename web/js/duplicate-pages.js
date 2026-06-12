// duplicate-pages.js — Duplicate pages (clone selected pages in place).
//
// The user types a page list/range (e.g. "2, 4-5") plus an optional copy count
// (default 1, 1–20). The tool builds a brand-new PDF in which each selected
// page is repeated that many EXTRA times immediately after its original, then
// downloads it. Example on a 5-page doc: duplicating "2" with copies=1 →
// 1,2,2,3,4,5 ; copies=2 → 1,2,2,2,3,4,5. This is the natural missing member of
// the page-tools family (rotate pages.js, delete delete-pages.js, extract
// extract-pages.js, split split.js, interleave interleave.js, reverse
// reverse-pages.js) and the standard fix for "I need three copies of this form
// page in one file" or padding a booklet. It is DISTINCT from Extract (which
// keeps only a subset, reordered) and from a whole-document "print N copies".
// Runs entirely client-side with pdf-lib; the open viewer document is never
// mutated and nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout
// (prompt rule 8). The raw PDF bytes come from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const MAX_COPIES = 20;

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let pagesInput = null;
let copiesInput = null;
let duplicateBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [pagesInput, copiesInput, duplicateBtn].forEach((el) => {
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
 * Parse a page-list / multi-range expression like "2, 4-5" into a Set of
 * 1-based page numbers to duplicate. Order and multiplicity in the input do not
 * matter here — duplicating a page is a set membership test, and the *copy
 * count* controls how many extra copies each gets. Returns { pages: Set } on
 * success or { error } with a specific message naming the problem. Empty tokens
 * (e.g. "2,,4") are tolerated and skipped.
 */
function parsePageSet(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (!trimmed) return { error: 'Enter pages to duplicate, e.g. 2, 4-5.' };

    const pages = new Set();
    for (const raw of trimmed.split(',')) {
        const token = raw.trim();
        if (!token) continue; // tolerate stray/empty commas

        if (/^\d+$/.test(token)) {
            const n = parseInt(token, 10);
            if (n < 1) return { error: `"${token}" is not a valid page or range.` };
            if (n > max) return { error: `Page ${n} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
            pages.add(n);
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
        const lo = Math.min(a, b);
        const hi = Math.max(a, b);
        for (let i = lo; i <= hi; i++) pages.add(i);
    }

    if (pages.size === 0) return { error: 'Enter pages to duplicate, e.g. 2, 4-5.' };
    return { pages };
}

/** Parse + validate the copy count. Returns { copies } or { error }. */
function parseCopies(raw) {
    const token = String(raw == null ? '' : raw).trim();
    // Must be a whole number between 1 and MAX_COPIES.
    if (!/^\d+$/.test(token)) return { error: `Copies must be between 1 and ${MAX_COPIES}.` };
    const n = parseInt(token, 10);
    if (n < 1 || n > MAX_COPIES) return { error: `Copies must be between 1 and ${MAX_COPIES}.` };
    return { copies: n };
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

/** Duplicate the chosen pages in place and download the result. */
async function duplicatePages() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[duplicate-pages] window.PDFLib unavailable');
        return;
    }

    const parsed = parsePageSet(pagesInput ? pagesInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const dupSet = parsed.pages; // Set of 1-based page numbers to duplicate

    const copiesParsed = parseCopies(copiesInput ? copiesInput.value : '1');
    if (copiesParsed.error) {
        setStatus(copiesParsed.error, true);
        return;
    }
    const copies = copiesParsed.copies;

    setStatus('Duplicating…');
    if (duplicateBtn) duplicateBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // Build the full output index list (0-based): walk every page in order,
        // emit the original, then `copies` extra copies of it if it was selected.
        // Copying the same index more than once yields independent page objects.
        const indices = [];
        for (let p = 1; p <= numPages; p++) {
            indices.push(p - 1);
            if (dupSet.has(p)) {
                for (let c = 0; c < copies; c++) indices.push(p - 1);
            }
        }

        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((pg) => outPdf.addPage(pg));

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_duplicated.pdf`;
        downloadBytes(outBytes, fileName);

        const total = indices.length;
        const dupCount = dupSet.size;
        setStatus(
            `Duplicated ${dupCount} page${dupCount === 1 ? '' : 's'} ` +
            `(${copies}× each) → ${total}-page ${fileName}`
        );
    } catch (err) {
        console.error('[duplicate-pages] duplicate failed:', err);
        setStatus('Failed to duplicate pages. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to duplicate pages.', error: err });
    } finally {
        if (duplicateBtn) duplicateBtn.disabled = numPages === 0;
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (pagesInput) pagesInput.value = '';
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (pagesInput) pagesInput.value = '';
    setEnabled(false);
    setStatus('Open a PDF first.');
}

export function initDuplicatePages() {
    pagesInput = document.getElementById('duplicate-input');
    copiesInput = document.getElementById('duplicate-copies');
    duplicateBtn = document.getElementById('duplicate-run');
    statusEl = document.getElementById('duplicate-status');

    // Pressing Enter in either input triggers the duplication.
    [pagesInput, copiesInput].forEach((el) => {
        if (!el) return;
        el.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                duplicatePages();
            }
        });
    });

    setEnabled(false);
    setStatus('Open a PDF first.');

    ActionRegistry.register('duplicate.run', {
        title: 'Duplicate pages',
        run: () => duplicatePages(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
