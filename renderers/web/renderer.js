// The web renderer. It applies the operations a commit carries to real DOM nodes and reports events
// back, and it decides nothing: every size, colour and position arrives already resolved.

import { installSheet } from "./sheet.js";
import { VarnLocation, VarnTileMap } from "./place.js";

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
    filepicker: "input",
    rating: "div",
    video: "video",
    audio: "audio",
    webview: "iframe",
    canvas: "canvas",
    gradient: "div",
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
    "button", "badge", "tooltip",
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
    onSelect: "change",
    onEnd: "ended",
    onPress: "click",
    onLongPress: "contextmenu",
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

// How many of the values a field reported it holds against a commit that is still on its way.
const SAID = 64;

// How long the browser has to stop scrolling before it counts as settled.
const SETTLED = 120;

// How far a surface is dragged past its top before it counts as a pull to refresh.
//
// A phone's own control decides this for itself, and the browser has no such control, so this is the
// one place the web has to name a number the platform would otherwise have named.
const PULL = 72;

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

export class WebRenderer {
    constructor(container, emit) {
        this.container = container;
        this.emit = emit;
        this.nodes = new Map();
        this.listeners = new Map();
        this.fonts = new Set();
        this.scale = window.devicePixelRatio || 1;

        installSheet(document);
        container.addEventListener?.("pointerdown", (event) => this.dismissOnPress(event));
        this.watchTravel(container);

        this.capabilities = {
            text: true, image: true, list: true, scroll: true, input: true,
            video: true, webview: true, canvas: true, audio: true, map: true, location: true,
            gradient: true, blur: true,
            picker: true, datepicker: true,
            haptics: false, safearea: true, fontBytes: true, imageBytes: true,
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
            element.addEventListener("scroll", () => {
                this.hold(element);
                this.dismissOnDrag(element);
            });
        }

        if (PARTED.has(type)) {
            element.style.display = "flex";
            element.style.alignItems = "center";
        }

        const node = {
            id, element, control, caption, content, type,
            props: {}, listeners: new Map(), settled: false,
        };
        this.nodes.set(id, node);

        if (type === "stepper") {
            this.buildStepper(node);
            this.showCount(node, 0);
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

                if (key === "onPress" && next !== undefined) {
                    this.showPress(node.element);
                }
            } else {
                this.applyProp(node, key, next);
            }

            node.props[key] = next;
        }

        node.place?.settle();

