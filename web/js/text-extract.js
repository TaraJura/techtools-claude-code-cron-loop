// text-extract.js — Extract all text from the open PDF and download as .txt.
//
// Walks every page of the currently open document, pulls its text layer via
// pdf.js `page.getTextContent()`, joins it into a plain-text document (one page
// per block, separated by a `--- Page N ---` header and a blank line), shows a
// small preview + a page/word/character summary in the panel, and downloads it
// as `<base>.txt`. Purely client-side; nothing is uploaded; the viewer document
// is never modified.
//
// Distinct from Search (search.js, which *locates/finds* text in the open
// document) — this one *exports* the full text layer to a downloadable file.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container flex-row layout,
// upload.js validation, or any sibling tool module. It holds the open pdf.js
// document reference from PDF_LOADED and never reaches into viewer.js'
// internals. Every extracted string reaches the DOM only via the readonly
// <textarea>.value / textContent (never innerHTML) and the download blob is
// text/plain (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const PREVIEW_LIMIT = 2000; // characters shown in the in-panel preview

let currentDoc = null;       // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;
let extracting = false;

let extractBtn = null;
let statusEl = null;
let summaryEl = null;
let previewEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the Extract control (also keeps aria-disabled in sync). */
function setEnabled(enabled) {
    if (!extractBtn) return;
    extractBtn.disabled = !enabled;
    extractBtn.setAttribute('aria-disabled', String(!enabled));
}

/**
 * Convert one page's text-content items into a plain-text string, inserting
 * line breaks where pdf.js reports an end-of-line (`hasEOL`) or where the
 * baseline Y of the next run drops (covering pdf.js builds without hasEOL).
 */
function pageItemsToText(items) {
    if (!Array.isArray(items)) return '';
    let out = '';
    let lastY = null;
    for (const it of items) {
        if (!it || typeof it.str !== 'string') continue;
        const y = Array.isArray(it.transform) ? it.transform[5] : null;
        if (lastY !== null && y !== null && Math.abs(y - lastY) > 1
            && out && !out.endsWith('\n')) {
            out += '\n';
        }
        out += it.str;
        if (it.hasEOL && !out.endsWith('\n')) out += '\n';
        lastY = y;
    }
    // Tidy trailing spaces before newlines and at the very end.
    return out.replace(/[ \t]+\n/g, '\n').replace(/\s+$/g, '');
}

/** Build a safe `<base>.txt` download filename from the open document name. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}.txt`;
}

/** Trigger a browser download for the given plain-text string. */
function downloadText(text, fileName) {
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
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

/** Extract text from every page of the open document and download it. */
async function extractText() {
    if (extracting) return;
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }

    extracting = true;
    setEnabled(false);
    if (summaryEl) summaryEl.textContent = '';
    if (previewEl) previewEl.value = '';

    const blocks = [];      // full document blocks (with page markers)
    const contentParts = [];// page text only (for word/char counts)
    let anyText = false;

    try {
        for (let i = 1; i <= numPages; i += 1) {
            setStatus(`Extracting text… page ${i} of ${numPages}`);
            const page = await currentDoc.getPage(i);
            let pageText = '';
            try {
                const tc = await page.getTextContent();
                pageText = pageItemsToText(tc.items);
            } catch (err) {
                console.warn(`[text-extract] getTextContent failed on page ${i}:`, err);
            } finally {
                // Release page resources promptly on a small-RAM box.
                if (typeof page.cleanup === 'function') page.cleanup();
            }
            if (pageText.trim()) anyText = true;
            blocks.push(`--- Page ${i} ---\n${pageText}`);
            contentParts.push(pageText);
        }

        if (!anyText) {
            setStatus('No selectable text found (this PDF may be scanned images — try OCR).', true);
            if (previewEl) previewEl.value = '';
            return; // do NOT download an empty file
        }

        const fullText = blocks.join('\n\n');
        const content = contentParts.join('\n\n');
        const charCount = content.length;
        const wordCount = (content.match(/\S+/g) || []).length;

        // In-panel preview (truncated) — value, never innerHTML.
        if (previewEl) {
            previewEl.value = fullText.length > PREVIEW_LIMIT
                ? `${fullText.slice(0, PREVIEW_LIMIT)}\n…`
                : fullText;
        }
        if (summaryEl) {
            const pw = numPages === 1 ? 'page' : 'pages';
            const ww = wordCount === 1 ? 'word' : 'words';
            const cw = charCount === 1 ? 'character' : 'characters';
            summaryEl.textContent =
                `${numPages} ${pw} · ${wordCount} ${ww} · ${charCount} ${cw}`;
        }

        const fileName = buildFileName();
        downloadText(fullText, fileName);
        setStatus(`Extracted text from ${numPages} page${numPages === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[text-extract] extraction failed:', err);
        setStatus('Failed to extract text. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to extract text.', error: err });
    } finally {
        extracting = false;
        setEnabled(currentDoc && numPages > 0);
    }
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    if (summaryEl) summaryEl.textContent = '';
    if (previewEl) previewEl.value = '';
    setEnabled(numPages > 0);
    setStatus(numPages > 0
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Click Extract to pull the text.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    if (summaryEl) summaryEl.textContent = '';
    if (previewEl) previewEl.value = '';
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initTextExtract() {
    extractBtn = document.getElementById('textextract-extract');
    statusEl = document.getElementById('textextract-status');
    summaryEl = document.getElementById('textextract-summary');
    previewEl = document.getElementById('textextract-preview');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('textextract.extract', {
        title: 'Extract text',
        run: () => extractText(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
