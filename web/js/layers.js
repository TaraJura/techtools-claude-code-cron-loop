// layers.js — Optional Content Group (OCG) / "layers" inspector panel (read-only).
//
// Lists the Optional Content Groups (the PDF "layers") declared in the open
// document. Layers let a PDF carry content that can be independently shown or
// hidden — CAD drawings, multilingual overlays, print-only/watermark layers,
// map layers, etc. This panel answers "does this PDF have layers, what are they
// called, and which are visible by default?" at a glance and auto-populates on
// document open (mirrors page-boxes.js / image-manager.js / font-inspector.js).
//
// It is purely observational — it NEVER modifies the document, never parses
// content streams or rasterizes pages, never downloads, and never uploads
// anything. It only reads the catalog's /OCProperties dictionary (the layer
// list plus the default visibility configuration), so peak memory stays tiny
// even for very large documents (safe for the 1.6 GiB box).
//
// Default visibility: the default configuration dict (/OCProperties /D) declares
// /ON and /OFF arrays plus a /BaseState (default /ON). A layer is hidden by
// default if it is listed in /OFF, or if /BaseState is /OFF and it is not in
// /ON. /D /Locked lists layers the user cannot toggle. We compare layers against
// those arrays by indirect-reference string.
//
// Isolation: this module only talks to the rest of the app through the EventBus
// (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering core or the
// .pdf-viewer-container flex-row layout (prompt rule 8) — it only renders into
// its own #layers-list panel. The raw PDF bytes come from pdf.js' own
// `doc.getData()`, parsed read-only with pdf-lib. Every value is inserted via
// textContent (never innerHTML), so it is XSS-safe.

import { EventBus, Events } from './event-bus.js';

let listEl = null;
let statusEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

