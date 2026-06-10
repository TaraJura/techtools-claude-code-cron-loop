// keyboard-shortcuts.js — accessible "Keyboard shortcuts" help overlay.
//
// This is a REFERENCE CARD ONLY. It does NOT implement any of the shortcuts —
// each real handler lives in its own module (search.js, page-nav.js, present.js).
// The single new global key handler this module owns is `?` (Shift+/), which
// opens this help dialog.
//
// CSP-safe: external module only, no inline <script>; all text set via
// textContent. The modal DOM is built once and toggled (RAM-cheap).

// Static reference data. Keep this ACCURATE — only list shortcuts that work
// today. A combo is an array of key tokens rendered as <kbd>+<kbd>; an item may
// list alternative combos (rendered as "combo / combo").
const SHORTCUT_GROUPS = [
    {
        title: 'Navigation',
        hint: 'Active while the PDF viewer is focused.',
        items: [
            { combos: [['Page Down'], ['↓']], description: 'Next page' },
            { combos: [['Page Up'], ['↑']], description: 'Previous page' },
            { combos: [['Home']], description: 'First page' },
            { combos: [['End']], description: 'Last page' },
        ],
    },
    {
        title: 'Search',
        items: [
            { combos: [['Ctrl/⌘', 'F']], description: 'Open search' },
            { combos: [['Enter']], description: 'Next match' },
            { combos: [['Shift', 'Enter']], description: 'Previous match' },
            { combos: [['Esc']], description: 'Close / clear search' },
        ],
    },
    {
        title: 'View',
        hint: 'Zoom/scroll keys are active while the PDF viewer is focused.',
        items: [
            { combos: [['+'], ['=']], description: 'Zoom in' },
            { combos: [['−']], description: 'Zoom out' },
            { combos: [['0']], description: 'Fit width' },
            { combos: [['Space']], description: 'Scroll down one screen' },
            { combos: [['Shift', 'Space']], description: 'Scroll up one screen' },
            { combos: [['Esc']], description: 'Exit presentation mode' },
        ],
    },
    {
        title: 'Pages',
        hint: 'Active while the PDF viewer is focused.',
        items: [
            { combos: [['[']], description: 'Rotate current page left' },
            { combos: [[']']], description: 'Rotate current page right' },
        ],
    },
    {
        title: 'General',
        items: [
            { combos: [['?']], description: 'Show this keyboard shortcuts help' },
        ],
    },
];

const TITLE_ID = 'shortcuts-dialog-title';

let dialogEl = null;     // the <dialog>
let openerEl = null;     // element focused before opening (for focus restore)

/** True when focus is in a text-entry context (so `?` shouldn't hijack typing). */
function isTypingTarget(el) {
    if (!el) return false;
    const tag = el.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el.isContentEditable;
}

/** Build one combo (e.g. ['Ctrl/⌘','F']) as <kbd>+<kbd>. */
function renderCombo(combo) {
    const frag = document.createDocumentFragment();
    combo.forEach((token, i) => {
        if (i > 0) {
            const plus = document.createElement('span');
            plus.className = 'kbd-sep';
            plus.textContent = '+';
            frag.appendChild(plus);
        }
        const kbd = document.createElement('kbd');
        kbd.textContent = token;
        frag.appendChild(kbd);
    });
    return frag;
}

/** Build the keys cell for an item (combos joined by " / "). */
function renderKeysCell(item) {
    const cell = document.createElement('dd');
    cell.className = 'shortcut-keys';
    item.combos.forEach((combo, i) => {
        if (i > 0) {
            const or = document.createElement('span');
            or.className = 'kbd-or';
            or.textContent = '/';
            cell.appendChild(or);
        }
        cell.appendChild(renderCombo(combo));
    });
    return cell;
}

/** Build the modal dialog DOM once. */
function buildDialog() {
    const dialog = document.createElement('dialog');
    dialog.className = 'shortcuts-dialog';
    dialog.id = 'shortcuts-dialog';
    dialog.setAttribute('aria-labelledby', TITLE_ID);

    const inner = document.createElement('div');
    inner.className = 'shortcuts-dialog-inner';

    const header = document.createElement('div');
    header.className = 'shortcuts-dialog-header';

    const title = document.createElement('h2');
    title.id = TITLE_ID;
    title.className = 'shortcuts-dialog-title';
    title.textContent = 'Keyboard shortcuts';

    const closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'shortcuts-close';
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.autofocus = true;
    closeBtn.textContent = '×';
    closeBtn.addEventListener('click', close);

    header.appendChild(title);
    header.appendChild(closeBtn);
    inner.appendChild(header);

    const body = document.createElement('div');
    body.className = 'shortcuts-dialog-body';

    SHORTCUT_GROUPS.forEach((group) => {
        const section = document.createElement('section');
        section.className = 'shortcut-group';

        const h = document.createElement('h3');
        h.className = 'shortcut-group-title';
        h.textContent = group.title;
        section.appendChild(h);

        if (group.hint) {
            const hint = document.createElement('p');
            hint.className = 'shortcut-group-hint';
            hint.textContent = group.hint;
            section.appendChild(hint);
        }

        const dl = document.createElement('dl');
        dl.className = 'shortcut-list';
        group.items.forEach((item) => {
            const row = document.createElement('div');
            row.className = 'shortcut-row';

            const desc = document.createElement('dt');
            desc.className = 'shortcut-desc';
            desc.textContent = item.description;

            row.appendChild(desc);
            row.appendChild(renderKeysCell(item));
            dl.appendChild(row);
        });
        section.appendChild(dl);
        body.appendChild(section);
    });

    inner.appendChild(body);
    dialog.appendChild(inner);

    // Close on backdrop click (clicks on the <dialog> itself, outside the inner box).
    dialog.addEventListener('click', (e) => {
        if (e.target === dialog) close();
    });
    // Native <dialog> fires "cancel" on Escape; let it close + restore focus.
    dialog.addEventListener('close', restoreFocus);

    return dialog;
}

function restoreFocus() {
    if (openerEl && typeof openerEl.focus === 'function' && document.contains(openerEl)) {
        openerEl.focus();
    }
    openerEl = null;
}

export function openShortcuts() {
    if (!dialogEl) return;
    if (dialogEl.open) return;
    // Capture the opener BEFORE showModal() moves focus into the dialog.
    openerEl = document.activeElement;
    dialogEl.showModal();
}

export function close() {
    if (dialogEl && dialogEl.open) dialogEl.close(); // triggers "close" → restoreFocus
}

export function initKeyboardShortcuts() {
    if (dialogEl) return; // idempotent
    dialogEl = buildDialog();
    document.body.appendChild(dialogEl);

    // Header button.
    const btn = document.getElementById('shortcuts-help');
    if (btn) btn.addEventListener('click', openShortcuts);

    // Global `?` (Shift+/) opens the help — but never while typing, and never
    // with another modifier held (so Ctrl+? etc. pass through).
    document.addEventListener('keydown', (e) => {
        if (e.key !== '?') return;
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        if (isTypingTarget(e.target)) return;
        if (dialogEl.open) return; // Escape closes; don't toggle
        e.preventDefault();
        openShortcuts();
    });
}
