// command-palette.js — Ctrl/⌘+K quick action runner (TASK-345).
//
// A single keyboard-driven way to discover and run ANY tool in the editor.
// It is purely a VIEW over js/action-registry.js — it never hard-codes a
// command list, so it stays automatically in sync as new tools register
// actions (tool-tab "open" actions + each tool's operation verbs).
//
// CSP-safe: external module only, no inline <script>; every bit of text is set
// via textContent (never innerHTML). The overlay DOM is built once on first
// open (lazy) and toggled thereafter. Uses a native <dialog> + showModal() so
// modal semantics, the Tab focus-trap and Escape-to-close come for free.

import { ActionRegistry } from './action-registry.js';

const LIST_ID = 'command-palette-list';
const OPT_PREFIX = 'command-palette-opt-';

let dialogEl = null;     // the <dialog>
let inputEl = null;      // search <input role="combobox">
let listEl = null;       // results <ul role="listbox">
let statusEl = null;     // aria-live result-count announcer
let emptyEl = null;      // "No matching commands" message
let openerEl = null;     // element focused before opening (for focus restore)

let matches = [];        // current filtered [{id,title,shortcut}]
let activeIndex = -1;    // index into `matches` of the highlighted option

/** Subsequence (fuzzy) test: do all chars of `q` appear in order within `s`? */
function fuzzyMatch(query, title) {
    const q = query.toLowerCase();
    const s = title.toLowerCase();
    if (q === '') return true;
    if (s.includes(q)) return true; // substring → always matches (and ranks first)
    let qi = 0;
    for (let si = 0; si < s.length && qi < q.length; si++) {
        if (s[si] === q[qi]) qi++;
    }
    return qi === q.length;
}

/** All registered commands, sorted by title (stable, predictable order). */
function allCommands() {
    return ActionRegistry.list().sort((a, b) =>
        a.title.localeCompare(b.title, undefined, { sensitivity: 'base' }));
}

/** Build one <li role="option">. */
function buildOption(cmd, index) {
    const li = document.createElement('li');
    li.className = 'command-palette__option';
    li.id = OPT_PREFIX + index;
    li.setAttribute('role', 'option');
    li.setAttribute('aria-selected', 'false');

    const title = document.createElement('span');
    title.className = 'command-palette__option-title';
    title.textContent = cmd.title;
    li.appendChild(title);

    if (cmd.shortcut) {
        const kbd = document.createElement('kbd');
        kbd.className = 'command-palette__option-shortcut';
        kbd.textContent = cmd.shortcut;
        li.appendChild(kbd);
    }

    // Hover highlights, click runs — same code path as keyboard select.
    li.addEventListener('mousemove', () => setActive(index));
    li.addEventListener('click', () => runActive());
    return li;
}

/** Re-render the result list for the current query. */
function render() {
    const query = inputEl.value.trim();
    matches = allCommands().filter((cmd) => fuzzyMatch(query, cmd.title));

    listEl.replaceChildren();
    matches.forEach((cmd, i) => listEl.appendChild(buildOption(cmd, i)));

    const count = matches.length;
    emptyEl.hidden = count !== 0;
    listEl.hidden = count === 0;
    statusEl.textContent = count === 0
        ? 'No matching commands'
        : `${count} command${count === 1 ? '' : 's'}`;

    setActive(count > 0 ? 0 : -1);
}

/** Highlight the option at `index` and expose it via aria-activedescendant. */
function setActive(index) {
    activeIndex = index;
    const options = listEl.children;
    for (let i = 0; i < options.length; i++) {
        options[i].setAttribute('aria-selected', String(i === index));
    }
    if (index >= 0 && options[index]) {
        inputEl.setAttribute('aria-activedescendant', options[index].id);
        options[index].scrollIntoView({ block: 'nearest' });
    } else {
        inputEl.removeAttribute('aria-activedescendant');
    }
}

/** Run the highlighted command (closes the palette first, then dispatches). */
function runActive() {
    if (activeIndex < 0 || !matches[activeIndex]) return;
    const { id } = matches[activeIndex];
    close();
    ActionRegistry.run(id); // same code path the toolbar buttons use
}

