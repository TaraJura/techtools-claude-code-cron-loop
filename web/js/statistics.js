// statistics.js — Document Statistics / analytics panel (read-only).
//
// Shows quantitative analytics about the open PDF that the Info panel
// (metadata.js) intentionally does NOT cover: on-disk file size, a per-page
// size breakdown with standard-paper detection (A4/Letter/Legal/…), the
// largest/smallest page, and structural facts (bookmark/outline count,
// attachment count, permission restrictions, PDF version). It is purely
// observational — it never modifies the document, never downloads, and never
// uploads anything.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering
// core or the .pdf-viewer-container flex-row layout — it only renders into its
// own #statistics-list panel. Every PDF-supplied value is inserted via
// textContent (never innerHTML), so a crafted name/outline title cannot inject
// markup (XSS-safe). The raw byte length comes from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';

let listEl = null;
let statusEl = null;

// Standard paper sizes in PDF points (1pt = 1/72"), stored portrait
// (width < height). Detection is orientation-independent.
const PAPER_SIZES = [
    { name: 'A6', w: 297.64, h: 419.53 },
    { name: 'A5', w: 419.53, h: 595.28 },
    { name: 'A4', w: 595.28, h: 841.89 },
    { name: 'A3', w: 841.89, h: 1190.55 },
    { name: 'A2', w: 1190.55, h: 1683.78 },
    { name: 'Letter', w: 612, h: 792 },
    { name: 'Legal', w: 612, h: 1008 },
    { name: 'Tabloid', w: 792, h: 1224 },
    { name: 'Executive', w: 522, h: 756 },
];

const PT_PER_MM = 72 / 25.4;
const SIZE_TOLERANCE_PT = 6; // ~2mm — covers rounding between producers.

function ensureEls() {
    if (!listEl) listEl = document.getElementById('statistics-list');
    if (!statusEl) statusEl = document.getElementById('statistics-status');
}

