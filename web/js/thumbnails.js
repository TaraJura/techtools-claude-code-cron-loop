// thumbnails.js — Page thumbnails navigator.
//
// Renders a small clickable preview of every page in the open PDF into the
// "Pages" tool panel. Clicking (or Enter/Space on) a thumbnail scrolls the
// matching .pdf-page[data-page-number] into view.
//
// Active-page tracking (TASK-312): a self-contained IntersectionObserver over
// the rendered .pdf-page elements (rooted on .pdf-viewer-inner, mirroring the
// page-nav.js pattern) marks the most-visible page's thumbnail .is-active +
// aria-current="page" and scrolls it into view *within the panel only*. We run
// our own observer rather than depend on page-nav.js — page-nav.js is on the
// contract list and emits no page-change event (see TASK-312 note).
//
// Keyboard navigation (TASK-323): the strip is a composite widget
// (role="toolbar") with roving tabindex — exactly one thumbnail is tabindex=0
// (the active page), the rest tabindex=-1, so Tab lands on the active page and
// arrow keys move within the strip. ArrowUp/Left and ArrowDown/Right (plus
// Home/End) move the active+focused thumbnail; Enter/Space is left to the
// button's NATIVE activation, which fires the same click handler as the mouse
// (so keyboard and click share one code path → identical active state). The
// scroll-driven observer updates the active highlight + roving tabindex but
// never steals focus; only explicit key presses move focus.
//
// Purely additive: subscribes to EventBus document events only. It never
// touches the viewer rendering core or the .pdf-viewer-container flex-row
// layout (developer prompt rule 8). Thumbnails render sequentially and a
// render token guards against overlap when a new document loads, keeping the
// memory footprint small on the 1.6 GiB-RAM box.

import { EventBus, Events } from './event-bus.js';

const THUMB_WIDTH = 120; // CSS px target width for each thumbnail canvas

let listEl = null;
let renderToken = 0; // bumped on each (re)render so a stale loop can bail out

// --- active-page tracking (TASK-312) ---
let pageObserver = null;            // IntersectionObserver over .pdf-page elements
const pageRatios = new Map();       // pageNumber -> latest intersection ratio
let activePage = 0;                 // 1-based current page; 0 = none

function ensureListEl() {
    if (!listEl) listEl = document.getElementById('thumbnails-list');
    return listEl;
}

/**
 * Reflect `activePage` into the DOM: move the .is-active / aria-current flag and
 * the roving tabindex (=0) to the matching thumbnail, optionally scroll it into
 * view inside the panel, and optionally move focus to it. The scroll is
 * `block: 'nearest'` and the target's only scrollable ancestor is
 * #thumbnails-list — .pdf-viewer-inner is NOT an ancestor — so the main
 * document never moves (no feedback loop with the viewer). `focus` is passed
 * only for explicit keyboard navigation, never for scroll-driven updates, so
 * scrolling the main view can never yank focus into the sidebar.
 */
function applyActiveThumbnail(scroll, focus) {
    const el = ensureListEl();
    if (!el) return;

    const prev = el.querySelector('.thumbnail.is-active');
    if (prev && Number(prev.dataset.pageNumber) !== activePage) {
        prev.classList.remove('is-active');
        prev.removeAttribute('aria-current');
        prev.tabIndex = -1; // roving tabindex: the old active leaves the tab order
    }

    if (!activePage) return;
    const next = el.querySelector(`.thumbnail[data-page-number="${activePage}"]`);
    if (!next) return; // thumbnail not built yet — re-applied when the strip finishes
    if (!next.classList.contains('is-active')) {
        next.classList.add('is-active');
        next.setAttribute('aria-current', 'page');
    }
    next.tabIndex = 0; // roving tabindex: exactly one thumbnail is tabbable
    if (scroll) next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    if (focus) next.focus();
}

/** Update the active page (from scroll observation) and sync the highlight.
 *  Never moves focus — the user is scrolling the main view, not the sidebar. */
