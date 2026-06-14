// image-manager.js — Image inspector / catalog panel (read-only).
//
// Catalogs the raster image XObjects embedded in the open PDF and reports, per
// distinct image: its pixel dimensions (W×H + megapixels), bit depth
// (/BitsPerComponent), color space (DeviceRGB / DeviceGray / DeviceCMYK /
// Indexed / ICCBased / …), compression filter (/DCTDecode → JPEG,
// /FlateDecode → lossless, /JPXDecode → JPEG2000, /CCITTFaxDecode & /JBIG2Decode
// → fax/bilevel, /RunLengthDecode, /LZWDecode), whether it carries a soft mask
// (/SMask → transparency), and how many pages reference it. The standard
// "what images does this PDF carry, are any huge, JPEG vs lossless?" audit
// before printing / archiving / compressing.
//
// It is purely observational — it NEVER modifies the document, never decodes or
// renders image bytes, never downloads, and never uploads anything. It only
// reads the structural metadata in each image stream's dictionary, so peak
// memory stays tiny even for image-heavy PDFs. It complements
// font-inspector.js (fonts) and statistics.js (page sizes / structural counts),
// neither of which catalog embedded images.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering
// core or the .pdf-viewer-container flex-row layout (prompt rule 8) — it only
// renders into its own #image-manager-list panel. The raw PDF bytes come from
// pdf.js' own `doc.getData()`, parsed read-only with pdf-lib. Every PDF-supplied
// value (color-space / filter names) is inserted via textContent (never
// innerHTML), so a crafted name cannot inject markup (XSS-safe).

import { EventBus, Events } from './event-bus.js';

let listEl = null;
let statusEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