function setStatus(msg, isError = false) {
    ensureEls();
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

function setPlaceholder(text) {
    ensureEls();
    if (!listEl) return;
    listEl.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'statistics-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/** Human-readable byte count (e.g. 1.4 MB). */
function formatBytes(bytes) {
    if (!Number.isFinite(bytes) || bytes < 0) return '—';
    if (bytes < 1024) return `${bytes} B`;
    const units = ['KB', 'MB', 'GB'];
    let val = bytes / 1024;
    let i = 0;
    while (val >= 1024 && i < units.length - 1) {
        val /= 1024;
        i += 1;
    }
    return `${val.toFixed(val >= 100 ? 0 : 1)} ${units[i]}`;
}

/** Match a point dimension pair to a known paper name, or null. */
function detectPaper(wPt, hPt) {
    const lo = Math.min(wPt, hPt);
    const hi = Math.max(wPt, hPt);
    for (const p of PAPER_SIZES) {
        if (Math.abs(lo - p.w) <= SIZE_TOLERANCE_PT && Math.abs(hi - p.h) <= SIZE_TOLERANCE_PT) {
            return p.name;
        }
    }
    return null;
}

/** Format a point dimension pair as "210 × 297 mm" (portrait/landscape kept). */
function formatDimensions(wPt, hPt) {
    const wmm = Math.round(wPt / PT_PER_MM);
    const hmm = Math.round(hPt / PT_PER_MM);
    return `${wmm} × ${hmm} mm`;
}

/** Append a term/description pair to a <dl>, only when value is non-empty. */
function addRow(dl, term, value) {
    if (value === undefined || value === null || value === '') return;
    const dt = document.createElement('dt');
    dt.textContent = term;
    const dd = document.createElement('dd');
    dd.textContent = String(value);
    dl.appendChild(dt);
    dl.appendChild(dd);
}

/** Count outline entries recursively (top-level + nested). */
function countOutline(items) {
    if (!Array.isArray(items)) return 0;
    let n = 0;
    for (const it of items) {
        n += 1;
        if (it && Array.isArray(it.items)) n += countOutline(it.items);
    }
    return n;
}

/**
 * Walk every page once, collecting point dimensions. Returns a grouped,
 * count-sorted summary plus the largest/smallest page by area.
 */
async function collectPageSizes(doc) {
    const groups = new Map(); // key "wPt|hPt" -> { wPt, hPt, count }
    let largest = null;
    let smallest = null;

    for (let i = 1; i <= doc.numPages; i += 1) {
        const page = await doc.getPage(i);
        const vp = page.getViewport({ scale: 1 });
        const wPt = Math.round(vp.width);
        const hPt = Math.round(vp.height);
        const area = wPt * hPt;
        const key = `${wPt}|${hPt}`;
        const g = groups.get(key);
        if (g) g.count += 1;
        else groups.set(key, { wPt, hPt, count: 1 });

        if (!largest || area > largest.area) largest = { wPt, hPt, area, index: i };
        if (!smallest || area < smallest.area) smallest = { wPt, hPt, area, index: i };
        // Release page resources promptly on a small-RAM box.
        if (typeof page.cleanup === 'function') page.cleanup();
    }

    const list = Array.from(groups.values()).sort((a, b) => b.count - a.count);
    return { list, largest, smallest };
}

/** Render one labelled section heading into the list. */
function addHeading(parent, text) {
    const h = document.createElement('h3');
    h.className = 'statistics-heading';
    h.textContent = text;
    parent.appendChild(h);
}

async function onLoaded({ doc, name, numPages }) {
    ensureEls();
    if (!listEl) return;

    if (!doc) {
        onCleared();
        return;
    }

    setStatus('Analyzing document…');

    // Gather everything defensively — any single failure degrades gracefully.
    let info = {};
    let byteLen = null;
    let outlineCount = 0;
    let attachCount = 0;
    let permissions = null;

    try {
        const meta = await doc.getMetadata();
        info = (meta && meta.info) || {};
    } catch (err) {
        console.warn('[statistics] getMetadata failed:', err);
    }
    try {
        const data = await doc.getData();
        byteLen = data ? data.length : null;
    } catch (err) {
        console.warn('[statistics] getData failed:', err);
    }
    try {
        const outline = await doc.getOutline();
        outlineCount = countOutline(outline);
    } catch (err) {
        console.warn('[statistics] getOutline failed:', err);
    }
    try {
        const att = await doc.getAttachments();
        attachCount = att ? Object.keys(att).length : 0;
    } catch (err) {
        console.warn('[statistics] getAttachments failed:', err);
    }
    try {
        permissions = await doc.getPermissions(); // array if encrypted w/ perms, else null
    } catch (err) {
        console.warn('[statistics] getPermissions failed:', err);
    }

    let sizes = { list: [], largest: null, smallest: null };
    try {
        sizes = await collectPageSizes(doc);
    } catch (err) {
        console.warn('[statistics] page size scan failed:', err);
    }

    // --- Render -----------------------------------------------------------
    const frag = document.createDocumentFragment();

    // Overview
    addHeading(frag, 'Overview');
    const overview = document.createElement('dl');
    overview.className = 'metadata-grid';
    addRow(overview, 'File name', name || 'document.pdf');
    addRow(overview, 'File size', byteLen != null ? formatBytes(byteLen) : '—');
    addRow(overview, 'Pages', numPages != null ? numPages : doc.numPages);
    if (byteLen != null && (numPages || doc.numPages)) {
        addRow(overview, 'Avg / page', formatBytes(Math.round(byteLen / (numPages || doc.numPages))));
    }
    addRow(overview, 'PDF version', info.PDFFormatVersion);
    addRow(overview, 'Bookmarks', outlineCount > 0 ? outlineCount : 'None');
    addRow(overview, 'Attachments', attachCount > 0 ? attachCount : 'None');
    addRow(overview, 'Restrictions', permissions ? 'Permission-restricted' : 'None');
    frag.appendChild(overview);

    // Page sizes
    addHeading(frag, 'Page sizes');
    if (sizes.list.length) {
        const dl = document.createElement('dl');
        dl.className = 'metadata-grid';
        for (const g of sizes.list) {
            const paper = detectPaper(g.wPt, g.hPt);
            const orient = g.wPt > g.hPt ? ' landscape' : '';
            const label = (paper ? `${paper}${orient} · ` : '') + formatDimensions(g.wPt, g.hPt);
            const pageWord = g.count === 1 ? 'page' : 'pages';
            addRow(dl, label, `${g.count} ${pageWord}`);
        }
        frag.appendChild(dl);

        if (sizes.largest && sizes.smallest && sizes.largest.area !== sizes.smallest.area) {
            const extremes = document.createElement('dl');
            extremes.className = 'metadata-grid';
            addRow(extremes, 'Largest page',
                `#${sizes.largest.index} · ${formatDimensions(sizes.largest.wPt, sizes.largest.hPt)}`);
            addRow(extremes, 'Smallest page',
                `#${sizes.smallest.index} · ${formatDimensions(sizes.smallest.wPt, sizes.smallest.hPt)}`);
            frag.appendChild(extremes);
        }
    } else {
        const p = document.createElement('p');
        p.className = 'statistics-empty';
        p.textContent = 'Page dimensions unavailable.';
        frag.appendChild(p);
    }

    listEl.innerHTML = '';
    listEl.appendChild(frag);
    setStatus(`Analyzed ${numPages != null ? numPages : doc.numPages} page(s).`);
}

function onCleared() {
    setStatus('Load a PDF first.');
    setPlaceholder('Open a PDF to see document statistics.');
}

export function initStatistics() {
    ensureEls();
    setStatus('Load a PDF first.');
    setPlaceholder('Open a PDF to see document statistics.');

    EventBus.on(Events.PDF_LOADED, (payload) => {
        onLoaded(payload || {}).catch((err) => {
            console.error('[statistics] render failed:', err);
            setStatus('Could not analyze this document.', true);
        });
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        onCleared();
    });
}
