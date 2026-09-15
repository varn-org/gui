// The web renderer. It applies the operations a commit carries to real DOM nodes and reports events
// back, and it decides nothing: every size, colour and position arrives already resolved.

import { Capture } from "./camera.js";
import { installSheet } from "./sheet.js";
import { VarnLocation, VarnTileMap } from "./place.js";

const TAGS = {
    view: "div",
    layer: "div",
    camera: "div",
    recorder: "div",
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
    checkbox: "label",
    radio: "label",
    slider: "input",
    stepper: "div",
    segmented: "div",
    picker: "select",
    datepicker: "input",
    timepicker: "input",
    searchbar: "input",
    colorpicker: "input",
    filepicker: "button",
    rating: "div",
    video: "video",
    audio: "audio",
    webview: "iframe",
    canvas: "canvas",
    gradient: "div",
    nineslice: "div",
    richeditor: "div",
    blur: "div",
    map: "div",
    location: "div",
    divider: "hr",
    spacer: "div",
    safearea: "div",
    keyboardavoiding: "div",
    activity: "div",
    progress: "progress",
    skeleton: "div",
    refresh: "div",
    badge: "span",
    card: "div",
    tooltip: "span",
};

// The types that draw their own text, where the padding around it is the renderer's to apply.
//
// Everywhere else the engine has already worked the padding into the frames of the children, and an
// absolutely placed child is positioned against the padding box, so setting it again would shift them.
const PADDED = new Set([
    "text", "richtext", "textinput", "textarea", "searchbar", "picker",
    "button", "badge", "tooltip", "richeditor",
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
    onDoublePress: "dblclick",
    onKeyDown: "keydown",
    onKeyUp: "keyup",
    onPressIn: "pointerdown",
    onPressOut: "pointerup",
    onCommit: "change",
    onSelect: "change",
    onEnd: "ended",
    onPress: "click",
    onLongPress: "contextmenu",
    onContextPress: "contextmenu",
    onHoverIn: "pointerenter",
    onHoverOut: "pointerleave",
    onPanStart: "pointerdown",
    onChange: "input",
    onPick: "change",
    onSubmit: "keydown",
    onFocus: "focus",
    onBlur: "blur",
    onScroll: "scroll",
    onScrollEnd: "scroll",
    onLoad: "load",
    onError: "error",
    onProgress: "timeupdate",
    onReady: "loadedmetadata",
};

// What the browser is asked to bring up, by the name the tree writes it under.
const KEYBOARDS = {
    default: "text",
    number: "numeric",
    decimal: "decimal",
    email: "email",
    phone: "tel",
    url: "url",
    search: "search",
};

// How far a finger may travel and still be a press, which is what the phones allow a tap.
const TRAVEL = 10;

// What a role is called in ARIA, where the name differs from the one the tree writes.
const ROLES = {
    radio: "radio",
    switch: "switch",
    listitem: "listitem",
    progressbar: "progressbar",
    search: "searchbox",
};

// What a state is written as, which ARIA spells out one attribute at a time.
const STATES = {
    checked: "aria-checked",
    selected: "aria-selected",
    disabled: "aria-disabled",
    expanded: "aria-expanded",
    busy: "aria-busy",
};

// What a reading is written as, which is what lets a reader step a slider by voice.
const READINGS = {
    now: "aria-valuenow",
    least: "aria-valuemin",
    most: "aria-valuemax",
    text: "aria-valuetext",
};

// How many of the values a field reported it holds against a commit that is still on its way.
const SAID = 64;

// How long the browser has to stop scrolling before it counts as settled.
const SETTLED = 120;

// How far a surface is dragged past its top before it counts as a pull to refresh.
//
// A phone's own control decides this for itself, and the browser has no such control, so this is the
// one place the web has to name a number the platform would otherwise have named.
const PULL = 72;

// Where the control a pull reveals sits, and how large it is drawn.
const PULLED = 10;
const SPINNER = 22;

// What a line is taken to be when the browser will not say what the font's own line height is.
const NATURAL_LINE = 1.35;

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

// The types that carry a caption beside the control itself.
//
// A checkbox and a radio are void elements: a browser draws nothing inside one, so the text written on
// them went nowhere at all. A label holding the control and its caption is what a form is written as,
// and it also makes the caption press the control, which is what a person expects of one.
const CAPTIONED = new Set(["checkbox", "radio"]);

// The types a reader types into, where an input method may be part way through a word.
const TYPING = new Set(["textinput", "textarea", "searchbar"]);

// What a toolbar may ask of an editor, which is a mark, a link, the clipboard or the whole document.
const EDITING = new Set(["toggleMark", "setLink", "clearLink", "copy", "cut", "paste", "selectAll"]);

// The types the browser already answers a keyboard on, which are the ones it drew itself.
const REACHED = new Set(["button", "textinput", "textarea", "searchbar", "picker", "slider", "switch",
    "checkbox", "radio", "datepicker", "timepicker", "colorpicker", "filepicker", "richeditor"]);

// The tag each mark is written as, and what a browser writes when it applies one itself.
//
// Every editor on every platform carries the same six, and each is drawn with what the platform draws
// its own bold and its own monospace with rather than with a weight or a family the tree named.
const MARKED = {
    B: "bold", STRONG: "bold",
    I: "italic", EM: "italic",
    U: "underline",
    S: "strikethrough", STRIKE: "strikethrough", DEL: "strikethrough",
    CODE: "code",
};

export class WebRenderer {
    constructor(container, emit) {
        this.container = container;
        this.emit = emit;
        this.nodes = new Map();
        this.listeners = new Map();
        this.fonts = new Set();
        this.scale = window.devicePixelRatio || 1;

        // What each control measured, since measuring one appends it and reads its box back, which makes
        // the browser lay the page out again in the middle of a frame the engine is still building.
        this.controlSizes = new Map();

        // The line each font draws in, which is a property of the face rather than of any string in it.
        this.naturalLines = new Map();

        this.capture = new Capture((id, name, payload) => this.emit(id, name, payload));

        installSheet(document);
        container.addEventListener?.("pointerdown", (event) => {
            this.takeWholeScreen();
            this.dismissOnPress(event);
        });
        this.watchTravel(container);

        this.capabilities = {
            text: true, image: true, list: true, scroll: true, input: true,
            video: true, webview: true, canvas: true, audio: true, map: true, location: true,
            gradient: true, nineSlice: true, blur: true, systemBars: false,
            picker: true, datepicker: true,
            haptics: false, safearea: true, fontBytes: true, imageBytes: true, address: true,
            camera: Capture.available(), microphone: Capture.available(),
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

    // Builds the element a type is drawn as, with the parts the browser has no control of its own for.
    //
    // What a node is made of is worked out here rather than in create, since a size is only the size the
    // browser draws a control at once the control is the one it will draw: a probe that is a bare element
    // carries neither the rules the stylesheet keys on the type nor the parts the control is built from,
    // and answers a size no control on the page ever has.
    build(type) {
        const tag = TAGS[type];
        if (tag === undefined) {
            throw new Error(`the renderer has no element for ${type}`);
        }

        const element = document.createElement(tag);
        element.dataset.varnType = type;
        element.style.position = "absolute";
        element.style.boxSizing = "border-box";
        element.style.margin = "0";

        // A button and a field carry a look of their own from the user agent, which the style is what
        // decides instead, so the parts the style does not name are cleared rather than left showing.
        //
        // A field is the one a screen notices: an application draws a search pill and puts an editable
        // run inside it, and the run arrives with a border, a white ground and a font of its own, so the
        // pill has a second box sitting in it. What the platform owns is the caret, the selection and the
        // keyboard, and the box around them belongs to whoever wrote the screen.
        if (type === "button") {
            element.style.font = "inherit";
            element.style.cursor = "pointer";
            element.style.appearance = "none";
        }

        // A range takes whole numbers until it is told otherwise, so a slider running from nought to one
        // could only ever be at either end: four tenths was rounded to nought and stayed there. A slider
        // the tree gave no step to is continuous, which is what the platform's own slider is.
        if (type === "slider") {
            element.step = "any";
        }

        if (type === "textinput" || type === "textarea" || type === "searchbar") {
            element.style.font = "inherit";
            element.style.color = "inherit";
            element.style.background = "transparent";
            element.style.border = "none";
            element.style.outline = "none";
            element.style.appearance = "none";
        }

        let control = element;
        let caption = null;

        if (CAPTIONED.has(type)) {
            control = document.createElement("input");
            caption = document.createElement("span");

            element.style.display = "flex";
            element.style.alignItems = "center";
            element.style.gap = "8px";
            element.appendChild(control);
            element.appendChild(caption);
        }

        // A file chooser is the button its caller titled, with the browser's own chooser hidden inside
        // it. An input drawn as it comes carries a caption of the browser's choosing, in the language of
        // the browser rather than of the application, and drops the title it was given.
        if (type === "filepicker") {
            control = document.createElement("input");
            caption = document.createElement("span");
            control.style.display = "none";

            element.appendChild(caption);
            element.appendChild(control);
            element.addEventListener("click", (event) => {
                if (event.target !== control && !control.disabled) {
                    control.click();
                }
            });
        }

        if (INPUT_TYPES[type] !== undefined) {
            control.type = INPUT_TYPES[type];
        }

        let content = null;

        if (SCROLLING.has(type)) {
            element.style.overflow = "auto";
            content = document.createElement("div");
            content.style.position = "relative";
            content.style.width = "100%";
            element.appendChild(content);
        }

        // A camera is a box with the preview inside it rather than a bare video, since a zoom is a scale
        // and a replaced element does not clip what a scale pushes outside its own box.
        if (type === "camera") {
            control = document.createElement("video");

            element.style.overflow = "hidden";
            control.style.position = "absolute";
            control.style.width = "100%";
            control.style.height = "100%";
            control.style.objectFit = "cover";
            control.autoplay = true;
            control.muted = true;
            control.playsInline = true;

            element.appendChild(control);
        }

        if (PARTED.has(type)) {
            element.style.display = "flex";
            element.style.alignItems = "center";
        }

        const parts = type === "stepper" ? WebRenderer.stepperParts(element) : null;

        return { element, control, caption, content, parts };
    }

    create({ id, type, props }) {
        const { element, control, caption, content, parts } = this.build(type);
        element.dataset.varnId = String(id);

        const node = {
            id, element, control, caption, content, parts, type,
            props: {}, listeners: new Map(), settled: false,
        };
        this.nodes.set(id, node);

        if (SCROLLING.has(type)) {
            element.addEventListener("scroll", () => this.dismissOnDrag(element));
        }

        if (type === "stepper") {
            this.watchStepper(node);
            this.showCount(node, 0);
        }

        if (TYPING.has(type)) {
            this.watchComposing(node);
        }

        if (type === "nineslice") {
            this.watchFrame(node);
        }

        if (type === "richeditor") {
            this.watchEditor(node);
        }

        if (type === "map") {
            node.place = new VarnTileMap(element, (name, payload) => this.report(node, name, payload));
        }

        if (type === "location") {
            node.place = new VarnLocation((name, payload) => this.report(node, name, payload));
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
            } else if (node.place !== undefined) {
                this.applyPlace(node, key, next);
            } else if (EVENTS[key] !== undefined) {
                this.bind(node, id, key, next);

                if (key === "onPress") {
                    this.showPress(node.element, next !== undefined);
                }
            } else {
                this.applyProp(node, key, next);
            }

            node.props[key] = next;
        }

        node.place?.settle();

        // How far a stepper may go and what it is worth are three props of one batch, which arrive in
        // no order, so the value is held to the bounds once all of them are in rather than against
        // whichever of them happened to be applied first.
        if (node.type === "stepper") {
            this.showCount(node, node.count ?? 0);
        }

        if (node.content !== null) {
            this.sizeContent(node);
        }
    }

    // Holds a box against the leading edge of the surface it scrolls in, over the range it was given.
    //
    // The browser is told to follow the surface rather than told where the box goes each time it moves.
    // A scroll is answered by the compositor and a scroll event arrives after the reader is already
    // looking at the next frame, so a position worked out in one is always a frame late, which is what
    // makes a pinned header tremble across the rows it covers.
    pin(node) {
        const range = node.pinned;
        const along = this.surfaceOf(node)?.props.horizontal === true;
        const size = node.frame ?? { width: 0, height: 0 };
        const extent = along ? size.width : size.height;
        const end = range === undefined ? 0 : Math.max(range.from, range.to - extent);

        const wanted = range === undefined ? "" : `${along} ${range.from} ${end}`;

        if (wanted === node.pinning) {
            return;
        }

        node.pinning = wanted;
        const css = node.element.style;

        if (range === undefined) {
            css.animationName = "";
            css.animationTimeline = "";
            css.animationRange = "";
            css.removeProperty("--varn-pin-from");
            css.removeProperty("--varn-pin-to");
            return;
        }

        // The box is followed from the very start of the surface rather than from where its own range
        // begins, which is the same travel inside the range and no step at either end of it. Held from
        // its own start instead, a header the tree had already swapped for the next section sat below
        // the edge until the next commit, and the rows ran through the gap above it.
        css.setProperty("--varn-pin-from", `${-range.from}px`);
        css.setProperty("--varn-pin-to", `${end - range.from}px`);
        css.animationName = along ? "varn-pin-inline" : "varn-pin-block";
        css.animationTimingFunction = "linear";
        css.animationFillMode = "both";
        css.animationDuration = "auto";
        css.animationTimeline = along ? "scroll(nearest inline)" : "scroll(nearest block)";
        css.animationRange = `0px ${end}px`;
    }

    // Answers the surface a box scrolls in, which holds its children in a content layer of its own.
    surfaceOf(node) {
        const element = node.element.parentNode?.parentNode;
        return this.nodes.get(Number(element?.dataset?.varnId));
    }

    // Takes the keyboard away when a scroll view whose caller asked for it is dragged.
    dismissOnDrag(element) {
        const node = this.nodes.get(Number(element.dataset.varnId));

        if (node?.props.keyboardDismissMode !== "on-drag") {
            return;
        }

        document.activeElement?.blur?.();
    }

    // Takes the keyboard away when a press lands anywhere but on what is being typed into.
    //
    // Every application on a phone does this, and nothing in a tree can, since only the surface sees a
    // press that landed on none of its nodes.
    // Asks for the whole screen while a finger is down, which is the only moment a browser grants it.
    takeWholeScreen() {
        if (this.wantsWholeScreen !== true || document.fullscreenElement !== null) {
            return;
        }

        this.container.requestFullscreen?.().catch(() => {});
    }

    dismissOnPress(event) {
        const focused = document.activeElement;

        if (focused === undefined || focused === null || focused === document.body) {
            return;
        }

        if (focused === event.target || focused.contains?.(event.target)) {
            return;
        }

        focused.blur?.();
    }

    // Answers a finger the way the platform answers one, since a control that does not react to a
    // press reads as one that is not listening.
    //
    // A box the tree listens to a press on is a control, whatever it is built out of, so it is also
    // reached with a tab and worked with a return or a space. A browser gives that to the controls it
    // drew itself and to nothing else, and a row nobody can reach is a row a reader with no pointer,
    // or none they can aim, cannot open at all.
    showPress(element, pressable) {
        element.dataset.varnPressable = pressable ? "yes" : "no";
        element.style.cursor = pressable ? "pointer" : "";

        // A handler that comes and goes takes what it made of the box with it, or a row whose press was
        // taken away is left with a hand over it and a tab stop that opens nothing.
        if (!REACHED.has(element.dataset.varnType)) {
            if (pressable) {
                element.setAttribute("tabindex", "0");
                element.setAttribute("role", "button");
            } else {
                element.removeAttribute("tabindex");
                element.removeAttribute("role");
            }
        }

        if (element.dataset.varnPressWatched === "yes") {
            return;
        }

        element.dataset.varnPressWatched = "yes";
        element.style.transition = "opacity 0.22s";

        const down = () => {
            if (element.dataset.varnPressable === "yes") {
                element.style.opacity = "0.55";
            }
        };

        const up = () => { element.style.opacity = ""; };

        element.addEventListener("pointerdown", down);
        element.addEventListener("pointerup", up);
        element.addEventListener("pointercancel", up);
        element.addEventListener("pointerleave", up);

        element.addEventListener("keydown", (event) => {
            if (element.dataset.varnPressable !== "yes" || (event.key !== "Enter" && event.key !== " ")) {
                return;
            }

            event.preventDefault();
            element.click();
        });
    }

    // Watches for a word an input method is composing, which is a guess the browser is holding rather
    // than text the field carries.
    //
    // A reader writing Japanese, Chinese or Korean types the sound of a word and picks it out of what
    // the browser offers. Writing the tree's own value over the field while that is happening takes the
    // half-written word away, and the return that picks one is not a return that submits.
    watchComposing(node) {
        node.control.addEventListener("compositionstart", () => { node.composing = true; });
        node.control.addEventListener("compositionend", () => { node.composing = false; });
    }

    // The content layer carries the whole scrollable extent, which is what gives the browser something
    // to scroll over while only the realised cells exist.
    sizeContent(node) {
        const horizontal = node.props.horizontal === true;
        const extent = node.props.contentExtent ?? 0;

        node.content.style[horizontal ? "width" : "height"] = `${extent}px`;
        node.content.style[horizontal ? "height" : "width"] = "100%";
    }

    // Answers the paint a run of colours is drawn with, which is the same run at the same angle on
    // every platform because the direction is one of a fixed set rather than an angle in degrees.
    // Paints a box with a picture cut into nine, from the cuts and the scale the node carries.
    static frame(node, element) {
        const cuts = node.slice;

        if (node.source === undefined || cuts === undefined) {
            return;
        }

        const scale = node.sliceScale ?? 1;
        const edges = ["top", "right", "bottom", "left"];

        element.style.borderImageSource = `url("${WebRenderer.artwork(node)}")`;
        element.style.borderImageSlice = `${edges.map((edge) => cuts[edge] ?? 0).join(" ")} fill`;
        element.style.borderImageWidth = edges.map((edge) => `${(cuts[edge] ?? 0) * scale}px`).join(" ");
        element.style.borderImageRepeat = "stretch";
    }

    // Answers the artwork a frame draws for how it is now, which is the plain one where there is none of
    // its own. A frame drawn from artwork is how a button is drawn from artwork, and a button is a
    // different picture while a finger is on it.
    static artwork(node) {
        const named = node.sources ?? {};

        if (node.off === true && named.disabled !== undefined) {
            return named.disabled;
        }

        if (node.pressed === true && named.pressed !== undefined) {
            return named.pressed;
        }

        if (node.hovered === true && named.hovered !== undefined) {
            return named.hovered;
        }

        if (node.focused === true && named.focused !== undefined) {
            return named.focused;
        }

        return node.source;
    }

    static gradient(node) {
        const colors = node.colors ?? [];

        if (colors.length < 2) {
            return "";
        }

        const angle = { up: "0deg", right: "90deg", left: "270deg", diagonal: "135deg" }[node.direction] ?? "180deg";
        const stops = colors.map((color, at) => {
            const location = node.locations?.[at];

            return location === undefined ? color : `${color} ${Math.round(location * 100)}%`;
        });

        return `linear-gradient(${angle}, ${stops.join(", ")})`;
    }

    // Hands a map and a location fix what they were told, since both answer their own props and raise
    // their own events rather than any the browser has of its own.
    applyPlace(node, key, value) {
        if (EVENTS[key] !== undefined || key === "onRegionChange" || key === "onMarkerPress") {
            return;
        }

        if (key === "center") {
            node.place.setCenter(value);
            return;
        }

        if (key === "zoom") {
            node.place.setZoom(value ?? 14);
            return;
        }

        if (key === "markers") {
            node.place.setMarkers(value ?? []);
            return;
        }

        if (key === "interactive") {
            node.place.setInteractive(value);
            return;
        }

        if (key === "watch") {
            node.place.setWatch(value);
            return;
        }

        if (key === "accuracy") {
            node.place.setAccuracy(value);
            return;
        }

        throw new Error(`a ${node.type} has no prop named ${key}`);
    }

    applyProp(node, key, value) {
        const { type } = node;

        // A captioned control is a label around the control and its text, so what belongs to the
        // control goes to the control and only the look belongs to the box around it.
        const element = node.control;

        if (key === "label" && node.caption !== null) {
            node.caption.style.whiteSpace = "pre-wrap";
            node.caption.textContent = value ?? "";
            return;
        }

        if (key === "text") {
            // A browser collapses a run of spaces and drops a line break, and the phones keep both, so a
            // string that says where its lines end says it on all three.
            element.style.whiteSpace = "pre-wrap";
            element.textContent = value ?? "";
            return;
        }

        // A picture cut into nine, which the browser draws as a border image: the slice says where the
        // cuts are in the picture's own pixels and the width says how thick they come out. The border
        // itself stays at nothing, so the frame is painted over the box rather than taking room inside
        // it — a border with width would shift every child the engine placed by the thickness of it.
        if (key === "source" && type === "nineslice") {
            node.source = value;
            WebRenderer.frame(node, element);
            return;
        }

        if (key === "slice" || key === "sliceScale" || key === "sources") {
            node[key] = value;
            WebRenderer.frame(node, element);
            return;
        }

        if (key === "source") {
            if (type === "image") {
                element.onerror = () => {
                    if (node.placeholder !== undefined && element.src !== node.placeholder) {
                        element.src = node.placeholder;
                    }
                };
            }

            element.src = value ?? "";
            return;
        }

        // A camera is turned round, zoomed and lit by its props, and a microphone is told to run or not.
        if (key === "facing" || key === "audio") {
            if (node.element.isConnected === true) {
                this.capture.open(node);
            }

            return;
        }

        if (key === "zoom") {
            const preview = Capture.preview(node);
            preview.style.transform = `scale(${Math.max(1, Number(value) || 1)})`;
            return;
        }

        if (key === "torch") {
            this.capture.settle(node);
            return;
        }

        if (key === "recording") {
            this.record(node, value === true);
            return;
        }

        // A picture is drawn through the colour matrix a filter came to.
        if (key === "filter") {
            element.style.filter = this.filter(node, value ?? undefined);
            return;
        }

        // A box with nothing to do with a touch lets it through to whatever sits under it.
        if (key === "pointerEvents") {
            element.style.pointerEvents = value === "none" ? "none" : "";
            return;
        }

        // A control is tinted with the colours it was given rather than the browser's own.
        //
        // A switch and a slider are drawn rather than left to the user agent, since their track and
        // their thumb are pseudo-elements that no colour could otherwise reach, so those read the
        // properties the stylesheet names. Everything else the browser tints from one accent.
        if (key === "onColor" || key === "offColor" || key === "trackColor" || key === "thumbColor") {
            const named = {
                onColor: "--varn-on-color",
                offColor: "--varn-off-color",
                trackColor: "--varn-track-color",
                thumbColor: "--varn-thumb-color",
            }[key];

            if (type === "switch" || type === "slider" || type === "progress") {
                this.paint(element, named, value);
                return;
            }

            if (key === "onColor" || key === "trackColor") {
                element.style.accentColor = value ?? "";
            }

            return;
        }

        // How the system draws its own bars over the page, which the browser takes from the page's
        // colour scheme rather than from any element.
        if (key === "barContent") {
            document.documentElement.style.colorScheme = value === "light" ? "dark" : "light";
            return;
        }

        // A page has no system bars to hide, and what it has instead is full screen, which a reader has
        // to grant and which a browser only grants inside a gesture. So what the page can honour is
        // leaving it once a screen asks for the bars back, and asking for it the next time a finger
        // lands. Asking outright would be refused and the screen would be told nothing.
        if (key === "bars") {
            const shown = new Set(value ?? []);
            this.wantsWholeScreen = shown.size === 0;

            if (!this.wantsWholeScreen && document.fullscreenElement !== null) {
                document.exitFullscreen?.();
            }

            return;
        }

        // A colour on a control rather than on text is the colour of the mark it draws: a tick, a
        // spinner or a bar. A style's colour is the colour of a string, which is a different thing.
        if (key === "color") {
            if (type === "activity") {
                this.paint(element, "--varn-activity-color", value);
                return;
            }

            // A control the renderer draws itself reads the colour rather than the accent, since a
            // browser stops honouring an accent on an element it is no longer drawing for itself.
            if (type === "progress") {
                this.paint(element, "--varn-control-color", value);
                return;
            }

            element.style.accentColor = value ?? "";
            return;
        }

        // A paragraph held to a number of lines is cut off at the last one it may run to, which is what
        // both phones do with a line count of their own.
        if (key === "numberOfLines") {
            const lines = Number(value);

            if (!Number.isFinite(lines) || lines <= 0) {
                element.style.removeProperty("-webkit-line-clamp");
                element.style.display = "";
                element.style.overflow = "";
                return;
            }

            element.style.display = "-webkit-box";
            element.style.setProperty("-webkit-box-orient", "vertical");
            element.style.setProperty("-webkit-line-clamp", String(lines));
            element.style.overflow = "hidden";
            return;
        }

        // A spinner is drawn here, so it is stopped by holding the animation rather than by hiding it.
        if (key === "animating") {
            element.dataset.varnStill = value === false ? "true" : "false";
            return;
        }

        if (key === "placeholderColor") {
            this.paint(element, "--varn-placeholder-color", value);
            return;
        }

        // A press is reported from an area larger than the box, which is what a small control needs to
        // be reachable with a finger. An overlay is what carries it, since a box cannot be hit outside
        // itself and growing the box itself would move everything laid out around it.
        if (key === "hitSlop") {
            const slop = Number(value);

            if (!Number.isFinite(slop) || slop <= 0) {
                delete element.dataset.varnSlop;
                element.style.removeProperty("--varn-hit-slop");
                return;
            }

            element.dataset.varnSlop = "true";
            element.style.setProperty("--varn-hit-slop", `${slop}px`);
            return;
        }

        // A run of colours painted across the box, in one of a fixed set of directions so the same run
        // comes out at the same angle wherever it is drawn.
        if (key === "colors" || key === "locations" || key === "direction") {
            node[key] = value;
            element.style.backgroundImage = WebRenderer.gradient(node);
            return;
        }

        if (key === "intensity" || (key === "tint" && type === "blur")) {
            node[key] = value;
            element.style.backdropFilter = `blur(${Math.round((node.intensity ?? 0.85) * 24)}px)`;
            element.style.webkitBackdropFilter = element.style.backdropFilter;
            element.style.backgroundColor = node.tint ?? "";
            return;
        }

        // A box the surface holds against its leading edge, over the range the tree named, and which is
        // drawn over the rows realised beneath it while the surface moves.
        if (key === "pinned") {
            node.pinned = value;
            element.style.zIndex = value === undefined ? "" : "1";
            this.pin(node);
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

        // An editor holds a tree of elements rather than a string, so the document is written into it
        // only when it is not what the reader already has: writing it back over them takes the caret to
        // the end of it on every keystroke.
        if (key === "value" && type === "richeditor") {
            const written = WebRenderer.written(value, node.props.linkColor);

            if (node.said?.has(written) !== true) {
                element.innerHTML = written;
            }

            node.said?.clear();
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
            // typing into a controlled field would lose their place on every keystroke. What the field
            // itself said a moment ago is not news either: the tree answers a keystroke a commit later,
            // by which time the reader has typed again, and writing it back loses what they typed.
            const text = value ?? "";

            if (node.said?.has(text) || node.composing === true) {
                return;
            }

            if (element.value !== text) {
                element.value = text;
            }

            node.said?.clear();
            return;
        }

        if (key === "bounces") {
            element.style.overscrollBehavior = value === false ? "contain" : "";
            return;
        }

        // A sound has no player of its own — the tree draws one — so it is told what to do and reports
        // where it has got to.
        if (key === "playing") {
            if (value !== true) {
                element.pause?.();
                return;
            }

            // A browser refuses to start a sound a person did not ask for, and answers the refusal to
            // nobody: a play button that does nothing and a page that says nothing about why.
            element.play?.()?.catch((problem) => {
                this.emit(node.id, "onError", { message: String(problem?.message ?? problem) });
            });

            return;
        }

        if (key === "linkColor" && type === "richeditor") {
            node.props.linkColor = value;
            element.innerHTML = WebRenderer.written(node.props.value, value);
            return;
        }

        if (key === "placeholder" && type === "richeditor") {
            element.dataset.varnPlaceholder = value ?? "";
            return;
        }

        if (key === "editable" && type === "richeditor") {
            element.contentEditable = value === false ? "false" : "true";
            return;
        }

        if (key === "accept") {
            element.accept = Array.isArray(value) ? value.join(",") : "";
            return;
        }

        if (key === "multiple") {
            element.multiple = value === true;
            return;
        }

        // Which chooser to open and how much of a file to read are both settled when one is chosen, so
        // neither is written onto the element.
        if (key === "kind" || key === "maxBytes") {
            return;
        }

        // WebKit has no scrollbar-width, so the bar is taken away by a rule on its own pseudo-element
        // and the attribute is what that rule matches on.
        if (key === "showsIndicator") {
            element.setAttribute("data-varn-indicator", value === false ? "false" : "true");
            return;
        }

        if (key === "scrollEnabled" && SCROLLING.has(type)) {
            element.style.overflow = value === false ? "hidden" : "auto";
            return;
        }

        if (key === "secure") {
            element.type = value === true ? "password" : (INPUT_TYPES[type] ?? "text");
            return;
        }

        if (key === "keyboard") {
            element.inputMode = KEYBOARDS[value] ?? "text";
            return;
        }

        if (key === "returnKey") {
            element.enterKeyHint = value ?? "done";
            return;
        }

        // Which drag dismisses the keyboard is decided when a scroll happens, so nothing goes on the
        // element itself.
        if (key === "keyboardDismissMode") {
            return;
        }

        if (key === "indeterminate") {
            if (value === true) {
                element.removeAttribute("value");
            } else {
                element.value = node.props.value ?? 0;
            }

            return;
        }

        // The thickness a bar is drawn at is a height, which the frame the engine sends already carries.
        if (key === "thickness") {
            return;
        }

        // A page has a start the browser raises no event for, so the start is what asking for one is.
        if (key === "url") {
            this.emit(node.id, "onWillLoad", { url: value ?? "" });
            element.src = value ?? "";
            return;
        }

        if (key === "html") {
            this.emit(node.id, "onWillLoad", { url: "" });
            element.srcdoc = value ?? "";
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
            if (type === "image") {
                node.placeholder = value;
                return;
            }

            element.placeholder = value ?? "";
            return;
        }

        if (key === "title" && type === "button") {
            element.style.whiteSpace = "pre-wrap";
            element.textContent = value ?? "";
            return;
        }

        if (key === "title" && type === "filepicker") {
            node.caption.style.whiteSpace = "pre-wrap";
            node.caption.textContent = value ?? "";
            return;
        }

        // A field that takes the keyboard as the screen opens says so, which is what a form with one
        // field wants and what a search screen is. The browser only focuses an element that is in the
        // page, and a node is created before it is inserted.
        if (key === "autoFocus") {
            if (value === true) {
                queueMicrotask(() => (node.control ?? element).focus?.());
            }

            return;
        }

        if (key === "disabled" || key === "editable") {
            element.disabled = key === "editable" ? !value : Boolean(value);

            // A frame that may not be pressed draws the artwork named for that, and a div has no
            // disabled state of its own for a rule to key on.
            if (type === "nineslice") {
                node.off = Boolean(value);
                WebRenderer.frame(node, element);
            }

            return;
        }

        if (key === "visible" || key === "open") {
            element.style.display = value ? "" : "none";
            return;
        }

        // What makes a box a stop on the way through with a keyboard. A box that is listening for a key
        // already takes focus so the key can reach it, and this is a box that says so for itself.
        // Which axis this box claims a drag along, which is what lets a slider inside a list be dragged
        // sideways while the list still scrolls down. The browser answers a scroll on the compositor, so
        // the claim has to be made before the gesture starts rather than when it is recognised.
        if (key === "panAxis") {
            element.style.touchAction = { horizontal: "pan-y", vertical: "pan-x", both: "none" }[value] ?? "";
            return;
        }

        if (key === "focusable") {
            if (value === true) {
                element.tabIndex = 0;
            } else {
                element.removeAttribute("tabindex");
            }

            return;
        }

        if (key === "accessibilityLabel") {
            element.setAttribute("aria-label", value ?? "");
            return;
        }

        // What a box is, what it is doing and what it is at. A control the platform draws says all three
        // for itself and a drawn one is a box with a colour in it, which is what a screen reader hears.
        if (key === "accessibilityRole") {
            if (value === undefined || value === "none") {
                element.removeAttribute("role");
                return;
            }

            element.setAttribute("role", ROLES[value] ?? value);
            return;
        }

        if (key === "accessibilityState") {
            for (const [name, attribute] of Object.entries(STATES)) {
                const held = value?.[name];

                if (held === undefined) {
                    element.removeAttribute(attribute);
                } else {
                    element.setAttribute(attribute, String(held));
                }
            }

            return;
        }

        if (key === "accessibilityValue") {
            for (const [name, attribute] of Object.entries(READINGS)) {
                const held = value?.[name];

                if (held === undefined) {
                    element.removeAttribute(attribute);
                } else {
                    element.setAttribute(attribute, String(held));
                }
            }

            return;
        }

        // The browser raises nothing for a pull, so the drag is watched for as long as one is listened for.
        if (key === "onRefresh") {
            if (value !== undefined) {
                this.bindRefresh(node);
            }

            return;
        }

        if (key === "commands") {
            this.draw(node, Array.isArray(value) ? value : []);
            return;
        }

        // The browser has no pull to refresh of its own, so the drag is watched and the spinner drawn.
        if (key === "refreshing") {
            this.showRefreshing(node, value === true);
            return;
        }

        // A surface that pages comes to rest on a whole one, which the browser does for itself once it is
        // told which edges to rest against. Which axis that is arrives as a prop of its own, and props
        // arrive in no order, so either of them settles it.
        if (key === "paging" || key === "horizontal") {
            node.props[key] = value;
            this.showPaging(node);
            return;
        }

        if (key === "contentExtent") {
            return;
        }

        if (key === "testID") {
            element.dataset.testid = value ?? "";
        }
    }

    // Answers how long a change to this node should take, or nothing when it is to be drawn at once.
    //
    // A curve arrives as its four control points, which is exactly what `cubic-bezier` takes, so a name
    // never has to mean the same thing in three places.
    motion(node) {
        const carried = node.props.transition;

        if (carried === undefined || carried === null) {
            return null;
        }

        const duration = Number(carried.duration) || 0;

        if (duration <= 0) {
            return null;
        }

        const easing = Array.isArray(carried.easing) ? carried.easing : [];
        const point = (at) => Number(easing[at]) || 0;

        return {
            duration,
            delay: Number(carried.delay) || 0,
            curve: `cubic-bezier(${point(0)}, ${point(1)}, ${point(2)}, ${point(3)})`,
        };
    }

    // Puts a node on screen in the state it arrives from and moves it to the one it settles at.
    //
    // The arrival is drawn a frame after the node is placed: a node given both states in the same frame
    // is only ever painted in the second of them, so there is nothing to move from.
    arrive(node) {
        const entering = node.props.enter;
        const timing = this.motion(node);

        if (entering === undefined || entering === null || timing === null) {
            node.settled = true;
            return;
        }

        const settled = node.props.style ?? {};

        this.applyStyle(node, { ...settled, ...entering });
        node.settled = true;

        const soon = globalThis.requestAnimationFrame ?? ((fn) => setTimeout(fn, 0));
        soon(() => this.applyStyle(node, settled));
    }

    applyStyle(node, style) {
        const css = node.element.style;

        // Only what the compositor can move is allowed to animate. A frame writes the position and the
        // size, so animating everything would slide every node the layout moved rather than the ones
        // the tree asked to move, which is what the phones do too.
        const timing = node.settled ? this.motion(node) : null;

        css.transition = timing === null
            ? ""
            : `opacity ${timing.duration}ms ${timing.curve} ${timing.delay}ms,`
                + ` transform ${timing.duration}ms ${timing.curve} ${timing.delay}ms`;

        // Layout arrives as a frame, so only what a frame does not carry is set here.
        // The colour a style names is written as the colour rather than through the shorthand, which
        // clears the picture with it: a gradient paints one and the style that follows wiped it out.
        css.backgroundColor = style.background ?? "";
        css.color = style.color ?? "";
        css.opacity = style.opacity ?? "";
        css.borderRadius = style.radius !== undefined ? `${style.radius}px` : "";
        css.fontSize = style.fontSize !== undefined ? `${style.fontSize}px` : "";
        css.fontWeight = style.fontWeight ?? "";
        css.fontFamily = style.fontFamily ?? "";
        css.fontStyle = style.fontStyle ?? "";
        css.lineHeight = `${this.lineOf(style)}px`;
        css.letterSpacing = style.letterSpacing !== undefined ? `${style.letterSpacing}px` : "";
        css.textAlign = style.textAlign ?? "";
        css.textDecoration = style.textDecoration ?? "";
        // A scrolling type owns its overflow, so a style that names none may not clear it and stop the
        // list scrolling at all.
        css.overflow = style.overflow ?? (SCROLLING.has(node.type) ? "auto" : "");
        // What a style does not name is cleared rather than written as nothing of its own. The chrome a
        // user agent draws on a control is taken away by a rule, and a control the browser has none of
        // is drawn by one: writing `none` here took the ring off every spinner on the page.
        css.borderColor = style.borderColor ?? "";
        css.borderStyle = style.borderColor !== undefined ? "solid" : "";
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
            segment.dataset.varnChosen = String(at + 1 === index);
        }
    }

    // Builds the stars a rating is made of, each reporting the score it stands for.
    applyStars(node, count) {
        WebRenderer.empty(node.element);
        node.parts = [];

        for (let at = 0; at < count; at += 1) {
            const star = document.createElement("span");

            star.textContent = "★";
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
    static stepperParts(element) {
        const less = document.createElement("button");
        const readout = document.createElement("span");
        const more = document.createElement("button");

        for (const [button, glyph] of [[less, "−"], [more, "+"]]) {
            button.textContent = glyph;
        }

        readout.textContent = "0";

        element.appendChild(less);
        element.appendChild(readout);
        element.appendChild(more);

        return [less, readout, more];
    }

    watchStepper(node) {
        for (const [button, by] of [[node.parts[0], -1], [node.parts[2], 1]]) {
            button.addEventListener("click", () => {
                this.showCount(node, (node.count ?? 0) + by * (node.props.step ?? 1));
                this.report(node, "onChange", node.count);
            });
        }
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
            `translate(${this.travel(transform.translateX)}, ${this.travel(transform.translateY)})`,
            `scale(${transform.scaleX}, ${transform.scaleY})`,
            `rotate(${transform.rotate}deg)`,
        ].join(" ");
    }

    // Applies the colour matrix a filter came to, which the browser has one primitive for.
    //
    // The shorthand functions are what a page usually writes, but the engine sends a matrix so that three
    // platforms cannot each round their own way, and a matrix reaches the browser only through a filter
    // element the style points at. It is declared to work in the colours it was given, since a filter
    // primitive is defined to work in linear light and neither phone does.
    filter(node, matrix) {
        if (matrix === undefined) {
            node.filter?.remove();
            node.filter = undefined;
            return "";
        }

        if (node.filter === undefined) {
            const filter = document.createElementNS("http://www.w3.org/2000/svg", "filter");
            const values = document.createElementNS("http://www.w3.org/2000/svg", "feColorMatrix");

            filter.setAttribute("id", `varn-filter-${node.id}`);
            filter.setAttribute("color-interpolation-filters", "sRGB");
            values.setAttribute("type", "matrix");

            filter.appendChild(values);
            this.definitions().appendChild(filter);

            node.filter = filter;
            node.filterMatrix = values;
        }

        node.filterMatrix.setAttribute("values", matrix.join(" "));
        return `url(#varn-filter-${node.id})`;
    }

    // Where the filters a page needs are declared, which is one drawing of no size holding all of them.
    definitions() {
        if (this.filters === undefined) {
            this.filters = document.createElementNS("http://www.w3.org/2000/svg", "svg");

            this.filters.setAttribute("width", "0");
            this.filters.setAttribute("height", "0");
            this.filters.style.position = "absolute";

            this.container.appendChild(this.filters);
        }

        return this.filters;
    }

    // A travel written as a percentage is a share of the node's own size, which is the only way a panel
    // says it leaves by its own edge without the tree knowing how tall it turned out to be.
    travel(value) {
        return typeof value === "string" && value.endsWith("%") ? value : `${value}px`;
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

            if (name === "onPanStart") {
                this.beginPan(node, id, event);
            }

            const payload = this.payload(node, name, event);

            if (name === "onChange" && typeof payload === "string") {
                node.said = node.said ?? new Set();
                node.said.add(payload);

                // What it remembers is what a commit could still be carrying, not the whole of what was
                // ever typed into it.
                if (node.said.size > SAID) {
                    node.said.delete(node.said.values().next().value);
                }
            }

            this.emit(id, name, payload);
        };

        for (const type of types) {
            node.element.addEventListener(type, fn);
        }

        node.listeners.set(name, { types, fn });

        // A surface asked where it is answers now rather than the next time a finger moves it. The engine
        // asks because it has to lift a field clear of the keyboard and put the surface back afterwards,
        // and neither is worked out correctly against an offset nobody has ever reported.
        if (name === "onScroll") {
            this.emit(id, "onScroll", this.payload(node, "onScroll", null));
        }
    }

    // Watches an editor, which is the one control the browser holds as a tree of elements rather than as
    // a string. What a reader typed is read back out of that tree as runs, and where the caret is and
    // what is on there are reported so a toolbar can show it.
    watchEditor(node) {
        const element = node.element;

        element.contentEditable = "true";
        element.style.whiteSpace = "pre-wrap";
        element.style.outline = "none";

        // A browser asked to apply a mark writes either a tag or a style of its own, and only the tags
        // survive being read back and written again, so it is told which to write once.
        document.execCommand?.("styleWithCSS", false, false);

        element.addEventListener("input", () => {
            const runs = WebRenderer.runsOf(element);

            // A tree answers a keystroke with the document it has just been told, and by then the reader
            // has typed two more, so what the editor said itself is ignored the way a field's value is.
            node.said = node.said ?? new Set();
            node.said.add(WebRenderer.written(runs, node.props.linkColor));

            if (node.said.size > SAID) {
                node.said.delete(node.said.values().next().value);
            }

            this.emit(node.id, "onChange", runs);
            this.reportCaret(node);
        });

        for (const name of ["keyup", "pointerup", "focus"]) {
            element.addEventListener(name, () => this.reportCaret(node));
        }
    }

    // Says where the caret is and what is on there, which is what a toolbar draws itself from.
    reportCaret(node) {
        const marks = {};

        for (const name of ["bold", "italic", "underline", "strikethrough"]) {
            const asked = name === "strikethrough" ? "strikeThrough" : name;

            if (document.queryCommandState?.(asked) === true) {
                marks[name] = true;
            }
        }

        const where = WebRenderer.caret(node.element);

        this.emit(node.id, "onSelectionChange", { start: where.start, end: where.end, marks });
    }

    // Answers where the selection is, as a count of the characters before each end of it.
    //
    // A browser holds a selection as a node and an offset inside it, and the tree counts in characters
    // like every other platform, so the two are joined by walking what stands before each end.
    static caret(element) {
        const selection = document.getSelection?.();

        if (selection === null || selection === undefined || selection.rangeCount === 0) {
            return { start: 0, end: 0 };
        }

        const range = selection.getRangeAt(0);

        if (!element.contains(range.startContainer)) {
            return { start: 0, end: 0 };
        }

        const before = range.cloneRange();

        before.selectNodeContents(element);
        before.setEnd(range.startContainer, range.startOffset);

        const start = before.toString().length;

        return { start, end: start + range.toString().length };
    }

    // Answers the document as runs, which is what the tree holds and what the next write is built from.
    static runsOf(element) {
        const runs = [];

        const walk = (node, marks) => {
            if (node.nodeType === 3) {
                if (node.data !== "") {
                    runs.push({ text: node.data, marks: { ...marks } });
                }

                return;
            }

            if (node.nodeName === "BR") {
                runs.push({ text: "\n", marks: { ...marks } });
                return;
            }

            const held = { ...marks };
            const named = MARKED[node.nodeName];

            if (named !== undefined) {
                held[named] = true;
            }

            if (node.nodeName === "A") {
                held.link = node.getAttribute("href") ?? "";
            }

            // A browser may write a style rather than a tag, and an application may paste one in.
            const style = node.style ?? {};
            const decoration = String(style.textDecoration ?? "") + String(style.textDecorationLine ?? "");

            if (style.fontWeight === "bold" || Number(style.fontWeight) >= 600) {
                held.bold = true;
            }

            if (style.fontStyle === "italic") {
                held.italic = true;
            }

            if (decoration.includes("underline")) {
                held.underline = true;
            }

            if (decoration.includes("line-through")) {
                held.strikethrough = true;
            }

            for (const child of node.childNodes) {
                walk(child, held);
            }

            // A block is a line of its own, which is a break wherever the tree reads the document.
            if (node.nodeName === "DIV" || node.nodeName === "P") {
                runs.push({ text: "\n", marks: {} });
            }
        };

        for (const child of element.childNodes) {
            walk(child, {});
        }

        return WebRenderer.joined(runs);
    }

    // Answers the runs with neighbours carrying the same marks written as one, which is what a document
    // a person would write looks like: three characters typed in bold are one run rather than three.
    static joined(runs) {
        const held = [];

        for (const run of runs) {
            const last = held[held.length - 1];

            if (last !== undefined && WebRenderer.same(last.marks, run.marks)) {
                last.text += run.text;
                continue;
            }

            held.push({ text: run.text, marks: run.marks });
        }

        return held.filter((run) => run.text !== "");
    }

    static same(one, other) {
        const names = new Set([...Object.keys(one), ...Object.keys(other)]);

        for (const name of names) {
            if (one[name] !== other[name]) {
                return false;
            }
        }

        return true;
    }

    // Answers the document as html, which is what a browser edits a tree of elements as.
    static written(runs, tint) {
        const escaped = (text) => text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

        return (runs ?? []).map((run) => {
            const marks = run.marks ?? {};
            let held = escaped(run.text ?? "");

            if (marks.code === true) {
                held = `<code>${held}</code>`;
            }

            if (marks.strikethrough === true) {
                held = `<s>${held}</s>`;
            }

            if (marks.underline === true) {
                held = `<u>${held}</u>`;
            }

            if (marks.italic === true) {
                held = `<i>${held}</i>`;
            }

            if (marks.bold === true) {
                held = `<b>${held}</b>`;
            }

            if (typeof marks.link === "string") {
                const where = escaped(marks.link).replace(/"/g, "&quot;");
                held = `<a href="${where}" style="color:${tint ?? "inherit"}">${held}</a>`;
            }

            return held;
        }).join("");
    }

    // Watches what a frame is doing, since a frame drawn from artwork is how a button is drawn from one
    // and a button is a different picture while a finger is on it. A rule cannot do it: the artwork is a
    // path the engine resolved rather than anything the stylesheet can name.
    watchFrame(node) {
        const set = (name, held) => {
            node[name] = held;
            WebRenderer.frame(node, node.element);
        };

        node.element.addEventListener("pointerdown", () => set("pressed", true));
        node.element.addEventListener("pointerup", () => set("pressed", false));
        node.element.addEventListener("pointercancel", () => set("pressed", false));
        node.element.addEventListener("pointerleave", () => {
            node.pressed = false;
            set("hovered", false);
        });

        node.element.addEventListener("pointerenter", (event) => {
            if (event.pointerType === "mouse" || event.pointerType === "pen") {
                set("hovered", true);
            }
        });

        node.element.addEventListener("focus", () => set("focused", true));
        node.element.addEventListener("blur", () => set("focused", false));
    }

    // Watches how far a finger goes, which is what tells a press from a swipe.
    //
    // It is watched on the surface rather than per node, since a pointer that leaves the node it landed
    // on still raises the click on whatever both ends have in common.
    watchTravel(container) {
        let landed = null;

        const lift = (event) => {
            if (landed !== null && event.pointerId === landed.pointer) {
                landed = null;
            }
        };

        container.addEventListener?.("pointerdown", (event) => {
            landed = {
                x: event.clientX ?? 0,
                y: event.clientY ?? 0,
                pointer: event.pointerId,
                from: event.target,
            };

            for (const node of this.nodes.values()) {
                node.travelled = false;
            }
        });

        container.addEventListener?.("pointermove", (event) => {
            // A gesture lasts from the moment a pointer goes down until it comes up, and a pointer moving
            // with nothing held is a mouse crossing the page. Watching a move without either was a swipe
            // reported minutes after the press it belonged to, on a control nobody was touching.
            if (landed === null || event.pointerId !== landed.pointer || event.buttons === 0) {
                return;
            }

            const across = (event.clientX ?? 0) - landed.x;
            const down = (event.clientY ?? 0) - landed.y;

            if (Math.abs(across) <= TRAVEL && Math.abs(down) <= TRAVEL) {
                return;
            }

            // Only what was swiped gives its press up: a finger on a screen is never still, and a press
            // held to a distance is a control a reader has to press three times to be heard once.
            const swept = this.swept(landed.from, across, down);

            landed = null;

            if (swept !== undefined) {
                swept.travelled = true;
            }
        });

        container.addEventListener?.("pointerup", lift);
        container.addEventListener?.("pointercancel", lift);
    }

    // Reports the way a finger went to whatever it landed on that asked to hear about one.
    swept(target, across, down) {
        const direction = Math.abs(across) >= Math.abs(down)
            ? (across < 0 ? "left" : "right")
            : (down < 0 ? "up" : "down");

        let element = target;

        while (element != null) {
            const node = this.nodes.get(Number(element.dataset?.varnId));

            if (node !== undefined && node.props.onSwipe !== undefined) {
                this.emit(node.id, "onSwipe", { direction });
                return node;
            }

            element = element.parentNode;
        }

        return undefined;
    }

    // A slider dragged with the finger down raises `input`, and one let go of raises `change`, so a
    // control that reports both ways is listening to both.
    listensTo(node, name) {
        if (name === "onChange" && node.type === "slider") {
            return ["input", "change"];
        }

        // A browser raises no event for a selection moving inside a field, so the moments a caret can
        // have moved are what is watched: a key, a pointer coming up, and the field being reached.
        if (name === "onSelectionChange") {
            return ["keyup", "pointerup", "select", "focus"];
        }

        return [EVENTS[name]];
    }

    // A slider reports every position it passes through, unless the tree asked to hear only the one it
    // was left at. The prop may arrive after the handler, so this is decided when an event fires rather
    // than when the listener is attached.
    reports(node, name, event) {
        // A finger that travels is not a press. A browser raises `click` whenever a pointer goes down and
        // comes up on one element however far it went between, so a swipe across a row the width of the
        // screen counted as opening it.
        // A press is given up to the gesture that beat it, which on a page is the swipe the tree asked
        // for and the scroll the browser answers itself. A distance is not one of those, since a finger
        // is never still, and a click the keyboard raised carries no finger behind it at all.
        if (name === "onPress") {
            return event.detail === 0 || !node.travelled;
        }

        // A hover is a pointer resting somewhere without pressing, which a finger cannot do: a browser
        // raises both of these around every tap, so a row would light up under a finger and stay lit.
        if (name === "onHoverIn" || name === "onHoverOut") {
            return event.pointerType === "mouse" || event.pointerType === "pen";
        }

        // A form-less input never raises `submit`, so a field reports what it holds when the return key
        // is pressed, and the key dismisses it the way it does on a phone.
        if (name === "onSubmit") {
            if (event.key !== "Enter" || event.isComposing === true) {
                return false;
            }

            if (node.props.returnKey !== "next") {
                node.control.blur();
            }

            return true;
        }

        // The browser raises no settled event, so one is taken to have happened when the scrolling stops
        // for long enough that another is not on its way.
        if (name === "onScrollEnd") {
            clearTimeout(node.settling);
            node.settling = setTimeout(() => {
                this.emit(node.id, "onScrollEnd", this.payload(node, "onScroll", event));
            }, SETTLED);

            return false;
        }

        // A chosen file is read before it is reported and a browser only reads one asynchronously, so
        // the reading is what emits rather than the change that started it.
        if (name === "onPick") {
            this.picked(node);
            return false;
        }

        if (name !== "onChange" || node.type !== "slider") {
            return true;
        }

        return (node.props.continuous === false) === (event.type === "change");
    }

    // Reads what was chosen and reports each one as it is ready.
    //
    // Gathering the whole set first put the bytes of every picture into one message, which is decoded and
    // written in a single turn of the loop: nothing moved until the last one landed.
    async picked(node) {
        const limit = Number(node.props.maxBytes) || 0;

        for (const file of Array.from(node.control.files ?? [])) {
            const within = limit === 0 || file.size <= limit;

            this.emit(node.id, "onPick", {
                name: file.name,
                size: file.size,
                type: file.type === "" ? "application/octet-stream" : file.type,
                bytes: within ? await this.encode(file) : null,
            });
        }
    }

    // Answers a file as the base64 the bridge carries it in, which is what a data url already holds.
    encode(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => resolve(String(reader.result).slice(String(reader.result).indexOf(",") + 1));
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    /**
     * Follows a finger from where it landed until it is lifted, reporting every point between.
     *
     * The pointer is captured so the drag keeps reaching this box once the finger has left it, which is
     * what makes a slider follow a finger that has wandered off the track.
     */
    beginPan(node, id, event) {
        const box = node.element.getBoundingClientRect?.() ?? { left: 0, top: 0 };
        const from = { x: (event.clientX ?? 0) - box.left, y: (event.clientY ?? 0) - box.top };

        node.element.setPointerCapture?.(event.pointerId);

        const at = (moved) => ({
            x: (moved.clientX ?? 0) - box.left,
            y: (moved.clientY ?? 0) - box.top,
            dx: (moved.clientX ?? 0) - box.left - from.x,
            dy: (moved.clientY ?? 0) - box.top - from.y,
        });

        const moved = (held) => this.emit(id, "onPanMove", at(held));

        const ended = (held) => {
            node.element.removeEventListener("pointermove", moved);
            node.element.removeEventListener("pointerup", ended);
            node.element.removeEventListener("pointercancel", ended);
            node.element.releasePointerCapture?.(event.pointerId);

            this.emit(id, "onPanEnd", at(held));
        };

        node.element.addEventListener("pointermove", moved);
        node.element.addEventListener("pointerup", ended);
        node.element.addEventListener("pointercancel", ended);
    }

    payload(node, name, event) {
        // What a control was changed to, what it was left at and which of a set was chosen are all the
        // same reading. A slider reports the first two: one for every position a finger passes through,
        // one for where it let go.
        if (name === "onChange" || name === "onCommit" || name === "onSelect") {
            const element = node.control;

            if (element.type === "checkbox" || element.type === "radio") {
                return element.checked;
            }

            return element.type === "range" ? Number(element.value) : element.value;
        }

        if (name === "onScroll") {
            return { x: node.element.scrollLeft, y: node.element.scrollTop };
        }

        // The second button on a mouse, which is the same gesture as a long press with a finger. What it
        // opens is drawn where it happened, so where it happened is what it carries.
        if (name === "onPanStart") {
            const box = node.element.getBoundingClientRect?.() ?? { left: 0, top: 0 };

            return {
                x: (event.clientX ?? 0) - box.left,
                y: (event.clientY ?? 0) - box.top,
                dx: 0,
                dy: 0,
            };
        }

        if (name === "onContextPress") {
            const box = node.element.getBoundingClientRect?.() ?? { left: 0, top: 0 };

            event.preventDefault?.();

            return { x: (event.clientX ?? 0) - box.left, y: (event.clientY ?? 0) - box.top };
        }

        // A key is named the way the browser names it, which is the one published set of names the
        // other two platforms are mapped onto.
        if (name === "onKeyDown" || name === "onKeyUp") {
            return {
                key: event.key,
                shift: event.shiftKey === true,
                ctrl: event.ctrlKey === true,
                alt: event.altKey === true,
                meta: event.metaKey === true,
                repeat: event.repeat === true,
            };
        }

        if (name === "onSelectionChange") {
            const control = node.control ?? node.element;

            return { start: control.selectionStart ?? 0, end: control.selectionEnd ?? 0, marks: {} };
        }

        if (name === "onProgress") {
            const whole = node.element.duration;

            return {
                position: node.element.currentTime ?? 0,
                duration: Number.isFinite(whole) ? whole : 0,
            };
        }

        if (name === "onReady") {
            const whole = node.element.duration;

            return { duration: Number.isFinite(whole) ? whole : 0 };
        }

        if (name === "onLoad" && node.type === "webview") {
            return { url: node.props.url ?? "" };
        }

        // An event that carries nothing carries nothing, which is what the phones send. An empty table
        // is a value a handler can read fields off, so a handler written against one of them broke on
        // the others.
        return null;
    }

    place({ id, parent, index }) {
        const node = this.expect(id);

        // A layer is drawn over the whole application rather than where it was written, and the engine
        // lays it out against the surface, so the surface is what it hangs from. A box with a border of
        // its own, one that clips what it holds, or one that is moved by a transition would each take an
        // overlay written inside it with them.
        if (node.type === "layer") {
            node.element.remove();
            this.container.appendChild(node.element);

            if (!node.settled) {
                this.arrive(node);
            }

            return;
        }

        const holder = parent === 0 ? null : this.expect(parent);
        const target = holder === null ? this.container : (holder.content ?? holder.element);

        // The index counts the siblings the node is not among, so it leaves the list before it is read.
        node.element.remove();

        const reference = target.children[index - 1];
        target.insertBefore(node.element, reference ?? null);

        // A camera is opened once it is on the page rather than as it is built, since a reader who leaves
        // while the browser is still asking must not be left with a device running behind an empty screen.
        if (node.type === "camera" && !this.capture.streams.has(node.id)) {
            this.capture.open(node);
        }

        if (!node.settled) {
            this.arrive(node);
        }
    }

    // Draws what the tree asked for onto a canvas, which is the one node that carries its own picture.
    //
    // The bitmap is sized from the frame the engine sent rather than from the box the browser has, since
    // props are applied before the frame that gives the element a size and a canvas of no size draws
    // nothing at all.
    draw(node, commands) {
        const canvas = node.element;
        const context = canvas.getContext?.("2d");
        const box = node.frame;

        if (context === undefined || context === null || box === undefined) {
            return;
        }

        canvas.width = Math.round(box.width * this.scale);
        canvas.height = Math.round(box.height * this.scale);
        context.setTransform(this.scale, 0, 0, this.scale, 0, 0);
        context.clearRect(0, 0, box.width, box.height);

        for (const command of commands) {
            if (command.op === "fill" || command.op === "stroke") {
                const points = (command.path ?? []).filter((point) => point?.length >= 2);

                if (points.length < 2) {
                    continue;
                }

                context.beginPath();
                context.moveTo(points[0][0], points[0][1]);

                for (const point of points.slice(1)) {
                    context.lineTo(point[0], point[1]);
                }

                if (command.op === "fill") {
                    context.closePath();
                    context.fillStyle = command.color ?? "#000000";
                    context.fill();
                    continue;
                }

                context.strokeStyle = command.color ?? "#000000";
                context.lineWidth = command.width ?? 1;
                context.stroke();
                continue;
            }

            if (command.op === "text") {
                const size = command.size ?? 15;

                context.font = `${size}px system-ui, sans-serif`;
                context.fillStyle = command.color ?? "#000000";
                context.textBaseline = "top";
                context.fillText(command.text ?? "", command.x ?? 0, command.y ?? 0);
            }
        }
    }

    // Rests a paging surface against the edge of a whole page, along the axis it scrolls.
    showPaging(node) {
        if (node.props.paging !== true) {
            delete node.element.dataset.varnPaging;
            node.element.style.scrollSnapType = "";
            return;
        }

        node.element.dataset.varnPaging = "true";
        node.element.style.scrollSnapType = `${node.props.horizontal === true ? "x" : "y"} mandatory`;
    }

    // Watches for a surface dragged past its own top, which is what a pull to refresh is.
    bindRefresh(node) {
        if (node.pulling !== undefined) {
            return;
        }

        const element = node.element;
        let from = null;

        const down = (event) => {
            from = element.scrollTop <= 0 ? event.clientY : null;
        };

        const move = (event) => {
            if (from === null || node.props.refreshing === true || event.buttons === 0) {
                return;
            }

            const pulled = event.clientY - from;

            if (pulled <= 0) {
                return;
            }

            this.showPull(node, Math.min(1, pulled / PULL));

            if (pulled < PULL) {
                return;
            }

            from = null;
            this.report(node, "onRefresh", null);
        };

        const up = () => {
            from = null;

            if (node.props.refreshing !== true) {
                this.showPull(node, 0);
            }
        };

        node.pulling = { down, move, up };

        element.addEventListener("pointerdown", down);
        element.addEventListener("pointermove", move);
        element.addEventListener("pointerup", up);
        element.addEventListener("pointercancel", up);
    }

    // The control a pull reveals, which the browser has none of.
    //
    // It is placed by an offset rather than by a transform, since the rule that turns it animates the
    // transform and took the placement with it: the spinner swung around a corner off to one side
    // instead of turning where it was put.
    puller(node) {
        if (node.spinner === undefined) {
            const spinner = document.createElement("div");

            spinner.dataset.varnType = "activity";
            spinner.dataset.varnStill = "true";
            spinner.style.position = "absolute";
            spinner.style.top = `${PULLED}px`;
            spinner.style.left = "50%";
            spinner.style.marginLeft = `${-SPINNER / 2}px`;
            spinner.style.width = `${SPINNER}px`;
            spinner.style.height = `${SPINNER}px`;

            node.spinner = spinner;
            node.element.appendChild(spinner);
        }

        return node.spinner;
    }

    // How far a pull has got, drawn as a control that is there before it turns, the way a phone draws it.
    showPull(node, fraction) {
        if (fraction <= 0) {
            node.spinner?.remove();
            node.spinner = undefined;
            return;
        }

        const spinner = this.puller(node);

        spinner.dataset.varnStill = "true";
        spinner.style.opacity = String(fraction);
        spinner.style.scale = String(0.6 + fraction * 0.4);
    }

    // Shows that a refresh is under way, which the tree says rather than the finger.
    showRefreshing(node, refreshing) {
        if (!refreshing) {
            this.showPull(node, 0);
            return;
        }

        const spinner = this.puller(node);

        spinner.dataset.varnStill = "false";
        spinner.style.opacity = "1";
        spinner.style.scale = "1";
    }

    // Hands a rule in the stylesheet the value it reads, or takes it away so the rule reverts.
    paint(element, name, value) {
        if (value === undefined || value === null || value === "") {
            element.style.removeProperty(name);
            return;
        }

        element.style.setProperty(name, value);
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

        // A scroll that had not settled yet would otherwise report for a node that is no longer there.
        clearTimeout(node.settling);

        // The filter a node was drawn through is declared beside the page rather than inside the node,
        // so it outlives the node it belonged to unless it is taken away with it.
        node.filter?.remove();

        // A camera left open is a light on over a screen nobody is looking at, and on a phone it is the
        // recording indicator still showing after the reader has gone somewhere else.
        if (node.type === "camera" || node.type === "recorder") {
            this.capture.close(node);
        }

        node.place?.release();

        // A media element taken out of the page carries on playing until it is collected, which is a
        // sound still going after the screen it belonged to has gone.
        node.element.pause?.();

        node.element.remove();
        this.nodes.delete(id);
    }

    frame({ id, x, y, width, height }) {
        const node = this.expect(id);
        const css = node.element.style;
        const shrinking = node.frame !== undefined && (height < node.frame.height || width < node.frame.width);
        const ended = shrinking && WebRenderer.atEnd(node);

        css.left = `${x}px`;
        css.top = `${y}px`;
        css.width = `${width}px`;
        css.height = `${height}px`;

        node.frame = { width, height };

        // A surface showing the end of what it holds goes on showing it when the room it has shrinks,
        // which is what the keyboard coming up does to a conversation: the composer rises with it and
        // the message being answered would otherwise slide away under the keyboard.
        if (ended) {
            WebRenderer.toEnd(node);
        }

        if (node.pinned !== undefined || node.pinning !== undefined) {
            this.pin(node);
        }

        // A map and a canvas each hold a drawing of their own, which is only worth anything once it has
        // a size. A location is a receiver rather than a drawing, and has no size at all.
        if (node.type === "map") {
            node.place.resize(width, height);
        }

        if (node.type === "canvas") {
            this.draw(node, node.props.commands ?? []);
        }
    }

    // Whether a scrolling surface is showing the end of what it holds, within a pixel of it.
    static atEnd(node) {
        const element = node.element;

        if (!SCROLLING.has(node.type)) {
            return false;
        }

        const horizontal = node.props?.horizontal === true;
        const room = horizontal
            ? element.scrollWidth - element.clientWidth
            : element.scrollHeight - element.clientHeight;

        if (room <= 1) {
            return false;
        }

        return (horizontal ? element.scrollLeft : element.scrollTop) >= room - 1;
    }

    static toEnd(node) {
        const element = node.element;

        if (node.props?.horizontal === true) {
            element.scrollLeft = element.scrollWidth;
            return;
        }

        element.scrollTop = element.scrollHeight;
    }

    // Answers the size the browser draws a control at, which is the one thing about it Lua cannot know.
    //
    // A number written into the tree is a number that was true of one platform on one day, and a frame
    // worked out from the old one spills the control out of the box it was given.
    measureControl(type) {
        if (TAGS[type] === undefined) {
            return { width: 0, height: 0 };
        }

        const measured = this.controlSizes.get(type);

        if (measured !== undefined) {
            return measured;
        }

        const { element } = this.build(type);
        element.style.visibility = "hidden";

        const ground = document.body ?? document.documentElement;
        ground.appendChild(element);

        const box = element.getBoundingClientRect();
        element.remove();

        const size = { width: box.width, height: box.height };
        this.controlSizes.set(type, size);

        return size;
    }

    measureText(text, style, bound) {
        const canvas = this.measureCanvas ?? (this.measureCanvas = document.createElement("canvas"));
        const context = canvas.getContext("2d");
        const spacing = Number(style.letterSpacing) || 0;

        // A string is measured with what it is drawn with, since the slant of its letters and the space
        // between them both change how much room it needs. The spacing is counted here rather than set
        // on the context, which not every browser reads.
        context.font = WebRenderer.fontOf(style);

        const measured = context.measureText(String(text));
        const width = measured.width + spacing * String(text).length;
        const lineHeight = this.lineOf(style);

        // A bound of zero is a node that has not been measured yet, not a node with no room.
        if (bound > 0 && width > bound) {
            return { width: bound, height: this.lines(String(text), bound, context, spacing) * lineHeight };
        }

        // A string that says where its own lines end takes as many as it says, however much room it has.
        if (String(text).indexOf("\n") >= 0) {
            return { width, height: this.lines(String(text), Infinity, context, spacing) * lineHeight };
        }

        return { width, height: lineHeight };
    }

    // The font a style is drawn in, written the way a canvas and an element both read one.
    static fontOf(style) {
        const size = style.fontSize ?? 15;
        const weight = style.fontWeight ?? "400";
        const family = style.fontFamily ?? "system-ui, sans-serif";
        const slant = style.fontStyle === "italic" ? "italic " : "";

        return `${slant}${weight} ${size}px ${family}`;
    }

    // Answers the line a string is drawn in, in points, which is the line it was measured in.
    //
    // A style names a multiple of its size or it names nothing, and what it names nothing for is the
    // font's own box, the way it is on a phone. Leaving the browser to choose instead draws every string
    // in whatever line height it inherited: the glyphs sit low in a box the engine made shorter, a badge
    // holds its number below the middle, and the second line of a row spills past the row.
    lineOf(style) {
        const declared = Number(style.lineHeight);
        const size = style.fontSize ?? 15;

        if (Number.isFinite(declared) && declared > 0) {
            return size * declared;
        }

        const font = WebRenderer.fontOf(style);
        const known = this.naturalLines.get(font);

        if (known !== undefined) {
            return known;
        }

        const canvas = this.measureCanvas ?? (this.measureCanvas = document.createElement("canvas"));
        const context = canvas.getContext("2d");
        context.font = font;

        const measured = context.measureText("Hg");
        const ascent = measured.fontBoundingBoxAscent;
        const descent = measured.fontBoundingBoxDescent;
        const natural = Number.isFinite(ascent) && Number.isFinite(descent)
            ? ascent + descent
            : size * NATURAL_LINE;

        this.naturalLines.set(font, natural);
        return natural;
    }

    // Answers how many lines a string takes inside a width, by breaking it where the browser breaks it.
    //
    // Dividing the whole width by the bound counts the lines a string would take if the words packed
    // perfectly, and words do not pack perfectly: every line ends with the slack the next word could not
    // fit into. A paragraph measured that way is short of a line more often than not, which on a page is
    // text drawn over what comes after it — and the phones, which ask their own layout engines, get it
    // right. The same words, broken on the same spaces, measured with the same font.
    lines(text, bound, context, spacing) {
        const width = (piece) => context.measureText(piece).width + spacing * piece.length;

        let count = 1;
        let used = 0;

        for (const paragraph of text.split("\n")) {
            if (used > 0) {
                count += 1;
                used = 0;
            }

            for (const word of paragraph.split(/\s+/).filter((piece) => piece.length > 0)) {
                const space = used > 0 ? width(" ") : 0;
                const extent = width(word);

                if (used > 0 && used + space + extent > bound) {
                    count += 1;
                    used = extent;
                    continue;
                }

                used = used + space + extent;
            }
        }

        return count;
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

        // A control that draws its own words — a date, a time — is as wide as the words in it, so what
        // each one measured before a font arrived is no longer what the browser draws it at, and the
        // line a face draws in is the face's own.
        this.controlSizes.clear();
        this.naturalLines.clear();
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

        // An action asked of a node that cannot do it is a caller's mistake, and all three say so rather
        // than one refusing, one doing something else and one failing inside the browser.
        if (method === "scrollTo") {
            if (!SCROLLING.has(node.type)) {
                throw new Error("scrollTo needs a scrolling view");
            }

            element.scrollTo({ left: args.x ?? 0, top: args.y ?? 0, behavior: args.animated ? "smooth" : "auto" });
            return true;
        }

        if (method === "play" || method === "pause") {
            if (node.type !== "video") {
                throw new Error(`${method} needs a video`);
            }

            element[method]();
            return true;
        }

        // Moving to a moment is a reader dragging a scrubber, so it is asked for rather than described:
        // the same moment twice is one value, and a prop carrying it would be sent only the first time.
        if (method === "seek") {
            if (node.type !== "audio" && node.type !== "video") {
                throw new Error("seek needs a sound or a film");
            }

            const seconds = Number(args.seconds);

            if (!Number.isFinite(seconds)) {
                throw new Error("seek is asked for a number of seconds");
            }

            const whole = Number.isFinite(element.duration) ? element.duration : seconds;

            element.currentTime = Math.max(0, Math.min(seconds, whole));
            return true;
        }

        if (method === "capturePhoto" || method === "startRecording" || method === "stopRecording") {
            if (node.type !== "camera") {
                throw new Error(`${method} needs a camera`);
            }

            if (method === "capturePhoto") {
                this.capture.photograph(node);
                return true;
            }

            if (method === "startRecording") {
                this.capture.start(node, "video");
                return true;
            }

            this.capture.stop(node);
            return true;
        }

        if (EDITING.has(method)) {
            if (node.type !== "richeditor") {
                throw new Error(`${method} needs an editor`);
            }

            return this.edit(node, method, args);
        }

        throw new Error(`the renderer has no action named ${method}`);
    }

    // Applies what a toolbar asked of an editor, which is a mark, a link or the clipboard.
    //
    // A browser has one way to change what is selected inside an editable element and it is the one every
    // editor on the page uses. Pasting is the exception: nothing on a page may read the clipboard without
    // being allowed to, so a refusal is reported rather than left as a button that does nothing.
    edit(node, method, args) {
        const element = node.element;

        element.focus();

        if (method === "toggleMark") {
            const named = {
                bold: "bold",
                italic: "italic",
                underline: "underline",
                strikethrough: "strikeThrough",
            }[args.mark];

            if (named !== undefined) {
                document.execCommand(named, false, null);
            } else {
                WebRenderer.wrap(element, args.mark === "code" ? "CODE" : null);
            }

            this.emit(node.id, "onChange", WebRenderer.runsOf(element));
            this.reportCaret(node);
            return true;
        }

        if (method === "setLink") {
            document.execCommand("createLink", false, String(args.url ?? ""));
            this.emit(node.id, "onChange", WebRenderer.runsOf(element));
            return true;
        }

        if (method === "clearLink") {
            document.execCommand("unlink", false, null);
            this.emit(node.id, "onChange", WebRenderer.runsOf(element));
            return true;
        }

        if (method === "selectAll") {
            document.execCommand("selectAll", false, null);
            this.reportCaret(node);
            return true;
        }

        if (method === "copy" || method === "cut") {
            document.execCommand(method, false, null);

            if (method === "cut") {
                this.emit(node.id, "onChange", WebRenderer.runsOf(element));
            }

            return true;
        }

        navigator.clipboard?.readText?.().then((text) => {
            document.execCommand("insertText", false, text);
            this.emit(node.id, "onChange", WebRenderer.runsOf(element));
        }).catch(() => {
            this.emit(node.id, "onSelectionChange", { start: 0, end: 0, marks: {}, refused: "paste" });
        });

        return true;
    }

    // Wraps or unwraps what is selected in a tag the browser has no command of its own for.
    static wrap(element, tag) {
        const selection = document.getSelection?.();

        if (tag === null || selection === null || selection === undefined || selection.rangeCount === 0) {
            return;
        }

        const range = selection.getRangeAt(0);
        const inside = range.commonAncestorContainer;

        for (let at = inside; at !== null && at !== element; at = at.parentNode) {
            if (at.nodeName === tag) {
                at.replaceWith(...at.childNodes);
                return;
            }
        }

        const held = document.createElement(tag.toLowerCase());

        held.appendChild(range.extractContents());
        range.insertNode(held);
    }

    // Starts and stops a microphone, which a recorder is told to be running or not rather than asked.
    async record(node, wanted) {
        if (!wanted) {
            this.capture.stop(node);
            return;
        }

        if (this.capture.recording(node)) {
            return;
        }

        // The microphone is asked for the first time one is told to record rather than when it is built,
        // so a screen carrying a recorder nobody used never asks the reader for anything.
        if (await this.capture.listen(node)) {
            this.capture.start(node, "audio");
        }
    }

    // Puts the surface in the appearance the system is in, which is what the parts of a control the
    // browser draws for itself are drawn from: the tick of a checkbox, the words inside a date picker,
    // and every caption written in no colour the tree named.
    // Paints what the page draws around the surface, which is everything the tree is not.
    //
    // A page has a ground of its own behind the application, a browser writes the captions of the controls
    // it owns in a colour of its own, and a selection, a caret and a control's accent are each drawn in
    // whatever the user agent decided. None of that is a node, so none of it follows a theme unless it is
    // told to: a dark application on a white page, with black words inside a date picker, is what leaving
    // it out looks like. The scheme is what a system colour is resolved against, and the rest is read by
    // the rules the stylesheet carries.
    showTheme(ground) {
        const root = document.documentElement;

        root.style.colorScheme = ground.appearance ?? "light";
        this.container.style.colorScheme = ground.appearance ?? "light";

        root.style.setProperty("--varn-ground", ground.background ?? "");
        root.style.setProperty("--varn-ink", ground.text ?? "");
        root.style.setProperty("--varn-accent", ground.primary ?? "");
        root.style.setProperty("--varn-face", ground.family ?? "");
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
