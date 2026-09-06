// The web renderer. It applies the operations a commit carries to real DOM nodes and reports events
// back, and it decides nothing: every size, colour and position arrives already resolved.

const TAGS = {
    view: "div",
    text: "span",
    richtext: "span",
    image: "img",
    button: "button",
    pressable: "div",
    textinput: "input",
    textarea: "textarea",
    scroll: "div",
    list: "div",
    sectionlist: "div",
    grid: "div",
    carousel: "div",
    switch: "input",
    checkbox: "input",
    radio: "input",
    slider: "input",
    stepper: "div",
    segmented: "div",
    picker: "select",
    datepicker: "input",
    timepicker: "input",
    searchbar: "input",
    colorpicker: "input",
    filepicker: "input",
    rating: "div",
    video: "video",
    webview: "iframe",
    canvas: "canvas",
    icon: "span",
    divider: "hr",
    spacer: "div",
    safearea: "div",
    keyboardavoiding: "div",
    activity: "div",
    progress: "progress",
    skeleton: "div",
    refresh: "div",
    badge: "span",
    chip: "span",
    avatar: "div",
    card: "div",
    tooltip: "span",
};

// The types that draw their own text, where the padding around it is the renderer's to apply.
//
// Everywhere else the engine has already worked the padding into the frames of the children, and an
// absolutely placed child is positioned against the padding box, so setting it again would shift them.
const PADDED = new Set([
    "text", "richtext", "textinput", "textarea", "searchbar", "picker",
    "button", "badge", "chip", "tooltip",
]);

const INPUT_TYPES = {
    switch: "checkbox",
    checkbox: "checkbox",
    radio: "radio",
    slider: "range",
    datepicker: "date",
    timepicker: "time",
    colorpicker: "color",
    filepicker: "file",
    searchbar: "search",
};

const EVENTS = {
    onPressIn: "pointerdown",
    onPressOut: "pointerup",
    onCommit: "change",
    onEnd: "ended",
    onPress: "click",
    onLongPress: "contextmenu",
    onChange: "input",
    onSubmit: "submit",
    onFocus: "focus",
    onBlur: "blur",
    onScroll: "scroll",
    onLoad: "load",
    onError: "error",
};

const REMOVED = "__varn_removed__";

// The props that build what a node holds or say what it may hold, which are applied before the ones
// that choose among it.
//
// A batch carries props as a map, so they arrive in no order at all. Rebuilding the segments of a
// control after the chosen one was set would drop the choice, and a range input takes nought to a
// hundred until it is told otherwise, so a value of four tenths applied first is clamped to nought and
// stays there. Both are defects that come and go rather than ones that can be found.
const STRUCTURAL = new Set([
    "segments", "options", "count", "text", "title", "label",
    "minimum", "maximum", "step",
]);

// A scrolling type keeps its children in a content layer, so the frames it is given are content
// coordinates and the browser scrolls over them.
const SCROLLING = new Set(["scroll", "list", "sectionlist", "grid", "carousel"]);

// The types the browser has no control for, which the renderer builds out of parts of its own.
//
// The engine sends these no children of their own, so what is inside one belongs to the renderer the
// way a UISegmentedControl's segments belong to UIKit.
const PARTED = new Set(["segmented", "rating", "stepper"]);

export class WebRenderer {
    constructor(container, emit) {
        this.container = container;
        this.emit = emit;
        this.nodes = new Map();
        this.listeners = new Map();
        this.fonts = new Set();
        this.scale = window.devicePixelRatio || 1;

        this.capabilities = {
            text: true, image: true, list: true, scroll: true, input: true,
            video: true, webview: true, canvas: true,
            picker: true, datepicker: true,
            haptics: false, safearea: true, fontBytes: true,
        };
    }

    apply(ops) {
        for (const op of ops) {
            switch (op.op) {
                case "create": this.create(op); break;
                case "update": this.update(op.id, op.props); break;
                case "insert":
                case "move": this.place(op); break;
                case "remove": this.remove(op.id); break;
                case "frame": this.frame(op); break;
                default: throw new Error(`unknown operation ${op.op}`);
            }
        }
    }

