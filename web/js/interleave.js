// interleave.js — Interleave (zipper-merge) the open PDF with a second PDF.
//
// Distinct from Merge (which concatenates: A1..An, then B1..Bn). Interleave
// alternates pages from the two documents: A1, B1, A2, B2, … This is the classic
// fix for double-sided ("duplex") scanning on a single-sided scanner — you scan
// all the fronts into PDF A, flip the stack and scan all the backs into PDF B,
// then interleave to reconstruct the original front/back order. Because the backs
// come out in reverse order when you flip the whole stack, an optional "Reverse
// second document" toggle feeds B from its last page to its first.
//
// When the two documents have a different number of pages, every extra page of
// the longer document is appended (in order) after the alternation runs out, so
// no pages are ever lost.
//
// Isolation: like merge.js, this module talks to the rest of the app only through
// the EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core, the .pdf-viewer-container layout, or upload.js. The
// base PDF bytes come from pdf.js' own `doc.getData()`; the second file is read
// and validated locally (same rules as upload.js, kept local so upload.js stays
// untouched). Nothing is uploaded; the open document is never modified.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

const MAX_BYTES = 50 * 1024 * 1024; // 50 MB (security rule, matches upload.js)

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open (base) document
let currentName = 'document.pdf';
let numPages = 0;

// The chosen second document, or null: { file, name, size, pages }
let second = null;

let addInput = null;
let infoEl = null;
let reverseEl = null;
let runBtn = null;
let statusEl = null;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Strip path separators / control chars from a user-supplied filename. */
function sanitizeName(name) {
    return String(name).replace(/[\\/ -]/g, '_').slice(0, 200) || 'document.pdf';
}

/** Human-readable file size. */
function formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/** Verify the first bytes are the %PDF- magic header. */
async function hasPdfMagic(file) {
    const head = await file.slice(0, 5).arrayBuffer();
    const sig = new Uint8Array(head);
    return sig[0] === 0x25 && sig[1] === 0x50 && sig[2] === 0x44 && sig[3] === 0x46 && sig[4] === 0x2d;
}

/** Validate a single file; throws Error(message) if it should be rejected. */
async function validateFile(file) {
    const name = sanitizeName(file.name);
    if (!/\.pdf$/i.test(name)) throw new Error(`"${name}" must have a .pdf extension.`);
    if (file.type && file.type !== 'application/pdf') {
        throw new Error(`"${name}" is not application/pdf.`);
    }
    if (file.size === 0) throw new Error(`"${name}" is empty.`);
    if (file.size > MAX_BYTES) throw new Error(`"${name}" exceeds the 50 MB limit.`);
    if (!(await hasPdfMagic(file))) throw new Error(`"${name}" does not look like a valid PDF (bad header).`);
    return name;
}

/** Whether interleave is currently possible (doc open + a second file chosen). */
function canRun() {
    return !!currentDoc && numPages > 0 && !!second;
}

/** Reflect current state into the controls. */
function syncControls() {
    const hasDoc = !!currentDoc && numPages > 0;
    if (addInput) addInput.disabled = !hasDoc;
    if (reverseEl) reverseEl.disabled = !hasDoc;
    if (runBtn) runBtn.disabled = !canRun();
}

/** Render the "second document" summary line. */
function renderInfo() {
    if (!infoEl) return;
    if (!second) {
        infoEl.textContent = '';
        return;
    }
    // textContent only — never innerHTML with a user-supplied filename (XSS).
    infoEl.textContent =
        `Second document: ${second.name} (${second.pages} page${second.pages === 1 ? '' : 's'}, ${formatSize(second.size)})`;
}

/** Read a file's page count via pdf-lib (also confirms it parses). */
async function countPages(PDFLib, bytes) {
    const doc = await PDFLib.PDFDocument.load(bytes, { updateMetadata: false });
    return doc.getPageCount();
}

