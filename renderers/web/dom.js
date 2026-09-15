// Enough of a document for the renderer to run outside a browser, so the conformance suite is executed
// by plain node rather than only read.
//
// It implements exactly what the renderer touches: element creation, a children list, inline styles,
// datasets, text content, listeners and a text metric. Nothing here is a browser, and nothing here is
// meant to be one — anything the renderer needs beyond this belongs in a real browser test.

class Style {
    constructor() {
        // A custom property is set and read by name rather than as a field, which is the only way to
        // reach a pseudo-element from script, so the three calls that do it are what a renderer uses.
        this.setProperty = (name, value) => {
            this[name] = value;
        };

        this.removeProperty = (name) => {
            this[name] = "";
        };

        this.getPropertyValue = (name) => this[name] ?? "";

        return new Proxy(this, {
            get: (target, key) => (key in target ? target[key] : (target[key] = "")),
            set: (target, key, value) => {
                target[key] = value === undefined || value === null ? "" : String(value);
                return true;
            },
        });
    }
}

class Element {
    constructor(tag) {
        this.tagName = tag.toUpperCase();
        this.children = [];
        this.parentNode = null;
        this.style = new Style();
        this.dataset = {};
        this.attributes = {};
        this.listeners = new Map();
        this.textContent = "";
        this.checked = false;
        this.disabled = false;
        this.placeholder = "";
        this.src = "";
        this.type = "";
        this.scrollLeft = 0;
        this.scrollTop = 0;
        this.text = "";
        this.selectionStart = 0;
        this.selectionEnd = 0;

        // A media element holds where it has got to and how long it runs for, which is what a seek
        // writes and reads back. A duration a browser has not read yet is not a number at all.
        this.currentTime = 0;
        this.duration = NaN;
    }

    // Writing a field's value puts the caret at the end of it, which is the browser behaviour a renderer
    // has to avoid triggering while somebody is typing.
    get value() {
        return this.text;
    }

    set value(text) {
        // A range input holds a number inside its range and on its step rather than the text it was
        // handed, and it counts nought to a hundred in ones until it is told otherwise, so four tenths
        // set before the step arrives becomes nought and stays there.
        if (this.type === "range") {
            const least = Number(this.min ?? 0);
            const most = Number(this.max ?? 100);
            const step = this.step === "any" ? 0 : Number(this.step ?? 1);
            const held = Math.min(most, Math.max(least, Number(text) || 0));

            this.text = String(step > 0 ? least + Math.round((held - least) / step) * step : held);
            return;
        }

        this.text = text === undefined || text === null ? "" : String(text);
        this.selectionStart = this.text.length;
        this.selectionEnd = this.text.length;
    }

    // Whether the element sits in a tree, which is what the host asks before it puts a banner up again.
    get isConnected() {
        return this.parentNode !== null;
    }

    appendChild(child) {
        return this.insertBefore(child, null);
    }

    append(child) {
        return this.insertBefore(child, null);
    }

    insertBefore(child, reference) {
        child.remove();
        child.parentNode = this;

        const at = reference === null ? this.children.length : this.children.indexOf(reference);
        this.children.splice(at < 0 ? this.children.length : at, 0, child);
        return child;
    }

    removeChild(child) {
        const at = this.children.indexOf(child);

        if (at >= 0) {
            this.children.splice(at, 1);
            child.parentNode = null;
        }

        return child;
    }

    remove() {
        this.parentNode?.removeChild(this);
    }

    setAttribute(name, value) {
        this.attributes[name] = value;
    }

    getAttribute(name) {
        return this.attributes[name] ?? null;
    }

    hasAttribute(name) {
        return this.attributes[name] !== undefined;
    }

    removeAttribute(name) {
        delete this.attributes[name];
    }

    addEventListener(type, handler) {
        this.listeners.set(type, (this.listeners.get(type) ?? []).concat(handler));
    }

    removeEventListener(type, handler) {
        this.listeners.set(type, (this.listeners.get(type) ?? []).filter((entry) => entry !== handler));
    }

