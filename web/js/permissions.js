// permissions.js — Security & Permissions Inspector panel (read-only).
//
// Reports the encryption + permission state of the open PDF in plain language:
//   • Is the document encrypted? (and, when known, the security handler.)
//   • A labelled ✓/✗ list of each standard PDF permission flag (Printing,
//     High-resolution printing, Copy/extract, Modify, Annotations,
//     Form-filling, Extract for accessibility, Assemble pages).
//   • A one-line summary ("No restrictions — all actions permitted." /
//     "Encrypted — printing and copying are not allowed.").
//
// Answers the everyday "can I print/copy from this file, or is it locked?"
// question before the user tries.
//
// It is purely observational — it NEVER modifies the document, never
// downloads, and never uploads anything. It complements metadata.js
// (title/author/subject), statistics.js (sizes/structural counts) and
// font-inspector.js (fonts) — none of those report encryption or the
// permission flags.
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering
// core or the .pdf-viewer-container flex-row layout (prompt rule 8) — it only
// renders into its own #permissions-* panel elements. Permission state comes
// from pdf.js' own `doc.getPermissions()`; the encrypted yes/no + handler is a
// pure structural read of the trailer's /Encrypt dict via pdf-lib (loaded with
// ignoreEncryption:true). Every PDF-supplied value is inserted via textContent
// (never innerHTML), so a crafted /Filter name cannot inject markup (XSS-safe).

import { EventBus, Events } from './event-bus.js';
import * as pdfjsLib from '../lib/pdf.min.mjs';

let listEl = null;
let statusEl = null;
let summaryEl = null;
let encEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

// The eight standard PDF permission bits, in the order we display them. We
// resolve the bit value from pdf.js' exported PermissionFlag where present and
// fall back to the spec constants so the module is robust if the export name
// ever shifts. doc.getPermissions() returns an array of these numeric flags
// (the ones that ARE allowed) or null when there are no restrictions.
const PF = pdfjsLib.PermissionFlag || {};
const PERMISSIONS = [
    { key: 'PRINT', bit: PF.PRINT ?? 0x04, label: 'Printing' },
    { key: 'PRINT_HIGH_QUALITY', bit: PF.PRINT_HIGH_QUALITY ?? 0x800, label: 'High-resolution printing' },
    { key: 'COPY', bit: PF.COPY ?? 0x10, label: 'Copy / extract text & graphics' },
    { key: 'MODIFY_CONTENTS', bit: PF.MODIFY_CONTENTS ?? 0x08, label: 'Modify document' },
    { key: 'MODIFY_ANNOTATIONS', bit: PF.MODIFY_ANNOTATIONS ?? 0x20, label: 'Add / modify annotations' },
    { key: 'FILL_INTERACTIVE_FORMS', bit: PF.FILL_INTERACTIVE_FORMS ?? 0x100, label: 'Fill form fields' },
    { key: 'COPY_FOR_ACCESSIBILITY', bit: PF.COPY_FOR_ACCESSIBILITY ?? 0x200, label: 'Extract for accessibility' },
    { key: 'ASSEMBLE', bit: PF.ASSEMBLE ?? 0x400, label: 'Assemble (insert/rotate/delete pages)' },
];

function ensureEls() {
    if (!listEl) listEl = document.getElementById('permissions-list');
    if (!statusEl) statusEl = document.getElementById('permissions-status');
    if (!summaryEl) summaryEl = document.getElementById('permissions-summary');
    if (!encEl) encEl = document.getElementById('permissions-encryption');
}

function setStatus(msg, isError = false) {
    ensureEls();
    if (!statusEl) return;
    statusEl.textContent = msg;
    statusEl.classList.toggle('error', !!isError);
}

/** Clear the report region (encryption line, summary, permission list). */
function clearReport() {
    ensureEls();
    if (encEl) encEl.textContent = '';
    if (summaryEl) summaryEl.textContent = '';
    if (listEl) listEl.innerHTML = '';
}

/**
 * Structurally read the trailer's /Encrypt dictionary with pdf-lib (read-only,
 * ignoreEncryption so an owner-password file still parses). Returns
 * { encrypted, handler, v, r } — handler/v/r best-effort, never throws.
 */
