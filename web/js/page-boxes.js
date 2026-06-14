// page-boxes.js — Page-box / print-geometry inspector panel (read-only).
//
// Reports the page-box geometry of every page in the open PDF. The PDF spec
// defines up to five boxes per page:
//   • MediaBox — the physical sheet (the only mandatory box; inheritable)
//   • CropBox  — the visible/clipped region (defaults to MediaBox)
//   • BleedBox — extends past the trim for print bleed (defaults to CropBox)
//   • TrimBox  — the finished, trimmed page (defaults to CropBox)
//   • ArtBox   — the meaningful content extent (defaults to CropBox)
// plus a page Rotation (0/90/180/270°). Prepress users need to confirm
// "does this PDF declare a proper TrimBox/BleedBox before I send it to print?",
// and ordinary users want to know "is the visible page (CropBox) smaller than
// the physical sheet (MediaBox)?". This panel answers both at a glance and
// auto-populates on document open (mirrors statistics.js / font-inspector.js /
// image-manager.js).
//
// It is purely observational — it NEVER modifies the document, never rasterizes
// or decodes page content, never downloads, and never uploads anything. It only
// reads the box rectangles from each page dictionary, so peak memory stays tiny
// even for very large documents (safe for the 1.6 GiB box).
//
// declared-vs-inherited: pdf-lib's get*Box() getters return the resolved spec
// default when a box is absent, so the resolved size alone cannot tell the user
// whether the box was actually set in the file. We therefore additionally do a
// raw present-key check on each page's leaf node (/CropBox /BleedBox /TrimBox
// /ArtBox) — the literal-key presence is what reveals declared vs inherited.
//
// Isolation: this module only talks to the rest of the app through the EventBus
// (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering core or the
// .pdf-viewer-container flex-row layout (prompt rule 8) — it only renders into
// its own #page-boxes-list panel. The raw PDF bytes come from pdf.js' own
// `doc.getData()`, parsed read-only with pdf-lib. Every value is inserted via
// textContent (never innerHTML), so it is XSS-safe.

import { EventBus, Events } from './event-bus.js';

const PT_TO_MM = 0.352778; // 1 pt = 25.4/72 mm

let listEl = null;
let statusEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

