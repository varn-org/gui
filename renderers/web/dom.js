// Enough of a document for the renderer to run outside a browser, so the conformance suite is executed
// by plain node rather than only read.
//
// It implements exactly what the renderer touches: element creation, a children list, inline styles,
// datasets, text content, listeners and a text metric. Nothing here is a browser, and nothing here is
// meant to be one — anything the renderer needs beyond this belongs in a real browser test.

class Style {
    constructor() {
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

    appendChild(child) {
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

    addEventListener(type, handler) {
        this.listeners.set(type, (this.listeners.get(type) ?? []).concat(handler));
    }

    removeEventListener(type, handler) {
        this.listeners.set(type, (this.listeners.get(type) ?? []).filter((entry) => entry !== handler));
    }

    /** Fires a listener the way a browser would, which is how an event test reaches a handler. */
    dispatch(type, event = {}) {
        for (const handler of this.listeners.get(type) ?? []) {
            handler(event);
        }
    }

    focus() {
        this.focused = true;
    }

    blur() {
        this.focused = false;
    }

    scrollTo({ left = 0, top = 0 }) {
        this.scrollLeft = left;
        this.scrollTop = top;
    }

    getContext() {
        // One context per canvas, so the font a caller sets is the font the next measurement reads.
        this.context = this.context ?? {
            font: "",
            measureText(text) {
                const size = Number(this.font.match(/(\d+)px/)?.[1]) || 15;
                return { width: text.length * size * 0.5 };
            },
        };

        return this.context;
    }
}

/** Installs the document the renderer expects, answering the surface it draws into. */
export function install() {
    const document = {
        createElement: (tag) => new Element(tag),
        documentElement: new Element("html"),
        fonts: { add() {} },
    };

    globalThis.atob = (text) => Buffer.from(text, "base64").toString("binary");
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

    return new Element("div");
}

export { Element };
