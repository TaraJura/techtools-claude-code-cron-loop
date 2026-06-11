// compress.js — Reduce the file size of the open PDF, entirely client-side.
//
// Two compression strategies are tried and the smallest result that actually
// beats the original is offered for download:
//   1. Structural re-save — pdf-lib `save({ useObjectStreams: true })` strips
//      redundant objects and packs the file. Lossless; keeps selectable text.
//   2. Rasterize — each page is rendered (via pdf.js, the viewer's own engine)
//      to an offscreen canvas at the chosen DPI, re-encoded as JPEG at the
//      chosen quality, and assembled into a brand-new PDF. This is what shrinks
//      scanned / image-heavy PDFs, at the cost of making text non-selectable.
//
// We NEVER claim a saving that didn't happen: the before/after byte sizes and
// % reduction are computed from the real output, and if nothing beats the
// original we tell the user the file is already optimized and offer no
// (larger) download. Nothing is uploaded; the viewed document is untouched.
//
// Isolation: this module talks to the rest of the app ONLY through the EventBus
// (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It renders into its OWN
// throwaway canvas (never the viewer's), so there is no #pdf-pages geometry
// risk (rule 8 — it never touches .pdf-viewer-container). Source bytes come
// from pdf.js' own `doc.getData()`. No user-controlled string ever reaches
// innerHTML — only `textContent` and download attributes (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

// Quality presets: Low / Medium / High → target raster DPI + JPEG quality.
// PDF user space is 72 units / inch, so scale = dpi / 72.
const PRESETS = {
    low: { label: 'Low (smallest)', dpi: 72, jpeg: 0.5 },
    medium: { label: 'Medium', dpi: 110, jpeg: 0.7 },
    high: { label: 'High (best looking)', dpi: 150, jpeg: 0.82 },
};
const DEFAULT_PRESET = 'medium';

// Cap each rasterized page side so a big page × high DPI can't exhaust the
// small (1.6 GiB) box or blow past the browser's max canvas size.
const MAX_PAGE_PX = 3000;

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;
let lastResult = null;   // { bytes, fileName } of the most recent smaller output
let busy = false;

let qualitySel = null;
let compressBtn = null;
let downloadBtn = null;
let progressEl = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Show/hide the indeterminate progress indicator with an optional label. */
function setProgress(visible, label) {
    if (!progressEl) return;
    progressEl.hidden = !visible;
    if (label !== undefined) progressEl.textContent = label;
}

/** Set the disabled property AND keep aria-disabled in sync (avoids stale AT state). */
function setControlDisabled(el, disabled) {
    if (!el) return;
    el.disabled = disabled;
    el.setAttribute('aria-disabled', String(disabled));
}

/** Enable/disable the controls depending on document + busy state. */
function refreshEnabled() {
    const ready = !!currentDoc && numPages > 0 && !busy;
    setControlDisabled(qualitySel, !ready);
    setControlDisabled(compressBtn, !ready);
    // Download is only enabled when we actually produced a smaller file.
    setControlDisabled(downloadBtn, busy || !lastResult);
}

/** Human-friendly byte size, e.g. 1.2 MB / 840 KB. */
function fmtBytes(n) {
    if (!Number.isFinite(n) || n < 0) return '—';
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
    return `${(n / (1024 * 1024)).toFixed(2)} MB`;
}

/** Build a safe download filename for the compressed output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_compressed.pdf`;
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
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Yield to the event loop so the progress text / spinner can repaint. */
function yieldToUi() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

/**
 * Rasterize every page of the open doc at `dpi`, JPEG-encode at `jpeg`, and
 * assemble a fresh PDF. Returns the saved bytes (Uint8Array).
 * Reuses one canvas across pages to keep peak memory low on the small box.
 */
async function rasterizeToPdf(PDFLib, dpi, jpeg) {
    const out = await PDFLib.PDFDocument.create();
    const scale = dpi / 72;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    for (let i = 1; i <= numPages; i++) {
        setProgress(true, `Compressing page ${i} of ${numPages}…`);
        // Let the spinner/label paint before this CPU-heavy page render.
        await yieldToUi();

        const page = await currentDoc.getPage(i);
        const baseViewport = page.getViewport({ scale: 1 }); // points (= PDF units)
        const ptW = baseViewport.width;
        const ptH = baseViewport.height;

        // Clamp the raster scale so neither side exceeds MAX_PAGE_PX.
        let renderScale = scale;
        const maxSide = Math.max(ptW, ptH) * renderScale;
        if (maxSide > MAX_PAGE_PX) renderScale = MAX_PAGE_PX / Math.max(ptW, ptH);

        const viewport = page.getViewport({ scale: renderScale });
        canvas.width = Math.max(1, Math.ceil(viewport.width));
        canvas.height = Math.max(1, Math.ceil(viewport.height));

        // JPEG has no alpha — paint white so transparent areas aren't black.
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        await page.render({ canvasContext: ctx, viewport }).promise;

        const blob = await new Promise((resolve, reject) => {
            canvas.toBlob(
                (b) => (b ? resolve(b) : reject(new Error('canvas.toBlob returned null'))),
                'image/jpeg',
                jpeg,
            );
        });
        const jpgBytes = new Uint8Array(await blob.arrayBuffer());
        const img = await out.embedJpg(jpgBytes);
        // New page keeps the ORIGINAL point dimensions; the image fills it, so
        // the on-screen size is unchanged — only the encoding got cheaper.
        const newPage = out.addPage([ptW, ptH]);
        newPage.drawImage(img, { x: 0, y: 0, width: ptW, height: ptH });
    }

    // Free the canvas backing store promptly.
    canvas.width = 0;
    canvas.height = 0;
    return out.save({ useObjectStreams: true });
}

