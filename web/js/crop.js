// crop.js — Trim a uniform margin off every page of the open PDF.
//
// Lets the user shrink each page's PDF *crop box* by a chosen margin on all
// four sides and download the result as a brand-new PDF, entirely client-side
// (pdf-lib). Cropping the crop box is non-destructive — the underlying page
// content is untouched, only the visible/printable region changes — so it is
// safe and reversible by re-cropping with a negative-equivalent (re-upload).
// The document in the viewer is never modified; nothing is uploaded.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, split.js, merge.js, watermark.js, pages.js, page-numbers.js,
// bates.js, or convert.js. The raw PDF bytes come from pdf.js' own
// `doc.getData()` so we don't reach into viewer.js' private buffer. No
// user-controlled string ever reaches innerHTML — only pdf-lib and
// `textContent` (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

// Point conversions (PDF user space is 72 points / inch).
const UNIT_TO_PT = {
    mm: 72 / 25.4,   // 1 mm  ≈ 2.8346 pt
    pt: 1,
    in: 72,          // 1 inch = 72 pt
};
const MAX_MARGIN_PT = 5000; // generous absolute cap; per-page clamp does the real work
const MIN_SIDE_PT = 1;      // a crop box must keep at least this width/height

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let marginInput = null;
let unitSel = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [marginInput, unitSel, applyBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Read & clamp the margin control to a finite, non-negative point value. */
function readMarginPt() {
    const raw = parseFloat(marginInput && marginInput.value);
    if (!Number.isFinite(raw) || raw < 0) return 0;
    const unit = (unitSel && unitSel.value) || 'mm';
    const factor = UNIT_TO_PT[unit] || 1;
    return Math.min(raw * factor, MAX_MARGIN_PT);
}

/** Build a safe download filename for the cropped output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_cropped.pdf`;
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
 * Shrink the crop box of every page by `marginPt` on all sides.
 * Returns { cropped, clamped } counts so the caller can report if the margin
 * was too large for some pages and had to be capped.
 */
function cropAllPages(pdf, marginPt) {
    const pages = pdf.getPages();
    let clamped = 0;

    pages.forEach((page) => {
        // Base the crop on the CURRENT crop box (falls back to the media box
        // inside pdf-lib if no explicit crop box is set), so re-cropping or
        // pages with an existing crop box behave correctly.
        const box = page.getCropBox(); // { x, y, width, height } in PDF points
        // Largest margin that still leaves >= MIN_SIDE_PT on each axis.
        const maxM = Math.max(0, Math.min(
            (box.width - MIN_SIDE_PT) / 2,
            (box.height - MIN_SIDE_PT) / 2,
        ));
        const eff = Math.min(marginPt, maxM);
        if (eff < marginPt) clamped += 1;

        page.setCropBox(
            box.x + eff,
            box.y + eff,
            box.width - 2 * eff,
            box.height - 2 * eff,
        );
    });

    return { cropped: pages.length, clamped };
}

/** Crop a copy of the open PDF and download it. */
async function applyCrop() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[crop] window.PDFLib unavailable');
        return;
    }
    const marginPt = readMarginPt();
    if (marginPt <= 0) {
        setStatus('Enter a margin greater than 0 to crop.', true);
        return;
    }

    setStatus('Cropping pages…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        const { cropped, clamped } = cropAllPages(pdf, marginPt);

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        let msg = `Cropped ${cropped} page${cropped === 1 ? '' : 's'} → ${fileName}`;
        if (clamped > 0) {
            msg += ` (margin capped on ${clamped} small page${clamped === 1 ? '' : 's'})`;
        }
        setStatus(msg);
    } catch (err) {
        console.error('[crop] apply failed:', err);
        setStatus('Failed to crop pages. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to crop pages.', error: err });
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
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Set a margin and crop.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initCrop() {
    marginInput = document.getElementById('crop-margin');
    unitSel = document.getElementById('crop-unit');
    applyBtn = document.getElementById('crop-apply');
    statusEl = document.getElementById('crop-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('crop.apply', {
        title: 'Crop pages',
        run: () => applyCrop(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
