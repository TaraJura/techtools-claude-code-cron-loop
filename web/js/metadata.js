// metadata.js — Document Properties / Info panel.
//
// Shows the open PDF's document properties (title, author, subject, keywords,
// creator, producer, creation/modification dates, PDF version) plus page count
// and file name in the "Info" tool panel, via pdf.js `getMetadata()`.
//
// Purely additive: subscribes to EventBus document events only. It never
// touches the viewer rendering core or the .pdf-viewer-container flex-row
// layout. All PDF-supplied values are inserted via textContent (never
// innerHTML) so a crafted metadata string cannot inject markup.

import { EventBus, Events } from './event-bus.js';

let listEl = null;

function ensureListEl() {
    if (!listEl) listEl = document.getElementById('metadata-list');
    return listEl;
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

async function renderMetadata({ doc, name, numPages }) {
    const el = ensureListEl();
    if (!el || !doc) return;

    let info = {};
    try {
        const meta = await doc.getMetadata();
        info = (meta && meta.info) || {};
    } catch (err) {
        console.warn('[metadata] getMetadata failed:', err);
    }

    const dl = document.createElement('dl');
    dl.className = 'metadata-grid';

    addRow(dl, 'File name', name);
    addRow(dl, 'Pages', numPages != null ? numPages : doc.numPages);
    addRow(dl, 'Title', info.Title);
    addRow(dl, 'Author', info.Author);
    addRow(dl, 'Subject', info.Subject);
    addRow(dl, 'Keywords', info.Keywords);
    addRow(dl, 'Creator', info.Creator);
    addRow(dl, 'Producer', info.Producer);
    addRow(dl, 'Created', parsePdfDate(info.CreationDate));
    addRow(dl, 'Modified', parsePdfDate(info.ModDate));
    addRow(dl, 'PDF version', info.PDFFormatVersion);

    el.innerHTML = '';
    if (!dl.children.length) {
        setPlaceholder('No document properties available.');
        return;
    }
    el.appendChild(dl);
}

export function initMetadata() {
    setPlaceholder('Open a PDF to see its document properties.');

    EventBus.on(Events.PDF_LOADED, (payload) => {
        renderMetadata(payload);
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        setPlaceholder('Open a PDF to see its document properties.');
    });
}