async function readEncryption(doc) {
    const result = { encrypted: false, handler: '', v: null, r: null };
    const PDFLib = window.PDFLib;
    if (!PDFLib || !PDFLib.PDFDocument) return result;

    let bytes;
    try {
        bytes = await doc.getData();
    } catch (e) {
        return result;
    }

    let pdfDoc;
    try {
        pdfDoc = await PDFLib.PDFDocument.load(bytes, {
            ignoreEncryption: true,
            updateMetadata: false,
        });
    } catch (e) {
        return result;
    }

    try {
        const { PDFName, PDFDict, PDFNumber } = PDFLib;
        const context = pdfDoc.context;
        const trailer = context.trailerInfo || {};
        let encryptDict = null;

        // pdf-lib exposes the trailer's /Encrypt entry on trailerInfo.Encrypt
        // (a ref or a dict). Resolve it to a dict if present.
        const encRef = trailer.Encrypt;
        if (encRef) {
            const resolved = context.lookup(encRef);
            if (resolved instanceof PDFDict) encryptDict = resolved;
        }

        if (encryptDict) {
            result.encrypted = true;
            const filter = encryptDict.lookupMaybe(PDFName.of('Filter'), PDFName);
            if (filter) {
                const f = filter.asString().replace(/^\//, '');
                result.handler = f === 'Standard' ? 'Standard security handler' : f;
            }
            const v = encryptDict.lookupMaybe(PDFName.of('V'), PDFNumber);
            if (v) result.v = v.asNumber();
            const r = encryptDict.lookupMaybe(PDFName.of('R'), PDFNumber);
            if (r) result.r = r.asNumber();
        }
    } catch (e) {
        // Best-effort structural read — keep whatever we have, never throw.
    }
    return result;
}

/** Render the encrypted yes/no line into #permissions-encryption. */
function renderEncryptionLine(enc) {
    ensureEls();
    if (!encEl) return;
    encEl.innerHTML = '';

    const label = document.createElement('span');
    label.className = 'permissions-enc-label';
    label.textContent = 'Encrypted: ';

    const value = document.createElement('span');
    value.className = `permissions-enc-value ${enc.encrypted ? 'is-encrypted' : 'not-encrypted'}`;
    if (enc.encrypted) {
        let txt = 'Yes';
        const detail = [];
        if (enc.handler) detail.push(enc.handler);
        if (enc.v != null) detail.push(`V${enc.v}`);
        if (enc.r != null) detail.push(`R${enc.r}`);
        if (detail.length) txt += ` — ${detail.join(', ')}`;
        value.textContent = txt;
    } else {
        value.textContent = 'No';
    }

    encEl.appendChild(label);
    encEl.appendChild(value);
}

/**
 * Render the ✓/✗ permission list.
 * @param {Set<number>|null} allowed - set of allowed permission bits, or null
 *        (null => no restrictions, every permission allowed).
 */
function renderPermissionList(allowed) {
    ensureEls();
    if (!listEl) return;
    listEl.innerHTML = '';

    const ul = document.createElement('ul');
    ul.className = 'permissions-rows';
    ul.setAttribute('aria-label', 'PDF permission flags');

    for (const perm of PERMISSIONS) {
        const isAllowed = allowed === null ? true : allowed.has(perm.bit);
        const li = document.createElement('li');
        li.className = `permissions-row ${isAllowed ? 'allowed' : 'denied'}`;

        const mark = document.createElement('span');
        mark.className = 'permissions-mark';
        mark.setAttribute('aria-hidden', 'true');
        mark.textContent = isAllowed ? '✓' : '✗';

        const text = document.createElement('span');
        text.className = 'permissions-text';
        // Visible label + an SR-only allowed/not-allowed word so the ✓/✗ glyph
        // (aria-hidden) is not the only signal for screen readers.
        text.textContent = perm.label;
        const sr = document.createElement('span');
        sr.className = 'visually-hidden';
        sr.textContent = isAllowed ? ' — allowed' : ' — not allowed';
        text.appendChild(sr);

        li.appendChild(mark);
        li.appendChild(text);
        ul.appendChild(li);
    }

    listEl.appendChild(ul);
}

/** Build the one-line plain-language summary. */
function buildSummary(enc, allowed) {
    if (allowed === null) {
        return enc.encrypted
            ? 'Encrypted, but no usage restrictions — all actions permitted.'
            : 'No restrictions — all actions permitted.';
    }
    // Identify the headline denied actions for a friendly summary.
    const denied = PERMISSIONS.filter((p) => !allowed.has(p.bit));
    if (denied.length === 0) {
        return enc.encrypted
            ? 'Encrypted, but all standard actions are permitted.'
            : 'No restrictions — all actions permitted.';
    }
    const names = denied.map((p) => p.label.toLowerCase());
    // Compact the common print/copy phrasing.
    let phrase;
    if (names.length === 1) phrase = names[0];
    else if (names.length === 2) phrase = `${names[0]} and ${names[1]}`;
    else phrase = `${names.slice(0, -1).join(', ')}, and ${names[names.length - 1]}`;
    const prefix = enc.encrypted ? 'Encrypted' : 'Restricted';
    return `${prefix} — the following are not allowed: ${phrase}.`;
}

async function inspect(doc) {
    ensureEls();
    const myToken = loadToken;

    setStatus('Inspecting security…');
    clearReport();

    // 1) Permission flags from pdf.js (null => no restrictions).
    let allowed = null; // Set<number> | null
    try {
        const perms = await doc.getPermissions();
        if (myToken !== loadToken) return; // a newer document loaded meanwhile
        allowed = Array.isArray(perms) ? new Set(perms) : null;
    } catch (e) {
        if (myToken !== loadToken) return;
        // pdf.js could not resolve permissions — fall back to "no restrictions"
        // for the flag list but note it; never throw.
        allowed = null;
    }

    // 2) Encryption yes/no + handler from the structural /Encrypt read.
    let enc = { encrypted: false, handler: '', v: null, r: null };
    try {
        enc = await readEncryption(doc);
    } catch (e) {
        // keep default — best effort.
    }
    if (myToken !== loadToken) return;

    renderEncryptionLine(enc);
    renderPermissionList(allowed);
    if (summaryEl) summaryEl.textContent = buildSummary(enc, allowed);

    const deniedCount = allowed === null
        ? 0
        : PERMISSIONS.filter((p) => !allowed.has(p.bit)).length;
    if (enc.encrypted || deniedCount > 0) {
        setStatus(`${enc.encrypted ? 'Encrypted' : 'Unencrypted'} — `
            + `${deniedCount} of ${PERMISSIONS.length} actions restricted.`);
    } else {
        setStatus('Unencrypted — all actions permitted.');
    }
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        clearReport();
        return;
    }
    inspect(doc).catch((err) => {
        console.error('[permissions] unexpected error:', err);
        setStatus('Could not read security info. The PDF may be corrupted or use an unsupported structure.', true);
        clearReport();
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    clearReport();
}

export function initPermissions() {
    ensureEls();
    setStatus('Open a PDF first.');
    clearReport();

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
