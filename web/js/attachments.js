// attachments.js — Manage embedded file attachments inside the open PDF.
//
// Two capabilities in one panel:
//   1. Attach a file — the user picks any local file; the module embeds it
//      into a *copy* of the open PDF (the PDF spec's EmbeddedFiles) and
//      downloads `<name>_with-attachment.pdf`. The standard "ship the source
//      file along with the PDF" workflow.
//   2. List & extract — show any files already embedded in the open PDF,
//      each with a button to download (extract) it back to disk.
//
// Isolation: like flatten.js / reverse-pages.js, this module only talks to
// the rest of the app through the EventBus (PDF_LOADED / PDF_CLEARED) and the
// ActionRegistry. It never touches viewer.js's render core or the
// .pdf-viewer-container flex-row layout (prompt rule 8). Raw PDF bytes come
// from pdf.js' own `doc.getData()`; the viewer document is never mutated.
//
// No third-party library and no network calls — pdf-lib already ships
// `PDFDocument.attach()` and pdf.js ships `doc.getAttachments()`. The browser
// download helper is reused from zip-writer.js.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import { downloadBytes } from './zip-writer.js';

const MAX_ATTACH_BYTES = 25 * 1024 * 1024; // 25 MB cap — protect the 1.6 GiB box.

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let fileInput = null;
let addBtn = null;
let statusEl = null;
let listEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the add controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (addBtn) addBtn.disabled = !enabled;
    if (fileInput) fileInput.disabled = !enabled;
}

/** Sanitised base name (no extension, no unsafe chars) for download filenames. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
}

/** Sanitise an arbitrary attachment filename for use as a download name. */
function safeAttachmentName(name) {
    return String(name || 'attachment')
        .replace(/[\/\\]/g, '_')          // no path separators
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'attachment';
}

/** Human-readable byte size. */
function fmtBytes(n) {
    if (!Number.isFinite(n) || n < 0) return '';
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
    return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * Embed the chosen file into a copy of the open document and download it.
 */
async function addAttachment() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const file = fileInput && fileInput.files && fileInput.files[0];
    if (!file) {
        setStatus('Choose a file to attach.', true);
        return;
    }
    if (file.size === 0) {
        setStatus('That file is empty — choose a non-empty file.', true);
        return;
    }
    if (file.size > MAX_ATTACH_BYTES) {
        setStatus(`File is too large (${fmtBytes(file.size)}). Maximum is 25 MB.`, true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[attachments] window.PDFLib unavailable');
        return;
    }

    setStatus(`Attaching ${file.name}…`);
    setEnabled(false);
    try {
        const fileBytes = new Uint8Array(await file.arrayBuffer());

        // pdf.js hands back the original document bytes; pdf-lib reads them so
        // we never mutate the live viewer document.
        const srcBytes = await currentDoc.getData();
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes);

        const now = new Date();
        await pdfDoc.attach(fileBytes, file.name, {
            mimeType: file.type || 'application/octet-stream',
            description: `Attached via CronLoop PDF Editor`,
            creationDate: now,
            modificationDate: now,
        });

        const outBytes = await pdfDoc.save();
        const outName = `${baseName()}_with-attachment.pdf`;
        downloadBytes(outBytes, outName, 'application/pdf');

        setStatus(`Attached ${file.name} → ${outName}`);
        // Reset the picker so the same file can be re-chosen if desired.
        if (fileInput) fileInput.value = '';
    } catch (err) {
        console.error('[attachments] attach failed:', err);
        setStatus('Failed to attach the file. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to attach file.', error: err });
    } finally {
        setEnabled(numPages > 0);
    }
}

/** Extract (download) one already-embedded attachment. */
function extractAttachment(filename, content) {
    try {
        const bytes = content instanceof Uint8Array ? content : new Uint8Array(content);
        downloadBytes(bytes, safeAttachmentName(filename), 'application/octet-stream');
    } catch (err) {
        console.error('[attachments] extract failed:', err);
        setStatus('Failed to extract that attachment.', true);
    }
}

/** Render the list of attachments already embedded in the open document. */
async function refreshList() {
    if (!listEl) return;
    listEl.innerHTML = '';

    if (!currentDoc || numPages === 0) {
        const p = document.createElement('p');
        p.className = 'attach-empty';
        p.textContent = 'Open a PDF to see its attachments.';
        listEl.appendChild(p);
        return;
    }

    let attachments = null;
    try {
        attachments = await currentDoc.getAttachments();
    } catch (err) {
        // Stale doc (cleared mid-flight) or malformed embedded-files tree.
        console.warn('[attachments] getAttachments failed:', err);
        attachments = null;
    }

    const entries = attachments ? Object.values(attachments) : [];
    if (entries.length === 0) {
        const p = document.createElement('p');
        p.className = 'attach-empty';
        p.textContent = 'No embedded attachments.';
        listEl.appendChild(p);
        return;
    }

    const count = document.createElement('p');
    count.className = 'attach-count';
    count.textContent = `${entries.length} attachment${entries.length === 1 ? '' : 's'}`;
    listEl.appendChild(count);

    const ul = document.createElement('ul');
    ul.className = 'attach-list';

    for (const entry of entries) {
        const filename = entry && entry.filename ? entry.filename : 'attachment';
        const content = entry && entry.content ? entry.content : new Uint8Array(0);
        const size = content && content.length != null ? content.length : 0;

        const li = document.createElement('li');
        li.className = 'attach-item';

        const meta = document.createElement('span');
        meta.className = 'attach-meta';

        const nameSpan = document.createElement('span');
        nameSpan.className = 'attach-name';
        nameSpan.textContent = filename; // textContent — never innerHTML with file-supplied names
        nameSpan.title = filename;

        const sizeSpan = document.createElement('span');
        sizeSpan.className = 'attach-size';
        sizeSpan.textContent = fmtBytes(size);

        meta.append(nameSpan, sizeSpan);

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'btn attach-extract';
        btn.textContent = 'Extract';
        btn.setAttribute('aria-label', `Extract ${filename}`);
        btn.addEventListener('click', () => extractAttachment(filename, content));

        li.append(meta, btn);
        ul.appendChild(li);
    }

    listEl.appendChild(ul);
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} available.` : 'Open a PDF first.');
    refreshList();
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    setEnabled(false);
    if (fileInput) fileInput.value = '';
    setStatus('Open a PDF first.');
    refreshList();
}

export function initAttachments() {
    fileInput = document.getElementById('attach-file-input');
    addBtn = document.getElementById('attach-run');
    statusEl = document.getElementById('attach-status');
    listEl = document.getElementById('attach-list');

    setEnabled(false);
    setStatus('Open a PDF first.');
    refreshList();

    if (addBtn) addBtn.addEventListener('click', () => addAttachment());

    ActionRegistry.register('attachments.add', {
        title: 'Attach a file to the PDF',
        run: () => addAttachment(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}

export default initAttachments;
