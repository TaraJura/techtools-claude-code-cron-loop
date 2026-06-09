// watermark.js — Stamp a text watermark across every page of the open PDF.
//
// Lets the user draw a diagonal text watermark over all pages of the currently
// open document and download the result as a brand-new PDF, entirely
// client-side (pdf-lib). The document in the viewer is never modified; nothing
// is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, split.js, merge.js, search.js, or annotate.js. The raw PDF bytes
// come from pdf.js' own `doc.getData()` so we don't reach into viewer.js'
// private buffer. The watermark text only ever reaches pdf-lib `drawText` and
// the status element via `textContent` — never innerHTML (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const MAX_TEXT_LEN = 80;        // sane cap on watermark text length
const ROTATION_DEG = 45;        // diagonal watermark

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let textInput = null;
let opacityInput = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [textInput, opacityInput, applyBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Read & clamp the opacity control to a 0.05–1 fraction (input is a %). */
function readOpacity() {
    const pct = parseInt(opacityInput && opacityInput.value, 10);
    if (!Number.isFinite(pct)) return 0.3;
    return Math.min(1, Math.max(0.05, pct / 100));
}

/** Build a safe download filename for the watermarked output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_watermarked.pdf`;
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

/** Stamp the watermark onto every page of `pdf` (pdf-lib doc). */
async function stampPages(PDFLib, pdf, text, opacity) {
    const { StandardFonts, degrees, rgb } = PDFLib;
    const font = await pdf.embedFont(StandardFonts.HelveticaBold);
    const rad = (ROTATION_DEG * Math.PI) / 180;
    const cos = Math.cos(rad);
    const sin = Math.sin(rad);
    const gray = rgb(0.5, 0.5, 0.5);

    for (const page of pdf.getPages()) {
        const { width, height } = page.getSize();
        // Size the text so it spans most of the page diagonal, but never
        // overflow: shrink until it fits within ~90% of the page width.
        let fontSize = Math.max(12, Math.min(width, height) / 8);
        let textWidth = font.widthOfTextAtSize(text, fontSize);
        const maxSpan = Math.min(width, height) * 1.1; // diagonal allowance
        if (textWidth > maxSpan) {
            fontSize = fontSize * (maxSpan / textWidth);
            textWidth = font.widthOfTextAtSize(text, fontSize);
        }
        // Center the rotated baseline midpoint on the page center.
        const cx = width / 2;
        const cy = height / 2;
        const x = cx - (textWidth / 2) * cos;
        const y = cy - (textWidth / 2) * sin;
        page.drawText(text, {
            x,
            y,
            size: fontSize,
            font,
            color: gray,
            opacity,
            rotate: degrees(ROTATION_DEG),
        });
    }
}

/** Apply the watermark to a copy of the open PDF and download it. */
async function applyWatermark() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[watermark] window.PDFLib unavailable');
        return;
    }
    const text = (textInput ? textInput.value : '').trim().slice(0, MAX_TEXT_LEN);
    if (!text) {
        setStatus('Enter watermark text.', true);
        return;
    }
    const opacity = readOpacity();

    setStatus('Applying watermark…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        await stampPages(PDFLib, pdf, text, opacity);

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = pdf.getPageCount();
        setStatus(`Watermarked ${n} page${n === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[watermark] apply failed:', err);
        setStatus('Failed to watermark PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to watermark PDF.', error: err });
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
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Enter text and apply.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initWatermark() {
    textInput = document.getElementById('watermark-text');
    opacityInput = document.getElementById('watermark-opacity');
    applyBtn = document.getElementById('watermark-apply');
    statusEl = document.getElementById('watermark-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('watermark.apply', {
        title: 'Apply watermark',
        run: () => applyWatermark(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
