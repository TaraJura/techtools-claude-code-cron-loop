// headers-footers.js — Stamp custom header & footer text onto every page.
//
// Lets the user add free text to any of six zones — header left/center/right
// and footer left/center/right — on every page of the currently open document,
// then download the result as a brand-new PDF, entirely client-side (pdf-lib).
// Each zone supports the tokens {page}, {pages}, {date}, and {title}, which are
// substituted per page. The document in the viewer is never modified; nothing
// is uploaded to the server.
//
// Distinct from the sibling text-stampers: page-numbers.js stamps a single page
// number, bates.js stamps sequential legal identifiers, watermark.js draws a
// diagonal overlay. This one places arbitrary header/footer text in six fixed
// zones with token substitution — the classic "running head / running foot".
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, upload.js
// validation, or any sibling tool module. The raw PDF bytes come from pdf.js'
// own `doc.getData()` so we don't reach into viewer.js' private buffer. No
// user-controlled string ever reaches innerHTML — only pdf-lib `drawText` and
// `textContent` (XSS-safe). User text is sanitized to the WinAnsi range that
// the standard Helvetica font can encode, so an exotic glyph never throws.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const DEFAULT_FONT_SIZE = 10;   // points
const MIN_FONT_SIZE = 6;
const MAX_FONT_SIZE = 36;
const MARGIN = 28;              // distance from page edge, points (~0.39in)
const MAX_TEXT_LEN = 120;       // per-zone character cap

let currentDoc = null;          // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

// Six zone inputs + size + apply + status, resolved in init().
const zoneIds = ['hf-hl', 'hf-hc', 'hf-hr', 'hf-fl', 'hf-fc', 'hf-fr'];
let zoneInputs = {};
let sizeInput = null;
let applyBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable every control depending on whether a document is open. */
function setEnabled(enabled) {
    Object.values(zoneInputs).forEach((el) => { if (el) el.disabled = !enabled; });
    if (sizeInput) sizeInput.disabled = !enabled;
    if (applyBtn) applyBtn.disabled = !enabled;
}

/** Read & clamp the font-size control to a sane point range. */
function readFontSize() {
    const n = parseInt(sizeInput && sizeInput.value, 10);
    if (!Number.isFinite(n)) return DEFAULT_FONT_SIZE;
    return Math.min(MAX_FONT_SIZE, Math.max(MIN_FONT_SIZE, n));
}

/**
 * Reduce a string to characters the standard Helvetica font (WinAnsi) can
 * encode. Any code point above 0xFF — and stray control characters — becomes
 * '?', so pdf-lib's drawText never throws on an un-encodable glyph.
 */
function sanitizeForWinAnsi(text) {
    let out = '';
    for (const ch of String(text)) {
        const code = ch.codePointAt(0);
        if (code === 9 || code === 32) { out += ' '; continue; } // tab/space → space
        if (code < 32 || code === 127) continue;                 // drop other controls
        out += code <= 0xFF ? ch : '?';
    }
    return out;
}

/** The {title} token value: the open document's base filename. */
function titleToken() {
    return String(currentName).replace(/\.pdf$/i, '') || 'document';
}

/**
 * Substitute the supported tokens in a zone template for page `index`
 * (0-based) of `total`, using the precomputed `dateStr`. Returns sanitized,
 * draw-ready text (possibly empty).
 */
function renderZone(template, index, total, dateStr) {
    const n = index + 1;
    const filled = String(template)
        .replace(/\{page\}/gi, String(n))
        .replace(/\{pages\}/gi, String(total))
        .replace(/\{date\}/gi, dateStr)
        .replace(/\{title\}/gi, titleToken());
    return sanitizeForWinAnsi(filled).slice(0, MAX_TEXT_LEN * 2);
}