/** Validate + load the chosen second file. */
async function chooseFile(fileList) {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    const files = Array.from(fileList || []);
    if (files.length === 0) return;
    const file = files[0];

    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[interleave] window.PDFLib unavailable');
        return;
    }

    try {
        const name = await validateFile(file);
        const bytes = new Uint8Array(await file.arrayBuffer());
        const pages = await countPages(PDFLib, bytes);
        second = { file, name, size: file.size, pages };
        renderInfo();
        syncControls();
        setStatus(`Ready: ${numPages} + ${pages} pages → ${numPages + pages} interleaved.`);
    } catch (err) {
        second = null;
        renderInfo();
        syncControls();
        setStatus(err && err.message ? err.message : 'Could not load that PDF.', true);
    }
}

/** Build a safe download filename for the interleaved output. */
function buildFileName() {
    const base = String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
    return `${base}_interleaved.pdf`;
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

/**
 * Interleave the base document with the chosen second document and download it.
 * Output order: A0, B0, A1, B1, … with any surplus pages of the longer document
 * appended (in their own order) after the alternation. When `reverse` is set,
 * the second document is consumed from its last page to its first.
 */
async function interleaveAndDownload() {
    if (!currentDoc || numPages === 0) {
        setStatus('Load a PDF first.', true);
        return;
    }
    if (!second) {
        setStatus('Choose a second PDF to interleave.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[interleave] window.PDFLib unavailable');
        return;
    }

    setStatus('Interleaving…');
    if (runBtn) runBtn.disabled = true;
    try {
        const baseBytes = await currentDoc.getData();
        const secondBytes = new Uint8Array(await second.file.arrayBuffer());

        const aDoc = await PDFLib.PDFDocument.load(baseBytes);
        const bDoc = await PDFLib.PDFDocument.load(secondBytes);

        const aIdx = aDoc.getPageIndices();            // [0..a-1] in order
        let bIdx = bDoc.getPageIndices();              // [0..b-1] in order
        if (reverseEl && reverseEl.checked) bIdx = bIdx.slice().reverse();

        const out = await PDFLib.PDFDocument.create();
        // Copy every page once, up front, then place them in interleaved order.
        const aPages = await out.copyPages(aDoc, aIdx);
        const bPages = await out.copyPages(bDoc, bIdx);

        const maxLen = Math.max(aPages.length, bPages.length);
        for (let i = 0; i < maxLen; i++) {
            if (i < aPages.length) out.addPage(aPages[i]);
            if (i < bPages.length) out.addPage(bPages[i]);
        }

        const outBytes = await out.save();
        const fileName = buildFileName();
        downloadBytes(outBytes, fileName);

        const total = aPages.length + bPages.length;
        setStatus(`Interleaved ${aPages.length} + ${bPages.length} → ${total} pages → ${fileName}`);
    } catch (err) {
        console.error('[interleave] interleave failed:', err);
        setStatus('Failed to interleave. One of the files may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to interleave PDFs.', error: err });
    } finally {
        if (runBtn) runBtn.disabled = !canRun();
    }
}

function resetSecond() {
    second = null;
    if (addInput) addInput.value = '';
    renderInfo();
    syncControls();
}

function onLoaded({ doc, name, numPages: n }) {
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    numPages = n || (doc && doc.numPages) || 0;
    // New base document — drop any second file chosen against the previous one.
    resetSecond();
    setStatus(numPages > 0
        ? `Base: ${numPages} page${numPages === 1 ? '' : 's'}. Choose a second PDF to interleave.`
        : 'Load a PDF first.');
}

function onCleared() {
    currentDoc = null;
    currentName = 'document.pdf';
    numPages = 0;
    resetSecond();
    setStatus('Load a PDF first.');
}

export function initInterleave() {
    addInput = document.getElementById('interleave-add');
    infoEl = document.getElementById('interleave-info');
    reverseEl = document.getElementById('interleave-reverse');
    runBtn = document.getElementById('interleave-run');
    statusEl = document.getElementById('interleave-status');

    if (addInput) {
        addInput.addEventListener('change', (e) => {
            chooseFile(e.target.files);
            e.target.value = ''; // allow re-selecting the same file
        });
    }

    syncControls();
    setStatus('Load a PDF first.');

    ActionRegistry.register('interleave.run', {
        title: 'Interleave with second PDF & download',
        run: () => interleaveAndDownload(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