    create({ id, type, props }) {
        const tag = TAGS[type];
        if (tag === undefined) {
            throw new Error(`the renderer has no element for ${type}`);
        }

        const element = document.createElement(tag);
        element.dataset.varnId = String(id);
        element.dataset.varnType = type;
        element.style.position = "absolute";
        element.style.boxSizing = "border-box";
        element.style.margin = "0";

        // A button and a field carry a look of their own from the user agent, which the style is what
        // decides instead, so the parts the style does not name are cleared rather than left showing.
        if (type === "button") {
            element.style.font = "inherit";
            element.style.cursor = "pointer";
            element.style.appearance = "none";
        }

        if (INPUT_TYPES[type] !== undefined) {
            element.type = INPUT_TYPES[type];
        }

        let content = null;

        if (SCROLLING.has(type)) {
            element.style.overflow = "auto";
            content = document.createElement("div");
            content.style.position = "relative";
            content.style.width = "100%";
            element.appendChild(content);
        }

        if (PARTED.has(type)) {
            element.style.display = "flex";
            element.style.alignItems = "center";
        }

        const node = { id, element, content, type, props: {}, listeners: new Map() };
        this.nodes.set(id, node);

        if (type === "stepper") {
            this.buildStepper(node);
            this.showCount(node, 0);
        }

        this.update(id, props || {});
        return element;
    }

    expect(id) {
        const node = this.nodes.get(id);
        if (node === undefined) {
            throw new Error(`the batch touched node ${id}, which was never created`);
        }

        return node;
    }

    update(id, props) {
        const node = this.expect(id);
        const ordered = Object.entries(props).sort(
            ([first], [second]) => Number(STRUCTURAL.has(second)) - Number(STRUCTURAL.has(first)),
        );

        for (const [key, value] of ordered) {
            const cleared = value === REMOVED || value === null;
            const next = cleared ? undefined : value;

            if (key === "style") {
                this.applyStyle(node, next || {});
            } else if (EVENTS[key] !== undefined) {
                this.bind(node, id, key, next);

                if (key === "onPress" && next !== undefined) {
                    this.showPress(node.element);
                }
            } else {
                this.applyProp(node, key, next);
            }

            node.props[key] = next;
        }

        if (node.content !== null) {
            this.sizeContent(node);
        }
    }

    // Answers a finger the way the platform answers one, since a control that does not react to a
    // press reads as one that is not listening.
    showPress(element) {
        if (element.dataset.varnPressed === "yes") {
            return;
        }

        element.dataset.varnPressed = "yes";
        element.style.cursor = "pointer";
        element.style.transition = "opacity 0.22s";

        const down = () => { element.style.opacity = "0.55"; };
        const up = () => { element.style.opacity = ""; };

        element.addEventListener("pointerdown", down);
        element.addEventListener("pointerup", up);
        element.addEventListener("pointercancel", up);
        element.addEventListener("pointerleave", up);
    }

    // The content layer carries the whole scrollable extent, which is what gives the browser something
    // to scroll over while only the realised cells exist.
    sizeContent(node) {
        const horizontal = node.props.horizontal === true;
        const extent = node.props.contentExtent ?? 0;

        node.content.style[horizontal ? "width" : "height"] = `${extent}px`;
        node.content.style[horizontal ? "height" : "width"] = "100%";
    }