function onInputKeydown(e) {
    switch (e.key) {
        case 'ArrowDown':
            e.preventDefault();
            if (matches.length) setActive(Math.min(activeIndex + 1, matches.length - 1));
            break;
        case 'ArrowUp':
            e.preventDefault();
            if (matches.length) setActive(Math.max(activeIndex - 1, 0));
            break;
        case 'Home':
            if (matches.length) { e.preventDefault(); setActive(0); }
            break;
        case 'End':
            if (matches.length) { e.preventDefault(); setActive(matches.length - 1); }
            break;
        case 'Enter':
            e.preventDefault();
            runActive();
            break;
        // Escape is handled by the native <dialog> "cancel" event.
        default:
            break;
    }
}

function buildDialog() {
    const dialog = document.createElement('dialog');
    dialog.className = 'command-palette';
    dialog.id = 'command-palette';
    dialog.setAttribute('aria-label', 'Command palette');
    dialog.setAttribute('aria-modal', 'true');

    const box = document.createElement('div');
    box.className = 'command-palette__box';

    inputEl = document.createElement('input');
    inputEl.className = 'command-palette__input';
    inputEl.type = 'text';
    inputEl.autocomplete = 'off';
    inputEl.setAttribute('role', 'combobox');
    inputEl.setAttribute('aria-expanded', 'true');
    inputEl.setAttribute('aria-controls', LIST_ID);
    inputEl.setAttribute('aria-autocomplete', 'list');
    inputEl.setAttribute('aria-label', 'Search for a command');
    inputEl.placeholder = 'Type a command…';
    inputEl.addEventListener('input', render);
    inputEl.addEventListener('keydown', onInputKeydown);

    listEl = document.createElement('ul');
    listEl.className = 'command-palette__list';
    listEl.id = LIST_ID;
    listEl.setAttribute('role', 'listbox');
    listEl.setAttribute('aria-label', 'Commands');

    emptyEl = document.createElement('p');
    emptyEl.className = 'command-palette__empty';
    emptyEl.textContent = 'No matching commands';
    emptyEl.hidden = true;

    statusEl = document.createElement('div');
    statusEl.className = 'visually-hidden';
    statusEl.setAttribute('role', 'status');
    statusEl.setAttribute('aria-live', 'polite');

    box.appendChild(inputEl);
    box.appendChild(listEl);
    box.appendChild(emptyEl);
    box.appendChild(statusEl);
    dialog.appendChild(box);

    // Backdrop click (on the <dialog> itself, outside the box) closes.
    dialog.addEventListener('click', (e) => {
        if (e.target === dialog) close();
    });
    // Native <dialog> fires "cancel" on Escape and "close" when dismissed.
    dialog.addEventListener('close', restoreFocus);

    return dialog;
}

function restoreFocus() {
    if (openerEl && typeof openerEl.focus === 'function' && document.contains(openerEl)) {
        openerEl.focus();
    }
    openerEl = null;
}

export function openPalette() {
    if (!dialogEl) return;
    if (dialogEl.open) return;
    openerEl = document.activeElement; // capture BEFORE showModal() moves focus
    inputEl.value = '';
    render();
    dialogEl.showModal();
    inputEl.focus();
}

export function close() {
    if (dialogEl && dialogEl.open) dialogEl.close(); // triggers "close" → restoreFocus
}

function toggle() {
    if (dialogEl && dialogEl.open) close();
    else openPalette();
}

export function initCommandPalette() {
    if (dialogEl) return; // idempotent
    dialogEl = buildDialog();
    document.body.appendChild(dialogEl);

    // Global Ctrl+K / Cmd+K — a launcher, so it works even while typing in a
    // tool field. No other modifiers, so Ctrl+Shift+K etc. pass through.
    document.addEventListener('keydown', (e) => {
        if (!(e.ctrlKey || e.metaKey) || e.altKey || e.shiftKey) return;
        if (e.key !== 'k' && e.key !== 'K') return;
        e.preventDefault();
        toggle();
    });
}

export default initCommandPalette;
