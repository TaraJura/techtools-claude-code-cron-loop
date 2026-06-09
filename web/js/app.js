// app.js — bootstrap & wiring. Loaded as the single module entry point.

import { EventBus, Events } from './event-bus.js';
import { ActionRegistry } from './action-registry.js';
import { initUpload } from './upload.js';
import { initToc } from './toc.js';
import { initSearch } from './search.js';
import { initMetadata } from './metadata.js';
import { initThumbnails } from './thumbnails.js';
import { initPageNav } from './page-nav.js';
import { initNotifications } from './notifications.js';
import { initTheme } from './theme.js';
import { initPresent } from './present.js';
import { initKeyboardShortcuts } from './keyboard-shortcuts.js';
import { initTabNav } from './tab-nav.js';
import { initAnnotate } from './annotate.js';
import { initSplit } from './split.js';
import { initMerge } from './merge.js';
import * as Viewer from './viewer.js';

// --- Register core viewer actions in the central registry ---
ActionRegistry.register('viewer.zoomIn', { title: 'Zoom in', run: () => Viewer.zoomIn() });
ActionRegistry.register('viewer.zoomOut', { title: 'Zoom out', run: () => Viewer.zoomOut() });
ActionRegistry.register('viewer.fitWidth', { title: 'Fit width', run: () => Viewer.fitWidth() });
ActionRegistry.register('viewer.clear', {
    title: 'Close document',
    run: () => {
        Viewer.clear();
        document.body.classList.remove('has-document');
    },
});

function wireToolbar() {
    document.querySelectorAll('[data-action]').forEach((btn) => {
        btn.addEventListener('click', () => ActionRegistry.run(btn.dataset.action));
    });
}

function wireZoomLabel() {
    const label = document.getElementById('zoom-level');
    if (!label) return;
    const update = ({ scale }) => {
        label.textContent = `${Math.round(scale * 100)}%`;
    };
    EventBus.on(Events.ZOOM_CHANGED, update);
    update({ scale: Viewer.getScale() });
}

function wireToolTabs() {
    const tabs = document.querySelectorAll('.tool-tab');
    const panels = document.querySelectorAll('.tool-panel');
    tabs.forEach((tab) => {
        tab.addEventListener('click', () => {
            const target = tab.dataset.tab;
            tabs.forEach((t) => t.classList.toggle('active', t === tab));
            tabs.forEach((t) => t.setAttribute('aria-selected', String(t === tab)));
            panels.forEach((p) => p.classList.toggle('active', p.dataset.panel === target));
        });
    });
}

function init() {
    initTheme();
    initNotifications();
    initUpload();
    initToc();
    initSearch();
    initMetadata();
    initThumbnails();
    initPageNav();
    initPresent();
    initAnnotate();
    initSplit();
    initMerge();
    initKeyboardShortcuts();
    wireToolbar();
    wireZoomLabel();
    wireToolTabs();
    initTabNav(); // keyboard nav for the tablist — MUST run after wireToolTabs()

    EventBus.on(Events.PDF_RENDERED, ({ numPages }) => {
        console.info(`[app] rendered ${numPages} page(s)`);
    });

    console.info('[app] PDF Editor initialized');
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