    applyProp(node, key, value) {
        const { element, type } = node;

        if (key === "text") {
            element.textContent = value ?? "";
            return;
        }

        if (key === "source") {
            if (type === "image") {
                element.src = value ?? "";
            } else if (type === "video" || type === "webview") {
                element.src = value ?? "";
            }
            return;
        }

        // A box with nothing to do with a touch lets it through to whatever sits under it.
        if (key === "pointerEvents") {
            element.style.pointerEvents = value === "none" ? "none" : "";
            return;
        }

        // A control is tinted with the colours it was given rather than the browser's own.
        if (key === "onColor" || key === "trackColor") {
            element.style.accentColor = value ?? "";
            return;
        }

        if (key === "step") {
            element.step = value ?? "any";
            return;
        }

        if (key === "minimum" || key === "maximum") {
            element[key === "minimum" ? "min" : "max"] = value ?? (key === "minimum" ? 0 : 1);
            return;
        }

        // Which of the two events a drag reports through is decided when one fires, so this needs
        // nothing applied to the element.
        if (key === "continuous") {
            return;
        }

        // A picture drawn in one colour is what an icon carried as an image is.
        if (key === "tint") {
            element.style.filter = value === undefined ? "" : "brightness(0) saturate(100%)";
            element.style.backgroundColor = value ?? "";
            element.style.maskImage = value === undefined ? "" : `url(${element.src})`;
            return;
        }

        // A video and a web view obey what they were told, rather than only what to show.
        if (["muted", "loop", "autoplay", "controls"].includes(key)) {
            element[key] = Boolean(value);
            return;
        }

        if (key === "volume" || key === "rate") {
            element[key === "rate" ? "playbackRate" : "volume"] = value ?? 1;
            return;
        }

        if (key === "javaScriptEnabled") {
            element.sandbox = value === false ? "allow-same-origin" : "allow-same-origin allow-scripts";
            return;
        }

        if (key === "poster") {
            element.poster = value ?? "";
            return;
        }

        // Says how a picture fills the frame the engine gave it, which is never the frame's own shape.
        if (key === "resizeMode") {
            element.style.objectFit = { contain: "contain", stretch: "fill", center: "none" }[value] ?? "cover";
            return;
        }

        if (key === "value") {
            // A radio's value is the identity it reports when chosen, never whether it is chosen, which
            // is what `selected` says, so it goes on as the value attribute the form reads.
            if (type === "radio") {
                element.value = value ?? "";
                return;
            }

            if (type === "switch" || type === "checkbox") {
                element.checked = Boolean(value);
                return;
            }

            if (type === "rating") {
                this.showStars(node, Number(value ?? 0));
                return;
            }

            if (type === "stepper") {
                this.showCount(node, Number(value ?? 0));
                return;
            }

            // Writing the text a field already holds puts the caret back at the end of it, so a reader
            // typing into a controlled field would lose their place on every keystroke.
            const text = value ?? "";
            if (element.value !== text) {
                element.value = text;
            }
            return;
        }

        if (key === "spans") {
            this.applySpans(element, value ?? []);
            return;
        }

        if (key === "options") {
            this.applyOptions(node, value ?? []);
            return;
        }

        if (key === "segments") {
            this.applySegments(node, value ?? []);
            return;
        }

        if (key === "selectedIndex") {
            this.showSegment(node, value ?? 1);
            return;
        }

        if (key === "count") {
            this.applyStars(node, value ?? 5);
            return;
        }

        if (key === "selected") {
            element.checked = Boolean(value);
            return;
        }

        if (key === "maxLength") {
            element.maxLength = value ?? -1;
            return;
        }

        if (key === "autoCapitalize") {
            element.autocapitalize = value ?? "sentences";
            return;
        }

        if (key === "autoCorrect") {
            element.autocomplete = value === false ? "off" : "on";
            element.spellcheck = value !== false;
            return;
        }

        if (key === "placeholder") {
            element.placeholder = value ?? "";
            return;
        }

        if (key === "title" && (type === "button" || type === "chip")) {
            element.textContent = value ?? "";
            return;
        }

        if (key === "label" && (type === "chip" || type === "checkbox" || type === "radio")) {
            element.textContent = value ?? "";
            return;
        }

        if (key === "disabled" || key === "editable") {
            element.disabled = key === "editable" ? !value : Boolean(value);
            return;
        }

        if (key === "visible" || key === "open") {
            element.style.display = value ? "" : "none";
            return;
        }

        if (key === "accessibilityLabel") {
            element.setAttribute("aria-label", value ?? "");
            return;
        }

        if (key === "contentExtent" || key === "horizontal") {
            return;
        }

        if (key === "testID") {
            element.dataset.testid = value ?? "";
        }
    }

