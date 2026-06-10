// metadata.js — Document Properties / Info panel (view + edit).
//
// Shows the open PDF's document properties (creator, producer,
// creation/modification dates, PDF version, page count, file name) as
// read-only rows via pdf.js `getMetadata()`, and exposes the four
// user-editable fields (Title, Author, Subject, Keywords) as real <input>
// controls pre-filled with the current values. "Apply & download" bakes the
// edited metadata into a brand-new PDF with pdf-lib and triggers a client-side
// download — the viewer document is never mutated and nothing is uploaded.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout. The
// raw PDF bytes come from pdf.js' own `doc.getData()`. All PDF-supplied display
// values are inserted via textContent and editable values via the `.value`
// property — never innerHTML — so a crafted metadata string cannot inject
// markup (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

let listEl = null;

// Editable controls + action affordances.
let titleInput = null;
let authorInput = null;
let subjectInput = null;
let keywordsInput = null;
let applyBtn = null;
let statusEl = null;

// State for the currently open document.
let currentDoc = null;     // pdf.js PDFDocumentProxy
let currentName = 'document.pdf';

function ensureListEl() {
    if (!listEl) listEl = document.getElementById('metadata-list');
    return listEl;
}

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the editable inputs + Apply button. */
function setEnabled(enabled) {
    [titleInput, authorInput, subjectInput, keywordsInput, applyBtn].forEach((el) => {
        if (!el) return;
        el.disabled = !enabled;
        el.setAttribute('aria-disabled', String(!enabled));
    });
}

/** Clear the editable inputs. */
function clearInputs() {
    [titleInput, authorInput, subjectInput, keywordsInput].forEach((el) => {
        if (el) el.value = '';
    });
}

function setPlaceholder(text) {
    const el = ensureListEl();
    if (!el) return;
    el.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'metadata-empty';
    p.textContent = text;
    el.appendChild(p);
}

/**
 * Parse a PDF date string (`D:YYYYMMDDHHmmSS±HH'mm'`) into a readable form.
 * Returns null if it can't be parsed so the caller can fall back to a dash.
 */
function parsePdfDate(raw) {
    if (typeof raw !== 'string') return null;
    const m = raw.match(/^D?:?(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?/);
    if (!m) return null;
    const [, y, mo = '01', d = '01', h = '00', mi = '00', s = '00'] = m;
    // Construct in local time; PDF tz offset is intentionally ignored for display.
    const date = new Date(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s));
    if (Number.isNaN(date.getTime())) return null;
    return date.toLocaleString();
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

/** Pre-fill the editable inputs from the parsed info object (via .value). */
function fillEditable(info) {
    if (titleInput) titleInput.value = info.Title || '';
    if (authorInput) authorInput.value = info.Author || '';
    if (subjectInput) subjectInput.value = info.Subject || '';
    if (keywordsInput) keywordsInput.value = info.Keywords || '';
}

/** Render the read-only (non-editable) document properties as a <dl>. */
function renderReadonly({ name, numPages, doc, info }) {
    const el = ensureListEl();
    if (!el) return;

    const dl = document.createElement('dl');
    dl.className = 'metadata-grid';

    addRow(dl, 'File name', name);
    addRow(dl, 'Pages', numPages != null ? numPages : (doc && doc.numPages));
    addRow(dl, 'Creator', info.Creator);
    addRow(dl, 'Producer', info.Producer);
    addRow(dl, 'Created', parsePdfDate(info.CreationDate));
    addRow(dl, 'Modified', parsePdfDate(info.ModDate));
    addRow(dl, 'PDF version', info.PDFFormatVersion);

    el.innerHTML = '';
    if (!dl.children.length) {
        setPlaceholder('No additional document properties available.');
        return;
    }
    el.appendChild(dl);
}

async function onLoaded({ doc, name, numPages }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';

    let info = {};
    if (doc) {
        try {
            const meta = await doc.getMetadata();
            info = (meta && meta.info) || {};
        } catch (err) {
            console.warn('[metadata] getMetadata failed:', err);
        }
    }

    fillEditable(info);
    renderReadonly({ name: currentName, numPages, doc, info });
    setEnabled(!!doc);
    setStatus(doc ? 'Edit the fields, then apply.' : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    clearInputs();
    setEnabled(false);
    setStatus('Load a PDF first.');
    setPlaceholder('Open a PDF to see its document properties.');
}

/** Build a safe download filename for the metadata-edited output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_metadata.pdf`;
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

/** Parse the keywords input into a trimmed, non-empty string array. */
function parseKeywords(raw) {
    return String(raw || '')
        .split(',')
        .map((k) => k.trim())
        .filter((k) => k.length > 0);
}

/** Apply the edited metadata to a copy of the open PDF and download it. */
async function applyMetadata() {
    if (!currentDoc) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[metadata] window.PDFLib unavailable');
        return;
    }

    const title = (titleInput ? titleInput.value : '').trim();
    const author = (authorInput ? authorInput.value : '').trim();
    const subject = (subjectInput ? subjectInput.value : '').trim();
    const keywords = parseKeywords(keywordsInput ? keywordsInput.value : '');

    setStatus('Updating metadata…');
    if (applyBtn) applyBtn.disabled = true;
    try {
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);

        // setX with an empty string clears the field — that's the intended
        // behaviour when the user blanks an input.
        pdf.setTitle(title);
        pdf.setAuthor(author);
        pdf.setSubject(subject);
        pdf.setKeywords(keywords);

        const outBytes = await pdf.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);
        setStatus(`Metadata updated → ${fileName}`);
    } catch (err) {
        console.error('[metadata] apply failed:', err);
        setStatus('Failed to update metadata. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to update metadata.', error: err });
    } finally {
        if (applyBtn) {
            applyBtn.disabled = !currentDoc;
            applyBtn.setAttribute('aria-disabled', String(!currentDoc));
        }
    }
}

export function initMetadata() {
    titleInput = document.getElementById('metadata-title');
    authorInput = document.getElementById('metadata-author');
    subjectInput = document.getElementById('metadata-subject');
    keywordsInput = document.getElementById('metadata-keywords');
    applyBtn = document.getElementById('metadata-apply');
    statusEl = document.getElementById('metadata-status');

    setEnabled(false);
    setStatus('Load a PDF first.');
    setPlaceholder('Open a PDF to see its document properties.');

    ActionRegistry.register('metadata.apply', {
        title: 'Apply metadata',
        run: () => applyMetadata(),
    });

    EventBus.on(Events.PDF_LOADED, (payload) => {
        onLoaded(payload || {});
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        onCleared();
    });
}
