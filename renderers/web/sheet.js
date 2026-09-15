// The rules a browser needs in a stylesheet because they reach parts of a control that no element
// stands for. A placeholder, a range thumb and a switch's track are pseudo-elements: nothing can set a
// property on them from script, so the rule is written once here and the value arrives per node as a
// custom property the rule reads.
//
// Nothing here decides a colour or a size that the tree could have decided. What a caller did not name
// reverts to what the user agent draws, which is what the phones do when a colour is not given either.

const RULES = `
/*
 * What the page itself is drawn in, which is everything around the tree rather than anything in it.
 *
 * A page carries a ground, a colour it writes in and a face, and a browser carries a look of its own for
 * a selection, a caret, the accent on a control it owns and the ring it draws around whatever has focus.
 * None of those is a node, so a dark application sat on a white page with a blue system accent is what
 * leaving them to the user agent looks like. Each is read from the theme the engine sends, and falls back
 * to what the browser would have drawn where an application has not started yet.
 */
html, body {
    margin: 0;
    height: 100%;
    background: var(--varn-ground, canvas);
    color: var(--varn-ink, canvastext);
    font-family: var(--varn-face, system-ui), system-ui, sans-serif;
    accent-color: var(--varn-accent, auto);
    caret-color: var(--varn-accent, auto);
}

/*
 * A page that bounces past its own end shows whatever is behind it, which on a phone is the browser's
 * own ground rather than the application's, and a long press on a box a finger is dragging lights it up
 * in a colour no theme chose.
 */
body {
    overscroll-behavior: none;
    -webkit-tap-highlight-color: transparent;
}

::selection {
    background: var(--varn-accent, highlight);
    color: var(--varn-ground, canvas);
}

/*
 * The surface is the box the engine draws every frame into, so the page positions nothing inside it and
 * clips what runs past its edge. It is written here rather than in the page, since a page is what an
 * application brings and the surface belongs to the renderer that draws into it.
 */
#surface {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
}

#surface * {
    box-sizing: border-box;
}

/*
 * What an application that has stopped answering looks like.
 *
 * A page outlives the engine drawing into it, so the last frame stays exactly as it was: a screen that
 * reads as a layout defect rather than as something that died, and answers a finger with nothing. Drained
 * of its colour and taking no press, it reads as what it is, and the banner beside it says why.
 */
#surface[data-varn-stopped="true"] {
    pointer-events: none;
    filter: grayscale(1);
    opacity: 0.45;
}

/*
 * The chrome a user agent draws on a control it owns, which the tree is what decides instead.
 *
 * It is taken away by a rule rather than on the element, since what a style names is written there and
 * what it does not name is cleared: an element clearing its own border cannot then be given one by a
 * rule, which is how every spinner on the page ended up as a ring nothing drew.
 */
[data-varn-type="button"],
[data-varn-type="filepicker"],
[data-varn-type="textinput"],
[data-varn-type="textarea"],
[data-varn-type="searchbar"],
[data-varn-type="picker"],
[data-varn-type="divider"],
[data-varn-type="progress"] {
    border: 0;
}

[data-varn-type="button"],
[data-varn-type="filepicker"] {
    background: transparent;
}

/*
 * A box painted with a picture cut into nine.
 *
 * The border style is set by a rule rather than on the element, since the style pass clears it for any
 * node that names no border colour and a border image is drawn by nothing without one. The width stays
 * at nothing so the frame is painted over the box: a border that took room would move every child the
 * engine placed inward by the thickness of it, on one platform out of three.
 *
 * The pieces are drawn without smoothing, the way the phones draw them. A frame is artwork, and a
 * two-pixel rule drawn larger and smoothed comes out as a smear rather than a rule.
 */
[data-varn-type="nineslice"] {
    border: 0 solid transparent;
    image-rendering: pixelated;
}

/*
 * A bar, drawn rather than left to the user agent.
 *
 * A browser draws its own progress element in a colour of its own and stops honouring the accent the
 * moment anything about it is styled, so a themed application had a green bar across it whatever colour
 * it asked for. The track and the part that is filled are pseudo-elements no colour could otherwise
 * reach, which is why they read the properties the renderer writes per node.
 */
[data-varn-type="progress"] {
    appearance: none;
    -webkit-appearance: none;
    overflow: hidden;
    border-radius: 999px;
    background: var(--varn-track-color, color-mix(in srgb, canvastext 12%, transparent));
}

[data-varn-type="progress"]::-webkit-progress-bar {
    background: transparent;
}

[data-varn-type="progress"]::-webkit-progress-value {
    border-radius: 999px;
    background: var(--varn-control-color, var(--varn-accent, currentColor));
}

[data-varn-type="progress"]::-moz-progress-bar {
    border-radius: 999px;
    background: var(--varn-control-color, var(--varn-accent, currentColor));
}

/*
 * A layer covers the application whether or not anything is in it, and an empty one is not there to be
 * pressed. A browser answers a pointer with any box under it, unlike the two phones, where a box takes a
 * touch only when it was given something to do with one, so a layer with nothing shown in it would have
 * swallowed every press on the screen it stands over.
 */
[data-varn-type="layer"] {
    pointer-events: none;
}

[data-varn-type="layer"] > * {
    pointer-events: auto;
}

@keyframes varn-spin { to { transform: rotate(360deg); } }

/*
 * How a box the tree pinned travels with the surface it is held in. The renderer names the range of the
 * scroll it is followed over and how far it travels across it, and the browser drives the rest against
 * the surface itself, so a header keeps up with a flick instead of arriving a frame after it.
 */
@keyframes varn-pin-block { from { translate: 0 var(--varn-pin-from); } to { translate: 0 var(--varn-pin-to); } }
@keyframes varn-pin-inline { from { translate: var(--varn-pin-from) 0; } to { translate: var(--varn-pin-to) 0; } }

[data-varn-type="activity"] {
    box-sizing: border-box;
    border-radius: 50%;
    border: 2px solid rgba(128, 128, 128, 0.25);
    border-top-color: var(--varn-activity-color, currentColor);
    animation: varn-spin 0.8s linear infinite;
}

[data-varn-type="activity"][data-varn-still="true"] {
    animation-play-state: paused;
}

[data-varn-type="textinput"]::placeholder,
[data-varn-type="textarea"]::placeholder,
[data-varn-type="searchbar"]::placeholder {
    color: var(--varn-placeholder-color, revert);
}

/*
 * What an editor with nothing in it says, which no element stands for.
 *
 * An editable element has no placeholder of its own, so the words are carried on the element and drawn
 * by a rule while it is empty. Without it the same tree shows the words on a phone and an empty box on
 * the page, which is exactly the shape of defect a tree-based case cannot see.
 */
[data-varn-type="richeditor"]:empty::before {
    content: attr(data-varn-placeholder);
    color: var(--varn-placeholder-color, revert);
    pointer-events: none;
}

/*
 * What a mark is drawn as inside an editor, which is the platform's own rather than a family the tree
 * named: a browser draws its own bold, its own italic and its own monospace the way a phone does.
 */
[data-varn-type="richeditor"] code {
    font-family: ui-monospace, monospace;
}

/*
 * What the browser draws a control at when nothing else says, for the controls it has none of.
 *
 * A frame arrives on the element itself and wins over every rule here, so these are what a control is
 * worth when it is measured rather than what it ends up drawn at. A switch drawn by a rule has no size
 * of its own at all, and a control the renderer builds out of parts is only as large as the parts the
 * page happens to have put in it, so both would be measured as nothing. The numbers are the ones a
 * phone draws the same control at, and so is the track a control built out of parts sits in.
 */
[data-varn-type="stepper"] {
    min-width: 94px;
    height: 32px;
    border-radius: 9px;
    background: var(--varn-track-color, color-mix(in srgb, canvastext 10%, transparent));
}

/*
 * What the parts of those controls look like. A button carries a face, a border and a font of the user
 * agent's choosing, and each of these is a part of a control rather than a button in a form.
 */
[data-varn-type="segmented"] > button,
[data-varn-type="stepper"] > button {
    appearance: none;
    -webkit-appearance: none;
    border: 0;
    background: transparent;
    color: inherit;
    font: inherit;
    cursor: pointer;
}

[data-varn-type="stepper"] > button {
    width: 32px;
    height: 100%;
}

[data-varn-type="stepper"] > span {
    flex: 1;
    text-align: center;
}

[data-varn-type="rating"] > span {
    cursor: pointer;
}

/*
 * The track a segmented control sits in and the raised segment inside it, which the browser has neither
 * of. Both are mixed out of the surface's own text colour, so the control follows the appearance the
 * way the phones' own does rather than carrying a grey chosen on one of them.
 */
[data-varn-type="segmented"] {
    height: 32px;
    padding: 2px;
    gap: 2px;
    border-radius: 9px;
    background: var(--varn-track-color, color-mix(in srgb, canvastext 10%, transparent));
}

[data-varn-type="segmented"] > button {
    flex: 1;
    height: 100%;
    border-radius: 7px;
}

[data-varn-type="segmented"] > button[data-varn-chosen="true"] {
    background: color-mix(in srgb, canvastext 22%, transparent);
    font-weight: 600;
}

/*
 * The controls the browser draws itself, given the shape they have in an application rather than the
 * one they have in a form: a date and a time read as fields, and a colour as the swatch a phone shows.
 */
[data-varn-type="datepicker"],
[data-varn-type="timepicker"] {
    padding: 8px 10px;
    border: 0;
    border-radius: 10px;
    background: color-mix(in srgb, canvastext 8%, transparent);
    color: inherit;
    font: inherit;
}

[data-varn-type="colorpicker"] {
    appearance: none;
    -webkit-appearance: none;
    width: 32px;
    height: 32px;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: transparent;
    cursor: pointer;
}

[data-varn-type="colorpicker"]::-webkit-color-swatch-wrapper {
    padding: 0;
}

[data-varn-type="colorpicker"]::-webkit-color-swatch {
    border: 0;
    border-radius: 50%;
}

[data-varn-type="switch"] {
    appearance: none;
    -webkit-appearance: none;
    width: 51px;
    height: 31px;
    border: 0;
    border-radius: 999px;
    background: var(--varn-off-color, #d1d1d6);
    transition: background 0.2s ease;
    cursor: pointer;
}

[data-varn-type="switch"]:checked {
    background: var(--varn-on-color, #34c759);
}

[data-varn-type="switch"]::after {
    content: "";
    position: absolute;
    top: 2px;
    left: 2px;
    height: calc(100% - 4px);
    aspect-ratio: 1;
    border-radius: 50%;
    background: var(--varn-thumb-color, #ffffff);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
    transition: left 0.2s ease, transform 0.2s ease;
}

[data-varn-type="switch"]:checked::after {
    left: calc(100% - 2px);
    transform: translateX(-100%);
}

/* An appearance reset leaves a range input as tall as its track, which is thinner than the thumb on it. */
[data-varn-type="slider"] {
    appearance: none;
    -webkit-appearance: none;
    height: 20px;
    background: transparent;
}

[data-varn-type="slider"]::-webkit-slider-runnable-track {
    height: 4px;
    border-radius: 2px;
    background: var(--varn-track-color, #d1d1d6);
}

[data-varn-type="slider"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    height: 20px;
    width: 20px;
    margin-top: -8px;
    border-radius: 50%;
    background: var(--varn-thumb-color, #ffffff);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

[data-varn-type="slider"]::-moz-range-track {
    height: 4px;
    border-radius: 2px;
    background: var(--varn-track-color, #d1d1d6);
}

[data-varn-type="slider"]::-moz-range-thumb {
    height: 20px;
    width: 20px;
    border: 0;
    border-radius: 50%;
    background: var(--varn-thumb-color, #ffffff);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

[data-varn-indicator="false"] {
    scrollbar-width: none;
}

[data-varn-indicator="false"]::-webkit-scrollbar {
    display: none;
}

[data-varn-paging="true"] > * > * {
    scroll-snap-align: start;
}

[data-varn-slop]::before {
    content: "";
    position: absolute;
    inset: calc(-1 * var(--varn-hit-slop));
}
`;

const MARKER = "varn-renderer-rules";

// Puts the rules the renderer depends on into the document, once however many renderers there are.
export function installSheet(document) {
    if (document.getElementById?.(MARKER) != null) {
        return;
    }

    const head = document.head ?? document.documentElement;

    if (head == null || document.createElement == null) {
        return;
    }

    const style = document.createElement("style");
    style.id = MARKER;
    style.textContent = RULES;
    head.appendChild(style);
}
