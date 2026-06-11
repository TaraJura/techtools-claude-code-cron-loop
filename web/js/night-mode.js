// night-mode.js — eye-comfort "night / invert" reading mode for the rendered PDF.
//
// Purely VISUAL and view-only: toggles a single CSS class (`.night-mode`) on the
// #pdf-pages container whose rule is `filter: invert(1) hue-rotate(180deg)` (defined
// in css/viewer.css). White page backgrounds become dark while photos/colours keep a
// roughly-true hue (the classic invert+hue-rotate trick). Nothing is re-rendered,
// uploaded, downloaded, or mutated — pdf.js and page geometry are untouched, so the
// filter never changes #pdf-pages width or the canvas count.
//
// Distinct from theme.js: theme.js themes the app CHROME (header/panels) via a
// `data-theme` attribute on <html>; night mode inverts only the PDF PAGE pixels.
//
// State persists across reloads via localStorage (key `pdf-night-mode`). Because the
// page list is rebuilt on every load, we re-assert the class on PDF_LOADED so newly
// rendered pages inherit the filter (the #pdf-pages element itself keeps its class,
// but re-asserting is cheap and robust if the container is ever recreated).

import { EventBus, Events } from './event-bus.js';

const STORAGE_KEY = 'pdf-night-mode';

let enabled = false;
let pagesEl = null;
let btn = null;

/** @returns {boolean} the persisted preference (default off). */
function storedEnabled() {
    try {
        return localStorage.getItem(STORAGE_KEY) === 'on';
    } catch {
        // localStorage can throw in private mode / when storage is blocked.
        return false;
    }
}

function persist(on) {
    try {
        localStorage.setItem(STORAGE_KEY, on ? 'on' : 'off');
    } catch {
        // Non-fatal: state still applies for this session, just not persisted.
    }
}

/** Add/remove the visual-only filter class on the pages container. */
function applyToPages() {
    if (!pagesEl) pagesEl = document.getElementById('pdf-pages');
    if (pagesEl) pagesEl.classList.toggle('night-mode', enabled);
}

/** Keep the toggle button's icon/label/aria state in sync with `enabled`. */
function syncButton() {
    if (!btn) return;
    btn.setAttribute('aria-pressed', String(enabled));
    // Label describes the current state; pressed conveys the toggle is on.
    btn.setAttribute('aria-label', enabled ? 'Night mode (on)' : 'Night mode');
    const icon = btn.querySelector('.header-btn-icon');
    const label = btn.querySelector('.header-btn-label');
    // ☀ = "currently inverted/dark page, click to turn off"; ☾ = "click to turn on".
    if (icon) icon.textContent = enabled ? '☀' : '☾';
    if (label) label.textContent = enabled ? 'Day' : 'Night';
}

export function initNightMode() {
    btn = document.getElementById('night-mode-toggle');
    pagesEl = document.getElementById('pdf-pages');

    enabled = storedEnabled();
    applyToPages();
    syncButton();

    if (btn) {
        btn.addEventListener('click', () => {
            enabled = !enabled;
            applyToPages();
            syncButton();
            persist(enabled);
        });
    }

    // Re-assert the class whenever a new document finishes loading so freshly
    // rendered pages inherit the filter (view-only — never re-renders pdf.js).
    EventBus.on(Events.PDF_LOADED, applyToPages);
}

export default initNightMode;
