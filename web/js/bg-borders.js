// bg-borders.js — Add a page background fill and/or a page border to every page.
//
// Lets the user paint a solid background colour behind the content of every page
// and/or stroke a coloured frame (border) a chosen distance in from each edge,
// then download the result as a brand-new PDF — entirely client-side (pdf-lib).
// The background is a TRUE background: each original page is embedded onto a fresh
// same-size page, the fill rectangle is drawn FIRST, then the original content is
// drawn on top, so whitespace/margins show the colour while the content stays
// fully legible. The border is stroked last, on top, inset from the page edge.
//
// Distinct from the text-stampers (watermark / page-numbers / bates /
// headers-footers, which all draw TEXT) and from Crop/Resize (which change the
// box geometry): this only paints colour — page count and page dimensions are
// preserved exactly. The document in the viewer is never modified; nothing is
// uploaded.
//
// Isolation: this module talks to the rest of the app ONLY through the EventBus
// (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches the viewer
// render core, the .pdf-viewer-container layout, upload.js validation, tab-nav.js,
// or any sibling tool module. The raw PDF bytes come from pdf.js' own
// `doc.getData()` so we don't reach into viewer.js' private buffer. No
// user-controlled string ever reaches innerHTML — only pdf-lib drawing and
// `textContent` (XSS-safe). Follows the VERIFIED isolated page-resize.js pattern.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

// Background-fill presets (besides "none"). Keys are the <select> values; the
// values are 0–255 RGB triples. Using a fixed preset list keeps the colour input
// trivially testable and avoids a free-text colour field.
const BG_PRESETS = {
    white:  [255, 255, 255],
    cream:  [252, 248, 227],
    gray:   [235, 235, 235],
    blue:   [225, 238, 250],
    yellow: [253, 250, 214],
    green:  [228, 244, 228],
};

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let bgSel = null;
let borderColorInput = null;
let borderWidthInput = null;
let borderInsetInput = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [bgSel, borderColorInput, borderWidthInput, borderInsetInput, applyBtn].forEach((el) => {
        if (el) {
            el.disabled = !enabled;
            el.setAttribute('aria-disabled', String(!enabled));
        }
    });
}

/** Parse a "#rrggbb" colour into a 0–1 RGB triple; falls back to dark grey. */
function hexToUnitRgb(hex) {
    const m = /^#?([0-9a-fA-F]{6})$/.exec(String(hex || '').trim());
    if (!m) return { r: 0.1, g: 0.1, b: 0.1 };
    const int = parseInt(m[1], 16);
    return {
        r: ((int >> 16) & 0xff) / 255,
        g: ((int >> 8) & 0xff) / 255,
        b: (int & 0xff) / 255,
    };
}

/** Clamp a numeric input to [min, max], returning `fallback` when not a number. */
function clampNum(value, min, max, fallback) {
    const n = Number(value);
    if (!Number.isFinite(n)) return fallback;
    return Math.min(max, Math.max(min, n));
}

/** Build a safe download filename for the output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_bordered.pdf`;
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

/**
 * Rebuild `srcPdf` into a NEW document, painting a background fill behind each
 * page's content and/or stroking a border on top. Page size and count preserved.
 */
async function buildDecorated(PDFLib, srcPdf, opts) {
    const { rgb } = PDFLib;
    const out = await PDFLib.PDFDocument.create();
    const srcPages = srcPdf.getPages();

    for (let i = 0; i < srcPages.length; i++) {
        // Embed the source page; its width/height reflect the crop box a viewer
        // actually shows. The new page matches it exactly (dimensions preserved).
        const embedded = await out.embedPage(srcPages[i]);
        const w = embedded.width;
        const h = embedded.height;
        const page = out.addPage([w, h]);

        // 1) Background fill FIRST so content drawn next sits on top of it.
        if (opts.bg) {
            page.drawRectangle({
                x: 0, y: 0, width: w, height: h,
                color: rgb(opts.bg.r, opts.bg.g, opts.bg.b),
            });
        }

        // 2) Original page content on top of the background.
        page.drawPage(embedded, { x: 0, y: 0, width: w, height: h });

        // 3) Border stroke last, inset from the edges. Cap the inset so the frame
        //    can never invert on a tiny page (leave at least 2pt of side length).
        if (opts.borderWidth > 0) {
            const maxInset = Math.max(0, (Math.min(w, h) - 2) / 2);
            const inset = Math.min(opts.borderInset, maxInset);
            page.drawRectangle({
                x: inset,
                y: inset,
                width: w - 2 * inset,
                height: h - 2 * inset,
                borderColor: rgb(opts.borderColor.r, opts.borderColor.g, opts.borderColor.b),
                borderWidth: opts.borderWidth,
                // No `color` key → no fill, so existing content stays visible.
            });
        }
    }

    return out;
}

/** Decorate a copy of the open PDF and download it. */
async function applyBgBorders() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[bg-borders] window.PDFLib unavailable');
        return;
    }

    const bgKey = (bgSel && bgSel.value) || 'none';
    const bgPreset = BG_PRESETS[bgKey];
    const bg = bgPreset
        ? { r: bgPreset[0] / 255, g: bgPreset[1] / 255, b: bgPreset[2] / 255 }
        : null;

    const borderWidth = clampNum(borderWidthInput && borderWidthInput.value, 0, 24, 0);
    const borderInset = clampNum(borderInsetInput && borderInsetInput.value, 0, 200, 18);
    const borderColor = hexToUnitRgb(borderColorInput && borderColorInput.value);

    if (!bg && borderWidth <= 0) {
        setStatus('Choose a background colour or a border width greater than 0 first.', true);
        return;
    }

    setStatus('Applying background & border…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);
        const out = await buildDecorated(PDFLib, srcPdf, { bg, borderWidth, borderInset, borderColor });

        const outBytes = await out.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = out.getPageCount();
        const parts = [];
        if (bg) parts.push(`${bgKey} background`);
        if (borderWidth > 0) parts.push(`${borderWidth}pt border`);
        setStatus(`Applied ${parts.join(' + ')} to ${n} page${n === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[bg-borders] apply failed:', err);
        setStatus('Failed to apply background/border. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to apply background/border.', error: err });
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
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Pick a background and/or border, then apply.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initBgBorders() {
    bgSel = document.getElementById('bgborders-bg');
    borderColorInput = document.getElementById('bgborders-border-color');
    borderWidthInput = document.getElementById('bgborders-border-width');
    borderInsetInput = document.getElementById('bgborders-border-inset');
    applyBtn = document.getElementById('bgborders-apply');
    statusEl = document.getElementById('bgborders-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('bgborders.apply', {
        title: 'Apply background & border',
        run: () => applyBgBorders(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
