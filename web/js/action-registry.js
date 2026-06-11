// action-registry.js — central registry of named commands.
// Tool tabs, the command palette, and keyboard shortcuts all resolve actions
// through this single map so there is one source of truth for "what can the app do".

const actions = new Map(); // id -> { id, title, run }

export const ActionRegistry = {
    /**
     * Register an action. Re-registering the same id overwrites (last wins),
     * which keeps hot-reload / re-init idempotent.
     * @param {string} id
     * @param {{title?:string, shortcut?:string, run:(arg?:any)=>any}} def
     *   `shortcut` is an OPTIONAL human-readable hint (e.g. "+", "Ctrl/⌘ K")
     *   shown by the command palette. Only set it for keys that are actually
     *   bound, so the palette and the keyboard-shortcuts reference never disagree.
     */
    register(id, def) {
        if (!def || typeof def.run !== 'function') {
            throw new Error(`[action-registry] action "${id}" needs a run() function`);
        }
        actions.set(id, { id, title: def.title || id, shortcut: def.shortcut || null, run: def.run });
    },

    has(id) {
        return actions.has(id);
    },

    /** Run a registered action by id. Returns the action's result. */
    run(id, arg) {
        const action = actions.get(id);
        if (!action) {
            console.warn(`[action-registry] no such action: "${id}"`);
            return undefined;
        }
        return action.run(arg);
    },

    list() {
        return [...actions.values()].map(({ id, title, shortcut }) => ({ id, title, shortcut }));
    },
};

export default ActionRegistry;