/** Lossless structural re-save via pdf-lib. Returns saved bytes (Uint8Array). */
async function resave(PDFLib, srcBytes) {
    // ignoreEncryption lets us at least re-save lightly-protected files.
    const doc = await PDFLib.PDFDocument.load(srcBytes, { ignoreEncryption: true });
    return doc.save({ useObjectStreams: true });
}

/** Run compression, pick the smallest real win, and report honestly. */
async function compress() {
    if (busy) return;
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[compress] window.PDFLib unavailable');
        return;
    }

    const presetKey = (qualitySel && qualitySel.value) || DEFAULT_PRESET;
    const preset = PRESETS[presetKey] || PRESETS[DEFAULT_PRESET];

    busy = true;
    lastResult = null;
    refreshEnabled();
    setProgress(true, 'Reading document…');
    setStatus('Compressing… this can take a moment on large files.');

    try {
        const srcBytes = await currentDoc.getData();
        const originalSize = srcBytes.byteLength;

        // Strategy 1: lossless re-save (keeps text). Tolerate failure.
        let resaveBytes = null;
        try {
            setProgress(true, 'Optimizing structure…');
            await yieldToUi();
            resaveBytes = await resave(PDFLib, srcBytes);
        } catch (err) {
            console.warn('[compress] re-save strategy failed:', err);
        }

        // Strategy 2: rasterize pages at the chosen DPI/quality.
        let rasterBytes = null;
        try {
            rasterBytes = await rasterizeToPdf(PDFLib, preset.dpi, preset.jpeg);
        } catch (err) {
            console.warn('[compress] rasterize strategy failed:', err);
        }

        setProgress(false);

        if (!resaveBytes && !rasterBytes) {
            setStatus('Could not process this PDF. It may be corrupted or encrypted.', true);
            return;
        }

        // Choose the smallest candidate that genuinely beats the original.
        const candidates = [];
        if (resaveBytes) candidates.push({ bytes: resaveBytes, raster: false });
        if (rasterBytes) candidates.push({ bytes: rasterBytes, raster: true });
        candidates.sort((a, b) => a.bytes.byteLength - b.bytes.byteLength);
        const best = candidates[0];
        const newSize = best.bytes.byteLength;

        if (newSize >= originalSize) {
            // Honest "no win" — do NOT force a larger file on the user.
            lastResult = null;
            setStatus(
                `Already optimized: this PDF is ${fmtBytes(originalSize)} and `
                + `compression couldn't make it smaller (0% saved). No download offered.`,
            );
            return;
        }

        const pct = Math.round((1 - newSize / originalSize) * 100);
        lastResult = { bytes: best.bytes, fileName: buildFileName() };
        const method = best.raster
            ? ` Pages were rasterized at ${preset.dpi} DPI, so text is no longer selectable.`
            : ' The document structure was optimized; text stays selectable.';
        setStatus(
            `Compressed: ${fmtBytes(originalSize)} → ${fmtBytes(newSize)} `
            + `(${pct}% smaller). Click Download to save.${method}`,
        );
    } catch (err) {
        console.error('[compress] failed:', err);
        setProgress(false);
        lastResult = null;
        setStatus('Failed to compress PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to compress PDF.', error: err });
    } finally {
        busy = false;
        refreshEnabled();
    }
}

/** Download the most recent successful (smaller) result. */
function downloadResult() {
    if (busy || !lastResult) {
        setStatus('Run Compress first to produce a smaller file.', true);
        return;
    }
    downloadBytes(lastResult.bytes, lastResult.fileName);
    setStatus(`Downloaded ${lastResult.fileName}.`);
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    lastResult = null;
    busy = false;
    setProgress(false);
    refreshEnabled();
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Choose a quality and compress.`
        : 'Open a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    lastResult = null;
    busy = false;
    setProgress(false);
    refreshEnabled();
    setStatus('Open a PDF first.');
}

export function initCompress() {
    qualitySel = document.getElementById('compress-quality');
    compressBtn = document.getElementById('compress-run');
    downloadBtn = document.getElementById('compress-download');
    progressEl = document.getElementById('compress-progress');
    statusEl = document.getElementById('compress-status');

    setProgress(false);
    refreshEnabled();
    setStatus('Open a PDF first.');

    ActionRegistry.register('compress.run', {
        title: 'Compress PDF',
        run: () => compress(),
    });
    ActionRegistry.register('compress.download', {
        title: 'Download compressed PDF',
        run: () => downloadResult(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
