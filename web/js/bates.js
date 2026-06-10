// bates.js — Stamp legal-style Bates numbers onto every page of the open PDF.
//
// Bates numbering applies a fixed-width, zero-padded sequential identifier with
// an optional prefix/suffix (e.g. ABC-000001, ABC-000002, …) to each page — the
// standard way documents are labelled for legal discovery/production. The result
// is downloaded as a brand-new PDF, entirely client-side (pdf-lib). The document
// in the viewer is never modified; nothing is uploaded to the server.
//
// Isolation: this module only talks to the rest of the app through the EventBus
// (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches the viewer
// rendering core, the .pdf-viewer-container layout, upload.js validation, or any
// sibling tool module (split/merge/watermark/page-numbers/pages/…). The raw PDF
// bytes come from pdf.js' own `doc.getData()` so we don't reach into viewer.js'
// private buffer. No user-controlled string ever reaches innerHTML — only pdf-lib
// `drawText` and `textContent` (XSS-safe). Prefix/suffix are additionally
// sanitized to WinAnsi-printable ASCII so pdf-lib's Helvetica encoder can never
// throw on an out-of-range glyph.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const FONT_SIZE = 11;       // Bates text size, points
const MARGIN = 28;          // distance from page edge, points (~0.39in)
const AFFIX_MAX = 32;       // max chars for prefix / suffix

let currentDoc = null;      // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let prefixInput = null;
let suffixInput = null;
let digitsSel = null;
let startInput = null;
let positionSel = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    [prefixInput, suffixInput, digitsSel, startInput, positionSel, applyBtn]
        .forEach((el) => { if (el) el.disabled = !enabled; });
}

/**
 * Keep only WinAnsi-printable characters (space..tilde plus Latin-1 supplement)
 * so the Helvetica embedder never throws, and cap the length. This is what makes
 * an over-long or non-Latin affix degrade gracefully instead of failing.
 */
function sanitizeAffix(raw) {
    if (!raw) return '';
    let out = '';
    for (const ch of String(raw)) {
        const c = ch.codePointAt(0);
        if ((c >= 0x20 && c <= 0x7e) || (c >= 0xa1 && c <= 0xff)) out += ch;
        if (out.length >= AFFIX_MAX) break;
    }
    return out;
}

/** Read & clamp the "start at" control to a non-negative integer. */
function readStart() {
    const n = parseInt(startInput && startInput.value, 10);
    if (!Number.isFinite(n) || n < 0) return 1;
    return Math.min(n, 100000000);
}

/** Read the zero-pad width (digits), clamped to a sane range. */
function readDigits() {
    const n = parseInt(digitsSel && digitsSel.value, 10);
    if (!Number.isFinite(n) || n < 1) return 6;
    return Math.min(n, 12);
}

/** Build the Bates label for page `index` (0-based). */
function formatLabel(prefix, suffix, digits, index, start) {
    const seq = String(start + index).padStart(digits, '0');
    return `${prefix}${seq}${suffix}`;
}

/** Compute the {x, y} baseline for the label on a page of the given size. */
function placement(position, pageW, pageH, textW) {
    const isTop = position.startsWith('top');
    const y = isTop ? pageH - MARGIN - FONT_SIZE : MARGIN;
    let x;
    if (position.endsWith('left')) {
        x = MARGIN;
    } else if (position.endsWith('right')) {
        x = pageW - MARGIN - textW;
    } else { // center
        x = (pageW - textW) / 2;
    }
    return { x: Math.max(2, x), y: Math.max(2, y) };
}

/** Build a safe download filename for the Bates-stamped output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_bates.pdf`;
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

/** Stamp Bates numbers onto every page of `pdf` (pdf-lib doc). */
async function stampBates(PDFLib, pdf, prefix, suffix, digits, start, position) {
    const { StandardFonts, rgb } = PDFLib;
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const color = rgb(0.15, 0.15, 0.15);
    const pages = pdf.getPages();

    pages.forEach((page, i) => {
        const { width, height } = page.getSize();
        const label = formatLabel(prefix, suffix, digits, i, start);
        const textW = font.widthOfTextAtSize(label, FONT_SIZE);
        const { x, y } = placement(position, width, height, textW);
        page.drawText(label, { x, y, size: FONT_SIZE, font, color });
    });
}

/** Apply Bates numbering to a copy of the open PDF and download it. */
async function applyBates() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[bates] window.PDFLib unavailable');
        return;
    }
    const prefix = sanitizeAffix(prefixInput && prefixInput.value);
    const suffix = sanitizeAffix(suffixInput && suffixInput.value);
    const digits = readDigits();
    const start = readStart();
    const position = (positionSel && positionSel.value) || 'bottom-right';

    setStatus('Adding Bates numbers…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        await stampBates(PDFLib, pdf, prefix, suffix, digits, start, position);

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = pdf.getPageCount();
        const sample = formatLabel(prefix, suffix, digits, 0, start);
        setStatus(`Stamped ${n} page${n === 1 ? '' : 's'} (${sample}…) → ${fileName}`);
    } catch (err) {
        console.error('[bates] apply failed:', err);
        setStatus('Failed to add Bates numbers. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to add Bates numbers.', error: err });
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
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Set options and apply.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initBates() {
    prefixInput = document.getElementById('bates-prefix');
    suffixInput = document.getElementById('bates-suffix');
    digitsSel = document.getElementById('bates-digits');
    startInput = document.getElementById('bates-start');
    positionSel = document.getElementById('bates-position');
    applyBtn = document.getElementById('bates-apply');
    statusEl = document.getElementById('bates-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('bates.apply', {
        title: 'Add Bates numbers',
        run: () => applyBates(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