    /** Fires a listener the way a browser would, which is how an event test reaches a handler.
     *
     * An event reaches the box around whatever raised it as well. A checkbox and its caption sit inside
     * a label the renderer listens on, and the chooser a file button opens is what raises the change the
     * button reports, so a renderer that leans on that has to be tested through it. */
    dispatch(type, event = {}) {
        const raised = event.target === undefined ? { ...event, target: this } : event;

        for (let at = this; at !== null; at = at.parentNode) {
            for (const handler of at.listeners.get(type) ?? []) {
                handler(raised);
            }
        }
    }

    /** Presses the element from script, which is what a return on a control does and what a label does
     * to the control it holds. A browser reports no finger behind such a press, which is how one is told
     * from a pointer that travelled. */
    click() {
        this.dispatch("click", { type: "click", detail: 0 });
    }

    focus() {
        this.focused = true;
    }

    blur() {
        this.focused = false;
    }

    // Where an element sits on the page, which outside a browser is nowhere, since nothing here lays out.
    getBoundingClientRect() {
        return { left: 0, top: 0, width: 0, height: 0 };
    }

    scrollTo({ left = 0, top = 0 }) {
        this.scrollLeft = left;
        this.scrollTop = top;
    }

    getContext() {
        // One context per canvas, so the font a caller sets is the font the next measurement reads, and
        // what was drawn on it is what a test reads back.
        if (this.context === undefined) {
            const calls = [];
            const records = [
                "setTransform", "clearRect", "beginPath", "moveTo", "lineTo",
                "closePath", "fill", "stroke", "fillText",
            ];

            this.context = { font: "", calls };

            for (const name of records) {
                this.context[name] = () => calls.push(name);
            }

            this.context.measureText = (text) => {
                const size = Number(this.context.font.match(/(\d+)px/)?.[1]) || 15;
                return { width: text.length * size * 0.5 };
            };
        }

        return this.context;
    }
}

/** Installs the document the renderer expects, answering the surface it draws into. */
export function install() {
    const root = new Element("html");

    const document = {
        createElement: (tag) => new Element(tag),
        // A filter is declared as a drawing rather than as an element of the page, and outside a browser
        // a drawing is an element like any other: what a test reads back is the attributes it was given.
        createElementNS: (_namespace, tag) => new Element(tag),
        documentElement: root,
        body: new Element("body"),
        getElementById: (id) => root.children.find((child) => child.id === id) ?? null,
        fonts: { add() {} },
        baseURI: "http://localhost/",

        // A page tells the host where it is through the document rather than through the window, and a
        // stand-in without that is a suite agreeing with itself about a host that never starts.
        visibilityState: "visible",
        hasFocus: () => true,
        fullscreenElement: null,
        // Many listeners may watch one event, which is what a page relies on: the host watches a page
        // being hidden both to say the application went away and to give back what it is holding.
        listening: new Map(),
        addEventListener(name, handler) {
            const watching = document.listening.get(name) ?? [];

            watching.push(handler);
            document.listening.set(name, watching);
        },
        removeEventListener(name, handler) {
            const watching = document.listening.get(name) ?? [];
            document.listening.set(name, watching.filter((each) => each !== handler));
        },
        dispatch(name, event) {
            for (const handler of document.listening.get(name) ?? []) {
                handler(event ?? { type: name });
            }
        },
    };

    globalThis.atob = (text) => Buffer.from(text, "base64").toString("binary");
    globalThis.FileReader = class {
        readAsDataURL(file) {
            const encoded = Buffer.from(file.bytes ?? []).toString("base64");

            this.result = `data:${file.type};base64,${encoded}`;
            queueMicrotask(() => this.onload?.());
        }
    };
    globalThis.FontFace = class {
        constructor(family, source) {
            this.family = family;
            this.source = source;
        }

        async load() {
            return this;
        }
    };

    globalThis.document = document;
    globalThis.window = { devicePixelRatio: 2 };
    globalThis.getComputedStyle = () => ({ getPropertyValue: () => "0" });

    // A page is always at an address and always has a history, and the host reads both: where the
    // application was asked to be is what a router opens on, and where it goes is what the browser keeps.
    globalThis.location = { pathname: "/", search: "", href: "http://localhost/" };
    globalThis.history = {
        pushState(_state, _title, where) { globalThis.location.pathname = new URL(where, "http://localhost/").pathname; },
        replaceState(_state, _title, where) { globalThis.location.pathname = new URL(where, "http://localhost/").pathname; },
        back() {},
    };

    return new Element("div");
}

export { Element };