    applyStyle(node, style) {
        const css = node.element.style;

        // Layout arrives as a frame, so only what a frame does not carry is set here.
        css.background = style.background ?? "";
        css.color = style.color ?? "";
        css.opacity = style.opacity ?? "";
        css.borderRadius = style.radius !== undefined ? `${style.radius}px` : "";
        css.fontSize = style.fontSize !== undefined ? `${style.fontSize}px` : "";
        css.fontWeight = style.fontWeight ?? "";
        css.fontFamily = style.fontFamily ?? "";
        css.lineHeight = style.lineHeight ?? "";
        css.letterSpacing = style.letterSpacing !== undefined ? `${style.letterSpacing}px` : "";
        css.textAlign = style.textAlign ?? "";
        css.textDecoration = style.textDecoration ?? "";
        css.overflow = style.overflow ?? "";
        css.borderColor = style.borderColor ?? "";
        css.borderStyle = style.borderColor !== undefined ? "solid" : "none";
        css.borderWidth = style.border !== undefined ? `${style.border}px` : "";
        css.transform = this.transform(style.transform);
        css.padding = PADDED.has(node.type) ? this.padding(style) : "";

        if (style.shadow !== undefined) {
            const shadow = style.shadow;
            css.boxShadow = `0 ${shadow.offsetY ?? 0}px ${shadow.radius ?? 0}px ${shadow.color ?? "rgba(0,0,0,0.2)"}`;
        } else {
            css.boxShadow = "";
        }
    }

    // Draws a paragraph made of runs that each carry a style of their own.
    //
    // A span flows inline within the paragraph rather than being placed by a frame, which is why this is
    // one of the few places a renderer builds something rather than being handed it as nodes.
    applySpans(element, spans) {
        WebRenderer.empty(element);

        for (const span of spans) {
            const style = span.style ?? {};
            const run = document.createElement("span");

            run.textContent = span.text ?? "";
            run.style.color = style.color ?? "";
            run.style.fontSize = style.fontSize !== undefined ? `${style.fontSize}px` : "";
            run.style.fontWeight = style.fontWeight ?? "";
            run.style.fontFamily = style.fontFamily ?? "";
            run.style.textDecoration = style.textDecoration ?? "";

            element.appendChild(run);
        }
    }

    // Reports what a control the renderer built out of its own parts was changed to.
    //
    // A handler travels as a marker, so the props the node already holds say whether the tree is
    // listening, and nothing is emitted for an event nobody asked for.
    report(node, name, payload) {
        if (node.props[name] === undefined) {
            return;
        }

        this.emit(node.id, name, payload);
    }

    // Takes back everything an element holds, so what a structural prop builds replaces what was there.
    static empty(element) {
        element.textContent = "";

        while (element.children.length > 0) {
            element.children[element.children.length - 1].remove();
        }
    }

    // Fills the chooser with what it may be set to, which the browser draws as its own list.
    applyOptions(node, options) {
        WebRenderer.empty(node.element);

        for (const option of options) {
            const entry = document.createElement("option");

            entry.value = option.value ?? option.label ?? "";
            entry.textContent = option.label ?? "";
            node.element.appendChild(entry);
        }
    }

    // Builds the segments of a control the browser has none of, each reporting where it sits.
    applySegments(node, segments) {
        WebRenderer.empty(node.element);
        node.parts = [];

        for (const [at, title] of segments.entries()) {
            const segment = document.createElement("button");

            segment.textContent = title;
            segment.style.flex = "1";
            segment.style.font = "inherit";
            segment.style.cursor = "pointer";
            segment.style.appearance = "none";
            segment.style.border = "0";
            segment.style.background = "transparent";
            segment.style.color = "inherit";
            segment.addEventListener("click", () => {
                this.showSegment(node, at + 1);
                this.report(node, "onChange", at + 1);
            });

            node.parts.push(segment);
            node.element.appendChild(segment);
        }

        this.showSegment(node, node.props.selectedIndex ?? 1);
    }

    showSegment(node, index) {
        for (const [at, segment] of (node.parts ?? []).entries()) {
            segment.style.opacity = at + 1 === index ? "1" : "0.5";
        }
    }

