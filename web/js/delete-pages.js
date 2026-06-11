// delete-pages.js — Delete pages (remove a set of pages, keep the rest).
//
// The inverse of split.js' Extract: instead of KEEPING a range, the user names
// the pages/ranges to REMOVE (e.g. "1, 3-5, 8") and we build a brand-new PDF
// containing every OTHER page in its original order, then download it. Runs
// entirely client-side with pdf-lib; the open viewer document is never mutated
// and nothing is uploaded to the server.
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

let removeInput = null;
let deleteBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [removeInput, deleteBtn].forEach((el) => {
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
 * Parse a page-list / multi-range expression like "1, 3-5, 8" into a Set of
 * 1-based page numbers to remove. Returns { pages: Set } on success or
 * { error } with a specific message naming the problem. Empty tokens
 * (e.g. "1,,3") are tolerated and skipped. Mirrors split.js' parser so the two
 * tools accept identical syntax.
 */
function parsePageSet(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (!trimmed) return { error: 'Enter pages to delete, e.g. 1, 3-5.' };

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
        if (a < 1 || b < 1 || a > b) return { error: `"${token}" is not a valid page or range.` };
        if (a > max || b > max) {
            return { error: `Page ${Math.max(a, b)} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
        }
        for (let i = a; i <= b; i++) pages.add(i);
    }

    if (pages.size === 0) return { error: 'Enter pages to delete, e.g. 1, 3-5.' };
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

/** Remove the chosen pages, keep the rest, and download the result. */
async function deletePages() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[delete-pages] window.PDFLib unavailable');
        return;
    }

    const parsed = parsePageSet(removeInput ? removeInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const toRemove = parsed.pages;

    // The surviving pages, in original order. Guard: a PDF needs ≥1 page.
    const keep = [];
    for (let p = 1; p <= numPages; p++) {
        if (!toRemove.has(p)) keep.push(p);
    }
    if (keep.length === 0) {
        setStatus('Cannot delete every page — at least one page must remain.', true);
        return;
    }

    const removedCount = numPages - keep.length;
    setStatus('Deleting…');
    if (deleteBtn) deleteBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        // copyPages expects 0-based indices; preserve original order.
        const indices = keep.map((p) => p - 1);
        const copied = await outPdf.copyPages(srcPdf, indices);
        copied.forEach((p) => outPdf.addPage(p));

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_deleted.pdf`;
        downloadBytes(outBytes, fileName);

        setStatus(
            `Removed ${removedCount} page${removedCount === 1 ? '' : 's'}, ` +
            `${keep.length} remaining → ${fileName}`
        );
    } catch (err) {
        console.error('[delete-pages] delete failed:', err);
        setStatus('Failed to delete pages. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to delete pages.', error: err });
    } finally {
        if (deleteBtn) deleteBtn.disabled = false;
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (removeInput) removeInput.value = '';
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : '');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (removeInput) removeInput.value = '';
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initDeletePages() {
    removeInput = document.getElementById('delpages-input');
    deleteBtn = document.getElementById('delpages-delete');
    statusEl = document.getElementById('delpages-status');

    // Pressing Enter in the input triggers the deletion.
    if (removeInput) {
        removeInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                deletePages();
            }
        });
    }

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('delpages.run', {
        title: 'Delete pages',
        run: () => deletePages(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