function setActiveThumbnail(n) {
    if (n === activePage) return;
    activePage = n;
    applyActiveThumbnail(true, false);
}

/**
 * Move the active+focused thumbnail to page `n` (clamped into range), driven by
 * keyboard. Updates the highlight + roving tabindex and moves focus to it.
 */
function moveActiveThumbnail(n) {
    const el = ensureListEl();
    if (!el) return;
    const total = el.querySelectorAll('.thumbnail').length;
    if (!total) return; // no document / no thumbnails — safe no-op
    const target = Math.max(1, Math.min(total, n));
    if (target !== activePage) {
        activePage = target;
        applyActiveThumbnail(true, true);
    } else {
        // Already on the target (e.g. ArrowUp at page 1) — keep it focused/visible.
        const cur = el.querySelector(`.thumbnail[data-page-number="${target}"]`);
        if (cur) {
            cur.scrollIntoView({ block: 'nearest', inline: 'nearest' });
            cur.focus();
        }
    }
}

/**
 * Composite-widget keyboard navigation (TASK-323). Arrow/Home/End move the
 * active thumbnail; Enter/Space are intentionally NOT handled here so the
 * focused button's native activation fires the existing click handler (same
 * path as a mouse click → jumps the viewer to that page).
 */
function onListKeyDown(e) {
    switch (e.key) {
        case 'ArrowDown':
        case 'ArrowRight':
            e.preventDefault();
            moveActiveThumbnail((activePage || 1) + 1);
            break;
        case 'ArrowUp':
        case 'ArrowLeft':
            e.preventDefault();
            moveActiveThumbnail((activePage || 1) - 1);
            break;
        case 'Home':
            e.preventDefault();
            moveActiveThumbnail(1);
            break;
        case 'End': {
            e.preventDefault();
            const el = ensureListEl();
            moveActiveThumbnail(el ? el.querySelectorAll('.thumbnail').length : 1);
            break;
        }
        default:
            break;
    }
}

/** (Re)build the IntersectionObserver over the freshly rendered pages. */
function attachPageObserver() {
    const scrollEl = document.querySelector('.pdf-viewer-inner');
    if (!scrollEl) return;
    if (pageObserver) pageObserver.disconnect();
    pageRatios.clear();

    pageObserver = new IntersectionObserver((entries) => {
        for (const entry of entries) {
            const num = Number(entry.target.dataset.pageNumber);
            if (num) pageRatios.set(num, entry.isIntersecting ? entry.intersectionRatio : 0);
        }
        // Most-visible page wins; ties resolve to the lower page number.
        let best = activePage || 1;
        let bestRatio = -1;
        for (const [num, ratio] of pageRatios) {
            if (ratio > bestRatio || (ratio === bestRatio && num < best)) {
                bestRatio = ratio;
                best = num;
            }
        }
        if (bestRatio > 0) setActiveThumbnail(best);
    }, {
        root: scrollEl,
        threshold: [0, 0.1, 0.25, 0.5, 0.75, 1],
    });

    document.querySelectorAll('.pdf-page[data-page-number]').forEach((el) => pageObserver.observe(el));
}

/** Tear down the observer and clear active state (RAM hygiene on PDF_CLEARED). */
function detachPageObserver() {
    if (pageObserver) pageObserver.disconnect();
    pageObserver = null;
    pageRatios.clear();
    activePage = 0;
}

function setPlaceholder(text) {
    const el = ensureListEl();
    if (!el) return;
    el.innerHTML = '';
    const p = document.createElement('p');
    p.className = 'thumbnails-empty';
    p.textContent = text;
    el.appendChild(p);
}

