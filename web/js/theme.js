// theme.js — light / dark theme switcher.
//
// The whole app is themed through CSS custom properties on :root (see main.css),
// so switching themes is just toggling a `data-theme` attribute on <html> and
// letting `:root[data-theme="light"]` override the design tokens. Fully additive:
// no event-bus, no dependency on PDF state, no inline <script> (CSP forbids it).

const STORAGE_KEY = 'pdf-editor-theme';
const root = document.documentElement;

/** @returns {'light'|'dark'} */
function storedTheme() {
    try {
        const v = localStorage.getItem(STORAGE_KEY);
        return v === 'light' || v === 'dark' ? v : null;
    } catch {
        // localStorage can throw in private mode / when storage is blocked.
        return null;
    }
}

/** @returns {'light'|'dark'} the system preference, defaulting to dark. */
function systemTheme() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches
        ? 'light'
        : 'dark';
}

/** Resolve the theme to use: explicit choice wins, else system preference. */
function resolveTheme() {
    return storedTheme() || systemTheme();
}

function applyTheme(theme) {
    root.dataset.theme = theme;
}

// Apply as early as possible (at import time, before init wiring) to minimise the
// flash for users whose chosen/preferred theme differs from the dark default.
applyTheme(resolveTheme());

/** Update the toggle button's label, icon and aria state for the active theme. */
function syncButton(btn, theme) {
    const isLight = theme === 'light';
    // Pressed = "light is on" (the non-default theme).
    btn.setAttribute('aria-pressed', String(isLight));
    // The label/aria-label describe the action the button performs.
    btn.setAttribute('aria-label', isLight ? 'Switch to dark theme' : 'Switch to light theme');
    const icon = btn.querySelector('.theme-toggle-icon');
    const label = btn.querySelector('.theme-toggle-label');
    if (icon) icon.textContent = isLight ? '☀' : '☾';
    if (label) label.textContent = isLight ? 'Light' : 'Dark';
}

export function initTheme() {
    const btn = document.getElementById('theme-toggle');
    if (!btn) return;

    let theme = resolveTheme();
    applyTheme(theme);
    syncButton(btn, theme);

    btn.addEventListener('click', () => {
        theme = theme === 'light' ? 'dark' : 'light';
        applyTheme(theme);
        syncButton(btn, theme);
        try {
            localStorage.setItem(STORAGE_KEY, theme);
        } catch {
            // Non-fatal: theme still applies for this session, just not persisted.
        }
    });

    // Follow the OS preference live, but only while the user hasn't pinned a choice.
    if (window.matchMedia) {
        const mq = window.matchMedia('(prefers-color-scheme: light)');
        const onChange = (e) => {
            if (storedTheme()) return; // explicit choice wins
            theme = e.matches ? 'light' : 'dark';
            applyTheme(theme);
            syncButton(btn, theme);
        };
        if (mq.addEventListener) mq.addEventListener('change', onChange);
        else if (mq.addListener) mq.addListener(onChange); // older browsers
    }
}

export default initTheme;