function ensureEls() {
    if (!listEl) listEl = document.getElementById('image-manager-list');
    if (!statusEl) statusEl = document.getElementById('image-manager-status');
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
    p.className = 'image-manager-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/** Strip the leading slash from a PDFName string ("/DeviceRGB" -> "DeviceRGB"). */
function nameStr(pdfName) {
    if (!pdfName) return '';
    const s = pdfName.asString ? pdfName.asString() : String(pdfName);
    return s.replace(/^\//, '');
}

/** Human label + short tag for a known image-compression filter. */
function filterLabel(filterName) {
    switch (filterName) {
        case 'DCTDecode':       return { label: 'JPEG (DCT)', tag: 'JPEG' };
        case 'JPXDecode':       return { label: 'JPEG 2000', tag: 'JPEG2000' };
        case 'FlateDecode':     return { label: 'Flate (lossless)', tag: 'Flate' };
        case 'LZWDecode':       return { label: 'LZW (lossless)', tag: 'LZW' };
        case 'RunLengthDecode': return { label: 'RunLength (lossless)', tag: 'RunLength' };
        case 'CCITTFaxDecode':  return { label: 'CCITT fax (bilevel)', tag: 'CCITT' };
        case 'JBIG2Decode':     return { label: 'JBIG2 (bilevel)', tag: 'JBIG2' };
        case '':                return { label: 'none (raw)', tag: 'raw' };
        default:                return { label: filterName, tag: filterName };
    }
}

/**
 * Read the /Filter of an image stream dict as a name string. /Filter may be a
 * single name or an array (filter chain) — use the LAST entry, which is the
 * image-compression filter relevant to the user.
 */
function readFilter(sdict, PDFLib) {
    const { PDFName, PDFArray } = PDFLib;
    try {
        const raw = sdict.lookup(PDFName.of('Filter'));
        if (raw instanceof PDFName) return nameStr(raw);
        if (raw instanceof PDFArray && raw.size() > 0) {
            const last = raw.lookup(raw.size() - 1);
            return last instanceof PDFName ? nameStr(last) : '';
        }
    } catch (e) { /* unreadable filter — treat as none */ }
    return '';
}

/** Describe an image's color space from its /ColorSpace entry (best-effort). */
function readColorSpace(sdict, PDFLib) {
    const { PDFName, PDFArray } = PDFLib;
    try {
        const raw = sdict.lookup(PDFName.of('ColorSpace'));
        if (raw instanceof PDFName) return nameStr(raw);
        if (raw instanceof PDFArray && raw.size() > 0) {
            // e.g. [/ICCBased <stream>], [/Indexed /DeviceRGB ...], [/ICCBased ...]
            const head = raw.lookup(0);
            const headName = head instanceof PDFName ? nameStr(head) : '';
            if (headName === 'Indexed') return 'Indexed';
            if (headName === 'ICCBased') {
                // The component count (/N) on the ICC stream hints the family.
                try {
                    const st = raw.lookup(1);
                    const sd = st && st.dict ? st.dict : null;
                    if (sd) {
                        const n = sd.lookupMaybe(PDFName.of('N'), PDFLib.PDFNumber);
                        const nv = n ? n.asNumber() : 0;
                        const fam = nv === 1 ? 'Gray' : nv === 4 ? 'CMYK' : nv === 3 ? 'RGB' : '';
                        return fam ? `ICCBased (${fam})` : 'ICCBased';
                    }
                } catch (e) { /* fall through */ }
                return 'ICCBased';
            }
            return headName || 'special';
        }
    } catch (e) { /* unreadable — unknown */ }
    return 'unknown';
}

/** Read a small positive integer entry from a dict, or 0 if absent/unreadable. */
function readInt(sdict, key, PDFLib) {
    try {
        const v = sdict.lookupMaybe(PDFLib.PDFName.of(key), PDFLib.PDFNumber);
        return v ? v.asNumber() : 0;
    } catch (e) { return 0; }
}

/**
 * Walk the /Resources of one page (and one level into its Form XObjects),
 * recording every distinct image XObject into `images`. Pure reads; never
 * mutates, never decodes the image bytes.
 */
function collectFromResources(resources, pageIndex, depth, images, visited, PDFLib) {
    const { PDFName, PDFDict, PDFRef } = PDFLib;
    if (!(resources instanceof PDFDict)) return;

    const xobjDict = resources.lookupMaybe(PDFName.of('XObject'), PDFDict);
    if (!(xobjDict instanceof PDFDict)) return;

    for (const [name] of xobjDict.entries()) {
        let stream;
        let ref = null;
        try {
            const raw = xobjDict.get(name);
            ref = raw instanceof PDFRef ? raw : null;
            stream = xobjDict.lookup(name);
        } catch (e) {
            continue; // unreadable XObject entry — skip, never throw
        }
        const sdict = stream && stream.dict ? stream.dict : null;
        if (!(sdict instanceof PDFDict)) continue;

        let sub = '';
        try {
            const st = sdict.lookupMaybe(PDFName.of('Subtype'), PDFName);
            if (st) sub = nameStr(st);
        } catch (e) { /* keep blank */ }

        if (sub === 'Image') {
            recordImage(sdict, ref, pageIndex, images, PDFLib);
        } else if (sub === 'Form' && depth > 0) {
            // A Form XObject may carry its own image resources — recurse once.
            const key = ref ? ref.toString() : null;
            if (key) {
                if (visited.has(key)) continue;
                visited.add(key);
            }
            try {
                const res2 = sdict.lookupMaybe(PDFName.of('Resources'), PDFDict);
                collectFromResources(res2, pageIndex, depth - 1, images, visited, PDFLib);
            } catch (e) { /* ignore an unreadable nested form */ }
        }
    }
}

/** Inspect a single image stream dict and merge it into the `images` map. */
function recordImage(sdict, ref, pageIndex, images, PDFLib) {
    const { PDFName } = PDFLib;

    const width = readInt(sdict, 'Width', PDFLib);
    const height = readInt(sdict, 'Height', PDFLib);

    // ImageMask images are 1-bit stencils with no /BitsPerComponent/ColorSpace.
    let isMask = false;
    try {
        const m = sdict.lookupMaybe(PDFName.of('ImageMask'), PDFLib.PDFBool);
        if (m && typeof m.asBoolean === 'function') isMask = m.asBoolean();
    } catch (e) { /* not a mask */ }

    const bpc = isMask ? 1 : readInt(sdict, 'BitsPerComponent', PDFLib);
    const colorSpace = isMask ? 'ImageMask (stencil)' : readColorSpace(sdict, PDFLib);
    const filterName = readFilter(sdict, PDFLib);
    const { label: filterText, tag: filterTag } = filterLabel(filterName);

    let hasAlpha = false;
    try {
        if (sdict.lookup(PDFName.of('SMask'))) hasAlpha = true;
    } catch (e) { /* no soft mask */ }

    // Distinct-image key: prefer the shared indirect ref (so an image reused
    // across pages counts once); otherwise fall back to its dimensions+filter.
    const key = ref ? ref.toString()
        : `${width}x${height}|${bpc}|${colorSpace}|${filterName}`;
    let entry = images.get(key);
    if (!entry) {
        entry = {
            width, height, bpc, colorSpace,
            filterText, filterTag, isMask, hasAlpha,
            pages: new Set(),
        };
        images.set(key, entry);
    }
    entry.pages.add(pageIndex);
}

/** Format a pixel count as megapixels (e.g. 3.4 MP) for the summary/cards. */
function megapixels(w, h) {
    return (w * h) / 1_000_000;
}

/** Build a labelled card for one image and append it to the list. */
function renderImageCard(parent, entry, index) {
    const card = document.createElement('div');
    card.className = 'image-card';

    const head = document.createElement('div');
    head.className = 'image-card-name';
    const dims = (entry.width > 0 && entry.height > 0)
        ? `${entry.width} × ${entry.height} px`
        : 'unknown size';
    head.textContent = `Image ${index} — ${dims}`;

    const filterBadge = document.createElement('span');
    filterBadge.className = 'image-badge';
    filterBadge.textContent = entry.filterTag;
    filterBadge.title = entry.filterText;
    head.appendChild(document.createTextNode(' '));
    head.appendChild(filterBadge);

    if (entry.hasAlpha) {
        const aBadge = document.createElement('span');
        aBadge.className = 'image-badge image-badge-alpha';
        aBadge.textContent = 'transparency';
        aBadge.title = 'Carries a soft mask (/SMask)';
        head.appendChild(document.createTextNode(' '));
        head.appendChild(aBadge);
    }
    card.appendChild(head);

    const dl = document.createElement('dl');
    dl.className = 'image-card-grid';
    const addRow = (term, value) => {
        if (value === undefined || value === null || value === '') return;
        const dt = document.createElement('dt');
        dt.textContent = term;
        const dd = document.createElement('dd');
        dd.textContent = String(value);
        dl.appendChild(dt);
        dl.appendChild(dd);
    };
    if (entry.width > 0 && entry.height > 0) {
        const mp = megapixels(entry.width, entry.height);
        addRow('Resolution', `${mp >= 0.1 ? mp.toFixed(1) : mp.toFixed(2)} MP`);
    }
    addRow('Color space', entry.colorSpace);
    addRow('Bit depth', entry.bpc > 0 ? `${entry.bpc} bit${entry.bpc === 1 ? '' : 's'}/component` : undefined);
    addRow('Compression', entry.filterText);
    const n = entry.pages.size;
    addRow('Used on', `${n} page${n === 1 ? '' : 's'}`);
    card.appendChild(dl);

    parent.appendChild(card);
}

async function inspectImages(doc) {
    ensureEls();
    if (!listEl) return;
    const myToken = loadToken;

    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        setPlaceholder('');
        return;
    }

    setStatus('Inspecting images…');
    setPlaceholder('');

    let images;
    try {
        const srcBytes = await doc.getData();
        if (myToken !== loadToken) return; // a newer document loaded meanwhile
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });

        images = new Map();
        const visited = new Set();
        const pages = pdfDoc.getPages();
        for (let i = 0; i < pages.length; i += 1) {
            let resources;
            try {
                resources = pages[i].node.Resources();
            } catch (e) {
                continue; // a page with unreadable resources — skip it
            }
            collectFromResources(resources, i + 1, 1, images, visited, PDFLib);
        }
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[image-manager] inspection failed:', err);
        setStatus('Could not read images. The PDF may be corrupted or use an unsupported structure.', true);
        setPlaceholder('');
        return;
    }

    if (myToken !== loadToken) return;

    // Largest-first so the heaviest images surface at the top.
    const entries = Array.from(images.values()).sort((a, b) =>
        (b.width * b.height) - (a.width * a.height));

    if (entries.length === 0) {
        setStatus('');
        setPlaceholder('No images found in this document.');
        return;
    }

    // Summary: count + largest MP + per-filter tally.
    const tally = new Map();
    let largest = 0;
    for (const e of entries) {
        largest = Math.max(largest, megapixels(e.width, e.height));
        tally.set(e.filterTag, (tally.get(e.filterTag) || 0) + 1);
    }
    const tallyText = Array.from(tally.entries())
        .map(([tag, count]) => `${count} ${tag}`)
        .join(', ');
    const largestText = largest >= 0.1
        ? `${largest.toFixed(1)} MP largest` : `${largest.toFixed(2)} MP largest`;
    setStatus(`${entries.length} image${entries.length === 1 ? '' : 's'} — ` +
        `${largestText}${tallyText ? ` — ${tallyText}` : ''}`);

    listEl.innerHTML = '';
    entries.forEach((entry, i) => renderImageCard(listEl, entry, i + 1));
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        setPlaceholder('');
        return;
    }
    inspectImages(doc).catch((err) => {
        console.error('[image-manager] unexpected error:', err);
        setStatus('Could not read images.', true);
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    setPlaceholder('');
}

export function initImageManager() {
    ensureEls();
    setStatus('Open a PDF first.');
    setPlaceholder('');

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
