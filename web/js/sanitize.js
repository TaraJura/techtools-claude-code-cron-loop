// sanitize.js — Sanitize tool: strip JavaScript, automatic actions & embedded
// files from the open PDF and deliver a CLEANED COPY for download.
//
// This is the ACTION half of the security story whose read-only half shipped as
// the Scripts inspector (js-inspector.js, TASK-364). A user who saw
// "⚠ this PDF contains JavaScript and 1 automatic action" needs a one-click way
// to remove it before opening or sharing the file. The panel pre-scans the open
// document on load, shows exactly what it found per category, lets the user
// choose which categories to remove, then writes a NEW PDF with those items
// deleted. The original document in the viewer is NEVER modified.
//
// Categories (each removed by a pure structural catalog edit, no rasterization):
//   • Document JavaScript      — the /Names /JavaScript name-tree scripts.
//   • Automatic actions        — catalog /OpenAction, document /AA, page /AA.
//   • Embedded / attached files — the /Names /EmbeddedFiles name tree.
//
// Self-contained, minimum-regression-risk MUTATE→DOWNLOAD tool (proven pattern:
// burst.js / split.js): NO rasterization, NO network, NO third-party lib, and it
// NEVER touches viewer.js's render core or the .pdf-viewer-container flex-row
// layout (prompt rule 8). It talks to the rest of the app only through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. Raw bytes come from
// pdf.js' own doc.getData(); pdf-lib reads them with ignoreEncryption:true.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import { downloadBytes } from './zip-writer.js';

let currentDoc = null;    // pdf.js PDFDocumentProxy of the open document
let currentName = 'document.pdf';

// Counts detected by the pre-scan of the open document.
let counts = { scripts: 0, actions: 0, embedded: 0 };

// Token for the currently open document so a stale async scan (the user
// opened/closed another PDF mid-scan) can be discarded.
let loadToken = 0;

let statusEl = null;
let summaryEl = null;
let cbScripts = null;
let cbActions = null;
let cbEmbedded = null;
let runBtn = null;

// Document-level additional-action triggers (/AA) we recognise & strip.
const DOC_AA_TRIGGERS = ['WC', 'WS', 'DS', 'WP', 'DP'];
// Page-level additional-action triggers (/AA) we recognise & strip.
const PAGE_AA_TRIGGERS = ['O', 'C'];

function ensureEls() {
    if (!statusEl) statusEl = document.getElementById('sanitize-status');
    if (!summaryEl) summaryEl = document.getElementById('sanitize-summary');
    if (!cbScripts) cbScripts = document.getElementById('sanitize-scripts');
    if (!cbActions) cbActions = document.getElementById('sanitize-actions');
    if (!cbEmbedded) cbEmbedded = document.getElementById('sanitize-embedded');
    if (!runBtn) runBtn = document.getElementById('sanitize-run');
}

function setStatus(msg, isError = false) {
    ensureEls();
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Sanitised base name (no extension, no unsafe chars) for the download. */
function baseName() {
    return String(currentName)
        .replace(/\.pdf$/i, '')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180) || 'document';
}

/** Count the leaf entries of a /Names name tree (Names array pairs + Kids
 *  recursion). Used for /JavaScript and /EmbeddedFiles. Never throws. */
function countNameTreeLeaves(context, PDFLib, node, depth = 0) {
    if (!node || depth > 50) return 0;
    const { PDFName, PDFArray, PDFDict } = PDFLib;
    let total = 0;

    let names = null;
    try { names = node.lookupMaybe(PDFName.of('Names'), PDFArray); } catch (e) { names = null; }
    if (names) total += Math.floor(names.size() / 2);

    let kids = null;
    try { kids = node.lookupMaybe(PDFName.of('Kids'), PDFArray); } catch (e) { kids = null; }
    if (kids) {
        for (let i = 0; i < kids.size(); i += 1) {
            let kid = null;
            try { kid = context.lookup(kids.get(i)); } catch (e) { kid = null; }
            if (kid instanceof PDFDict) {
                total += countNameTreeLeaves(context, PDFLib, kid, depth + 1);
            }
        }
    }
    return total;
}

