// flip-pages.js — Flip / Mirror pages: horizontally and/or vertically mirror
// every page (or a chosen page range) of the open PDF and download the result.
//
// Useful for correcting mirrored scans, transparency / iron-on printing, and
// back-lit originals. This is a MIRROR REFLECTION, not a rotation (that is
// Rotate / pages.js, TASK-328) and not an imposition layout (N-up / Margins /
// Booklet).
//
// Pure pdf-lib structural imposition: for each target page we embed the source
// page and draw it onto a same-size new page with a mirrored transform —
//   Horizontal: xScale -1, x offset = pageWidth   (left↔right)
//   Vertical:   yScale -1, y offset = pageHeight   (top↔bottom)
// Both: scale -1 on both axes with both offsets. No rasterization, so memory
// stays low (safe for the 1.6 GiB box). Page size and order are preserved;
// pages outside the chosen range are copied through unchanged.
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

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let hInput = null;       // "Flip horizontal" checkbox
let vInput = null;       // "Flip vertical" checkbox
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
    if (hInput) hInput.disabled = !enabled;
    if (vInput) vInput.disabled = !enabled;
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
 * Parse the range expression into a Set of 1-based page numbers to flip.
 * Empty or "all" (case-insensitive) selects every page. Otherwise accepts a
 * comma list of single pages and ascending/descending ranges, e.g. "1, 3, 5-7".
 * Returns { pages: Set<number> } on success or { error } with a specific
 * message. Out-of-bounds / malformed tokens are rejected (never silent).
 */
function parseRange(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (trimmed === '' || /^all$/i.test(trimmed)) {
        const all = new Set();
        for (let i = 1; i <= max; i++) all.add(i);
        return { pages: all };
    }

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

    if (pages.size === 0) return { error: 'Enter pages to flip, e.g. all or 1, 3, 5-7.' };
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
 * Build the flipped PDF and download it. Every page is copied onto a new
 * same-size page; pages in the chosen set are drawn with a mirrored transform,
 * the rest are drawn straight (1:1). This preserves page count, size and order.
 */
async function runFlip() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[flip-pages] window.PDFLib unavailable');
        return;
    }

    const flipH = !!(hInput && hInput.checked);
    const flipV = !!(vInput && vInput.checked);
    if (!flipH && !flipV) {
        setStatus('Choose at least one direction: flip horizontal and/or vertical.', true);
        return;
    }

    const parsed = parseRange(rangeInput ? rangeInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const targets = parsed.pages; // Set of 1-based pages to flip

    setStatus('Flipping…');
    setEnabled(false);
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        const srcPages = srcPdf.getPages();
        for (let i = 0; i < srcPages.length; i++) {
            const src = srcPages[i];
            const w = src.getWidth();
            const h = src.getHeight();
            const outPage = outPdf.addPage([w, h]);
            const embedded = await outPdf.embedPage(src);

            if (targets.has(i + 1)) {
                // Mirror: a negative scale reflects the axis; the offset shifts
                // the reflected content back into the visible page box.
                outPage.drawPage(embedded, {
                    x: flipH ? w : 0,
                    y: flipV ? h : 0,
                    xScale: flipH ? -1 : 1,
                    yScale: flipV ? -1 : 1,
                });
            } else {
                outPage.drawPage(embedded, { x: 0, y: 0, xScale: 1, yScale: 1 });
            }
        }

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_flipped.pdf`;
        downloadBytes(outBytes, fileName);

        const dir = flipH && flipV ? 'horizontally & vertically' : flipH ? 'horizontally' : 'vertically';
        const count = targets.size;
        setStatus(`Flipped ${count} page${count === 1 ? '' : 's'} ${dir} → ${fileName}`);
    } catch (err) {
        console.error('[flip-pages] Flip failed:', err);
        setStatus('Failed to flip pages. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to flip pages.', error: err });
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

export function initFlipPages() {
    hInput = document.getElementById('flip-horizontal');
    vInput = document.getElementById('flip-vertical');
    rangeInput = document.getElementById('flip-range');
    runBtn = document.getElementById('flip-run');
    statusEl = document.getElementById('flip-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="flip"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runFlip();
            }
        });
    }

    ActionRegistry.register('flip.run', {
        title: 'Flip / mirror pages (horizontal / vertical)',
        run: () => runFlip(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
