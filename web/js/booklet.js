// booklet.js — Booklet: saddle-stitch imposition for print-and-fold booklets.
//
// Rearranges the open document's pages onto landscape 2-up sheet-faces in the
// special order that — when the output is printed double-sided (flip on the
// short edge) and the stack is folded in half — yields a correctly-ordered
// booklet. The page count is padded to the next multiple of 4 with blank
// leaves; the output PDF has ceil(srcPages / 4) * 2 landscape pages (one per
// printed side), then it downloads (e.g. example_booklet.pdf).
//
// This is DISTINCT from N-up (nup.js): N-up tiles pages in plain reading order
// to save paper, whereas a booklet REORDERS pages into print signatures so the
// folded result reads in sequence. Example, 4-page doc → 2 faces: [4,1], [2,3].
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

let runBtn = null;
let statusEl = null;

// Sheet geometry (points): margin around the sheet + gutter between the two
// cells so the folded pages never touch the spine. Same convention as nup.js.
const MARGIN = 18;
const GUTTER = 14;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
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
 * Compute the saddle-stitch face order for `padded` pages (a multiple of 4).
 * Returns an array of [leftIndex, rightIndex] pairs (0-based source indices;
 * an index >= numPages is a blank padding leaf). Two pointers walk inward; the
 * front face of each physical sheet places [last, first], the back face places
 * [first+1, last-1], and so on — the classic booklet imposition.
 *   4 pages → [[3,0],[1,2]]   (i.e. pages [4,1] then [2,3])
 *   8 pages → [[7,0],[1,6],[5,2],[3,4]]
 */
function bookletFaces(padded) {
    const faces = [];
    let lo = 0;
    let hi = padded - 1;
    let face = 0;
    while (lo < hi) {
        if (face % 2 === 0) {
            faces.push([hi, lo]); // front of a sheet: outer-left = last, right = first
        } else {
            faces.push([lo, hi]); // back of the same sheet
        }
        lo++;
        hi--;
        face++;
    }
    return faces;
}

/**
 * Build the booklet PDF and download it. The cell footprint comes from the
 * first source page; each landscape face holds two cells (2×1). Every real
 * page is scaled UNIFORMLY into its cell (aspect ratio preserved) and centred;
 * blank padding cells are left empty (never an error).
 */
async function runBooklet() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[booklet] window.PDFLib unavailable');
        return;
    }

    setStatus('Building booklet…');
    if (runBtn) runBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const outPdf = await PDFLib.PDFDocument.create();

        const srcPages = srcPdf.getPages();
        const realCount = srcPages.length;

        // Cell footprint = first source page (A4-ish convention, like N-up).
        const cellW = srcPages[0].getWidth();
        const cellH = srcPages[0].getHeight();

        // Landscape face: two cells side-by-side.
        const sheetW = 2 * cellW + GUTTER + 2 * MARGIN;
        const sheetH = cellH + 2 * MARGIN;

        // Embed every real source page once; embedded[i] aligns with page i.
        const embedded = await outPdf.embedPages(srcPages);

        const padded = Math.ceil(realCount / 4) * 4;
        const faces = bookletFaces(padded);

        for (const [leftIdx, rightIdx] of faces) {
            const sheet = outPdf.addPage([sheetW, sheetH]);
            const cellIndexes = [leftIdx, rightIdx]; // slot 0 = left, slot 1 = right
            for (let slot = 0; slot < 2; slot++) {
                const srcIndex = cellIndexes[slot];
                if (srcIndex >= realCount) continue; // blank padding leaf

                const cellX = MARGIN + slot * (cellW + GUTTER);
                const cellY = MARGIN; // single row, sits above the bottom margin

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
        const fileName = `${baseName()}_booklet.pdf`;
        downloadBytes(outBytes, fileName);
        const out = faces.length;
        setStatus(`Booklet: ${realCount} page${realCount === 1 ? '' : 's'} → ${out} landscape sheet-side${out === 1 ? '' : 's'} (${fileName}). Print double-sided, flip on the short edge, then fold.`);
    } catch (err) {
        console.error('[booklet] Booklet build failed:', err);
        setStatus('Failed to build the booklet. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to build the booklet.', error: err });
    } finally {
        if (runBtn) runBtn.disabled = !(numPages > 0);
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

export function initBooklet() {
    runBtn = document.getElementById('booklet-run');
    statusEl = document.getElementById('booklet-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="booklet"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runBooklet();
            }
        });
    }

    ActionRegistry.register('booklet.run', {
        title: 'Booklet (saddle-stitch imposition)',
        run: () => runBooklet(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