/**
 * Structurally scan the document catalog and return per-category counts.
 * Pure read — never mutates. Mirrors js-inspector's detection so the numbers
 * shown here match what the Scripts panel reports. Never throws.
 */
async function scan(doc, myToken) {
    const result = { scripts: 0, actions: 0, embedded: 0 };
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) throw new Error('PDF library unavailable');
    const { PDFName, PDFDict, PDFArray } = PDFLib;

    const bytes = await doc.getData();
    if (myToken !== loadToken) return result;
    const pdfDoc = await PDFLib.PDFDocument.load(bytes, {
        ignoreEncryption: true,
        updateMetadata: false,
    });
    if (myToken !== loadToken) return result;
    const context = pdfDoc.context;
    const catalog = pdfDoc.catalog;

    // /Names dictionary: JavaScript + EmbeddedFiles name trees.
    let namesDict = null;
    try { namesDict = catalog.lookupMaybe(PDFName.of('Names'), PDFDict); } catch (e) { namesDict = null; }
    if (namesDict) {
        try {
            const jsTree = namesDict.lookupMaybe(PDFName.of('JavaScript'), PDFDict);
            if (jsTree) result.scripts += countNameTreeLeaves(context, PDFLib, jsTree);
        } catch (e) { /* no named scripts */ }
        try {
            const efTree = namesDict.lookupMaybe(PDFName.of('EmbeddedFiles'), PDFDict);
            if (efTree) result.embedded += countNameTreeLeaves(context, PDFLib, efTree);
        } catch (e) { /* no embedded files */ }
    }
    if (myToken !== loadToken) return result;

    // Catalog /OpenAction (dict action or array dest) counts as one auto action.
    try {
        const oa = catalog.lookup(PDFName.of('OpenAction'));
        if (oa instanceof PDFDict || oa instanceof PDFArray) result.actions += 1;
    } catch (e) { /* none */ }

    // Document-level /AA additional actions.
    try {
        const aa = catalog.lookupMaybe(PDFName.of('AA'), PDFDict);
        if (aa) {
            for (const code of DOC_AA_TRIGGERS) {
                try { if (aa.lookupMaybe(PDFName.of(code), PDFDict)) result.actions += 1; } catch (e) { /* skip */ }
            }
        }
    } catch (e) { /* none */ }
    if (myToken !== loadToken) return result;

    // Page-level /AA open/close actions.
    try {
        const pages = pdfDoc.getPages();
        for (let p = 0; p < pages.length; p += 1) {
            if (myToken !== loadToken) return result;
            let aa = null;
            try { aa = pages[p].node.lookupMaybe(PDFName.of('AA'), PDFDict); } catch (e) { aa = null; }
            if (!aa) continue;
            for (const code of PAGE_AA_TRIGGERS) {
                try { if (aa.lookupMaybe(PDFName.of(code), PDFDict)) result.actions += 1; } catch (e) { /* skip */ }
            }
        }
    } catch (e) { /* none */ }

    return result;
}

/** Reflect a category count onto its checkbox: checked+enabled when >0,
 *  unchecked+disabled when 0. */
function applyCategory(cb, count) {
    if (!cb) return;
    const has = count > 0;
    cb.disabled = !has;
    cb.setAttribute('aria-disabled', String(!has));
    cb.checked = has;
}

/** Enable the Sanitize button only when a PDF is open, something was detected,
 *  and at least one enabled category is checked. */
function refreshRunBtn() {
    ensureEls();
    if (!runBtn) return;
    const anySelected = (cbScripts && !cbScripts.disabled && cbScripts.checked)
        || (cbActions && !cbActions.disabled && cbActions.checked)
        || (cbEmbedded && !cbEmbedded.disabled && cbEmbedded.checked);
    runBtn.disabled = !(currentDoc && anySelected);
    runBtn.setAttribute('aria-disabled', String(runBtn.disabled));
}