        if (node.content !== null) {
            this.sizeContent(node);
        }
    }

    // Keeps every box the tree pinned against the leading edge as the surface moves under it.
    hold(element) {
        const surface = this.nodes.get(Number(element?.dataset?.varnId));

        if (surface === undefined || surface.content === null) {
            return;
        }

        const along = surface.props.horizontal === true ? element.scrollLeft : element.scrollTop;

        for (const child of surface.content.children) {
            const node = this.nodes.get(Number(child.dataset?.varnId));
            const range = node?.pinned;

            if (range === undefined) {
                continue;
            }

            const size = node.frame ?? { width: 0, height: 0 };
            const extent = surface.props.horizontal === true ? size.width : size.height;
            const at = Math.min(Math.max(along, range.from), Math.max(range.from, range.to - extent));

            child.style[surface.props.horizontal === true ? "left" : "top"] = `${at}px`;
        }
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

    // Answers the paint a run of colours is drawn with, which is the same run at the same angle on
    // every platform because the direction is one of a fixed set rather than an angle in degrees.
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
            node.caption.textContent = value ?? "";
            return;
        }

        if (key === "text") {
            element.textContent = value ?? "";
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

            if (type === "switch" || type === "slider") {
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

        // A colour on a control rather than on text is the colour of the mark it draws: a tick, a
        // spinner or a bar. A style's colour is the colour of a string, which is a different thing.
        if (key === "color") {
            if (type === "activity") {
                this.paint(element, "--varn-activity-color", value);
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

        // A box the surface holds against its leading edge, over the range the tree named. A header
        // placed from the tree follows a finger a commit late, which is a header drifting over the rows
        // it is meant to cover.
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

        if (key === "pinned") {
            node.pinned = value;
            element.style.zIndex = value === undefined ? "" : "1";
            this.hold(element.parentNode?.parentNode);
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
            // typing into a controlled field would lose their place on every keystroke. What the field
            // itself said a moment ago is not news either: the tree answers a keystroke a commit later,
            // by which time the reader has typed again, and writing it back loses what they typed.
            const text = value ?? "";

            if (node.said?.has(text)) {
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

        // WebKit has no scrollbar-width, so the bar is taken away by a rule on its own pseudo-element
        // and the attribute is what that rule matches on.
        // A sound has no player of its own — the tree draws one — so it is told what to do and reports
        // where it has got to.
        if (key === "playing") {
            if (value === true) {
                element.play?.();
            } else {
                element.pause?.();
            }

            return;
        }

        if (key === "position") {
            if (Math.abs((element.currentTime ?? 0) - Number(value)) > 0.25) {
                element.currentTime = Number(value);
            }

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

        if (key === "url") {
            element.src = value ?? "";
            return;
        }

        if (key === "html") {
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
            element.textContent = value ?? "";
            return;
        }

        if (key === "label" && (type === "checkbox" || type === "radio")) {
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
        css.background = style.background ?? "";
        css.color = style.color ?? "";
        css.opacity = style.opacity ?? "";
        css.borderRadius = style.radius !== undefined ? `${style.radius}px` : "";
        css.fontSize = style.fontSize !== undefined ? `${style.fontSize}px` : "";
        css.fontWeight = style.fontWeight ?? "";
        css.fontFamily = style.fontFamily ?? "";
        css.fontStyle = style.fontStyle ?? "";
        css.lineHeight = style.lineHeight ?? "";
        css.letterSpacing = style.letterSpacing !== undefined ? `${style.letterSpacing}px` : "";
        css.textAlign = style.textAlign ?? "";
        css.textDecoration = style.textDecoration ?? "";
        // A scrolling type owns its overflow, so a style that names none may not clear it and stop the
        // list scrolling at all.
        css.overflow = style.overflow ?? (SCROLLING.has(node.type) ? "auto" : "");
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
            `translate(${this.travel(transform.translateX)}, ${this.travel(transform.translateY)})`,
            `scale(${transform.scaleX}, ${transform.scaleY})`,
            `rotate(${transform.rotate}deg)`,
        ].join(" ");
    }

    /// A travel written as a percentage is a share of the node's own size, which is the only way a panel
    /// says it leaves by its own edge without the tree knowing how tall it turned out to be.
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
    }

    // Watches how far a finger goes, which is what tells a press from a swipe.
    //
    // It is watched on the surface rather than per node, since a pointer that leaves the node it landed
    // on still raises the click on whatever both ends have in common.
    watchTravel(container) {
        let landed = null;
        let from = null;

        container.addEventListener?.("pointerdown", (event) => {
            landed = { x: event.clientX ?? 0, y: event.clientY ?? 0 };
            from = event.target;

            for (const node of this.nodes.values()) {
                node.travelled = false;
            }
        });

        container.addEventListener?.("pointermove", (event) => {
            if (landed === null) {
                return;
            }

            const across = (event.clientX ?? 0) - landed.x;
            const down = (event.clientY ?? 0) - landed.y;

            if (Math.abs(across) <= TRAVEL && Math.abs(down) <= TRAVEL) {
                return;
            }

            // Only what was swiped gives its press up: a finger on a screen is never still, and a press
            // held to a distance is a control a reader has to press three times to be heard once.
            const swept = this.swept(from, across, down);

            landed = null;
            from = null;

            if (swept !== undefined) {
                swept.travelled = true;
            }
        });
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

        // A form-less input never raises `submit`, so a field reports what it holds when the return key
        // is pressed, and the key dismisses it the way it does on a phone.
        if (name === "onSubmit") {
            if (event.key !== "Enter") {
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

        // An event that carries nothing carries nothing, which is what the phones send. An empty table
        // is a value a handler can read fields off, so a handler written against one of them broke on
        // the others.
        return null;
    }

    place({ id, parent, index }) {
        const node = this.expect(id);
        const holder = parent === 0 ? null : this.expect(parent);
        const target = holder === null ? this.container : (holder.content ?? holder.element);

        // The index counts the siblings the node is not among, so it leaves the list before it is read.
        node.element.remove();

        const reference = target.children[index - 1];
        target.insertBefore(node.element, reference ?? null);

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
            if (from === null || node.props.refreshing === true) {
                return;
            }

            if (event.clientY - from < PULL) {
                return;
            }

            from = null;
            this.report(node, "onRefresh", null);
        };

        const up = () => { from = null; };

        node.pulling = { down, move, up };

        element.addEventListener("pointerdown", down);
        element.addEventListener("pointermove", move);
        element.addEventListener("pointerup", up);
        element.addEventListener("pointercancel", up);
    }

    // Shows that a refresh is under way, which the tree says rather than the finger.
    showRefreshing(node, refreshing) {
        if (!refreshing) {
            node.spinner?.remove();
            node.spinner = undefined;
            return;
        }

        if (node.spinner !== undefined) {
            return;
        }

        const spinner = document.createElement("div");

        spinner.dataset.varnType = "activity";
        spinner.style.position = "absolute";
        spinner.style.top = "8px";
        spinner.style.left = "50%";
        spinner.style.width = "20px";
        spinner.style.height = "20px";
        spinner.style.transform = "translateX(-50%)";

        node.spinner = spinner;
        node.element.appendChild(spinner);
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

        css.left = `${x}px`;
        css.top = `${y}px`;
        css.width = `${width}px`;
        css.height = `${height}px`;

        node.frame = { width, height };
        node.place?.resize(width, height);

        if (node.pinned !== undefined) {
            this.hold(node.element.parentNode?.parentNode);
        }

        // A canvas holds a bitmap of its own, which is only worth anything once it has a size.
        if (node.type === "canvas") {
            this.draw(node, node.props.commands ?? []);
        }
    }

    // Only the platform knows what its font engine does with a string, which is why this crosses back.
    // Answers the size the browser draws a control at, which is the one thing about it Lua cannot know.
    //
    // A number written into the tree is a number that was true of one platform on one day, and a frame
    // worked out from the old one spills the control out of the box it was given.
    // A variant names which of a control the tree asked for, since a browser draws a date one way only
    // and a wheel is a thing the phones have. Asked for one it has none of, it answers nothing rather
    // than the size of the one it does have.
    measureControl(type, variant) {
        if (variant === "wheel") {
            return { width: 0, height: 0 };
        }

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

        const ground = document.body ?? document.documentElement;
        ground.appendChild(probe);

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
        const slant = style.fontStyle === "italic" ? "italic " : "";
        const spacing = Number(style.letterSpacing) || 0;

        // A string is measured with what it is drawn with, since the slant of its letters and the space
        // between them both change how much room it needs. The spacing is counted here rather than set
        // on the context, which not every browser reads.
        context.font = `${slant}${weight} ${size}px ${family}`;

        const measured = context.measureText(String(text));
        const width = measured.width + spacing * String(text).length;

        // A paragraph has to be the same height on all three, so the line is the font's own the way it
        // is on a phone. A line height a caller declared is a multiple of the size, and anything that is
        // not a real one measures as NaN, which passes every check a number passes and then spreads
        // through every frame in the tree.
        const ascent = measured.fontBoundingBoxAscent;
        const descent = measured.fontBoundingBoxDescent;
        const natural = Number.isFinite(ascent) && Number.isFinite(descent)
            ? ascent + descent
            : size * NATURAL_LINE;

        const declared = Number(style.lineHeight);
        const lineHeight = Number.isFinite(declared) && declared > 0 ? size * declared : natural;

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
