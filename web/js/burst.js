// burst.js — Burst / Split to single pages: explode the open PDF into ONE
// single-page PDF per page and deliver them all as a single ZIP download
// (e.g. document-pages.zip containing page-001.pdf, page-002.pdf, …).
//
// Distinct from Split (split.js — contiguous ranges → a few multi-page PDFs)
// and Extract pages (extract-pages.js — a chosen subset → ONE PDF). Burst is
// the "explode a PDF" workflow: one file per page, bundled into a ZIP.
//
// Pure pdf-lib structural copy — for each target page we create a fresh
// PDFDocument, copyPages() that single page, save() to bytes, and add it to the
// archive. NO rasterization, so memory stays low (safe for the 1.6 GiB box);
// each page's original size and rotation are preserved. Pages are processed
// sequentially (await each save) to keep peak memory low.
//
// The ZIP is assembled by a tiny self-contained STORE-only writer below rather
// than a third-party library: JSZip is not present in lib/ and the CSP is
// `script-src 'self'` (no CDN), so a ~60-line dependency-free writer is the
// lowest-risk path. PDFs are already compressed, so storing (no deflate) costs
// almost nothing in size. The output is a standards-compliant ZIP (local file
// headers + central directory + EOCD) that any unzip tool — and pdf-lib, after
// extraction — reads cleanly.
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

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let rangeInput = null;   // page-range text input ("all" or "1-3,5")
let runBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (rangeInput) rangeInput.disabled = !enabled;
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
 * Parse the range expression into a sorted array of 1-based page numbers.
 * Empty or "all" (case-insensitive) selects every page. Otherwise accepts a
 * comma list of single pages and ascending/descending ranges, e.g. "1, 3, 5-7".
 * Returns { pages: number[] } (ascending, de-duplicated) on success or
 * { error } with a specific message. Out-of-bounds / malformed tokens are
 * rejected (never silent). Mirrors the helper used by flip-pages.js /
 * extract-pages.js so behaviour is consistent across page tools.
 */
