// search.js — in-document full-text search (TASK-307).
//
// Lets the user find text across the loaded PDF. Text is extracted per page via
// pdf.js's `getTextContent()`, lazily on the first search and cached so repeat
// searches are instant. Matches are case-insensitive substring matches; the
// user steps Next/Previous through them and the matching page is scrolled into
// view with the surrounding snippet shown.
//
// Purely additive (TASK-307): it does NOT modify viewer.js's rendering core or
// upload.js's validation. It subscribes to EventBus document events, reuses the
// `doc` proxy from the PDF_LOADED payload, and reads the `.pdf-page
// [data-page-number]` elements viewer.js already rendered.
//
// NOTE on highlighting: the viewer renders pages to <canvas> only (no pdf.js
// text layer), so a precise in-page highlight overlay isn't possible without
// touching the rendering core. As the task permits, navigating to a match
// scrolls its page into view and shows the matching snippet + live match count
// ("3 of 12") rather than drawing an overlay box on the page.

import { EventBus, Events } from './event-bus.js';

const DEBOUNCE_MS = 200;
const SNIPPET_RADIUS = 40; // chars of context shown on each side of a match

let inputEl = null;     // #search-input
let statusEl = null;    // #search-status (aria-live=polite — announces "N of M")
let snippetEl = null;   // #search-snippet (current match context)
let prevBtn = null;     // #search-prev
let nextBtn = null;     // #search-next
let tabEl = null;       // the "Search" tool tab
let viewerEl = null;    // .pdf-viewer-inner (focus target on Escape)

let doc = null;             // current pdfjs document (from PDF_LOADED payload)
let numPages = 0;
const pageText = new Map(); // pageNumber -> extracted text string (lazy cache)
let matches = [];           // [{ pageNumber, matchIndex, snippet }]
let currentIdx = -1;        // index into `matches` of the active match
let lastQuery = null;       // last query actually searched (so Enter can advance)
let token = 0;              // bumps on load/clear to abort stale async work
let debounceTimer = null;

function cacheEls() {
    inputEl = document.getElementById('search-input');
    statusEl = document.getElementById('search-status');
    snippetEl = document.getElementById('search-snippet');
    prevBtn = document.getElementById('search-prev');
    nextBtn = document.getElementById('search-next');
    tabEl = document.querySelector('.tool-tab[data-tab="search"]');
    viewerEl = document.querySelector('.pdf-viewer-inner');
}

function setStatus(text) {
    if (statusEl) statusEl.textContent = text;
}

function setSnippet(text) {
    if (snippetEl) snippetEl.textContent = text;
}

/** Enable/disable the controls based on whether a document is open. */
function setEnabled(on) {
    if (inputEl) inputEl.disabled = !on;
    updateNavButtons();
}

/** Next/Prev are only operable when there is more than one match to step to. */
function updateNavButtons() {
    const has = matches.length > 0 && !!doc;
    if (prevBtn) prevBtn.disabled = !has;
    if (nextBtn) nextBtn.disabled = !has;
}

/** Build a trimmed, single-line snippet of context around a match. */
function makeSnippet(text, idx, len) {
    const start = Math.max(0, idx - SNIPPET_RADIUS);
    const end = Math.min(text.length, idx + len + SNIPPET_RADIUS);
    let s = text.slice(start, end).replace(/\s+/g, ' ').trim();
    if (start > 0) s = '…' + s;
    if (end < text.length) s = s + '…';
    return s;
}

