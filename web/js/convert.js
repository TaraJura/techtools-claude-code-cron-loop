// convert.js — Export a page of the open PDF as a PNG or JPEG image.
//
// Renders the chosen page of the currently open document to an offscreen
// canvas (via pdf.js, the same engine the viewer uses) and downloads it as a
// raster image at the selected resolution — entirely client-side. Nothing is
// uploaded; the document in the viewer is never modified.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, or any sibling tool module. It renders into its OWN throwaway
// canvas (never the viewer's), so there is no #pdf-pages geometry risk. The
// page proxy comes from pdf.js' own `doc.getPage()`. No user-controlled string
// ever reaches innerHTML — only `textContent` and download attributes
// (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const JPEG_QUALITY = 0.92; // 0..1, used only for JPEG output

let currentDoc = null;     // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let pageInput = null;
let formatSel = null;
let scaleSel = null;
let exportBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [pageInput, formatSel, scaleSel, exportBtn].forEach((el) => {
        if (el) el.disabled = !enabled;
    });
}

/** Read & clamp the page control to a valid 1-based page number. */
function readPage() {
    const n = parseInt(pageInput && pageInput.value, 10);
    if (!Number.isFinite(n) || n < 1) return 1;
    return Math.min(n, numPages || 1);
}

/** Build a safe download filename for the exported image. */
function buildFileName(pageNum, ext) {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_page-${pageNum}.${ext}`;
}

/** Trigger a browser download for the given blob. */
function downloadBlob(blob, fileName) {
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

/** Render `pageNum` of the open doc to a canvas and return a {blob, ext}. */
async function renderPageToImage(pageNum, format, scale) {
    const page = await currentDoc.getPage(pageNum);
    const viewport = page.getViewport({ scale });
    const canvas = document.createElement('canvas');
    // Cap dimensions so a huge page × high scale can't blow past the browser's
    // max canvas size (and our 1.6 GiB box). 8000px/side is well within limits.
    const MAX = 8000;
    canvas.width = Math.min(MAX, Math.max(1, Math.ceil(viewport.width)));
    canvas.height = Math.min(MAX, Math.max(1, Math.ceil(viewport.height)));
    const ctx = canvas.getContext('2d');

    const isJpeg = format === 'jpeg';
    // JPEG has no alpha — paint a white background so transparent areas aren't black.
    if (isJpeg) {
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    await page.render({ canvasContext: ctx, viewport }).promise;

    const mime = isJpeg ? 'image/jpeg' : 'image/png';
    const ext = isJpeg ? 'jpg' : 'png';
    const quality = isJpeg ? JPEG_QUALITY : undefined;
    const blob = await new Promise((resolve, reject) => {
        canvas.toBlob(
            (b) => (b ? resolve(b) : reject(new Error('canvas.toBlob returned null'))),
            mime,
            quality,
        );
    });
    return { blob, ext };
}

/** Export the selected page as an image and download it. */
async function exportImage() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const pageNum = readPage();
    if (pageInput) pageInput.value = String(pageNum); // reflect clamp back to the user
    const format = (formatSel && formatSel.value) || 'png';
    const scale = parseFloat(scaleSel && scaleSel.value) || 2;

    setStatus(`Rendering page ${pageNum}…`);
    if (exportBtn) exportBtn.disabled = true;
    try {
        const { blob, ext } = await renderPageToImage(pageNum, format, scale);
        const fileName = buildFileName(pageNum, ext);
        downloadBlob(blob, fileName);
        const kb = Math.max(1, Math.round(blob.size / 1024));
        setStatus(`Exported page ${pageNum} → ${fileName} (${kb} KB)`);
    } catch (err) {
        console.error('[convert] export failed:', err);
        setStatus('Failed to export image. The page may be corrupted or too large.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to export image.', error: err });
    } finally {
        if (exportBtn) exportBtn.disabled = !(currentDoc && numPages > 0);
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (pageInput) {
        pageInput.max = String(numPages || 1);
        pageInput.value = '1';
    }
    setEnabled(numPages > 0);
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Choose a page and export.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (pageInput) {
        pageInput.max = '1';
        pageInput.value = '1';
    }
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initConvert() {
    pageInput = document.getElementById('convert-page');
    formatSel = document.getElementById('convert-format');
    scaleSel = document.getElementById('convert-scale');
    exportBtn = document.getElementById('convert-export');
    statusEl = document.getElementById('convert-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('convert.export', {
        title: 'Export page as image',
        run: () => exportImage(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
