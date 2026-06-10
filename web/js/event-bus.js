// event-bus.js — minimal inter-module pub/sub.
// Every module talks through this so features stay decoupled.

const listeners = new Map(); // event name -> Set<handler>

export const EventBus = {
    /**
     * Subscribe to an event. Returns an unsubscribe function.
     * @param {string} event
     * @param {(payload:any)=>void} handler
     */
    on(event, handler) {
        if (!listeners.has(event)) listeners.set(event, new Set());
        listeners.get(event).add(handler);
        return () => this.off(event, handler);
    },

    off(event, handler) {
        const set = listeners.get(event);
        if (set) set.delete(handler);
    },

    /**
     * Emit an event to all subscribers. Handler errors are isolated so one
     * broken listener can't take down the rest of the app.
     * @param {string} event
     * @param {any} [payload]
     */
    emit(event, payload) {
        const set = listeners.get(event);
        if (!set) return;
        for (const handler of [...set]) {
            try {
                handler(payload);
            } catch (err) {
                console.error(`[event-bus] handler for "${event}" threw:`, err);
            }
        }
    },
};

// Canonical event names used across modules.
export const Events = {
    PDF_LOADING: 'pdf:loading',     // { name } — file accepted, parse/render in progress
    PDF_LOADED: 'pdf:loaded',       // { doc, name, numPages }
    PDF_RENDERED: 'pdf:rendered',   // { numPages }
    PDF_CLEARED: 'pdf:cleared',
    ZOOM_CHANGED: 'viewer:zoom',    // { scale }
    PAGES_ROTATED: 'pages:rotated', // { pages:number[], all?:boolean } — page rotation state changed (pages.js/viewer.js)
    ANNOTATIONS_CHANGED: 'annotations:changed', // {} — markup added/removed/cleared (annotate.js)
    ERROR: 'app:error',             // { message, error }
};

export default EventBus;
