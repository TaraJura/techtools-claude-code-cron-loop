// font-inspector.js — Font Inspector panel (read-only).
//
// Lists the fonts declared in the open PDF and reports, per distinct font:
// its name (with any subset prefix stripped + flagged), its type
// (Type1 / TrueType / Type0 CID / Type3 / …), whether the font *program* is
// embedded in the file (and which program format — FontFile/FontFile2/
// FontFile3), and how many pages reference it. The standard "are my fonts
// embedded before I print/archive this?" check.
//
// It is purely observational — it NEVER modifies the document, never
// downloads, and never uploads anything. It complements statistics.js (which
// covers page sizes / structural counts but explicitly NOT fonts) and
// metadata.js (document properties).
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering
// core or the .pdf-viewer-container flex-row layout (prompt rule 8) — it only
// renders into its own #font-inspector-list panel. The raw PDF bytes come
// from pdf.js' own `doc.getData()`, parsed read-only with pdf-lib. Every
// PDF-supplied value (font names) is inserted via textContent (never
// innerHTML), so a crafted /BaseFont cannot inject markup (XSS-safe).

import { EventBus, Events } from './event-bus.js';

let listEl = null;
let statusEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

function ensureEls() {
    if (!listEl) listEl = document.getElementById('font-inspector-list');
    if (!statusEl) statusEl = document.getElementById('font-inspector-status');
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
    p.className = 'font-inspector-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/** Decode a PDFName string ("/ABCDEF+Arial#20Bold") to a readable name. */
function decodeFontName(pdfName) {
    if (!pdfName) return '';
    let s = pdfName.asString ? pdfName.asString() : String(pdfName);
    if (s.startsWith('/')) s = s.slice(1);
    // PDF name escapes: #XX hex -> char.
    return s.replace(/#([0-9A-Fa-f]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
}

/**
 * Walk the /Resources of one page (and one level into its Form XObjects),
 * recording every distinct font into `fonts`. Pure reads; never mutates.
 */
function collectFromResources(resources, pageIndex, depth, fonts, visited, PDFLib) {
    const { PDFName, PDFDict, PDFArray, PDFRef } = PDFLib;
    if (!(resources instanceof PDFDict)) return;

    // --- Fonts declared at this resource level ---
    const fontDict = resources.lookupMaybe(PDFName.of('Font'), PDFDict);
    if (fontDict instanceof PDFDict) {
        for (const [name] of fontDict.entries()) {
            let font;
            let ref = null;
            try {
                const raw = fontDict.get(name);
                ref = raw instanceof PDFRef ? raw : null;
                font = fontDict.lookup(name);
            } catch (e) {
                continue; // unreadable font entry — skip, never throw
            }
            if (!(font instanceof PDFDict)) continue;
            recordFont(font, ref, pageIndex, fonts, PDFLib);
        }
    }

    // --- One level into Form XObjects (they can carry their own fonts) ---
    if (depth > 0) {
        const xobjDict = resources.lookupMaybe(PDFName.of('XObject'), PDFDict);
        if (xobjDict instanceof PDFDict) {
            for (const [name] of xobjDict.entries()) {
                try {
                    const raw = xobjDict.get(name);
                    const key = raw instanceof PDFRef ? raw.toString() : null;
                    if (key) {
                        if (visited.has(key)) continue;
                        visited.add(key);
                    }
                    const stream = xobjDict.lookup(name);
                    const sdict = stream && stream.dict ? stream.dict : null;
                    if (!(sdict instanceof PDFDict)) continue;
                    const sub = sdict.lookupMaybe(PDFName.of('Subtype'), PDFName);
                    if (!sub || sub.asString() !== '/Form') continue;
                    const res2 = sdict.lookupMaybe(PDFName.of('Resources'), PDFDict);
                    collectFromResources(res2, pageIndex, depth - 1, fonts, visited, PDFLib);
                } catch (e) {
                    // ignore an unreadable XObject — keep walking
                }
            }
        }
    }
}

/** Inspect a single font dict and merge it into the `fonts` map. */
function recordFont(font, ref, pageIndex, fonts, PDFLib) {
    const { PDFName, PDFDict, PDFArray } = PDFLib;

    let subtype = 'Unknown';
    try {
        const st = font.lookupMaybe(PDFName.of('Subtype'), PDFName);
        if (st) subtype = st.asString().replace(/^\//, '');
    } catch (e) { /* keep default */ }

    let rawName = '';
    try {
        const bf = font.lookupMaybe(PDFName.of('BaseFont'), PDFName);
        if (bf) rawName = decodeFontName(bf);
    } catch (e) { /* leave blank */ }

    const isType3 = subtype === 'Type3';
    if (!rawName) rawName = isType3 ? '(embedded Type3 font)' : '(unnamed font)';

    const subsetMatch = /^([A-Z]{6})\+(.+)$/.exec(rawName);
    const isSubset = !!subsetMatch;
    const cleanName = subsetMatch ? subsetMatch[2] : rawName;

    // Locate the font descriptor (on the descendant font for Type0/CID fonts).
    let descriptor = null;
    try {
        if (subtype === 'Type0') {
            const desc = font.lookupMaybe(PDFName.of('DescendantFonts'), PDFArray);
            if (desc instanceof PDFArray && desc.size() > 0) {
                const df = desc.lookup(0);
                if (df instanceof PDFDict) {
                    descriptor = df.lookupMaybe(PDFName.of('FontDescriptor'), PDFDict);
                }
            }
        } else {
            descriptor = font.lookupMaybe(PDFName.of('FontDescriptor'), PDFDict);
        }
    } catch (e) { descriptor = null; }

    let embedded = false;
    let program = '';
    if (isType3) {
        embedded = true;
        program = 'Type3 (glyph procedures)';
    } else if (descriptor instanceof PDFDict) {
        try {
            if (descriptor.get(PDFName.of('FontFile'))) { embedded = true; program = 'Type1'; }
            else if (descriptor.get(PDFName.of('FontFile2'))) { embedded = true; program = 'TrueType'; }
            else if (descriptor.get(PDFName.of('FontFile3'))) {
                embedded = true;
                program = 'CFF / OpenType';
                try {
                    const ff3 = descriptor.lookup(PDFName.of('FontFile3'));
                    const fd = ff3 && ff3.dict ? ff3.dict : null;
                    if (fd instanceof PDFDict) {
                        const s = fd.lookupMaybe(PDFName.of('Subtype'), PDFName);
                        if (s) program = `${s.asString().replace(/^\//, '')} (CFF)`;
                    }
                } catch (e) { /* keep generic label */ }
            }
        } catch (e) { /* presence checks failed — treat as not embedded */ }
    }

    // Distinct-font key: prefer the shared indirect ref (so a font reused
    // across pages counts once); otherwise fall back to its identity.
    const key = ref ? ref.toString() : `${rawName}|${subtype}|${embedded}`;
    let entry = fonts.get(key);
    if (!entry) {
        entry = { cleanName, rawName, subtype, embedded, program, isSubset, pages: new Set() };
        fonts.set(key, entry);
    }
    entry.pages.add(pageIndex);
}

/** Build a labelled card for one font and append it to the list. */
function renderFontCard(parent, entry) {
    const card = document.createElement('div');
    card.className = 'font-card';

    const head = document.createElement('div');
    head.className = 'font-card-name';
    head.textContent = entry.cleanName;
    if (entry.isSubset) {
        const badge = document.createElement('span');
        badge.className = 'font-badge';
        badge.textContent = 'subset';
        badge.title = 'Only the glyphs actually used are embedded';
        head.appendChild(document.createTextNode(' '));
        head.appendChild(badge);
    }
    const embBadge = document.createElement('span');
    embBadge.className = `font-badge ${entry.embedded ? 'font-badge-ok' : 'font-badge-warn'}`;
    embBadge.textContent = entry.embedded ? 'embedded' : 'not embedded';
    head.appendChild(document.createTextNode(' '));
    head.appendChild(embBadge);
    card.appendChild(head);

    const dl = document.createElement('dl');
    dl.className = 'font-card-grid';
    const addRow = (term, value) => {
        if (value === undefined || value === null || value === '') return;
        const dt = document.createElement('dt');
        dt.textContent = term;
        const dd = document.createElement('dd');
        dd.textContent = String(value);
        dl.appendChild(dt);
        dl.appendChild(dd);
    };
    addRow('Type', entry.subtype);
    addRow('Program', entry.embedded ? (entry.program || 'embedded') : 'referenced (relies on viewer fonts)');
    const n = entry.pages.size;
    addRow('Used on', `${n} page${n === 1 ? '' : 's'}`);
    card.appendChild(dl);

    parent.appendChild(card);
}

async function inspectFonts(doc) {
    ensureEls();
    if (!listEl) return;
    const myToken = loadToken;

    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        setPlaceholder('');
        return;
    }

    setStatus('Inspecting fonts…');
    setPlaceholder('');

    let fonts;
    try {
        const srcBytes = await doc.getData();
        if (myToken !== loadToken) return; // a newer document loaded meanwhile
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });

        fonts = new Map();
        const visited = new Set();
        const pages = pdfDoc.getPages();
        for (let i = 0; i < pages.length; i += 1) {
            let resources;
            try {
                resources = pages[i].node.Resources();
            } catch (e) {
                continue; // a page with unreadable resources — skip it
            }
            collectFromResources(resources, i + 1, 1, fonts, visited, PDFLib);
        }
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[font-inspector] inspection failed:', err);
        setStatus('Could not read fonts. The PDF may be corrupted or use an unsupported structure.', true);
        setPlaceholder('');
        return;
    }

    if (myToken !== loadToken) return;

    const entries = Array.from(fonts.values()).sort((a, b) =>
        a.cleanName.localeCompare(b.cleanName));

    if (entries.length === 0) {
        setStatus('');
        setPlaceholder('No fonts found in this document.');
        return;
    }

    const embeddedCount = entries.filter((e) => e.embedded).length;
    const notEmbedded = entries.length - embeddedCount;
    setStatus(`${entries.length} font${entries.length === 1 ? '' : 's'} — ` +
        `${embeddedCount} embedded, ${notEmbedded} not embedded`);

    listEl.innerHTML = '';
    for (const entry of entries) renderFontCard(listEl, entry);
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        setPlaceholder('');
        return;
    }
    inspectFonts(doc).catch((err) => {
        console.error('[font-inspector] unexpected error:', err);
        setStatus('Could not read fonts.', true);
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    setPlaceholder('');
}

export function initFontInspector() {
    ensureEls();
    setStatus('Open a PDF first.');
    setPlaceholder('');

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