    // Builds the stars a rating is made of, each reporting the score it stands for.
    applyStars(node, count) {
        WebRenderer.empty(node.element);
        node.parts = [];

        for (let at = 0; at < count; at += 1) {
            const star = document.createElement("span");

            star.textContent = "★";
            star.style.cursor = "pointer";
            star.addEventListener("click", () => {
                this.showStars(node, at + 1);
                this.report(node, "onChange", at + 1);
            });

            node.parts.push(star);
            node.element.appendChild(star);
        }

        this.showStars(node, Number(node.props.value ?? 0));
    }

    showStars(node, value) {
        for (const [at, star] of (node.parts ?? []).entries()) {
            star.style.opacity = at < value ? "1" : "0.3";
        }
    }

    showCount(node, value) {
        const least = node.props.minimum ?? -Infinity;
        const most = node.props.maximum ?? Infinity;

        node.count = Math.min(most, Math.max(least, value));
        node.parts[1].textContent = String(node.count);
    }

    // Builds the two buttons and the readout a stepper is, which the browser has no control for.
    buildStepper(node) {
        const less = document.createElement("button");
        const readout = document.createElement("span");
        const more = document.createElement("button");

        for (const [button, by] of [[less, -1], [more, 1]]) {
            button.textContent = by < 0 ? "−" : "+";
            button.style.font = "inherit";
            button.style.cursor = "pointer";
            button.style.appearance = "none";
            button.style.border = "0";
            button.style.background = "transparent";
            button.style.color = "inherit";
            button.addEventListener("click", () => {
                this.showCount(node, (node.count ?? 0) + by * (node.props.step ?? 1));
                this.report(node, "onChange", node.count);
            });
        }

        readout.style.flex = "1";
        readout.style.textAlign = "center";

        node.parts = [less, readout, more];
        node.element.appendChild(less);
        node.element.appendChild(readout);
        node.element.appendChild(more);
    }

    // A box property arrives as one value, a pair, or a value per edge, the way the engine reads it.
    padding(style) {
        const whole = style.padding ?? 0;
        const horizontal = style.paddingHorizontal ?? whole;
        const vertical = style.paddingVertical ?? whole;

        const top = style.paddingTop ?? vertical;
        const right = style.paddingRight ?? horizontal;
        const bottom = style.paddingBottom ?? vertical;
        const left = style.paddingLeft ?? horizontal;

        return `${top}px ${right}px ${bottom}px ${left}px`;
    }

    // A transform arrives as fields rather than text, so three renderers cannot disagree about the order.
    transform(transform) {
        if (transform === undefined) {
            return "";
        }

        return [
            `translate(${transform.translateX}px, ${transform.translateY}px)`,
            `scale(${transform.scaleX}, ${transform.scaleY})`,
            `rotate(${transform.rotate}deg)`,
            `skew(${transform.skewX}deg, ${transform.skewY}deg)`,
        ].join(" ");
    }

    bind(node, id, name, handler) {
        const existing = node.listeners.get(name);
        if (existing !== undefined) {
            for (const type of existing.types) {
                node.element.removeEventListener(type, existing.fn);
            }

            node.listeners.delete(name);
        }

        if (handler === undefined) {
            return;
        }

        const types = this.listensTo(node, name);
        const fn = (event) => {
            if (!this.reports(node, name, event)) {
                return;
            }

            this.emit(id, name, this.payload(node, name, event));
        };

        for (const type of types) {
            node.element.addEventListener(type, fn);
        }

        node.listeners.set(name, { types, fn });
    }

    // A slider dragged with the finger down raises `input`, and one let go of raises `change`, so a
    // control that reports both ways is listening to both.
    listensTo(node, name) {
        if (name === "onChange" && node.type === "slider") {
            return ["input", "change"];
        }

        return [EVENTS[name]];
    }

    // A slider reports every position it passes through, unless the tree asked to hear only the one it
    // was left at. The prop may arrive after the handler, so this is decided when an event fires rather
    // than when the listener is attached.
    reports(node, name, event) {
        if (name !== "onChange" || node.type !== "slider") {
            return true;
        }

        return (node.props.continuous === false) === (event.type === "change");
    }