/** Scroll the rendered page with the given 1-based number into view. */
function scrollToPage(pageNumber) {
    const page = document.querySelector(`.pdf-page[data-page-number="${pageNumber}"]`);
    if (page) page.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/**
 * Lazily extract and cache text for every page. Aborts cleanly if the document
 * changes mid-extraction (token mismatch). Chunked with `await` so the UI
 * thread is never blocked on large docs.
 */
async function extractAllText(myToken) {
    if (!doc) return;
    for (let p = 1; p <= numPages; p++) {
        if (myToken !== token) return; // a newer load/clear superseded us
        if (pageText.has(p)) continue;
        try {
            const page = await doc.getPage(p);
            const tc = await page.getTextContent();
            pageText.set(p, tc.items.map((i) => i.str).join(' '));
        } catch (err) {
            console.warn(`[search] could not extract text for page ${p}:`, err);
            pageText.set(p, ''); // don't retry a bad page on every search
        }
    }
}

/** Run a search for `query`, populate `matches`, and show the first hit. */
async function runSearch(query) {
    matches = [];
    currentIdx = -1;
    setSnippet('');

    if (!doc) {
        setStatus('Load a PDF first.');
        updateNavButtons();
        return;
    }

    const q = (query || '').trim();
    lastQuery = q;
    if (!q) {
        setStatus('');
        updateNavButtons();
        return;
    }

    const myToken = token;
    setStatus('Searching…');
    await extractAllText(myToken);
    if (myToken !== token) return; // document changed while we were extracting

    const needle = q.toLowerCase();
    for (let p = 1; p <= numPages; p++) {
        const text = pageText.get(p) || '';
        const hay = text.toLowerCase();
        let from = 0;
        let idx;
        while ((idx = hay.indexOf(needle, from)) !== -1) {
            matches.push({
                pageNumber: p,
                matchIndex: idx,
                snippet: makeSnippet(text, idx, needle.length),
            });
            from = idx + needle.length;
        }
    }

    if (!matches.length) {
        setStatus('No matches found.');
        updateNavButtons();
        return;
    }

    currentIdx = 0;
    showCurrent();
}

/** Reflect the active match: live count, snippet, scroll, button state. */
function showCurrent() {
    if (currentIdx < 0 || currentIdx >= matches.length) return;
    const m = matches[currentIdx];
    setStatus(`${currentIdx + 1} of ${matches.length}`);
    setSnippet(`Page ${m.pageNumber}: ${m.snippet}`);
    scrollToPage(m.pageNumber);
    updateNavButtons();
}

/** Step to the next/previous match, wrapping around like a browser find bar. */
function step(delta) {
    if (!matches.length) return;
    currentIdx = (currentIdx + delta + matches.length) % matches.length;
    showCurrent();
}

/** Clear the query, results, and return focus to the document. */
function escapeSearch() {
    if (inputEl) inputEl.value = '';
    matches = [];
    currentIdx = -1;
    lastQuery = '';
    setStatus('');
    setSnippet('');
    updateNavButtons();
    if (viewerEl) viewerEl.focus();
}

/** Reset everything for a new (or no) document. */
function resetForDoc(newDoc, pages) {
    token++;                 // abort any in-flight extraction / search
    doc = newDoc || null;
    numPages = pages || 0;
    pageText.clear();
    matches = [];
    currentIdx = -1;
    lastQuery = null;
    if (inputEl) inputEl.value = '';
    setSnippet('');
    if (doc) {
        setEnabled(true);
        setStatus('');
    } else {
        setEnabled(false);
        setStatus('Load a PDF first.');
    }
}

/** Activate the Search tab and focus the input (after the panel is shown). */
function focusSearch() {
    if (tabEl) tabEl.click(); // app.js's tab wiring toggles the active panel
    // Focus only once the panel is visible (display:none children can't focus).
    requestAnimationFrame(() => {
        if (inputEl && !inputEl.disabled) {
            inputEl.focus();
            inputEl.select();
        }
    });
}

export function initSearch() {
    cacheEls();
    setEnabled(false);
    setStatus('Load a PDF first.');

    if (inputEl) {
        inputEl.addEventListener('input', () => {
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(() => runSearch(inputEl.value), DEBOUNCE_MS);
        });
        inputEl.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                if (debounceTimer) clearTimeout(debounceTimer);
                const q = inputEl.value.trim();
                // Same query as last time → advance; otherwise (re)run the search.
                if (q === lastQuery && matches.length) {
                    step(e.shiftKey ? -1 : 1);
                } else {
                    runSearch(inputEl.value);
                }
            } else if (e.key === 'Escape') {
                e.preventDefault();
                escapeSearch();
            }
        });
    }

    if (nextBtn) nextBtn.addEventListener('click', () => step(1));
    if (prevBtn) prevBtn.addEventListener('click', () => step(-1));

    // Ctrl/Cmd+F opens the search panel instead of the browser's native find.
    document.addEventListener('keydown', (e) => {
        if ((e.ctrlKey || e.metaKey) && (e.key === 'f' || e.key === 'F')) {
            e.preventDefault();
            focusSearch();
        }
    });

    // Clicking the Search tab focuses the input once its panel is active.
    if (tabEl) {
        tabEl.addEventListener('click', () => {
            requestAnimationFrame(() => {
                if (inputEl && !inputEl.disabled) inputEl.focus();
            });
        });
    }

    EventBus.on(Events.PDF_LOADED, ({ doc: d, numPages: n }) => {
        resetForDoc(d, n);
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        resetForDoc(null, 0);
    });
}

export default initSearch;
