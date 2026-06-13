// burst.js — Burst / Split to single pages: explode the open PDF into ONE
// single-page PDF per page and deliver them all as a single ZIP download
// (e.g. document-pages.zip containing page-001.pdf, page-002.pdf, …).
//
// Distinct from Split (split.js — contiguous ranges → a few multi-page PDFs)
// and Extract pages (extract-pages.js — a chosen subset → ONE PDF). Burst is
// the "explode a PDF" workflow: one file per page, bundled into a ZIP.
//
// Pure pdf-lib structural copy — for each target page we create a fresh
// PDFDocument, copyPages() that single page, save() to bytes, and add it to the
// archive. NO rasterization, so memory stays low (safe for the 1.6 GiB box);
// each page's original size and rotation are preserved. Pages are processed
// sequentially (await each save) to keep peak memory low.
//
// The ZIP is assembled by a tiny self-contained STORE-only writer (zip-writer.js)
// rather than a third-party library: JSZip is not present in lib/ and the CSP is
// `script-src 'self'` (no CDN), so a dependency-free writer is the lowest-risk
// path. PDFs are already compressed, so storing (no deflate) costs almost nothing
// in size. The output is a standards-compliant ZIP (local file headers + central
// directory + EOCD) that any unzip tool — and pdf-lib, after extraction — reads
// cleanly. The writer was factored out (TASK-358) so Burst and Split-into-Chunks
// share one already-verified implementation.
//
// Runs entirely client-side; the open viewer document is never mutated and
// nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout
// (prompt rule 8). The raw PDF bytes come from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import { buildZip, downloadBytes } from './zip-writer.js';

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let rangeInput = null;   // page-range text input ("all" or "1-3,5")
let runBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (rangeInput) rangeInput.disabled = !enabled;
    if (runBtn) runBtn.disabled = !enabled;
}

/** Sanitised base name (no extension, no unsafe chars) for download filenames. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
}

/**
 * Parse the range expression into a sorted array of 1-based page numbers.
 * Empty or "all" (case-insensitive) selects every page. Otherwise accepts a
 * comma list of single pages and ascending/descending ranges, e.g. "1, 3, 5-7".
 * Returns { pages: number[] } (ascending, de-duplicated) on success or
 * { error } with a specific message. Out-of-bounds / malformed tokens are
 * rejected (never silent). Mirrors the helper used by flip-pages.js /
 * extract-pages.js so behaviour is consistent across page tools.
 */
function parseRange(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (trimmed === '' || /^all$/i.test(trimmed)) {
        const all = [];
        for (let i = 1; i <= max; i++) all.push(i);
        return { pages: all };
    }

    const set = new Set();
    for (const raw of trimmed.split(',')) {
        const token = raw.trim();
        if (!token) continue; // tolerate stray/empty commas

        if (/^\d+$/.test(token)) {
            const n = parseInt(token, 10);
            if (n < 1) return { error: `"${token}" is not a valid page or range.` };
            if (n > max) return { error: `Page ${n} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
            set.add(n);
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
        for (let i = lo; i <= hi; i++) set.add(i);
    }

    if (set.size === 0) return { error: 'Enter pages to burst, e.g. all or 1, 3, 5-7.' };
    return { pages: Array.from(set).sort((x, y) => x - y) };
}

/**
 * Burst the open PDF: one single-page PDF per selected page, bundled into a ZIP.
 * Each page is copied (structural, no rasterization) into a fresh PDFDocument
 * and saved to bytes; filenames are zero-padded and reflect the ORIGINAL page
 * numbers. Pages are processed sequentially to keep peak memory low.
 */
async function runBurst() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[burst] window.PDFLib unavailable');
        return;
    }

    const parsed = parseRange(rangeInput ? rangeInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const targets = parsed.pages; // ascending 1-based page numbers

    setStatus('Bursting…');
    setEnabled(false);
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them once.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);

        // Zero-pad to the width of the largest page number in the whole document
        // so filenames sort correctly (page-001.pdf … page-010.pdf).
        const pad = String(numPages).length;
        const entries = [];

        for (let idx = 0; idx < targets.length; idx++) {
            const pageNo = targets[idx]; // 1-based, original numbering
            const onePage = await PDFLib.PDFDocument.create();
            const [copied] = await onePage.copyPages(srcPdf, [pageNo - 1]);
            onePage.addPage(copied);
            const bytes = await onePage.save();
            const fileName = `page-${String(pageNo).padStart(pad, '0')}.pdf`;
            entries.push({ name: fileName, data: bytes });
            setStatus(`Bursting… ${idx + 1}/${targets.length}`);
        }

        const zipBytes = buildZip(entries);
        const zipName = `${baseName()}-pages.zip`;
        downloadBytes(zipBytes, zipName, 'application/zip');

        const n = entries.length;
        setStatus(`Burst ${n} page${n === 1 ? '' : 's'} into ${zipName} (one PDF per page).`);
    } catch (err) {
        console.error('[burst] Burst failed:', err);
        setStatus('Failed to burst the PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to burst the PDF.', error: err });
    } finally {
        setEnabled(numPages > 0);
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

export function initBurst() {
    rangeInput = document.getElementById('burst-range');
    runBtn = document.getElementById('burst-run');
    statusEl = document.getElementById('burst-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="burst"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runBurst();
            }
        });
    }

    ActionRegistry.register('burst.run', {
        title: 'Burst PDF into one single-page PDF per page (ZIP)',
        run: () => runBurst(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