    payload(node, name, event) {
        if (name === "onChange") {
            const element = node.element;
            if (element.type === "checkbox" || element.type === "radio") {
                return element.checked;
            }

            return element.type === "range" ? Number(element.value) : element.value;
        }

        if (name === "onScroll") {
            return { x: node.element.scrollLeft, y: node.element.scrollTop };
        }

        return {};
    }

    place({ id, parent, index }) {
        const node = this.expect(id);
        const holder = parent === 0 ? null : this.expect(parent);
        const target = holder === null ? this.container : (holder.content ?? holder.element);

        // The index counts the siblings the node is not among, so it leaves the list before it is read.
        node.element.remove();

        const reference = target.children[index - 1];
        target.insertBefore(node.element, reference ?? null);
    }

    remove(id) {
        const node = this.nodes.get(id);
        if (node === undefined) {
            return;
        }

        for (const { types, fn } of node.listeners.values()) {
            for (const type of types) {
                node.element.removeEventListener(type, fn);
            }
        }

        node.element.remove();
        this.nodes.delete(id);
    }

    frame({ id, x, y, width, height }) {
        const css = this.expect(id).element.style;
        css.left = `${x}px`;
        css.top = `${y}px`;
        css.width = `${width}px`;
        css.height = `${height}px`;
    }

    // Only the platform knows what its font engine does with a string, which is why this crosses back.
    // Answers the size the browser draws a control at, which is the one thing about it Lua cannot know.
    //
    // A number written into the tree is a number that was true of one platform on one day, and a frame
    // worked out from the old one spills the control out of the box it was given.
    measureControl(type) {
        const tag = TAGS[type];

        if (tag === undefined) {
            return { width: 0, height: 0 };
        }

        const probe = document.createElement(tag);

        if (INPUT_TYPES[type] !== undefined) {
            probe.type = INPUT_TYPES[type];
        }

        probe.style.position = "absolute";
        probe.style.visibility = "hidden";
        document.body.appendChild(probe);

        const box = probe.getBoundingClientRect();
        probe.remove();

        return { width: box.width, height: box.height };
    }

    measureText(text, style, bound) {
        const canvas = this.measureCanvas ?? (this.measureCanvas = document.createElement("canvas"));
        const context = canvas.getContext("2d");

        const size = style.fontSize ?? 15;
        const weight = style.fontWeight ?? "400";
        const family = style.fontFamily ?? "system-ui, sans-serif";
        context.font = `${weight} ${size}px ${family}`;

        const lineHeight = size * (style.lineHeight ?? 1.35);
        const width = context.measureText(String(text)).width;

        // A bound of zero is a node that has not been measured yet, not a node with no room.
        if (bound > 0 && width > bound) {
            return { width: bound, height: Math.ceil(width / bound) * lineHeight };
        }

        return { width, height: lineHeight };
    }

    // The font lives in the engine's filesystem, which the page cannot fetch, so it arrives as bytes.
    async registerFont(family, bytes, descriptors) {
        const binary = atob(bytes);
        const buffer = new Uint8Array(binary.length);

        for (let at = 0; at < binary.length; at += 1) {
            buffer[at] = binary.charCodeAt(at);
        }

        const face = new FontFace(family, buffer.buffer, descriptors ?? {});
        await face.load();
        document.fonts.add(face);
        this.fonts.add(family);
    }

    invoke(id, method, args) {
        const node = this.expect(id);
        const element = node.element;

        if (method === "focus") {
            element.focus();
            return true;
        }

        if (method === "blur") {
            element.blur();
            return true;
        }

        if (method === "scrollTo") {
            element.scrollTo({ left: args.x ?? 0, top: args.y ?? 0, behavior: args.animated ? "smooth" : "auto" });
            return true;
        }

        if (method === "play" || method === "pause") {
            element[method]();
            return true;
        }

        throw new Error(`the renderer has no action named ${method}`);
    }

    safeArea() {
        const style = getComputedStyle(document.documentElement);
        const read = (name) => parseFloat(style.getPropertyValue(name)) || 0;

        return {
            top: read("--safe-area-top"),
            right: read("--safe-area-right"),
            bottom: read("--safe-area-bottom"),
            left: read("--safe-area-left"),
        };
    }
}
