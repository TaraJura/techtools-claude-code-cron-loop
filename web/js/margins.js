// margins.js — Add margins: enlarge each page with blank whitespace / binding gutter.
//
// The user enters a margin size in millimetres (default 20 mm) and picks which
// sides to pad (all sides, left-only binding gutter, or top & bottom). The tool
// builds a brand-new PDF where every page is ENLARGED by that margin on the
// chosen sides while the original page content is placed un-scaled (1:1) inside,
// leaving blank whitespace around it. This is the standard way to add a binding
// gutter for printing/binding, or to create writing/annotation whitespace around
// a slide or scan. It is the inverse of Crop (which removes margin area) and is
// NOT Page Resize (content is never scaled).
//
// Pure pdf-lib structural imposition: embedPage + drawPage, no rasterization
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

let sizeInput = null;
let sidesSel = null;
let runBtn = null;
let statusEl = null;

const MM_PER_PT = 25.4 / 72;     // 1 pt = 0.3528 mm
const MAX_MM = 100;              // sane cap to keep output sane on the small box

// Which sides each option pads. true = add the margin on that edge.
const SIDE_MODES = {
    all:    { left: true,  right: true,  top: true,  bottom: true,  label: 'all sides' },
    left:   { left: true,  right: false, top: false, bottom: false, label: 'left (binding gutter)' },
    topbot: { left: false, right: false, top: true,  bottom: true,  label: 'top & bottom' },
};

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (sizeInput) sizeInput.disabled = !enabled;
    if (sidesSel) sidesSel.disabled = !enabled;
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
 * Build the margined PDF and download it. For each source page we read its own
 * size, create an output page enlarged by the chosen margins, embed the source
 * page and draw it un-scaled (xScale/yScale = 1) offset by the left & bottom
 * margins (PDF y grows upward, so the bottom margin is the y offset). Each
 * page's own size is preserved, so mixed-size documents are handled correctly.
 */
async function runMargins() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[margins] window.PDFLib unavailable');
        return;
    }

    // Validate the margin value: a number ≥ 0 and ≤ the cap.
    const raw = sizeInput ? sizeInput.value.trim() : '';
    const mm = Number(raw);
    if (raw === '' || !Number.isFinite(mm) || mm < 0 || mm > MAX_MM) {
        setStatus(`Margin must be a number between 0 and ${MAX_MM} mm.`, true);
        return;
    }

    const mode = SIDE_MODES[(sidesSel && sidesSel.value) || 'all'] || SIDE_MODES.all;
    const pt = mm * 72 / 25.4;
    const mLeft = mode.left ? pt : 0;
    const mRight = mode.right ? pt : 0;
    const mTop = mode.top ? pt : 0;
    const mBottom = mode.bottom ? pt : 0;

    setStatus('Building…');
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
            const outPage = outPdf.addPage([w + mLeft + mRight, h + mTop + mBottom]);
            const embedded = await outPdf.embedPage(src);
            // Content un-scaled, shifted right by the left margin and up by the
            // bottom margin, leaving blank whitespace on the padded sides.
            outPage.drawPage(embedded, { x: mLeft, y: mBottom, xScale: 1, yScale: 1 });
        }

        const outBytes = await outPdf.save();
        const fileName = `${baseName()}_margins.pdf`;
        downloadBytes(outBytes, fileName);
        const mmTxt = Number.isInteger(mm) ? String(mm) : mm.toFixed(1);
        setStatus(`Added ${mmTxt} mm margin on ${mode.label} to ${numPages} page${numPages === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[margins] Add margins failed:', err);
        setStatus('Failed to add margins. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to add margins.', error: err });
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

export function initMargins() {
    sizeInput = document.getElementById('margins-size');
    sidesSel = document.getElementById('margins-sides');
    runBtn = document.getElementById('margins-run');
    statusEl = document.getElementById('margins-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="margins"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runMargins();
            }
        });
    }

    ActionRegistry.register('margins.run', {
        title: 'Add margins (whitespace / binding gutter)',
        run: () => runMargins(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