/** Scroll the rendered page with this 1-based number into view. */
function goToPage(pageNum) {
    const page = document.querySelector(`.pdf-page[data-page-number="${pageNum}"]`);
    if (page) page.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/** Build the (empty) button shell for one page; the canvas is filled in later. */
function createThumbButton(pageNum) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'thumbnail';
    btn.dataset.pageNumber = String(pageNum);
    btn.setAttribute('aria-label', `Go to page ${pageNum}`);
    // Roving tabindex: only the active page is tabbable; arrow keys move within.
    btn.tabIndex = pageNum === activePage ? 0 : -1;

    const canvas = document.createElement('canvas');
    canvas.className = 'thumbnail-canvas';
    btn.appendChild(canvas);

    const label = document.createElement('span');
    label.className = 'thumbnail-num';
    label.textContent = String(pageNum);
    btn.appendChild(label);

    // Click (and the native Enter/Space activation of the focused button) both
    // route through here, so mouse and keyboard share one path: jump the viewer
    // AND set the active highlight + roving tabindex immediately (the scroll
    // observer then confirms it once the page scrolls into view).
    btn.addEventListener('click', () => {
        goToPage(pageNum);
        if (pageNum !== activePage) {
            activePage = pageNum;
            applyActiveThumbnail(false, false);
        }
    });
    return { btn, canvas };
}

async function renderThumbnails({ doc, numPages }) {
    const el = ensureListEl();
    if (!el || !doc) return;

    const token = ++renderToken;
    const total = numPages != null ? numPages : doc.numPages;

    el.innerHTML = '';
    el.setAttribute('aria-busy', 'true');

    // A freshly loaded doc shows page 1 at the top; seed the highlight + roving
    // tabindex there so exactly one thumbnail is active/tabbable immediately
    // (the observer refines it as the user scrolls). Reset unconditionally so a
    // stale active page from a prior, longer document can't point past the end.
    activePage = 1;

    for (let pageNum = 1; pageNum <= total; pageNum++) {
        if (token !== renderToken) return; // a newer document superseded us

        const { btn, canvas } = createThumbButton(pageNum);
        el.appendChild(btn);
        if (pageNum === activePage) applyActiveThumbnail(false); // highlight as it appears

        try {
            const page = await doc.getPage(pageNum);
            if (token !== renderToken) return;

            const base = page.getViewport({ scale: 1 });
            const scale = THUMB_WIDTH / base.width;
            const viewport = page.getViewport({ scale });

            // Render at device-pixel resolution (capped) for crisp previews,
            // but keep the CSS size small to bound memory.
            const dpr = Math.min(window.devicePixelRatio || 1, 2);
            canvas.width = Math.floor(viewport.width * dpr);
            canvas.height = Math.floor(viewport.height * dpr);
            canvas.style.width = `${Math.floor(viewport.width)}px`;
            canvas.style.height = `${Math.floor(viewport.height)}px`;

            await page.render({
                canvasContext: canvas.getContext('2d'),
                viewport,
                transform: dpr !== 1 ? [dpr, 0, 0, dpr, 0, 0] : null,
            }).promise;
        } catch (err) {
            // A single failed page must not abort the rest of the strip.
            console.warn(`[thumbnails] page ${pageNum} render failed:`, err);
        }
    }

    if (token === renderToken) el.removeAttribute('aria-busy');
}

export function initThumbnails() {
    const el = ensureListEl();
    if (el) {
        // Composite widget: a labeled toolbar of page buttons navigated with the
        // arrow keys via roving tabindex (the container already carries
        // aria-label="Page thumbnails" in index.html).
        el.setAttribute('role', 'toolbar');
        el.setAttribute('aria-orientation', 'vertical');
        el.addEventListener('keydown', onListKeyDown);
    }

    setPlaceholder('Open a PDF to see page thumbnails.');

    EventBus.on(Events.PDF_LOADED, (payload) => {
        renderThumbnails(payload);
    });

    // Pages are (re)created on every render (initial load + zoom) — (re)arm the
    // observer against the fresh .pdf-page elements, mirroring page-nav.js.
    EventBus.on(Events.PDF_RENDERED, () => {
        attachPageObserver();
    });

    EventBus.on(Events.PDF_CLEARED, () => {
        renderToken++; // cancel any in-flight render loop
        detachPageObserver();
        setPlaceholder('Open a PDF to see page thumbnails.');
    });
}