function parseRange(expr, max) {
    const trimmed = String(expr == null ? '' : expr).trim();
    if (trimmed === '' || /^all$/i.test(trimmed)) {
        const all = [];
        for (let i = 1; i <= max; i++) all.push(i);
        return { pages: all };
    }

    const set = new Set();
    for (const raw of trimmed.split(',')) {
        const token = raw.trim();
        if (!token) continue; // tolerate stray/empty commas

        if (/^\d+$/.test(token)) {
            const n = parseInt(token, 10);
            if (n < 1) return { error: `"${token}" is not a valid page or range.` };
            if (n > max) return { error: `Page ${n} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
            set.add(n);
            continue;
        }

        const m = token.match(/^(\d+)\s*-\s*(\d+)$/);
        if (!m) return { error: `"${token}" is not a valid page or range.` };
        const a = parseInt(m[1], 10);
        const b = parseInt(m[2], 10);
        if (a < 1 || b < 1) return { error: `"${token}" is not a valid page or range.` };
        if (a > max || b > max) {
            return { error: `Page ${Math.max(a, b)} is out of range (document has ${max} page${max === 1 ? '' : 's'}).` };
        }
        const lo = Math.min(a, b);
        const hi = Math.max(a, b);
        for (let i = lo; i <= hi; i++) set.add(i);
    }

    if (set.size === 0) return { error: 'Enter pages to burst, e.g. all or 1, 3, 5-7.' };
    return { pages: Array.from(set).sort((x, y) => x - y) };
}

// ---------------------------------------------------------------------------
// Minimal STORE-only ZIP writer (no compression, no dependency, no eval).
// ---------------------------------------------------------------------------

let crcTable = null;
function makeCrcTable() {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) {
            c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        }
        t[n] = c >>> 0;
    }
    return t;
}
function crc32(bytes) {
    if (!crcTable) crcTable = makeCrcTable();
    let c = 0xFFFFFFFF;
    for (let i = 0; i < bytes.length; i++) {
        c = crcTable[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) >>> 0;
}

/**
 * Build a ZIP archive (stored, uncompressed) from [{ name, data:Uint8Array }].
 * Filenames are ASCII (page-001.pdf …) so no UTF-8 flag is needed. Sizes stay
 * well under 4 GB for any realistic document, so 32-bit fields (no ZIP64) are
 * fine. Returns a single Uint8Array.
 */
function buildZip(entries) {
    const enc = new TextEncoder();
    const dosTime = 0;
    const dosDate = 0x21; // 1980-01-01 — fixed, no real timestamp needed
    const localChunks = [];
    const centralChunks = [];
    let offset = 0;

    for (const ent of entries) {
        const nameBytes = enc.encode(ent.name);
        const data = ent.data;
        const crc = crc32(data);
        const size = data.length;

        const lh = new Uint8Array(30 + nameBytes.length);
        const lv = new DataView(lh.buffer);
        lv.setUint32(0, 0x04034b50, true); // local file header signature
        lv.setUint16(4, 20, true);         // version needed to extract
        lv.setUint16(6, 0, true);          // general purpose flags
        lv.setUint16(8, 0, true);          // compression method: 0 = store
        lv.setUint16(10, dosTime, true);
        lv.setUint16(12, dosDate, true);
        lv.setUint32(14, crc, true);
        lv.setUint32(18, size, true);      // compressed size
        lv.setUint32(22, size, true);      // uncompressed size
        lv.setUint16(26, nameBytes.length, true);
        lv.setUint16(28, 0, true);         // extra field length
        lh.set(nameBytes, 30);
        localChunks.push(lh, data);

        const ch = new Uint8Array(46 + nameBytes.length);
        const cv = new DataView(ch.buffer);
        cv.setUint32(0, 0x02014b50, true); // central directory signature
        cv.setUint16(4, 20, true);         // version made by
        cv.setUint16(6, 20, true);         // version needed
        cv.setUint16(8, 0, true);          // flags
        cv.setUint16(10, 0, true);         // method: store
        cv.setUint16(12, dosTime, true);
        cv.setUint16(14, dosDate, true);
        cv.setUint32(16, crc, true);
        cv.setUint32(20, size, true);
        cv.setUint32(24, size, true);
        cv.setUint16(28, nameBytes.length, true);
        cv.setUint16(30, 0, true);         // extra length
        cv.setUint16(32, 0, true);         // comment length
        cv.setUint16(34, 0, true);         // disk number start
        cv.setUint16(36, 0, true);         // internal attributes
        cv.setUint32(38, 0, true);         // external attributes
        cv.setUint32(42, offset, true);    // local header offset
        ch.set(nameBytes, 46);
        centralChunks.push(ch);

        offset += lh.length + data.length;
    }

    const cdOffset = offset;
    let cdSize = 0;
    for (const c of centralChunks) cdSize += c.length;

    const eocd = new Uint8Array(22);
    const ev = new DataView(eocd.buffer);
    ev.setUint32(0, 0x06054b50, true);     // end of central directory signature
    ev.setUint16(4, 0, true);              // number of this disk
    ev.setUint16(6, 0, true);              // disk with central directory
    ev.setUint16(8, entries.length, true); // entries on this disk
    ev.setUint16(10, entries.length, true);// total entries
    ev.setUint32(12, cdSize, true);
    ev.setUint32(16, cdOffset, true);
    ev.setUint16(20, 0, true);             // comment length

    const all = localChunks.concat(centralChunks, [eocd]);
    let total = 0;
    for (const c of all) total += c.length;
    const out = new Uint8Array(total);
    let p = 0;
    for (const c of all) { out.set(c, p); p += c.length; }
    return out;
}

/** Trigger a browser download for the given bytes. */
function downloadBytes(bytes, fileName, mime) {
    const blob = new Blob([bytes], { type: mime || 'application/octet-stream' });
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
 * Burst the open PDF: one single-page PDF per selected page, bundled into a ZIP.
 * Each page is copied (structural, no rasterization) into a fresh PDFDocument
 * and saved to bytes; filenames are zero-padded and reflect the ORIGINAL page
 * numbers. Pages are processed sequentially to keep peak memory low.
 */
async function runBurst() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[burst] window.PDFLib unavailable');
        return;
    }

    const parsed = parseRange(rangeInput ? rangeInput.value : '', numPages);
    if (parsed.error) {
        setStatus(parsed.error, true);
        return;
    }
    const targets = parsed.pages; // ascending 1-based page numbers

    setStatus('Bursting…');
    setEnabled(false);
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them once.
        const srcBytes = await currentDoc.getData();
        const srcPdf = await PDFLib.PDFDocument.load(srcBytes);

        // Zero-pad to the width of the largest page number in the whole document
        // so filenames sort correctly (page-001.pdf … page-010.pdf).
        const pad = String(numPages).length;
        const entries = [];

        for (let idx = 0; idx < targets.length; idx++) {
            const pageNo = targets[idx]; // 1-based, original numbering
            const onePage = await PDFLib.PDFDocument.create();
            const [copied] = await onePage.copyPages(srcPdf, [pageNo - 1]);
            onePage.addPage(copied);
            const bytes = await onePage.save();
            const fileName = `page-${String(pageNo).padStart(pad, '0')}.pdf`;
            entries.push({ name: fileName, data: bytes });
            setStatus(`Bursting… ${idx + 1}/${targets.length}`);
        }

        const zipBytes = buildZip(entries);
        const zipName = `${baseName()}-pages.zip`;
        downloadBytes(zipBytes, zipName, 'application/zip');

        const n = entries.length;
        setStatus(`Burst ${n} page${n === 1 ? '' : 's'} into ${zipName} (one PDF per page).`);
    } catch (err) {
        console.error('[burst] Burst failed:', err);
        setStatus('Failed to burst the PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to burst the PDF.', error: err });
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

export function initBurst() {
    rangeInput = document.getElementById('burst-range');
    runBtn = document.getElementById('burst-run');
    statusEl = document.getElementById('burst-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="burst"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runBurst();
            }
        });
    }

    ActionRegistry.register('burst.run', {
        title: 'Burst PDF into one single-page PDF per page (ZIP)',
        run: () => runBurst(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
