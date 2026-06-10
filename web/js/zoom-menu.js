// zoom-menu.js — turns the passive #zoom-level percentage indicator into an
// accessible dropdown menu of zoom presets (TASK-332).
//
// It is layout-isolated: it lives entirely in the View-panel toolbar, never
// touches the viewer render core, #pdf-pages geometry, .pdf-viewer-container
// layout, or the upload pipeline. It communicates only through viewer.js's
// public API (setScale) and the ActionRegistry (fit-width/fit-page/actual-size
// actions registered in app.js), and listens to the EventBus for enable/disable
// and the current-percent aria-label. The #zoom-level button text itself is
// kept in sync by app.js's existing ZOOM_CHANGED listener (wireZoomLabel).
//
// The trigger keeps id="zoom-level" so that existing listener keeps working; we
// only add the popup behaviour, aria wiring, and the disabled state here.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import * as Viewer from './viewer.js';

// Menu entries. 'action' routes through the ActionRegistry (registered in
// app.js); 'scale' calls viewer.setScale directly with an exact factor; 'sep'
// is a non-focusable visual divider.
const ENTRIES = [
    { type: 'action', action: 'viewer.fitWidth', label: 'Fit width' },
    { type: 'action', action: 'viewer.fitPage', label: 'Fit page' },
    { type: 'action', action: 'viewer.actualSize', label: 'Actual size (100%)' },
    { type: 'sep' },
    { type: 'scale', scale: 0.5, label: '50%' },
    { type: 'scale', scale: 0.75, label: '75%' },
    { type: 'scale', scale: 1.0, label: '100%' },
    { type: 'scale', scale: 1.25, label: '125%' },
    { type: 'scale', scale: 1.5, label: '150%' },
    { type: 'scale', scale: 2.0, label: '200%' },
    { type: 'scale', scale: 3.0, label: '300%' },
];

let trigger = null;   // #zoom-level <button>
let listEl = null;    // role="menu" container
let items = [];       // focusable menuitem <button>s, in DOM order
let isOpen = false;
let hasDoc = false;

function setOpen(state) {
    // Guard: never open while disabled / no document loaded.
    if (state && (!trigger || trigger.disabled || !hasDoc)) return;
    if (state === isOpen) return;
    isOpen = state;
    listEl.hidden = !state;
    trigger.setAttribute('aria-expanded', String(state));
    if (state) {
        document.addEventListener('pointerdown', onOutsidePointer, true);
        focusItem(0);
    } else {
        document.removeEventListener('pointerdown', onOutsidePointer, true);
    }
}

function focusItem(i) {
    if (!items.length) return;
    const idx = (i + items.length) % items.length;
    items[idx].focus();
}

function currentIndex() {
    return items.indexOf(document.activeElement);
}

function activate(entry) {
    // Run the selection, then close and return focus to the trigger so the
    // keyboard user lands somewhere sensible.
    try {
        if (entry.type === 'action') {
            ActionRegistry.run(entry.action);
        } else if (entry.type === 'scale') {
            Viewer.setScale(entry.scale);
        }
    } catch (err) {
        // A guarded no-op must never surface as an exception.
        console.warn('[zoom-menu] action failed:', err);
    }
    setOpen(false);
    trigger.focus();
}

function onOutsidePointer(e) {
    const root = trigger.closest('.zoom-menu');
    if (root && !root.contains(e.target)) setOpen(false);
}

function onTriggerKeydown(e) {
    switch (e.key) {
        case 'ArrowDown':
        case 'Enter':
        case ' ':
        case 'Spacebar':
            e.preventDefault();
            setOpen(true);
            focusItem(0);
            break;
        case 'ArrowUp':
            e.preventDefault();
            setOpen(true);
            focusItem(items.length - 1);
            break;
        default:
            break;
    }
}

function onListKeydown(e) {
    switch (e.key) {
        case 'ArrowDown':
            e.preventDefault();
            focusItem(currentIndex() + 1);
            break;
        case 'ArrowUp':
            e.preventDefault();
            focusItem(currentIndex() - 1);
            break;
        case 'Home':
            e.preventDefault();
            focusItem(0);
            break;
        case 'End':
            e.preventDefault();
            focusItem(items.length - 1);
            break;
        case 'Escape':
            e.preventDefault();
            setOpen(false);
            trigger.focus();
            break;
        case 'Tab':
            // Let focus leave naturally, but collapse the menu behind it.
            setOpen(false);
            break;
        default:
            break;
    }
}

function buildMenu() {
    items = [];
    listEl.textContent = '';
    for (const entry of ENTRIES) {
        const li = document.createElement('li');
        if (entry.type === 'sep') {
            li.className = 'zoom-menu__sep';
            li.setAttribute('role', 'separator');
        } else {
            li.setAttribute('role', 'none');
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'zoom-menu__item';
            btn.setAttribute('role', 'menuitem');
            btn.tabIndex = -1;
            btn.textContent = entry.label; // static developer strings, but never innerHTML
            btn.addEventListener('click', () => activate(entry));
            li.appendChild(btn);
            items.push(btn);
        }
        listEl.appendChild(li);
    }
}

function setEnabled(enabled) {
    hasDoc = enabled;
    if (!trigger) return;
    trigger.disabled = !enabled;
    trigger.setAttribute('aria-disabled', String(!enabled));
    if (!enabled) setOpen(false);
}

function syncLabel(scale) {
    if (!trigger) return;
    trigger.setAttribute('aria-label', `Zoom level, currently ${Math.round(scale * 100)}%`);
}

export function initZoomMenu() {
    trigger = document.getElementById('zoom-level');
    listEl = document.getElementById('zoom-menu-list');
    if (!trigger || !listEl) return; // markup absent — degrade gracefully

    buildMenu();

    trigger.addEventListener('click', () => setOpen(!isOpen));
    trigger.addEventListener('keydown', onTriggerKeydown);
    listEl.addEventListener('keydown', onListKeydown);

    // Start disabled until a PDF is loaded; keep the current-percent aria-label
    // fresh alongside app.js's textContent listener.
    setEnabled(false);
    syncLabel(Viewer.getScale());
    EventBus.on(Events.ZOOM_CHANGED, ({ scale }) => syncLabel(scale));
    EventBus.on(Events.PDF_LOADED, ({ numPages }) => setEnabled((numPages || 0) > 0));
    EventBus.on(Events.PDF_CLEARED, () => setEnabled(false));
}
