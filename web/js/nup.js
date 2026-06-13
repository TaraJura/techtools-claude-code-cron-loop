// nup.js — N-up: tile multiple source pages onto each output sheet.
//
// "Multiple pages per sheet" / "2-up / 4-up": the standard way to save paper
// when printing a slide deck or a long document. The user picks a layout —
// 2-up (2 source pages side-by-side on one landscape sheet) or 4-up (a 2×2
// grid on one portrait sheet) — and the tool builds a brand-new PDF where every
// group of N consecutive source pages is scaled-to-fit into the cells of one
// larger sheet, in left-to-right / top-to-bottom reading order, then downloads
// it (e.g. example_2up.pdf). The last sheet is partially filled when the page
// count isn't a multiple of N (leftover cells stay blank — never an error).
//
// Pure pdf-lib structural imposition: embedPages + drawPage, no rasterization
// (low memory, safe for the 1.6 GiB box). Runs entirely client-side; the open
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

let layoutSel = null;
let runBtn = null;
let statusEl = null;

// Sheet geometry (points). Margin around the sheet + gutter between cells so
// tiled pages never touch. Within the 12–18 pt range the spec calls for.
const MARGIN = 18;
const GUTTER = 14;

// Supported layouts → grid shape. 2-up: 2×1 (landscape). 4-up: 2×2 (portrait).
const LAYOUTS = {
    2: { n: 2, cols: 2, rows: 1, suffix: '2up' },
    4: { n: 4, cols: 2, rows: 2, suffix: '4up' },
};

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (layoutSel) layoutSel.disabled = !enabled;
    if (runBtn) runBtn.disabled = !enabled;
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

/**
 * Build the N-up PDF and download it. The output sheet size is derived from the
 * first source page: each grid cell is sized to that page's footprint, and the
 * sheet is cols×cellW / rows×cellH plus margins + gutters — so 2-up sheets come
 * out landscape and 4-up sheets portrait. Every page is scaled UNIFORMLY into
 * its own cell (aspect ratio preserved, never distorted) and centred, so pages
 * of differing sizes each fit their cell independently.
 */
async function runNup() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[nup] window.PDFLib unavailable');
        return;
    }

    const layout = LAYOUTS[Number(layoutSel && layoutSel.value)] || LAYOUTS[2];
    const { n, cols, rows, suffix } = layout;

    setStatus('Building…');
    if (runBtn) runBtn.disabled = true;
    if (layoutSel) layoutSel.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        const srcPages = srcPdf.getPages();
        // Cell footprint comes from the first source page (A4-ish convention).
        const first = srcPages[0];
        const cellW = first.getWidth();
        const cellH = first.getHeight();

        const sheetW = cols * cellW + (cols - 1) * GUTTER + 2 * MARGIN;
        const sheetH = rows * cellH + (rows - 1) * GUTTER + 2 * MARGIN;

        // Embed every source page once; embedded[i] aligns with source page i.
        const embedded = await outPdf.embedPages(srcPages);

        const sheetCount = Math.ceil(numPages / n);
        for (let s = 0; s < sheetCount; s++) {
            const sheet = outPdf.addPage([sheetW, sheetH]);
            for (let slot = 0; slot < n; slot++) {
                const srcIndex = s * n + slot;
                if (srcIndex >= numPages) break; // leftover cells stay blank
                const col = slot % cols;
                const rowFromTop = Math.floor(slot / cols);

                // Cell origin (bottom-left). Top row sits at the highest y since
                // PDF y grows upward; reading order is top-to-bottom.
                const cellX = MARGIN + col * (cellW + GUTTER);
                const cellY = sheetH - MARGIN - (rowFromTop + 1) * cellH - rowFromTop * GUTTER;

                const emb = embedded[srcIndex];
                const pw = emb.width;
                const ph = emb.height;
                // Uniform scale to fit the cell, preserving aspect ratio.
                const scale = Math.min(cellW / pw, cellH / ph);
                const drawnW = pw * scale;
                const drawnH = ph * scale;
                // Centre the page within its cell.
                const x = cellX + (cellW - drawnW) / 2;
                const y = cellY + (cellH - drawnH) / 2;

                sheet.drawPage(emb, { x, y, xScale: scale, yScale: scale });
            }
        }

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_${suffix}.pdf`;
        downloadBytes(outBytes, fileName);
        setStatus(`${n}-up: ${numPages} page${numPages === 1 ? '' : 's'} → ${sheetCount} sheet${sheetCount === 1 ? '' : 's'} (${fileName})`);
    } catch (err) {
        console.error('[nup] N-up failed:', err);
        setStatus('Failed to build the N-up PDF. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to build the N-up PDF.', error: err });
    } finally {
        const open = numPages > 0;
        if (runBtn) runBtn.disabled = !open;
        if (layoutSel) layoutSel.disabled = !open;
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

export function initNup() {
    layoutSel = document.getElementById('nup-layout');
    runBtn = document.getElementById('nup-run');
    statusEl = document.getElementById('nup-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="nup"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !runBtn.disabled) {
                e.preventDefault();
                runNup();
            }
        });
    }

    ActionRegistry.register('nup.run', {
        title: 'N-up (pages per sheet)',
        run: () => runNup(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