function ensureEls() {
    if (!listEl) listEl = document.getElementById('page-boxes-list');
    if (!statusEl) statusEl = document.getElementById('page-boxes-status');
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
    if (!text) return;
    const p = document.createElement('p');
    p.className = 'page-boxes-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/** Round a number to one decimal, dropping a trailing ".0". */
function r1(n) {
    const v = Math.round(n * 10) / 10;
    return Number.isInteger(v) ? String(v) : v.toFixed(1);
}

/** Format a box {width,height} (in PDF points) as "W × H pt · W × H mm". */
function fmtBox(box) {
    if (!box) return 'unknown';
    const w = box.width;
    const h = box.height;
    return `${r1(w)} × ${r1(h)} pt · ${r1(w * PT_TO_MM)} × ${r1(h * PT_TO_MM)} mm`;
}

/** Safe getter: returns a {x,y,width,height} box or null if the getter throws. */
function safeBox(fn) {
    try {
        const b = fn();
        if (b && typeof b.width === 'number' && typeof b.height === 'number') return b;
    } catch (e) { /* unreadable box — treat as absent */ }
    return null;
}

/**
 * Is `key` literally declared on this page's leaf node? pdf-lib's get*Box()
 * resolves the spec default, so this raw present-key check is what tells the
 * user whether the box was actually set in the file (vs inherited/defaulted).
 */
function isDeclared(pageNode, key, PDFLib) {
    try {
        const v = pageNode.get(PDFLib.PDFName.of(key));
        return v !== undefined && v !== null;
    } catch (e) {
        return false;
    }
}

/** Inspect a single page → a plain descriptor object (no DOM, no mutation). */
function describePage(page, PDFLib) {
    const node = page.node;
    const media = safeBox(() => page.getMediaBox());
    const crop = safeBox(() => page.getCropBox());
    const bleed = safeBox(() => page.getBleedBox());
    const trim = safeBox(() => page.getTrimBox());
    const art = safeBox(() => page.getArtBox());

    let rotation = 0;
    try {
        const rot = page.getRotation();
        rotation = rot && typeof rot.angle === 'number' ? rot.angle : 0;
    } catch (e) { rotation = 0; }
    // Normalise to 0/90/180/270.
    rotation = ((rotation % 360) + 360) % 360;

    return {
        media,
        crop,
        bleed,
        trim,
        art,
        rotation,
        cropDeclared: isDeclared(node, 'CropBox', PDFLib),
        bleedDeclared: isDeclared(node, 'BleedBox', PDFLib),
        trimDeclared: isDeclared(node, 'TrimBox', PDFLib),
        artDeclared: isDeclared(node, 'ArtBox', PDFLib),
        mediaDeclared: isDeclared(node, 'MediaBox', PDFLib),
    };
}

/**
 * A signature that is identical for pages with the same geometry, so a uniform
 * document collapses to a single group/row.
 */
function signature(d) {
    const b = (box) => box ? `${r1(box.width)}x${r1(box.height)}` : 'none';
    return [
        b(d.media), b(d.crop), b(d.bleed), b(d.trim), b(d.art),
        d.rotation,
        d.cropDeclared ? 'C' : 'c',
        d.bleedDeclared ? 'B' : 'b',
        d.trimDeclared ? 'T' : 't',
        d.artDeclared ? 'A' : 'a',
    ].join('|');
}

/** Compress an ascending list of page numbers into "1–4, 7, 9–10". */
function compressPages(nums) {
    if (nums.length === 0) return '';
    const parts = [];
    let start = nums[0];
    let prev = nums[0];
    for (let i = 1; i <= nums.length; i += 1) {
        const n = nums[i];
        if (n === prev + 1) { prev = n; continue; }
        parts.push(start === prev ? `${start}` : `${start}–${prev}`);
        start = n;
        prev = n;
    }
    return parts.join(', ');
}

/** Append a definition row (term / value [+ flag badge]) to a <dl>. */
function addRow(dl, term, value, flag) {
    const dt = document.createElement('dt');
    dt.textContent = term;
    const dd = document.createElement('dd');
    dd.textContent = value;
    if (flag) {
        const badge = document.createElement('span');
        badge.className = `page-box-flag ${flag.declared ? 'page-box-flag-declared' : 'page-box-flag-inherited'}`;
        badge.textContent = flag.declared ? 'declared' : 'inherited';
        if (flag.title) badge.title = flag.title;
        dd.appendChild(document.createTextNode(' '));
        dd.appendChild(badge);
    }
    dl.appendChild(dt);
    dl.appendChild(dd);
}

/** Build a card for one distinct geometry group and append it to the list. */
function renderGroupCard(parent, group, totalPages) {
    const d = group.descriptor;
    const card = document.createElement('div');
    card.className = 'page-box-card';

    const head = document.createElement('div');
    head.className = 'page-box-card-name';
    const pageList = compressPages(group.pages);
    const isAll = group.pages.length === totalPages;
    if (group.pages.length === 1) {
        head.textContent = `Page ${pageList}`;
    } else if (isAll) {
        head.textContent = `Pages ${pageList} (all)`;
    } else {
        head.textContent = `Pages ${pageList}`;
    }

    const countBadge = document.createElement('span');
    countBadge.className = 'page-box-count';
    countBadge.textContent = `${group.pages.length} page${group.pages.length === 1 ? '' : 's'}`;
    head.appendChild(document.createTextNode(' '));
    head.appendChild(countBadge);
    card.appendChild(head);

    const dl = document.createElement('dl');
    dl.className = 'page-box-grid';

    // MediaBox is always concrete (it is the only mandatory box).
    addRow(dl, 'MediaBox', d.media ? fmtBox(d.media) : 'unknown');
    // CropBox defaults to MediaBox; the others default to CropBox.
    addRow(dl, 'CropBox', d.crop ? fmtBox(d.crop) : 'unknown',
        { declared: d.cropDeclared, title: d.cropDeclared ? 'CropBox set on the page' : 'No /CropBox — inherits MediaBox' });
    addRow(dl, 'BleedBox', d.bleed ? fmtBox(d.bleed) : 'unknown',
        { declared: d.bleedDeclared, title: d.bleedDeclared ? 'BleedBox set on the page' : 'No /BleedBox — inherits CropBox' });
    addRow(dl, 'TrimBox', d.trim ? fmtBox(d.trim) : 'unknown',
        { declared: d.trimDeclared, title: d.trimDeclared ? 'TrimBox set on the page' : 'No /TrimBox — inherits CropBox' });
    addRow(dl, 'ArtBox', d.art ? fmtBox(d.art) : 'unknown',
        { declared: d.artDeclared, title: d.artDeclared ? 'ArtBox set on the page' : 'No /ArtBox — inherits CropBox' });
    addRow(dl, 'Rotation', `${d.rotation}°`);

    card.appendChild(dl);
    parent.appendChild(card);
}

async function inspectPageBoxes(doc) {
    ensureEls();
    if (!listEl) return;
    const myToken = loadToken;

    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        setPlaceholder('');
        return;
    }

    setStatus('Inspecting page boxes…');
    setPlaceholder('');

    let groups;
    let totalPages = 0;
    let anyTrim = false;
    let anyBleed = false;
    let allTrim = true;
    try {
        const srcBytes = await doc.getData();
        if (myToken !== loadToken) return; // a newer document loaded meanwhile
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });

        const pages = pdfDoc.getPages();
        totalPages = pages.length;
        const map = new Map(); // signature -> { descriptor, pages: [] }
        for (let i = 0; i < pages.length; i += 1) {
            let d;
            try {
                d = describePage(pages[i], PDFLib);
            } catch (e) {
                continue; // an unreadable page — skip it, never throw
            }
            if (d.trimDeclared) anyTrim = true; else allTrim = false;
            if (d.bleedDeclared) anyBleed = true;
            const sig = signature(d);
            let g = map.get(sig);
            if (!g) { g = { descriptor: d, pages: [] }; map.set(sig, g); }
            g.pages.push(i + 1);
        }
        // Order groups by their first page so the report reads top-to-bottom.
        groups = Array.from(map.values()).sort((a, b) => a.pages[0] - b.pages[0]);
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[page-boxes] inspection failed:', err);
        setStatus('Could not read page boxes. The PDF may be corrupted or use an unsupported structure.', true);
        setPlaceholder('');
        return;
    }

    if (myToken !== loadToken) return;

    if (totalPages === 0 || groups.length === 0) {
        setStatus('');
        setPlaceholder('No pages found in this document.');
        return;
    }

    // Summary: page count + geometry-group count + print-readiness hint.
    let summary = `${totalPages} page${totalPages === 1 ? '' : 's'} — `;
    summary += groups.length === 1
        ? 'all share one geometry'
        : `${groups.length} distinct box layouts`;
    if (allTrim && totalPages > 0) {
        summary += '; TrimBox declared on all pages';
    } else if (!anyTrim && !anyBleed) {
        summary += '; no TrimBox/BleedBox declared — not print-ready';
    } else if (anyTrim || anyBleed) {
        summary += '; TrimBox/BleedBox declared on some pages';
    }
    setStatus(summary);

    listEl.innerHTML = '';
    groups.forEach((g) => renderGroupCard(listEl, g, totalPages));
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        setPlaceholder('');
        return;
    }
    inspectPageBoxes(doc).catch((err) => {
        console.error('[page-boxes] unexpected error:', err);
        setStatus('Could not read page boxes.', true);
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    setPlaceholder('');
}

export function initPageBoxes() {
    ensureEls();
    setStatus('Open a PDF first.');
    setPlaceholder('');

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