/** Render the per-category summary line and sync the controls. */
function renderSummary() {
    ensureEls();
    applyCategory(cbScripts, counts.scripts);
    applyCategory(cbActions, counts.actions);
    applyCategory(cbEmbedded, counts.embedded);

    if (summaryEl) {
        const s = counts.scripts;
        const a = counts.actions;
        const e = counts.embedded;
        summaryEl.textContent = `Detected: ${s} script${s === 1 ? '' : 's'}, `
            + `${a} automatic action${a === 1 ? '' : 's'}, `
            + `${e} embedded file${e === 1 ? '' : 's'}.`;
    }
    refreshRunBtn();
}

/** Run the pre-scan for the open document and update the panel. */
async function rescan() {
    ensureEls();
    if (!currentDoc) {
        counts = { scripts: 0, actions: 0, embedded: 0 };
        renderSummary();
        setStatus('Open a PDF first.');
        return;
    }
    const myToken = loadToken;
    setStatus('Scanning…');
    let res;
    try {
        res = await scan(currentDoc, myToken);
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[sanitize] scan failed:', err);
        counts = { scripts: 0, actions: 0, embedded: 0 };
        renderSummary();
        setStatus('Could not scan this PDF. It may be corrupted or use an unsupported structure.', true);
        return;
    }
    if (myToken !== loadToken) return;

    counts = res;
    renderSummary();
    const total = counts.scripts + counts.actions + counts.embedded;
    if (total === 0) {
        setStatus('Nothing to sanitize — no scripts, actions, or embedded files found.');
    } else {
        setStatus('Scan ready — choose what to remove, then Sanitize & download.');
    }
}

/**
 * Write a cleaned copy of the open PDF with the selected categories removed and
 * trigger a download. Pure structural catalog edit — page content is untouched,
 * no rasterization, the open viewer document is never mutated, nothing is
 * uploaded. Never throws uncaught.
 */
