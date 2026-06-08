// notifications.js — accessible toast feedback for the upload/render lifecycle.
//
// Purely additive feedback layer: subscribes to existing EventBus events and
// renders transient on-screen toasts so the product *tells the user what
// happened* (a rejected upload or a slow load is no longer silent).
//
// Accessibility: toasts live inside two persistent ARIA live regions —
// info/success in a polite role="status" region, errors in an assertive
// role="alert" region — so screen readers announce them. Every dismiss button
// has an accessible name. All message text is inserted via textContent only
// (never innerHTML) — file-supplied values like a filename are untrusted
// (security rule 4).
//
// RAM hygiene (1.6 GiB box): concurrent toasts are capped and DOM nodes are
// removed on dismiss/auto-clear so nothing accumulates.

import { EventBus, Events } from './event-bus.js';

const MAX_TOASTS = 4;          // cap concurrent toasts (oldest evicted past this)
const AUTO_DISMISS_MS = 4000;  // info/success auto-clear; errors persist

let container = null;       // #toast-container
let politeRegion = null;    // role="status"  aria-live="polite"  (info/success)
let assertiveRegion = null; // role="alert"   aria-live="assertive" (errors)
let loadingToast = null;    // the in-progress "Loading …" toast, if any

const ICONS = { info: 'ℹ', success: '✓', error: '⚠' };

/** Remove a toast node and clear its auto-dismiss timer. Safe to call twice. */
function removeToast(toast) {
    if (!toast) return;
    if (toast._timer) {
        clearTimeout(toast._timer);
        toast._timer = null;
    }
    if (toast === loadingToast) loadingToast = null;
    toast.remove();
}

/** Evict the oldest toasts once we exceed the concurrency cap (RAM hygiene). */
function trimToasts() {
    if (!container) return;
    const toasts = container.querySelectorAll('.toast');
    for (let i = 0; i < toasts.length - MAX_TOASTS; i++) {
        removeToast(toasts[i]);
    }
}

/**
 * Build a toast element. Text is set via textContent only.
 * @param {'info'|'success'|'error'} type
 * @param {string} message
 */
function makeToast(type, message) {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const icon = document.createElement('span');
    icon.className = 'toast-icon';
    icon.setAttribute('aria-hidden', 'true');
    icon.textContent = ICONS[type] || ICONS.info;

    const text = document.createElement('span');
    text.className = 'toast-msg';
    text.textContent = message; // untrusted content is safe via textContent

    const dismiss = document.createElement('button');
    dismiss.type = 'button';
    dismiss.className = 'toast-dismiss';
    dismiss.setAttribute('aria-label', 'Dismiss');
    dismiss.textContent = '×'; // ×
    dismiss.addEventListener('click', () => removeToast(toast));

    toast.append(icon, text, dismiss);
    return toast;
}

/**
 * Show a toast.
 * @param {'info'|'success'|'error'} type
 * @param {string} message
 * @param {{persist?: boolean}} [opts] persist=true skips auto-dismiss.
 * @returns {HTMLElement|null}
 */
function showToast(type, message, { persist = false } = {}) {
    const region = type === 'error' ? assertiveRegion : politeRegion;
    if (!region) return null;

    const toast = makeToast(type, message);
    region.appendChild(toast);
    trimToasts();

    // Errors always persist until dismissed; info/success auto-clear unless asked to persist.
    if (type !== 'error' && !persist) {
        toast._timer = setTimeout(() => removeToast(toast), AUTO_DISMISS_MS);
    }
    return toast;
}

export function initNotifications() {
    container = document.getElementById('toast-container');
    politeRegion = container?.querySelector('.toast-region--polite') || null;
    assertiveRegion = container?.querySelector('.toast-region--assertive') || null;
    if (!container || !politeRegion || !assertiveRegion) {
        console.warn('[notifications] toast container missing; feedback disabled');
        return;
    }

    // Loading started — show a persistent progress toast we replace on resolve.
    EventBus.on(Events.PDF_LOADING, ({ name } = {}) => {
        if (loadingToast) removeToast(loadingToast);
        loadingToast = showToast('info', `Loading ${name || 'PDF'}…`, { persist: true });
    });

    // Loaded OK — clear the loading toast, confirm success (auto-dismisses).
    EventBus.on(Events.PDF_LOADED, ({ name } = {}) => {
        if (loadingToast) removeToast(loadingToast);
        showToast('success', `Loaded ${name || 'PDF'}`);
    });

    // Failure on any path (bad type / too large / empty / corrupt) — clear the
    // loading toast and show a persistent, human-readable error.
    EventBus.on(Events.ERROR, ({ message } = {}) => {
        if (loadingToast) removeToast(loadingToast);
        showToast('error', message || 'Something went wrong. Please try again.');
    });
}

export default initNotifications;
