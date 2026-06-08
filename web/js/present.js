// present.js — full-screen presentation / distraction-free viewing mode.
//
// Purely additive: registers a `present.toggle` action (the View-panel
// "Present" button uses it via data-action) that puts the PDF viewing area
// into the browser's native full-screen, hiding all app chrome for a clean,
// reader-/projector-friendly view. Escape (handled natively by the browser)
// or the button exits.
//
// Design notes:
//  - Does NOT touch viewer.js's rendering core, the upload pipeline, or the
//    .pdf-viewer-container flex-row contract — it only requests/exits
//    fullscreen on that element and toggles a body class for styling.
//  - State is driven by the real `fullscreenchange` event, not by our own
//    bookkeeping, so the button stays correct even when the user presses
//    Escape or exits fullscreen by other means.
//  - Vendor-prefixed (webkit) fallbacks are included for older engines; modern
//    Chrome/Firefox use the standard API.
//  - All text via textContent; no innerHTML, no inline script (CSP-safe).

import { ActionRegistry } from './action-registry.js';
import { EventBus, Events } from './event-bus.js';

let containerEl = null; // .pdf-viewer-container — the element we make fullscreen
let buttonEl = null;    // #present-toggle — the View-panel button

/** The element currently in fullscreen, if any (standard + webkit). */
function fullscreenElement() {
    return document.fullscreenElement || document.webkitFullscreenElement || null;
}

function requestFullscreen(el) {
    if (el.requestFullscreen) return el.requestFullscreen();
    if (el.webkitRequestFullscreen) return el.webkitRequestFullscreen();
    return Promise.reject(new Error('Fullscreen API unavailable'));
}

function exitFullscreen() {
    if (document.exitFullscreen) return document.exitFullscreen();
    if (document.webkitExitFullscreen) return document.webkitExitFullscreen();
    return Promise.resolve();
}

/** Is the viewer the element currently presented full-screen? */
function isPresenting() {
    return !!containerEl && fullscreenElement() === containerEl;
}

/** Sync the button label/ARIA and the body class to the real fullscreen state. */
function syncState() {
    const presenting = isPresenting();
    document.body.classList.toggle('is-presenting', presenting);
    if (buttonEl) {
        buttonEl.setAttribute('aria-pressed', String(presenting));
        const label = presenting ? 'Exit full screen' : 'Present';
        buttonEl.textContent = label;
        buttonEl.setAttribute('aria-label', label);
    }
}

/** Toggle presentation mode. Returns a promise so callers can await it. */
async function toggle() {
    if (!containerEl) return;
    try {
        if (isPresenting()) {
            await exitFullscreen();
        } else {
            await requestFullscreen(containerEl);
        }
    } catch (err) {
        // Fullscreen can be blocked (no user gesture, permissions policy,
        // unsupported engine). Tell the user rather than failing silently.
        console.error('[present] fullscreen toggle failed:', err);
        EventBus.emit(Events.ERROR, {
            message: 'Full-screen presentation is not available in this browser.',
            error: err,
        });
    }
}

export function initPresent() {
    containerEl = document.querySelector('.pdf-viewer-container');
    buttonEl = document.getElementById('present-toggle');

    ActionRegistry.register('present.toggle', {
        title: 'Toggle full-screen presentation',
        run: () => toggle(),
    });

    // Drive UI state from the real fullscreen lifecycle (covers Escape / F11 / etc.).
    document.addEventListener('fullscreenchange', syncState);
    document.addEventListener('webkitfullscreenchange', syncState);

    syncState();
}

export default initPresent;
