// The rules a browser needs in a stylesheet because they reach parts of a control that no element
// stands for. A placeholder, a range thumb and a switch's track are pseudo-elements: nothing can set a
// property on them from script, so the rule is written once here and the value arrives per node as a
// custom property the rule reads.
//
// Nothing here decides a colour or a size that the tree could have decided. What a caller did not name
// reverts to what the user agent draws, which is what the phones do when a colour is not given either.

const RULES = `
@keyframes varn-spin { to { transform: rotate(360deg); } }

[data-varn-type="activity"] {
    box-sizing: border-box;
    border-radius: 50%;
    border: 2px solid var(--varn-activity-track, rgba(128, 128, 128, 0.25));
    border-top-color: var(--varn-activity-color, currentColor);
    animation: varn-spin 0.8s linear infinite;
}

[data-varn-type="activity"][data-varn-still="true"] {
    animation-play-state: paused;
}

[data-varn-type="avatar"] {
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    text-align: center;
}

[data-varn-type="textinput"]::placeholder,
[data-varn-type="textarea"]::placeholder,
[data-varn-type="searchbar"]::placeholder {
    color: var(--varn-placeholder-color, revert);
}

[data-varn-type="switch"] {
    appearance: none;
    -webkit-appearance: none;
    position: absolute;
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

[data-varn-type="slider"] {
    appearance: none;
    -webkit-appearance: none;
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

/// Puts the rules the renderer depends on into the document, once however many renderers there are.
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
