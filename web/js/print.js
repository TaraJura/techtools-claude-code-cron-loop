// print.js — Print the open PDF via the browser's native print path.
//
// Sends the ORIGINAL loaded PDF bytes to the printer (not a re-rasterized
// canvas) so the output is crisp vector quality with the correct page sizes.
// The bytes come straight from pdf.js' own `doc.getData()`, are wrapped in a
// Blob (application/pdf) → object URL, and printed entirely client-side. No
// upload, no server round trip, and the open viewer document is never mutated.
//
// Two-path mechanism (browsers handle embedded PDFs differently):
//   1. Hidden-iframe silent print — load the blob into an off-screen <iframe>
//      and call `iframe.contentWindow.print()`. This opens the print dialog
//      directly on Firefox / Edge / engines that render PDFs in a same-origin
//      document.
//   2. New-tab fallback — Chrome renders a PDF in its OUT-OF-PROCESS PDF viewer,
//      which makes `iframe.contentWindow` cross-origin (contentDocument is null
//      and print() throws SecurityError). When the silent path throws, we open
//      the original PDF in a new browser tab, where Chrome's built-in viewer
//      shows it print-ready (the user presses Ctrl/⌘+P or the viewer's print
//      button). The original vector PDF is preserved either way.
//
// This is distinct from the heavyweight `printprep` roadmap item (bleed / crop
// marks / print-shop prep) — this is simply "send the current PDF to print."
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED) and the ActionRegistry. It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout
// (prompt rule 8). The raw PDF bytes come from pdf.js' own `doc.getData()`.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';

let currentDoc = null;   // pdf.js PDFDocumentProxy of the open document
let numPages = 0;

let printBtn = null;
let statusEl = null;

// The in-flight print iframe + its object URL, so a second Print press tears
// down the previous one first (no stacking, no leaks). The object URL is kept
// alive long enough for either the print dialog or a fallback tab to read it.
let activeFrame = null;
let activeUrl = null;
let revokeTimer = 0;
let safetyTimer = 0;

function setStatus(msg, isError = false) {
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Enable/disable the controls depending on whether a document is open. */
function setEnabled(enabled) {
    if (printBtn) printBtn.disabled = !enabled;
}

/** Remove the active print iframe (idempotent). */
function removeFrame() {
    if (safetyTimer) { clearTimeout(safetyTimer); safetyTimer = 0; }
    if (activeFrame) { activeFrame.remove(); activeFrame = null; }
}

/** Revoke the active object URL (idempotent). */
function revokeUrl() {
    if (revokeTimer) { clearTimeout(revokeTimer); revokeTimer = 0; }
    if (activeUrl) { URL.revokeObjectURL(activeUrl); activeUrl = null; }
}

/** Full teardown — used on PDF_CLEARED and before starting a fresh print. */
function cleanupAll() {
    removeFrame();
    revokeUrl();
}

/** Chrome fallback: open the original PDF in a new tab (native viewer prints).
 *  An anchor click with target="_blank" during a user gesture opens a real tab
 *  and — unlike scripted window.open — is not treated as a blockable popup. */
function openInNewTab(url) {
    const a = document.createElement('a');
    a.href = url;
    a.target = '_blank';
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setStatus('Opened the PDF in a new tab — press Ctrl/⌘+P there to print.');
    // Keep the blob URL alive so the new tab can read it, then reclaim.
    revokeTimer = window.setTimeout(revokeUrl, 60000);
}

/** Print the original loaded PDF bytes. */
async function printPdf() {
    if (!currentDoc || numPages === 0) {
        setStatus('Open a PDF first.', true);
        return;
    }

    setStatus('Preparing to print…');
    if (printBtn) printBtn.disabled = true;
    try {
        // Any previous print frame/URL is torn down before a new one is created
        // so repeated prints never accumulate iframes / object URLs.
        cleanupAll();

        // pdf.js hands back the original document bytes untouched.
        const srcBytes = await currentDoc.getData();
        const blob = new Blob([srcBytes], { type: 'application/pdf' });
        const url = URL.createObjectURL(blob);
        activeUrl = url;

        const iframe = document.createElement('iframe');
        iframe.id = 'print-frame';
        // Hidden, off-screen, zero-size — present only to host the PDF document.
        iframe.setAttribute(
            'style',
            'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;',
        );
        iframe.setAttribute('aria-hidden', 'true');
        activeFrame = iframe;

        iframe.onload = () => {
            // Try the silent same-origin print path first (Firefox / Edge).
            const win = iframe.contentWindow;
            try {
                if (!win) throw new Error('no contentWindow');
                // afterprint reclaims the iframe + URL once the dialog returns.
                win.addEventListener('afterprint', cleanupAll, { once: true });
                win.focus();
                win.print(); // throws SecurityError in Chrome (cross-origin PDF)
                setStatus(`Printing ${numPages} page${numPages === 1 ? '' : 's'}…`);
            } catch (_silentBlocked) {
                // Expected on Chrome — the PDF viewer is cross-origin. Fall back
                // to a new tab. This is NOT an error worth logging to console.
                removeFrame();            // drop the unusable iframe…
                openInNewTab(url);        // …but keep `url` alive for the new tab.
            }
        };

        iframe.src = url;
        document.body.appendChild(iframe);

        // Safety net: if onload/afterprint never fire (silent path), reclaim the
        // iframe after 60s so nothing leaks. The URL is revoked separately so a
        // fallback tab keeps working.
        safetyTimer = window.setTimeout(removeFrame, 60000);
    } catch (err) {
        console.error('[print] failed:', err);
        setStatus('Failed to prepare the document for printing. It may be corrupted or encrypted.', true);
        cleanupAll();
        EventBus.emit(Events.ERROR, { message: 'Failed to print PDF.', error: err });
    } finally {
        // Re-enable the button (the print itself is fire-and-forget).
        if (printBtn) printBtn.disabled = numPages === 0;
    }
}

function onLoaded({ doc, numPages: n }) {
    currentDoc = doc || null;
    numPages = n || (doc && doc.numPages) || 0;
    setEnabled(numPages > 0);
    setStatus(numPages > 0 ? `${numPages} page${numPages === 1 ? '' : 's'} ready to print.` : '');
}

function onCleared() {
    currentDoc = null;
    numPages = 0;
    setEnabled(false);
    cleanupAll();
    setStatus('Open a PDF first.');
}

export function initPrint() {
    printBtn = document.getElementById('print-run');
    statusEl = document.getElementById('print-status');

    setEnabled(false);
    setStatus('Open a PDF first.');

    ActionRegistry.register('print.run', {
        title: 'Print',
        run: () => printPdf(),
    });

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
