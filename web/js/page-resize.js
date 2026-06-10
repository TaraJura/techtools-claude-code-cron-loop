// page-resize.js — Re-page the open PDF so every page becomes one standard size.
//
// Lets the user normalize a PDF with mixed/odd page sizes to a single chosen
// paper size (A4 / US Letter / US Legal) and orientation (Portrait / Landscape /
// "Keep each page's orientation"), then download the result as a brand-new PDF,
// entirely client-side (pdf-lib). Unlike Crop (TASK-335, which only shrinks the
// visible crop box) this changes the actual MEDIA box: each original page is
// embedded onto a fresh fixed-size page, scaled-to-fit (uniform scale, aspect
// preserved) and centered (letterbox margins), so content is never stretched or
// clipped. The document in the viewer is never modified; nothing is uploaded.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, or any sibling tool module (split/merge/watermark/pages/
// page-numbers/bates/convert/crop). The raw PDF bytes come from pdf.js' own
// `doc.getData()` so we don't reach into viewer.js' private buffer. No
// user-controlled string ever reaches innerHTML — only pdf-lib and
// `textContent` (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

// Standard paper sizes in PDF points (72 pt / inch), expressed PORTRAIT
// (width <= height). Landscape just swaps the two.
const PAPER_SIZES = {
    a4:     { w: 595, h: 842 },   // ISO A4   (210 × 297 mm)
    letter: { w: 612, h: 792 },   // US Letter (8.5 × 11 in)
    legal:  { w: 612, h: 1008 },  // US Legal  (8.5 × 14 in)
};

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let sizeSel = null;
let orientSel = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [sizeSel, orientSel, applyBtn].forEach((el) => {
        if (el) {
            el.disabled = !enabled;
            el.setAttribute('aria-disabled', String(!enabled));
        }
    });
}

/**
 * Resolve the target page dimensions for a source page of size srcW×srcH.
 * For "keep" orientation, pick portrait vs landscape from the source page's
 * own aspect ratio so a landscape source lands on a landscape target.
 */
function targetDimsFor(base, orientation, srcW, srcH) {
    let landscape;
    if (orientation === 'portrait') landscape = false;
    else if (orientation === 'landscape') landscape = true;
    else landscape = srcW > srcH; // "keep"
    return landscape
        ? { w: base.h, h: base.w }
        : { w: base.w, h: base.h };
}

/** Build a safe download filename for the resized output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_resized.pdf`;
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
 * Embed every page of `srcPdf` onto a fresh fixed-size page in a NEW document,
 * scaled-to-fit and centered. Returns the new PDFDocument.
 */
async function resizeAllPages(PDFLib, srcPdf, base, orientation) {
    const out = await PDFLib.PDFDocument.create();
    const srcPages = srcPdf.getPages();

    for (let i = 0; i < srcPages.length; i++) {
        const src = srcPages[i];
        // Embed the source page; the embedded page's own width/height reflect
        // its crop box — the region a viewer actually shows.
        const embedded = await out.embedPage(src);
        const srcW = embedded.width;
        const srcH = embedded.height;

        const { w: targetW, h: targetH } = targetDimsFor(base, orientation, srcW, srcH);
        const page = out.addPage([targetW, targetH]);

        // Uniform scale preserves aspect ratio (letterbox); guard tiny pages.
        const scale = Math.min(targetW / srcW, targetH / srcH) || 1;
        const drawW = srcW * scale;
        const drawH = srcH * scale;
        const x = (targetW - drawW) / 2;
        const y = (targetH - drawH) / 2;

        page.drawPage(embedded, { x, y, width: drawW, height: drawH });
    }

    return out;
}

/** Resize a copy of the open PDF and download it. */
async function applyResize() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[page-resize] window.PDFLib unavailable');
        return;
    }

    const sizeKey = (sizeSel && sizeSel.value) || 'a4';
    const base = PAPER_SIZES[sizeKey] || PAPER_SIZES.a4;
    const orientation = (orientSel && orientSel.value) || 'portrait';

    setStatus('Resizing pages…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const out = await resizeAllPages(PDFLib, srcPdf, base, orientation);

        const outBytes = await out.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = out.getPageCount();
        const sizeLabel = sizeKey.toUpperCase();
        setStatus(`Resized ${n} page${n === 1 ? '' : 's'} → ${sizeLabel} → ${fileName}`);
    } catch (err) {
        console.error('[page-resize] apply failed:', err);
        setStatus('Failed to resize pages. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to resize pages.', error: err });
    } finally {
        if (applyBtn) applyBtn.disabled = !(currentDoc && numPages > 0);
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    setEnabled(numPages > 0);
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Pick a size and resize.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initPageResize() {
    sizeSel = document.getElementById('resize-size');
    orientSel = document.getElementById('resize-orient');
    applyBtn = document.getElementById('resize-apply');
    statusEl = document.getElementById('resize-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('resize.apply', {
        title: 'Resize pages',
        run: () => applyResize(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
