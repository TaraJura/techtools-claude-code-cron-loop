// flatten.js — Flatten interactive form fields into static page content.
//
// A single-click operation: takes the open PDF, bakes every interactive
// AcroForm field (text fields, checkboxes, radio buttons, dropdowns/list
// boxes, and the visual appearance of signature fields) into the page as
// static, non-editable content, then downloads the result. The standard
// "lock this filled form before sending it" workflow — once flattened the
// values can no longer be changed in a PDF reader. A natural companion to
// the page-tools family (rotate pages.js, reverse reverse-pages.js,
// delete delete-pages.js, …). Runs entirely client-side with pdf-lib; the
// open viewer document is never mutated and nothing is uploaded.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never
// touches the viewer rendering core or the .pdf-viewer-container flex-row
// layout (prompt rule 8). The raw PDF bytes come from pdf.js' own
// `doc.getData()`. No third-party library is added — pdf-lib already ships
// `PDFDocument.getForm().flatten()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let flattenBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (flattenBtn) flattenBtn.disabled = !enabled;
}

/** Sanitised base name (no extension, no unsafe chars) for download filenames. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
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
    // Revoke on the next tick so the download has a chance to start.
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Flatten the open document's form fields and download the result. */
async function flattenForm() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[flatten] window.PDFLib unavailable');
        return;
    }

    setStatus('Flattening…');
    if (flattenBtn) flattenBtn.disabled = true;
    try {
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes);

        // getForm() always returns a form object — 0 fields if there's no
        // AcroForm. Count first so we can report meaningfully, then flatten.
        const form = pdfDoc.getForm();
        let fieldCount = 0;
        try {
            fieldCount = form.getFields().length;
        } catch (e) {
            // Some malformed forms throw on enumeration — treat as unknown
            // and still attempt the flatten below.
            console.warn('[flatten] could not enumerate fields:', e);
        }

        if (fieldCount > 0) {
            // flatten() bakes field appearances into the page content streams
            // and removes the interactive widgets.
            form.flatten();
        }

        const outBytes = await pdfDoc.save();
        const fileName = `${baseName()}_flattened.pdf`;
        downloadBytes(outBytes, fileName);

        if (fieldCount > 0) {
            setStatus(`Flattened ${fieldCount} form field${fieldCount === 1 ? '' : 's'} → ${fileName}`);
        } else {
            setStatus(`No form fields found — saved a flattened copy → ${fileName}`);
        }
    } catch (err) {
        console.error('[flatten] flatten failed:', err);
        setStatus('Failed to flatten. The PDF may be corrupted, encrypted, or have an unsupported form.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to flatten form fields.', error: err });
    } finally {
        if (flattenBtn) flattenBtn.disabled = numPages === 0;
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

export function initFlatten() {
    flattenBtn = document.getElementById('flatten-run');
    statusEl = document.getElementById('flatten-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    ActionRegistry.register('flatten.run', {
        title: 'Flatten form fields',
        run: () => flattenForm(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
