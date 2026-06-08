// toc.js — Table of Contents / document outline.
//
// Lists a PDF's embedded outline (a.k.a. bookmarks) in the "Contents" tool
// panel. Each entry resolves its destination through pdf.js and scrolls the
// target page into view on click.
//
// Purely additive: subscribes to EventBus document events and reads pages that
// viewer.js already rendered (`.pdf-page[data-page-number]`). It never touches
// the viewer rendering core or the .pdf-viewer-container flex-row layout.

import { EventBus, Events } from './event-bus.js';
import { getDocument } from './viewer.js';

let listEl = null;

function ensureListEl() {
    if (!listEl) listEl = document.getElementById('toc-list');
    return listEl;
}

function setPlaceholder(text) {
    const el = ensureListEl();
    if (!el) return;
    el.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'toc-empty';
    p.textContent = text;
    el.appendChild(p);
}

/**
 * Resolve an outline item's destination to a 1-based page number.
 * Handles both named destinations (string) and explicit dest arrays.
 * @returns {Promise<number|null>}
 */
async function destToPageNumber(doc, dest) {
    try {
        let explicit = dest;
        if (typeof dest === 'string') explicit = await doc.getDestination(dest);
        if (!Array.isArray(explicit) || !explicit[0]) return null;
        const pageIndex = await doc.getPageIndex(explicit[0]);
        return pageIndex + 1; // pdf.js page indices are 0-based
    } catch (err) {
        console.warn('[toc] could not resolve destination:', err);
        return null;
    }
}

/** Scroll the rendered page with the given 1-based number into view. */
function scrollToPage(pageNumber) {
    const page = document.querySelector(`.pdf-page[data-page-number="${pageNumber}"]`);
    if (page) page.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/** Build a nested <ul> for an array of outline items. */
function buildList(items, doc) {
    const ul = document.createElement('ul');
    ul.className = 'toc-tree';

    for (const item of items) {
        const li = document.createElement('li');

        if (item.url) {
            // External link — open safely in a new tab.
            const a = document.createElement('a');
            a.className = 'toc-link';
            a.textContent = item.title || item.url;
            a.href = item.url;
            a.target = '_blank';
            a.rel = 'noopener noreferrer';
            li.appendChild(a);
        } else {
            // Internal destination — resolve + scroll on click.
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'toc-link';
            btn.textContent = item.title || '(untitled)';
            btn.addEventListener('click', async () => {
                const doc2 = getDocument();
                if (!doc2) return;
                const pageNumber = await destToPageNumber(doc2, item.dest);
                if (pageNumber) scrollToPage(pageNumber);
            });
            li.appendChild(btn);
        }

        if (Array.isArray(item.items) && item.items.length) {
            li.appendChild(buildList(item.items, doc));
        }
        ul.appendChild(li);
    }
    return ul;
}

async function renderOutline(doc) {
    const el = ensureListEl();
    if (!el || !doc) return;
    let outline = null;
    try {
        outline = await doc.getOutline();
    } catch (err) {
        console.warn('[toc] getOutline failed:', err);
    }
    if (!outline || !outline.length) {
        setPlaceholder('No table of contents in this document.');
        return;
    }
    el.innerHTML = '';
    el.appendChild(buildList(outline, doc));
}

export function initToc() {
    setPlaceholder('Open a PDF to see its table of contents.');

    EventBus.on(Events.PDF_LOADED, ({ doc }) => {
        renderOutline(doc);
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        setPlaceholder('Open a PDF to see its table of contents.');
    });
}
