// split-chunks.js — Split into Chunks: break the open PDF into CONSECUTIVE
// equal-size parts of N pages each and deliver them as a single ZIP download
// (e.g. document-chunks.zip containing part-01_pages-001-010.pdf,
// part-02_pages-011-020.pdf, …). The final part holds the remainder when the
// page count isn't an exact multiple of N.
//
// Distinct from the three adjacent tools:
//   • Split (split.js)          — user-typed arbitrary ranges → a few PDFs
//   • Burst (burst.js)          — ONE single-page PDF per page → ZIP
//   • Extract pages (extract-pages.js) — a chosen subset → ONE PDF
// This covers the common "cut this large document into evenly-sized pieces" case.
//
// Pure pdf-lib structural copy — for each group of N pages we create a fresh
// PDFDocument, copyPages() that group, save() to bytes, and add it to the
// archive. NO rasterization, so memory stays low (safe for the 1.6 GiB box);
// each page's original size and rotation are preserved. Groups are processed
// sequentially (await each save) to keep peak memory low.
//
// The ZIP is assembled by the shared dependency-free STORE-only writer
// (zip-writer.js, factored out of burst.js) — JSZip is not present in lib/ and
// the CSP is `script-src 'self'` (no CDN).
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
import { buildZip, downloadBytes } from './zip-writer.js';

const DEFAULT_CHUNK = 10;

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let sizeInput = null;    // numeric "pages per part" input
let runBtn = null;
let statusEl = null;
let previewEl = null;    // live "→ N parts" preview line

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (sizeInput) sizeInput.disabled = !enabled;
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
 * Validate the chunk-size text. Accepts a positive integer only. Returns
 * { size } on success or { error } with a specific, user-facing message.
 * Rejects empty / non-numeric / ≤ 0 / non-integer (never silent).
 */
function parseChunkSize(raw) {
    const trimmed = String(raw == null ? '' : raw).trim();
    if (trimmed === '') return { error: 'Enter how many pages per part.' };
    if (!/^\d+$/.test(trimmed)) return { error: 'Pages per part must be a whole number greater than 0.' };
    const n = parseInt(trimmed, 10);
    if (n < 1) return { error: 'Pages per part must be at least 1.' };
    return { size: n };
}

/**
 * Update the live "→ N parts" preview from the current page count + chunk size.
 * Shows the validation error inline (without touching the status line) when the
 * size is invalid, so the user gets feedback as they type.
 */
function updatePreview() {
    if (!previewEl) return;
    if (numPages === 0) {
        previewEl.textContent = '';
        return;
    }
    const parsed = parseChunkSize(sizeInput ? sizeInput.value : '');
    if (parsed.error) {
        previewEl.textContent = parsed.error;
        return;
    }
    const size = parsed.size;
    const parts = Math.ceil(numPages / size);
    previewEl.textContent =
        `${numPages} page${numPages === 1 ? '' : 's'} ÷ ${size} → ${parts} part${parts === 1 ? '' : 's'}`;
}

/**
 * Split the open PDF into consecutive N-page chunks, bundled into a ZIP.
 * Each group is copied (structural, no rasterization) into a fresh PDFDocument
 * and saved to bytes; filenames are zero-padded and name BOTH the part number
 * and the original page range each part covers. Groups are processed
 * sequentially to keep peak memory low.
 */
async function runSplitChunks() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[split-chunks] window.PDFLib unavailable');
        return;
    }

    const parsed = parseChunkSize(sizeInput ? sizeInput.value : '');
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const size = parsed.size;
    const totalParts = Math.ceil(numPages / size);

    setStatus('Splitting…');
    setEnabled(false);
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them once.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);

        // Zero-pad the part number to the part count, and page numbers to the
        // document's page-count width, so filenames sort correctly.
        const partPad = String(totalParts).length;
        const pagePad = String(numPages).length;
        const entries = [];

        for (let part = 0; part < totalParts; part++) {
            const first = part * size;            // 0-based index of first page in group
            const last = Math.min(first + size, numPages); // exclusive end
            const indices = [];
            for (let i = first; i < last; i++) indices.push(i);

            const chunkPdf = await PDFLib.PDFDocument.create();
            const copied = await chunkPdf.copyPages(srcPdf, indices);
            copied.forEach((pg) => chunkPdf.addPage(pg));
            const bytes = await chunkPdf.save();

            const partLabel = String(part + 1).padStart(partPad, '0');
            const fromLabel = String(first + 1).padStart(pagePad, '0');
            const toLabel = String(last).padStart(pagePad, '0');
            const fileName = `part-${partLabel}_pages-${fromLabel}-${toLabel}.pdf`;
            entries.push({ name: fileName, data: bytes });
            setStatus(`Splitting… part ${part + 1}/${totalParts}`);
        }

        const zipBytes = buildZip(entries);
        const zipName = `${baseName()}-chunks.zip`;
        downloadBytes(zipBytes, zipName, 'application/zip');

        const n = entries.length;
        setStatus(`Split into ${n} part${n === 1 ? '' : 's'} of up to ${size} page${size === 1 ? '' : 's'} → ${zipName}.`);
    } catch (err) {
        console.error('[split-chunks] Split failed:', err);
        setStatus('Failed to split the PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to split the PDF into chunks.', error: err });
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
    updatePreview();
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Open a PDF first.');
    updatePreview();
}

export function initSplitChunks() {
    sizeInput = document.getElementById('split-chunks-size');
    runBtn = document.getElementById('split-chunks-run');
    statusEl = document.getElementById('split-chunks-status');
    previewEl = document.getElementById('split-chunks-preview');

    setEnabled(false);
    setStatus('Open a PDF first.');
    updatePreview();

    // Live preview as the user changes the chunk size.
    if (sizeInput) {
        sizeInput.addEventListener('input', updatePreview);
    }

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="split-chunks"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runSplitChunks();
            }
        });
    }

    // Move focus into the panel when its tab is opened (acceptance criterion).
    const tab = document.querySelector('.tool-tab[data-tab="split-chunks"]');
    if (tab && sizeInput) {
        tab.addEventListener('click', () => {
            // Defer so the panel is .active (display change) before focusing.
            setTimeout(() => { if (!sizeInput.disabled) sizeInput.focus(); }, 0);
        });
    }

    ActionRegistry.register('split-chunks.run', {
        title: 'Split PDF into fixed-size chunks (every N pages → ZIP)',
        run: () => runSplitChunks(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