/** Compute the x baseline for a zone given its horizontal alignment. */
function zoneX(align, pageW, textW) {
    if (align === 'left') return MARGIN;
    if (align === 'right') return Math.max(2, pageW - MARGIN - textW);
    return Math.max(2, (pageW - textW) / 2); // center
}

/** Build a safe download filename for the stamped output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_headerfooter.pdf`;
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
 * Stamp header/footer text onto every page of `pdf` (pdf-lib doc).
 * `zones` maps zone key → raw template string. Returns the number of
 * individual zone draws performed (for the status line).
 */
async function stampHeadersFooters(PDFLib, pdf, zones, fontSize, dateStr) {
    const { StandardFonts, rgb } = PDFLib;
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const color = rgb(0.25, 0.25, 0.25);
    const pages = pdf.getPages();
    const total = pages.length;

    // Each zone key → which vertical band (header/footer) and alignment.
    const layout = {
        'hf-hl': { band: 'header', align: 'left' },
        'hf-hc': { band: 'header', align: 'center' },
        'hf-hr': { band: 'header', align: 'right' },
        'hf-fl': { band: 'footer', align: 'left' },
        'hf-fc': { band: 'footer', align: 'center' },
        'hf-fr': { band: 'footer', align: 'right' },
    };

    let draws = 0;
    pages.forEach((page, i) => {
        const { width, height } = page.getSize();
        for (const key of zoneIds) {
            const template = zones[key];
            if (!template) continue;
            const text = renderZone(template, i, total, dateStr);
            if (!text) continue;
            const { band, align } = layout[key];
            const textW = font.widthOfTextAtSize(text, fontSize);
            const x = zoneX(align, width, textW);
            const y = band === 'header'
                ? Math.max(2, height - MARGIN - fontSize)
                : MARGIN;
            page.drawText(text, { x, y, size: fontSize, font, color });
            draws++;
        }
    });
    return draws;
}

/** Apply headers/footers to a copy of the open PDF and download it. */
async function applyHeadersFooters() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[headers-footers] window.PDFLib unavailable');
        return;
    }

    // Collect the six zone templates (trimmed). Bail early if all are empty.
    const zones = {};
    let anyText = false;
    for (const key of zoneIds) {
        const raw = (zoneInputs[key] && zoneInputs[key].value || '').slice(0, MAX_TEXT_LEN).trim();
        zones[key] = raw;
        if (raw) anyText = true;
    }
    if (!anyText) {
        setStatus('Enter header or footer text in at least one box first.', true);
        return;
    }

    const fontSize = readFontSize();
    // Localized short date, computed once so every page shares the same stamp.
    let dateStr;
    try {
        dateStr = new Date().toLocaleDateString();
    } catch (_e) {
        dateStr = '';
    }
    dateStr = sanitizeForWinAnsi(dateStr);

    setStatus('Adding headers & footers…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        const draws = await stampHeadersFooters(PDFLib, pdf, zones, fontSize, dateStr);

        if (draws === 0) {
            setStatus('Nothing to stamp — your text contained no printable characters.', true);
            return;
        }

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const n = pdf.getPageCount();
        setStatus(`Stamped ${n} page${n === 1 ? '' : 's'} → ${fileName}`);
    } catch (err) {
        console.error('[headers-footers] apply failed:', err);
        setStatus('Failed to add headers & footers. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to add headers & footers.', error: err });
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
        ? `${numPages} page${numPages === 1 ? '' : 's'} ready. Type header/footer text and apply.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    setStatus('Load a PDF first.');
}

export function initHeadersFooters() {
    zoneInputs = {};
    zoneIds.forEach((id) => { zoneInputs[id] = document.getElementById(id); });
    sizeInput = document.getElementById('hf-size');
    applyBtn = document.getElementById('hf-apply');
    statusEl = document.getElementById('hf-status');

    setEnabled(false);
    setStatus('Load a PDF first.');

    ActionRegistry.register('hf.apply', {
        title: 'Add headers & footers',
        run: () => applyHeadersFooters(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
