// page-nav.js — page navigator: current-page indicator, go-to-page input,
// prev/next buttons, and keyboard navigation.
//
// Purely additive (TASK-303). It does NOT modify viewer.js's rendering core.
// It subscribes to EventBus document events and reads the `.pdf-page
// [data-page-number]` elements that viewer.js already rendered, tracking the
// most-visible page with an IntersectionObserver rooted on the scroll
// container (`.pdf-viewer-inner`). Layout-safe: the nav bar is an app-shell
// element, never a flex-row child of `.pdf-viewer-container` (prompt rule 8).

import { EventBus, Events } from './event-bus.js';

let inputEl = null;     // #page-nav-input (editable current page)
let totalEl = null;     // #page-nav-total (TOTAL text)
let prevBtn = null;     // previous-page button
let nextBtn = null;     // next-page button
let scrollEl = null;    // .pdf-viewer-inner (IntersectionObserver root + key target)

let numPages = 0;
let currentPage = 1;
let observer = null;
const ratios = new Map(); // pageNumber -> latest intersection ratio

function cacheEls() {
    inputEl = document.getElementById('page-nav-input');
    totalEl = document.getElementById('page-nav-total');
    prevBtn = document.getElementById('page-nav-prev');
    nextBtn = document.getElementById('page-nav-next');
    scrollEl = document.querySelector('.pdf-viewer-inner');
}

/** Reflect current state into the controls (value, total, disabled, max). */
function updateDisplay() {
    if (totalEl) totalEl.textContent = String(numPages);
    if (inputEl) {
        inputEl.max = String(Math.max(numPages, 1));
        // Don't clobber what the user is actively typing.
        if (document.activeElement !== inputEl) inputEl.value = String(currentPage);
    }
    if (prevBtn) prevBtn.disabled = currentPage <= 1 || numPages === 0;
    if (nextBtn) nextBtn.disabled = currentPage >= numPages || numPages === 0;
}

/** Scroll the rendered page with the given 1-based number into view. */
function scrollToPage(pageNumber) {
    const page = document.querySelector(`.pdf-page[data-page-number="${pageNumber}"]`);
    if (page) page.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/** Navigate to a page, clamping into [1, numPages]; never scrolls out of bounds. */
function goToPage(n) {
    if (numPages === 0) return;
    const target = Math.max(1, Math.min(numPages, n));
    currentPage = target;
    scrollToPage(target);
    updateDisplay();
}

/** Set the current page from scroll observation — updates UI without scrolling. */
function setCurrentFromScroll(n) {
    if (n === currentPage) return;
    currentPage = n;
    updateDisplay();
}

/** Commit whatever is in the page input: navigate if numeric, else revert. */
function commitInput() {
    if (!inputEl) return;
    const raw = inputEl.value.trim();
    const parsed = Number.parseInt(raw, 10);
    if (Number.isNaN(parsed)) {
        // Non-numeric / empty — revert the field to the current page.
        inputEl.value = String(currentPage);
        return;
    }
    // Numeric: goToPage clamps into range, so 0, negatives and > TOTAL never
    // scroll out of bounds; the field is then resynced to the clamped page.
    goToPage(parsed);
    inputEl.value = String(currentPage);
}

/** (Re)build the IntersectionObserver over the freshly rendered pages. */
function attachObserver() {
    if (!scrollEl) return;
    if (observer) observer.disconnect();
    ratios.clear();

    observer = new IntersectionObserver((entries) => {
        for (const entry of entries) {
            const num = Number(entry.target.dataset.pageNumber);
            if (num) ratios.set(num, entry.isIntersecting ? entry.intersectionRatio : 0);
        }
        // Most-visible page wins; ties resolve to the lower page number.
        let best = currentPage;
        let bestRatio = -1;
        for (const [num, ratio] of ratios) {
            if (ratio > bestRatio || (ratio === bestRatio && num < best)) {
                bestRatio = ratio;
                best = num;
            }
        }
        if (bestRatio > 0) setCurrentFromScroll(best);
    }, {
        root: scrollEl,
        threshold: [0, 0.1, 0.25, 0.5, 0.75, 1],
    });

    document.querySelectorAll('.pdf-page[data-page-number]').forEach((el) => observer.observe(el));
}

function reset() {
    if (observer) observer.disconnect();
    observer = null;
    ratios.clear();
    numPages = 0;
    currentPage = 1;
    updateDisplay();
}

/** Keyboard navigation on the viewer (ignored while typing in a field). */
function onKeyDown(e) {
    if (numPages === 0) return;
    const t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;

    switch (e.key) {
        case 'PageDown':
        case 'ArrowDown':
            e.preventDefault();
            goToPage(currentPage + 1);
            break;
        case 'PageUp':
        case 'ArrowUp':
            e.preventDefault();
            goToPage(currentPage - 1);
            break;
        case 'Home':
            e.preventDefault();
            goToPage(1);
            break;
        case 'End':
            e.preventDefault();
            goToPage(numPages);
            break;
        default:
            break;
    }
}

export function initPageNav() {
    cacheEls();
    updateDisplay();

    if (prevBtn) prevBtn.addEventListener('click', () => goToPage(currentPage - 1));
    if (nextBtn) nextBtn.addEventListener('click', () => goToPage(currentPage + 1));

    if (inputEl) {
        inputEl.addEventListener('change', commitInput);
        inputEl.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                commitInput();
                inputEl.blur();
            }
        });
    }

    if (scrollEl) scrollEl.addEventListener('keydown', onKeyDown);

    EventBus.on(Events.PDF_LOADED, ({ numPages: n }) => {
        numPages = n || 0;
        currentPage = 1;
        updateDisplay();
    });

    // Pages are (re)created on every render (load + zoom) — rebind the observer.
    EventBus.on(Events.PDF_RENDERED, () => {
        attachObserver();
        updateDisplay();
    });

    EventBus.on(Events.PDF_CLEARED, reset);
}

export default initPageNav;