async function runSanitize() {
    ensureEls();
    if (!currentDoc) {
        setStatus('Open a PDF first.', true);
        return;
    }
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) {
        setStatus('PDF engine not ready — please retry in a moment.', true);
        console.error('[sanitize] window.PDFLib unavailable');
        return;
    }
    const { PDFName, PDFDict } = PDFLib;

    const doScripts = cbScripts && !cbScripts.disabled && cbScripts.checked;
    const doActions = cbActions && !cbActions.disabled && cbActions.checked;
    const doEmbedded = cbEmbedded && !cbEmbedded.disabled && cbEmbedded.checked;
    if (!doScripts && !doActions && !doEmbedded) {
        setStatus('Select at least one category to remove.', true);
        return;
    }

    setStatus('Sanitizing…');
    if (runBtn) runBtn.disabled = true;
    try {
        // Load a FRESH copy of the bytes — the open document is never mutated.
        const srcBytes = await currentDoc.getData();
        const pdfDoc = await PDFLib.PDFDocument.load(srcBytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });
        const catalog = pdfDoc.catalog;

        let removedScripts = 0;
        let removedActions = 0;
        let removedEmbedded = 0;

        if (doActions) {
            // Catalog /OpenAction.
            try {
                if (catalog.has(PDFName.of('OpenAction'))) {
                    catalog.delete(PDFName.of('OpenAction'));
                    removedActions += 1;
                }
            } catch (e) { /* ignore */ }
            // Catalog /AA (document additional actions).
            try {
                const aa = catalog.lookupMaybe(PDFName.of('AA'), PDFDict);
                if (aa) {
                    for (const code of DOC_AA_TRIGGERS) {
                        try { if (aa.lookupMaybe(PDFName.of(code), PDFDict)) removedActions += 1; } catch (e) { /* skip */ }
                    }
                    catalog.delete(PDFName.of('AA'));
                }
            } catch (e) { /* ignore */ }
            // Per-page /AA (open/close actions).
            try {
                const pages = pdfDoc.getPages();
                for (const page of pages) {
                    const node = page.node;
                    let aa = null;
                    try { aa = node.lookupMaybe(PDFName.of('AA'), PDFDict); } catch (e) { aa = null; }
                    if (!aa) continue;
                    for (const code of PAGE_AA_TRIGGERS) {
                        try { if (aa.lookupMaybe(PDFName.of(code), PDFDict)) removedActions += 1; } catch (e) { /* skip */ }
                    }
                    node.delete(PDFName.of('AA'));
                }
            } catch (e) { /* ignore */ }
        }

        if (doScripts || doEmbedded) {
            try {
                const namesDict = catalog.lookupMaybe(PDFName.of('Names'), PDFDict);
                if (namesDict) {
                    if (doScripts) {
                        try {
                            const jsTree = namesDict.lookupMaybe(PDFName.of('JavaScript'), PDFDict);
                            if (jsTree) {
                                removedScripts += countNameTreeLeaves(pdfDoc.context, PDFLib, jsTree);
                                namesDict.delete(PDFName.of('JavaScript'));
                            }
                        } catch (e) { /* ignore */ }
                    }
                    if (doEmbedded) {
                        try {
                            const efTree = namesDict.lookupMaybe(PDFName.of('EmbeddedFiles'), PDFDict);
                            if (efTree) {
                                removedEmbedded += countNameTreeLeaves(pdfDoc.context, PDFLib, efTree);
                                namesDict.delete(PDFName.of('EmbeddedFiles'));
                            }
                        } catch (e) { /* ignore */ }
                    }
                    // Drop an emptied /Names dict so we leave no dangling shell.
                    try {
                        if (namesDict.keys().length === 0) catalog.delete(PDFName.of('Names'));
                    } catch (e) { /* ignore */ }
                }
            } catch (e) { /* ignore */ }
        }

        const cleanedBytes = await pdfDoc.save();
        const outName = `${baseName()}_sanitized.pdf`;
        downloadBytes(cleanedBytes, outName, 'application/pdf');

        const parts = [];
        if (doScripts) parts.push(`${removedScripts} script${removedScripts === 1 ? '' : 's'}`);
        if (doActions) parts.push(`${removedActions} action${removedActions === 1 ? '' : 's'}`);
        if (doEmbedded) parts.push(`${removedEmbedded} embedded file${removedEmbedded === 1 ? '' : 's'}`);
        setStatus(`Sanitized → ${outName} — removed ${parts.join(', ')}.`);
    } catch (err) {
        console.error('[sanitize] sanitize failed:', err);
        setStatus('Failed to sanitize the PDF. The file may be corrupted or encrypted.', true);
        EventBus.emit(Events.ERROR, { message: 'Failed to sanitize the PDF.', error: err });
    } finally {
        refreshRunBtn();
    }
}

function onLoaded({ doc, name }) {
    loadToken += 1;
    currentDoc = doc || null;
    currentName = name || 'document.pdf';
    rescan().catch((err) => {
        console.error('[sanitize] unexpected scan error:', err);
        setStatus('Could not scan this PDF.', true);
    });
}

function onCleared() {
    loadToken += 1;
    currentDoc = null;
    currentName = 'document.pdf';
    counts = { scripts: 0, actions: 0, embedded: 0 };
    renderSummary();
    setStatus('Open a PDF first.');
}

export function initSanitize() {
    ensureEls();
    counts = { scripts: 0, actions: 0, embedded: 0 };
    renderSummary();
    setStatus('Open a PDF first.');

    [cbScripts, cbActions, cbEmbedded].forEach((cb) => {
        if (cb) cb.addEventListener('change', refreshRunBtn);
    });

    // Enter anywhere in the panel runs the tool (matches the other one-shot tools).
    const panel = document.querySelector('[data-panel="sanitize"]');
    if (panel) {
        panel.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && runBtn && !runBtn.disabled) {
                e.preventDefault();
                runSanitize();
            }
        });
    }

    ActionRegistry.register('sanitize.run', {
        title: 'Sanitize PDF — strip JavaScript, automatic actions & embedded files',
        run: () => runSanitize(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
