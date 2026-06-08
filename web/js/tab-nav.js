// tab-nav.js — keyboard navigation for the tool tablist (WAI-ARIA Tabs pattern).
//
// Completes the keyboard half of the tablist that wireToolTabs() (app.js) already
// drives by mouse: a roving tabindex (the tablist is one Tab stop) plus
// ArrowLeft/ArrowRight/Home/End navigation with automatic activation.
//
// It does NOT own panel activation — activation goes through the existing click
// path (tab.click()), so aria-selected / .active toggling stays in one place
// (wireToolTabs). This module only manages focus order and key handling.
//
// IMPORTANT: initTabNav() must be called AFTER wireToolTabs() in app.js so that the
// roving-tabindex sync (registered as a click listener here) runs after
// wireToolTabs has updated aria-selected.

export function initTabNav() {
    const tablist = document.querySelector('.tool-tabs[role="tablist"]');
    if (!tablist) return;
    const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
    if (!tabs.length) return;

    // Roving tabindex: the currently-selected tab is the single Tab stop (0),
    // every other tab is removed from the sequence (-1). Source of truth is the
    // aria-selected state that wireToolTabs maintains.
    function syncRoving() {
        tabs.forEach((tab) => {
            tab.tabIndex = tab.getAttribute('aria-selected') === 'true' ? 0 : -1;
        });
    }

    // Activate a tab via the existing click path, then move focus to it.
    // tab.click() fires wireToolTabs' handler (panel + aria-selected) and then
    // this module's click listener (syncRoving), so focus lands on a tab whose
    // tabindex is already 0.
    function activate(tab) {
        tab.click();
        tab.focus();
    }

    tablist.addEventListener('keydown', (e) => {
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        const current = tabs.indexOf(document.activeElement);
        if (current === -1) return; // focus isn't on one of the tabs

        let nextIndex;
        switch (e.key) {
            case 'ArrowRight':
                nextIndex = (current + 1) % tabs.length;
                break;
            case 'ArrowLeft':
                nextIndex = (current - 1 + tabs.length) % tabs.length;
                break;
            case 'Home':
                nextIndex = 0;
                break;
            case 'End':
                nextIndex = tabs.length - 1;
                break;
            default:
                return; // Enter/Space are handled natively by the <button>
        }
        e.preventDefault(); // stop the page from scrolling on the handled keys
        activate(tabs[nextIndex]);
    });

    // Keep the roving tabindex correct for mouse activation too. Registered after
    // wireToolTabs' click handler (because initTabNav runs after wireToolTabs), so
    // aria-selected is already current when this reads it.
    tabs.forEach((tab) => tab.addEventListener('click', syncRoving));

    // Initialize from whichever tab currently has aria-selected="true".
    syncRoving();
}
