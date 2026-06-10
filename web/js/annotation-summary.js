// annotation-summary.js — list & jump to all markups (TASK-327).
//
// A read-only navigation surface over the annotations created by annotate.js
// (highlight / underline / strikethrough). It renders a live list of every
// markup grouped by page; clicking an entry scrolls that page into view and
// selects the markup (reusing annotate.js's existing select + scroll path).
//
// Decoupled by design: it owns NO annotation state. It reads a snapshot via
// Annotate.getAnnotations() and re-renders whenever the store changes
// (Events.ANNOTATIONS_CHANGED) or a document is loaded/cleared. It never
// touches viewer.js, the render core, or the markup store directly.

import { EventBus, Events } from './event-bus.js';
import * as Annotate from './annotate.js';
import * as Viewer from './viewer.js';

let listEl = null; // #annotation-summary-list

function cacheEls() {
    listEl = document.getElementById('annotation-summary-list');
}

/** Render the empty/placeholder state with a short message. */
function renderEmpty(message) {
    listEl.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'summary-empty';
    p.textContent = message;
    listEl.appendChild(p);
}

/** Re-paint the whole list from a fresh annotate.js snapshot. Idempotent. */
function render() {
    if (!listEl) return;

    if (!Viewer.getDocument()) {
        renderEmpty('Load a PDF first.');
        return;
    }

    const items = Annotate.getAnnotations();
    if (items.length === 0) {
        renderEmpty('No markups yet. Use the Annotate tools to highlight, underline, or strike through text.');
        return;
    }

    // Stable order: by page, then by creation order (id ascending).
    items.sort((a, b) => (a.page - b.page) || (a.id - b.id));

    listEl.innerHTML = '';

    // Count header (aria-friendly summary of how many markups exist).
    const count = document.createElement('p');
    count.className = 'summary-count';
    count.textContent = `${items.length} markup${items.length === 1 ? '' : 's'}`;
    listEl.appendChild(count);

    const ul = document.createElement('ul');
    ul.className = 'summary-list';

    let lastPage = null;
    for (const item of items) {
        if (item.page !== lastPage) {
            const heading = document.createElement('li');
            heading.className = 'summary-page-heading';
            heading.setAttribute('aria-hidden', 'true');
            heading.textContent = `Page ${item.page}`;
            ul.appendChild(heading);
            lastPage = item.page;
        }

        const li = document.createElement('li');
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = `summary-item summary-item--${item.type}`;
        btn.setAttribute('aria-label', `${item.label} on page ${item.page} — jump to it`);

        const dot = document.createElement('span');
        dot.className = 'summary-dot';
        dot.setAttribute('aria-hidden', 'true');

        const text = document.createElement('span');
        text.className = 'summary-text';
        text.textContent = item.label; // label comes from annotate.js, never user input

        const pageBadge = document.createElement('span');
        pageBadge.className = 'summary-page';
        pageBadge.textContent = `p.${item.page}`;

        btn.append(dot, text, pageBadge);
        btn.addEventListener('click', () => Annotate.focusAnnotation(item.id));
        li.appendChild(btn);
        ul.appendChild(li);
    }

    listEl.appendChild(ul);
}

export function initAnnotationSummary() {
    cacheEls();
    render();

    EventBus.on(Events.ANNOTATIONS_CHANGED, render);
    EventBus.on(Events.PDF_LOADED, render);
    EventBus.on(Events.PDF_CLEARED, render);
}

export default initAnnotationSummary;
