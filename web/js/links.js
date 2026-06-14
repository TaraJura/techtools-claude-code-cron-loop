// links.js — Links inspector panel (read-only).
//
// Enumerates every link annotation in the open PDF and reports them grouped by
// page: external hyperlinks (URLs) and internal cross-references (GoTo
// destinations to another page). The standard "what does this PDF link to, and
// where do its internal links point?" audit before sharing or archiving.
//
// It is purely observational — it NEVER modifies the document, never downloads,
// and never uploads anything. It complements toc.js (the document outline /
// bookmark tree, which is NOT link annotations), search.js / text-extract.js
// (text), and the read-only inspector family statistics.js / metadata.js /
// font-inspector.js (none of which enumerate link annotations).
//
// Isolation: this module only talks to the rest of the app through the
// EventBus (PDF_LOADED / PDF_CLEARED). It never touches the viewer rendering
// core or the .pdf-viewer-container flex-row layout (prompt rule 8) — it only
// renders into its own #links-list panel. Link data comes from pdf.js' own
// `page.getAnnotations()`, read-only. Every PDF-supplied value (URLs, dest
// names) is inserted via textContent (never innerHTML) and URLs are shown as
// PLAIN TEXT, never as a clickable <a href> — so a crafted javascript:/data:
// URI can neither execute nor be followed (XSS-safe, no navigation risk).

import { EventBus, Events } from './event-bus.js';

let listEl = null;
let statusEl = null;

// Token shown for the currently open document so a stale async walk (the user
// opened/closed another PDF mid-walk) can be discarded.
let loadToken = 0;

function ensureEls() {
    if (!listEl) listEl = document.getElementById('links-list');
    if (!statusEl) statusEl = document.getElementById('links-status');
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
    p.className = 'links-empty';
    p.textContent = text;
    listEl.appendChild(p);
}

/**
 * Resolve an internal GoTo destination to a 1-based page number, best-effort.
 * `dest` may be a named-destination string or an explicit destination array
 * whose first element is a page reference. Returns a number, or null if it
 * cannot be resolved. Never throws.
 */
async function resolveDestPage(doc, dest, myToken) {
    try {
        let explicit = dest;
        if (typeof dest === 'string') {
            explicit = await doc.getDestination(dest);
        }
        if (myToken !== loadToken) return null;
        if (!Array.isArray(explicit) || explicit.length === 0) return null;
        const ref = explicit[0];
        if (ref == null || typeof ref !== 'object') return null;
        const idx = await doc.getPageIndex(ref);
        if (myToken !== loadToken) return null;
        return typeof idx === 'number' ? idx + 1 : null;
    } catch (e) {
        return null; // unresolvable destination — caller shows a generic label
    }
}

/** Classify one Link annotation into { type, target } display strings. */
async function describeLink(doc, ann, myToken) {
    // External URL link.
    const url = ann.url || ann.unsafeUrl;
    if (url) {
        return { type: 'External URL', target: String(url), external: true };
    }
    // Internal GoTo destination.
    if (ann.dest != null) {
        const pageNum = await resolveDestPage(doc, ann.dest, myToken);
        if (pageNum != null) {
            return { type: 'Internal link', target: `→ page ${pageNum}`, internal: true };
        }
        return { type: 'Internal link', target: 'internal destination', internal: true };
    }
    // Some links carry a non-GoTo action (e.g. named/JS actions) or none.
    return { type: 'Other action', target: '—', other: true };
}

/** Build one row for a link and append it to the list. */
function renderLinkRow(parent, row) {
    const card = document.createElement('div');
    card.className = 'link-card';

    const head = document.createElement('div');
    head.className = 'link-card-head';

    const pageBadge = document.createElement('span');
    pageBadge.className = 'link-badge';
    pageBadge.textContent = `Page ${row.page}`;
    head.appendChild(pageBadge);

    const typeBadge = document.createElement('span');
    let typeClass = 'link-badge-other';
    if (row.external) typeClass = 'link-badge-ext';
    else if (row.internal) typeClass = 'link-badge-int';
    typeBadge.className = `link-badge ${typeClass}`;
    typeBadge.textContent = row.type;
    head.appendChild(document.createTextNode(' '));
    head.appendChild(typeBadge);

    card.appendChild(head);

    const target = document.createElement('div');
    target.className = 'link-card-target';
    target.textContent = row.target; // plain text only — never a clickable href
    card.appendChild(target);

    parent.appendChild(card);
}

async function inspectLinks(doc) {
    ensureEls();
    if (!listEl) return;
    const myToken = loadToken;

    setStatus('Inspecting links…');
    setPlaceholder('');

    const rows = [];
    try {
        const total = doc.numPages || 0;
        for (let i = 1; i <= total; i += 1) {
            let anns;
            try {
                const page = await doc.getPage(i);
                if (myToken !== loadToken) return; // a newer document loaded
                anns = await page.getAnnotations();
            } catch (e) {
                continue; // a page with unreadable annotations — skip it
            }
            if (myToken !== loadToken) return;
            if (!Array.isArray(anns)) continue;
            for (const ann of anns) {
                if (!ann || ann.subtype !== 'Link') continue;
                const desc = await describeLink(doc, ann, myToken);
                if (myToken !== loadToken) return;
                rows.push({ page: i, ...desc });
            }
        }
    } catch (err) {
        if (myToken !== loadToken) return;
        console.error('[links] inspection failed:', err);
        setStatus('Could not read links. The PDF may be corrupted or use an unsupported structure.', true);
        setPlaceholder('');
        return;
    }

    if (myToken !== loadToken) return;

    if (rows.length === 0) {
        setStatus('');
        setPlaceholder('No links found in this document.');
        return;
    }

    const external = rows.filter((r) => r.external).length;
    const internal = rows.filter((r) => r.internal).length;
    const parts = [];
    if (external) parts.push(`${external} external`);
    if (internal) parts.push(`${internal} internal`);
    const other = rows.length - external - internal;
    if (other) parts.push(`${other} other`);
    setStatus(`${rows.length} link${rows.length === 1 ? '' : 's'}` +
        (parts.length ? ` — ${parts.join(', ')}` : ''));

    listEl.innerHTML = '';
    for (const row of rows) renderLinkRow(listEl, row);
}

function onLoaded({ doc }) {
    loadToken += 1;
    if (!doc) {
        setStatus('Open a PDF first.');
        setPlaceholder('');
        return;
    }
    inspectLinks(doc).catch((err) => {
        console.error('[links] unexpected error:', err);
        setStatus('Could not read links.', true);
    });
}

function onCleared() {
    loadToken += 1;
    setStatus('Open a PDF first.');
    setPlaceholder('');
}

export function initLinks() {
    ensureEls();
    setStatus('Open a PDF first.');
    setPlaceholder('');

    EventBus.on(Events.PDF_LOADED, onLoaded);
    EventBus.on(Events.PDF_CLEARED, onCleared);
}
