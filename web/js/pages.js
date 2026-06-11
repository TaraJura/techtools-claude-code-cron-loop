// pages.js — Page rotation (90° increments) with download (TASK-328).
//
// Lets the user correct the orientation of scanned/photographed pages. Rotation
// is applied VISUALLY by viewer.js (which owns the per-page rotation state and
// re-renders through its single hardened render path) and baked into a real,
// downloadable PDF here with pdf-lib. The original document in the viewer is
// never mutated server-side; nothing is uploaded.
//
// Isolation: this module talks to the rest of the app only through the
// EventBus (PDF_LOADED / PDF_CLEARED), the ActionRegistry, and viewer.js's
// rotatePage/rotateAll/getPageRotation API. It never touches the viewer
// rendering core or the .pdf-viewer-container flex-row layout (prompt rule 8).
// The raw PDF bytes for download come from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import * as Viewer from './viewer.js';

let currentDoc = null;     // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';
let numPages = 0;

let rotateLeftBtn = null;
let rotateRightBtn = null;
let rotateAllLeftBtn = null;
let rotateAllRightBtn = null;
let downloadBtn = null;
let statusEl = null;
let pageNavInput = null;   // #page-nav-input — the app's current-page source of truth

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable controls and reflect it to assistive tech. */
function setEnabled(enabled) {
    [rotateLeftBtn, rotateRightBtn, rotateAllLeftBtn, rotateAllRightBtn, downloadBtn].forEach((el) => {
        if (!el) return;
        el.disabled = !enabled;
        el.setAttribute('aria-disabled', String(!enabled));
    });
}

function hasDoc() {
    return !!currentDoc && numPages > 0;
}

/**
 * The current page, read from the page navigator (which already tracks the
 * most-visible page via its own IntersectionObserver) so we don't run a third
 * observer. Clamped into [1, numPages]; defaults to 1 if the field is empty.
 */
function getCurrentPage() {
    if (!pageNavInput) pageNavInput = document.getElementById('page-nav-input');
    let n = parseInt(pageNavInput && pageNavInput.value, 10);
    if (!Number.isInteger(n)) n = 1;
    return Math.max(1, Math.min(numPages || 1, n));
}

/** Sanitised base name (no extension, no unsafe chars) for the download. */
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
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function rotateCurrent(delta) {
    if (!hasDoc()) { setStatus('Open a PDF first.', true); return; }
    const p = getCurrentPage();
    await Viewer.rotatePage(p, delta);
    setStatus(`Rotated page ${p} ${delta < 0 ? 'left' : 'right'}.`);
}

async function rotateEvery(delta) {
    if (!hasDoc()) { setStatus('Open a PDF first.', true); return; }
    await Viewer.rotateAll(delta);
    setStatus(`Rotated all ${numPages} page${numPages === 1 ? '' : 's'} ${delta < 0 ? 'left' : 'right'}.`);
}

/** Bake the current per-page rotations into a new PDF and download it. */
async function downloadRotated() {
    if (!hasDoc()) { setStatus('Open a PDF first.', true); return; }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[pages] window.PDFLib unavailable');
        return;
    }

    setStatus('Preparing download…');
    if (downloadBtn) downloadBtn.disabled = true;
    try {
        const { degrees } = PDFLib;
        // pdf.js hands back the original document bytes; pdf-lib reads them.
        const srcBytes = await currentDoc.getData();
        const pdf = await PDFLib.PDFDocument.load(srcBytes);
        const pages = pdf.getPages();
        pages.forEach((page, i) => {
            const delta = Viewer.getPageRotation(i + 1) || 0; // user delta for 1-based page
            if (!delta) return;
            const orig = (page.getRotation && page.getRotation().angle) || 0;
            const next = (((orig + delta) % 360) + 360) % 360;
            page.setRotation(degrees(next));
        });
        const outBytes = await pdf.save();
        const fileName = `rotated-${baseName()}.pdf`;
        downloadBytes(outBytes, fileName);
        setStatus(`Downloaded ${fileName}`);
    } catch (err) {
        console.error('[pages] download failed:', err);
        setStatus('Failed to build the rotated PDF. The PDF may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to build the rotated PDF.', error: err });
    } finally {
        if (downloadBtn) downloadBtn.disabled = !hasDoc();
    }
}

/** True when focus is in a text-entry context (so [ / ] don't hijack typing). */
function isTypingTarget(t) {
    return !!(t && t.closest && t.closest('input,textarea,[contenteditable],.tool-panel'));
}

/** Global accelerators: "[" rotate current page left, "]" rotate right. */
function onKeyDown(e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (isTypingTarget(e.target)) return;
    if (!hasDoc()) return; // no-doc safety: do nothing, never throw
    if (e.key === '[') {
        e.preventDefault();
        rotateCurrent(-90);
    } else if (e.key === ']') {
        e.preventDefault();
        rotateCurrent(90);
    }
}

export function initPages() {
    rotateLeftBtn = document.getElementById('rotate-left');
    rotateRightBtn = document.getElementById('rotate-right');
    rotateAllLeftBtn = document.getElementById('rotate-all-left');
    rotateAllRightBtn = document.getElementById('rotate-all-right');
    downloadBtn = document.getElementById('rotate-download');
    statusEl = document.getElementById('pages-status');
    pageNavInput = document.getElementById('page-nav-input');

    setEnabled(false);
    setStatus('Open a PDF first.');

    ActionRegistry.register('pages.rotateLeft', { title: 'Rotate current page left', shortcut: '[', run: () => rotateCurrent(-90) });
    ActionRegistry.register('pages.rotateRight', { title: 'Rotate current page right', shortcut: ']', run: () => rotateCurrent(90) });
    ActionRegistry.register('pages.rotateAllLeft', { title: 'Rotate all pages left', run: () => rotateEvery(-90) });
    ActionRegistry.register('pages.rotateAllRight', { title: 'Rotate all pages right', run: () => rotateEvery(90) });
    ActionRegistry.register('pages.download', { title: 'Download rotated PDF', run: () => downloadRotated() });

    document.addEventListener('keydown', onKeyDown);

    EventBus.on(Events.PDF_LOADED, ({ doc, name, numPages: n }) => {
        currentDoc = doc || null;
        currentName = name || 'document.pdf';
        numPages = n || (doc && doc.numPages) || 0;
        setEnabled(numPages > 0);
        setStatus(numPages > 0 ? `Ready — ${numPages} page${numPages === 1 ? '' : 's'}.` : 'Open a PDF first.');
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        currentDoc = null;
        currentName = 'document.pdf';
        numPages = 0;
        setEnabled(false);
        setStatus('Open a PDF first.');
    });
}

export default initPages;
