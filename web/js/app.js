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
import { initAnnotationSummary } from './annotation-summary.js';
import { initSplit } from './split.js';
import { initDeletePages } from './delete-pages.js';
import { initExtractPages } from './extract-pages.js';
import { initReversePages } from './reverse-pages.js';
import { initDuplicatePages } from './duplicate-pages.js';
import { initNup } from './nup.js';
import { initBooklet } from './booklet.js';
import { initMargins } from './margins.js';
import { initFlipPages } from './flip-pages.js';
import { initBurst } from './burst.js';
import { initSplitChunks } from './split-chunks.js';
import { initFlatten } from './flatten.js';
import { initAttachments } from './attachments.js';
import { initPrint } from './print.js';
import { initPages } from './pages.js';
import { initMerge } from './merge.js';
import { initInterleave } from './interleave.js';
import { initWatermark } from './watermark.js';
import { initPageNumbers } from './page-numbers.js';
import { initHeadersFooters } from './headers-footers.js';
import { initBates } from './bates.js';
import { initConvert } from './convert.js';
import { initImg2Pdf } from './img2pdf.js';
import { initCompress } from './compress.js';
import { initCrop } from './crop.js';
import { initInsertPages } from './insert-pages.js';
import { initPageResize } from './page-resize.js';
import { initBgBorders } from './bg-borders.js';
import { initZoomMenu } from './zoom-menu.js';
import { initStatistics } from './statistics.js';
import { initFontInspector } from './font-inspector.js';
import { initLinks } from './links.js';
import { initPermissions } from './permissions.js';
import { initJsInspector } from './js-inspector.js';
import { initSanitize } from './sanitize.js';
import { initImageManager } from './image-manager.js';
import { initNightMode } from './night-mode.js';
import { initTextExtract } from './text-extract.js';
import { initCommandPalette } from './command-palette.js';
import * as Viewer from './viewer.js';

// --- Register core viewer actions in the central registry ---
// `shortcut` hints mirror the real bindings in viewer.js / keyboard-shortcuts.js
// so the command palette and the shortcuts reference card never disagree.
ActionRegistry.register('viewer.zoomIn', { title: 'Zoom in', shortcut: '+', run: () => Viewer.zoomIn() });
ActionRegistry.register('viewer.zoomOut', { title: 'Zoom out', shortcut: '−', run: () => Viewer.zoomOut() });
ActionRegistry.register('viewer.fitWidth', { title: 'Fit width', shortcut: '0', run: () => Viewer.fitWidth() });
ActionRegistry.register('viewer.fitPage', { title: 'Fit page', run: () => Viewer.fitPage() });
ActionRegistry.register('viewer.actualSize', { title: 'Actual size (100%)', run: () => Viewer.actualSize() });
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
    const tabs = [...document.querySelectorAll('.tool-tab')];
    const panels = [...document.querySelectorAll('.tool-panel')];

    // Single source of truth for "show this tool's panel" — used by both the
    // toolbar click handler and the registry action (so the command palette
    // opens a tool exactly the way clicking its tab does).
    function activateTab(target) {
        const tab = tabs.find((t) => t.dataset.tab === target);
        if (!tab) return;
        tabs.forEach((t) => t.classList.toggle('active', t === tab));
        tabs.forEach((t) => t.setAttribute('aria-selected', String(t === tab)));
        panels.forEach((p) => p.classList.toggle('active', p.dataset.panel === target));
    }

    tabs.forEach((tab) => {
        const target = tab.dataset.tab;
        tab.addEventListener('click', () => activateTab(target));
        // Expose each tool tab to the central registry so the command palette
        // surfaces it automatically (title = the tab's visible label).
        ActionRegistry.register(`tab.${target}`, {
            title: tab.textContent.trim(),
            run: () => activateTab(target),
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
    Viewer.initViewerKeys(); // keyboard zoom (+/-/0) + Space scroll — nav keys are page-nav.js's
    initPresent();
    initAnnotate();
    initAnnotationSummary();
    initSplit();
    initDeletePages(); // remove a set of pages, keep + download the rest (TASK-347)
    initExtractPages(); // keep an arbitrary, possibly-reordered set of pages (TASK-348)
    initReversePages(); // flip the open PDF back-to-front and download (TASK-350)
    initDuplicatePages(); // clone selected pages in place, N copies each (TASK-351)
    initNup(); // tile 2/4 source pages per output sheet (imposition) (TASK-353)
    initBooklet(); // saddle-stitch imposition for print-and-fold booklets (TASK-355)
    initMargins(); // enlarge each page with blank whitespace / binding gutter (TASK-354)
    initFlipPages(); // horizontally/vertically mirror chosen pages (TASK-356)
    initBurst(); // explode the PDF into one single-page PDF per page → ZIP (TASK-357)
    initSplitChunks(); // break the PDF into consecutive N-page parts → ZIP (TASK-358)
    initFlatten(); // bake interactive form fields into static page content (TASK-359)
    initAttachments(); // manage embedded file attachments (add / list / extract) (TASK-360)
    initPrint(); // print the original loaded PDF bytes via a hidden iframe (TASK-352)
    initPages();
    initMerge();
    initInterleave(); // zipper-merge the open PDF with a second PDF, A1,B1,A2,B2… (TASK-349)
    initWatermark();
    initPageNumbers();
    initHeadersFooters(); // custom running header/footer text in six zones (TASK-342)
    initBates();
    initConvert();
    initImg2Pdf(); // assemble a PDF from JPEG/PNG images (TASK-346)
    initCompress(); // shrink the open PDF client-side: re-save + rasterize (TASK-344)
    initCrop(); // trim a uniform margin off every page (TASK-335)
    initInsertPages(); // insert blank pages at a chosen position (TASK-337)
    initPageResize(); // normalize every page to a standard paper size (TASK-336)
    initBgBorders(); // paint a page background fill and/or stroke a page border (TASK-344)
    initZoomMenu(); // zoom preset dropdown on #zoom-level (TASK-332)
    initStatistics(); // read-only document analytics panel (statistics.js)
    initFontInspector(); // read-only font inspector — lists fonts + embedded status (TASK-361)
    initLinks(); // read-only links inspector — enumerates link annotations (TASK-363)
    initPermissions(); // read-only security inspector — encryption + permission flags (TASK-362)
    initJsInspector(); // read-only JavaScript & automatic-actions inspector (TASK-364)
    initSanitize(); // strip JS / auto-actions / embedded files → cleaned copy download (TASK-365)
    initImageManager(); // read-only image inspector — catalogs embedded image XObjects (TASK-366)
    initNightMode(); // view-only invert/night reading mode for the PDF pages (TASK-341)
    initTextExtract(); // extract all text to a downloadable .txt (text-extract.js, TASK-343)
    initKeyboardShortcuts();
    wireToolbar();
    wireZoomLabel();
    wireToolTabs();
    initTabNav(); // keyboard nav for the tablist — MUST run after wireToolTabs()
    initCommandPalette(); // Ctrl/⌘+K quick action runner (TASK-345)

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
