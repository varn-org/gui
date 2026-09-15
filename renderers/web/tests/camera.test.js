// What a camera and a microphone are made of on the page, short of the devices themselves.
//
// A browser opens neither without a reader saying so, which is why the device itself is driven from
// browser.test.js against a browser carrying one of its own. What is here is everything around it: the
// box the preview is drawn in, the zoom, and the actions only a camera answers.

import { install } from "../dom.js";
import { WebRenderer } from "../renderer.js";

const surface = install();
const renderer = new WebRenderer(surface, () => {});

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

const GREY = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
];

/** Builds one node, places it, and answers what the renderer made for it. */
function node(id, type, props) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id);
}

// A camera is a box with the preview inside it, since a zoom is a scale and a video clips nothing.
{
    const built = node(4, "camera", { facing: "front", zoom: 2, filter: GREY });

    assert(built.control !== built.element, "a camera holds the preview rather than being one");
    assert(built.control.tagName === "VIDEO", `and the preview is a video, got ${built.control.tagName}`);
    assert(built.element.style.overflow === "hidden", "and the box clips what a zoom pushes outside it");
    assert(built.control.style.transform === "scale(2)",
        `a zoom is a scale on the preview, got "${built.control.style.transform}"`);
    assert(built.control.style.filter === "url(#varn-filter-4)",
        `a look is drawn over the preview rather than over the box, got "${built.control.style.filter}"`);
}

// Only a camera answers the actions a camera has, since a box asked for one is a caller's mistake.
{
    node(5, "view", {});

    let refused = false;

    try {
        renderer.invoke(5, "capturePhoto", {});
    } catch {
        refused = true;
    }

    assert(refused, "asking a box for a picture is refused rather than answered with silence");
}

// A recorder draws nothing, so what it is is what it was told to be doing.
{
    const built = node(6, "recorder", { recording: false });

    assert(built.element.tagName === "DIV", "a microphone has nothing of its own to draw");
    assert(renderer.capture.recording(built) === false, "and it is not recording until it is told to be");
}

console.log("web.camera ok");