function ensureEls() {
    if (!listEl) listEl = document.getElementById('layers-list');
    if (!statusEl) statusEl = document.getElementById('layers-status');
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
    p.className = 'layers-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/** Decode a pdf-lib PDFString / PDFHexString (or anything) to readable text. */
function decodeStr(v) {
    if (v === undefined || v === null) return null;
    if (typeof v.decodeText === 'function') {
        try { return v.decodeText(); } catch (e) { /* fall through */ }
    }
    if (typeof v.asString === 'function') {
        try { return v.asString(); } catch (e) { /* fall through */ }
    }
    try { return String(v); } catch (e) { return null; }
}

/**
 * Collect the indirect-ref strings ("12 0 R") of every element of `dict`'s
 * `key` array — used to test which OCGs are in /ON, /OFF or /Locked.
 */
function refStrings(dict, key, PDFName) {
    const set = new Set();
    if (!dict || typeof dict.lookup !== 'function') return set;
    let arr;
    try { arr = dict.lookup(PDFName.of(key)); } catch (e) { return set; }
    if (!arr || typeof arr.size !== 'function' || typeof arr.get !== 'function') return set;
    for (let i = 0; i < arr.size(); i += 1) {
        const el = arr.get(i);
        if (el && typeof el.toString === 'function') set.add(el.toString());
    }
    return set;
}

/** Inspect the open document's OCProperties → a plain descriptor array. */
function describeLayers(pdfDoc, PDFLib) {
    const PDFName = PDFLib.PDFName;
    const catalog = pdfDoc.catalog;
    if (!catalog || typeof catalog.lookup !== 'function') return [];

    let ocProps;
    try { ocProps = catalog.lookup(PDFName.of('OCProperties')); } catch (e) { ocProps = null; }
    if (!ocProps || typeof ocProps.lookup !== 'function') return [];

    let ocgsArr;
    try { ocgsArr = ocProps.lookup(PDFName.of('OCGs')); } catch (e) { ocgsArr = null; }
    if (!ocgsArr || typeof ocgsArr.size !== 'function') return [];

    let dConfig;
    try { dConfig = ocProps.lookup(PDFName.of('D')); } catch (e) { dConfig = null; }

    const offSet = refStrings(dConfig, 'OFF', PDFName);
    const onSet = refStrings(dConfig, 'ON', PDFName);
    const lockedSet = refStrings(dConfig, 'Locked', PDFName);

    let baseOff = false; // default /BaseState is /ON
    if (dConfig && typeof dConfig.lookup === 'function') {
        let baseState;
        try { baseState = dConfig.lookup(PDFName.of('BaseState')); } catch (e) { baseState = null; }
        if (baseState && typeof baseState.toString === 'function') {
            baseOff = /OFF/.test(baseState.toString());
        }
    }

    const out = [];
    for (let i = 0; i < ocgsArr.size(); i += 1) {
        const ref = typeof ocgsArr.get === 'function' ? ocgsArr.get(i) : null;
        const refKey = ref && typeof ref.toString === 'function' ? ref.toString() : null;

        let dict;
        try { dict = ocgsArr.lookup(i); } catch (e) { dict = null; }
        if (!dict || typeof dict.lookup !== 'function') continue;

        let name = null;
        try { name = decodeStr(dict.lookup(PDFName.of('Name'))); } catch (e) { name = null; }
        if (!name) name = '(unnamed layer)';

        const hidden = (refKey && offSet.has(refKey)) || (baseOff && !(refKey && onSet.has(refKey)));
        const locked = !!(refKey && lockedSet.has(refKey));

        // Intent: usually /View. If a layer is /Design-only it does not affect
        // on-screen viewing. Intent may be a single name or an array of names.
        let designOnly = false;
        try {
            const intent = dict.lookup(PDFName.of('Intent'));
            if (intent && typeof intent.toString === 'function') {
                const s = intent.toString();
                designOnly = /Design/.test(s) && !/View/.test(s);
            }
        } catch (e) { designOnly = false; }

        out.push({ name, hidden, locked, designOnly });
    }
    return out;
}

/** Build a card for one layer and append it to the list. */
function renderLayerCard(parent, layer) {
    const card = document.createElement('div');
    card.className = 'layer-card';

    const head = document.createElement('div');
    head.className = 'layer-card-name';
    head.textContent = layer.name;

    const stateBadge = document.createElement('span');
    stateBadge.className = `layer-badge ${layer.hidden ? 'layer-badge-hidden' : 'layer-badge-shown'}`;
    stateBadge.textContent = layer.hidden ? 'hidden' : 'shown';
    stateBadge.title = layer.hidden
        ? 'Hidden by default (in the document’s /OFF set)'
        : 'Shown by default';
    head.appendChild(document.createTextNode(' '));
    head.appendChild(stateBadge);

    if (layer.locked) {
        const lockBadge = document.createElement('span');
        lockBadge.className = 'layer-badge layer-badge-locked';
        lockBadge.textContent = 'locked';
        lockBadge.title = 'Locked — the viewer will not let the user toggle this layer';
        head.appendChild(document.createTextNode(' '));
        head.appendChild(lockBadge);
    }

    if (layer.designOnly) {
        const intentBadge = document.createElement('span');
        intentBadge.className = 'layer-badge layer-badge-design';
        intentBadge.textContent = 'design-only';
        intentBadge.title = 'Intent is /Design — does not affect on-screen viewing';
        head.appendChild(document.createTextNode(' '));
        head.appendChild(intentBadge);
    }

    card.appendChild(head);
    parent.appendChild(card);
}

async function inspectLayers(doc) {
    ensureEls();
    if (!listEl) return;
    const myToken = loadToken;

    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument || !PDFLib.PDFName) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        setPlaceholder('');
        return;
    }

    setStatus('Inspecting layers…');
    setPlaceholder('');

    let layers;
    try {
        const srcBytes = await doc.getData();
        if (myToken !== loadToken) return; // a newer document loaded meanwhile
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });
        layers = describeLayers(pdfDoc, PDFLib);
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[layers] inspection failed:', err);
        setStatus('Could not read layers. The PDF may be corrupted or use an unsupported structure.', true);
        setPlaceholder('');
        return;
    }

    if (myToken !== loadToken) return;

    if (!layers || layers.length === 0) {
        setStatus('');
        setPlaceholder('No optional-content layers (OCGs) in this document.');
        return;
    }

    const total = layers.length;
    const hiddenCount = layers.filter((l) => l.hidden).length;
    const shownCount = total - hiddenCount;
    const lockedCount = layers.filter((l) => l.locked).length;
    let summary = `${total} layer${total === 1 ? '' : 's'} — ${shownCount} shown, ${hiddenCount} hidden by default`;
    if (lockedCount > 0) summary += `; ${lockedCount} locked`;
    setStatus(summary);

    listEl.innerHTML = '';
    layers.forEach((l) => renderLayerCard(listEl, l));
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        setPlaceholder('');
        return;
    }
    inspectLayers(doc).catch((err) => {
        console.error('[layers] unexpected error:', err);
        setStatus('Could not read layers.', true);
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    setPlaceholder('');
}

export function initLayers() {
    ensureEls();
    setStatus('Open a PDF first.');
    setPlaceholder('');

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
