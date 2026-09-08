// What the browser draws over time rather than between two frames, and the two nodes that draw their
// own picture.
//
// The web had no animation at all: a transition, an arrival and an exit all fell through and were
// ignored, so every sheet, alert, drawer and screen change was instant there while both phones moved.
// A canvas drew nothing and a pull to refresh did nothing, for the same reason.

import { install } from "../dom.js";
import { WebRenderer } from "../renderer.js";

const surface = install();
const events = [];
const renderer = new WebRenderer(surface, (id, name, payload) => events.push({ id, name, payload }));

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

const FAST = { duration: 220, delay: 0, easing: [0.4, 0, 0.2, 1] };

/** Builds one node, places it, and answers what the renderer made for it. */
function node(id, type, props) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id);
}

// A node told how long a change should take is given a curve to take it over.
{
    const built = node(1, "view", { transition: FAST, style: { opacity: 1 } });

    renderer.apply([{ op: "update", id: 1, props: { style: { opacity: 0 } } }]);

    const transition = built.element.style.transition;

    assert(transition.includes("220ms"), `a change must take the time it was given, got "${transition}"`);
    assert(transition.includes("cubic-bezier(0.4, 0, 0.2, 1)"),
        `and follow the curve it was given, got "${transition}"`);

    // Only what the compositor can move animates. A frame writes the position and the size, and
    // animating those slides every node the layout moved rather than the ones the tree asked to move.
    assert(!transition.includes("all"), "a change may not animate everything");
    assert(!transition.includes("left") && !transition.includes("width"),
        `a frame is drawn at once, got "${transition}"`);
}

// A node told nothing about time is drawn between two frames, the way everything else is.
{
    const built = node(2, "view", { style: { opacity: 1 } });

    renderer.apply([{ op: "update", id: 2, props: { style: { opacity: 0 } } }]);

    assert(built.element.style.transition === "",
        `a node with no transition must be drawn at once, got "${built.element.style.transition}"`);
}

// A node given a state to arrive from is put on screen in it, and moves to the one it settles at.
{
    const built = node(3, "view", { transition: FAST, enter: { opacity: 0 }, style: { opacity: 1 } });

    assert(built.element.style.opacity === "0",
        `an arriving node starts in the state it arrives from, got "${built.element.style.opacity}"`);
    assert(built.settled === true, "and is settled once it has been placed");
}

// A canvas draws what it was given rather than staying an empty box, once it has a size to draw into.
//
// Props are applied before the frame that gives the element a size, and a canvas of no size draws
// nothing at all, so it is the frame that has to bring the picture with it.
{
    const built = node(4, "canvas", {
        commands: [
            { op: "stroke", path: [[0, 0], [10, 10]], color: "#ff0000ff", width: 2 },
            { op: "text", text: "hi", x: 4, y: 6, size: 12, color: "#0000ffff" },
        ],
    });

    const context = built.element.getContext?.("2d");

    assert(context !== undefined && context !== null, "a canvas must answer a drawing context");
    assert((context.calls ?? []).length === 0, "a canvas with no size yet draws nothing");

    renderer.apply([{ op: "frame", id: 4, x: 0, y: 0, width: 24, height: 24 }]);

    const drawn = context.calls ?? [];

    assert(built.element.width > 0, `the bitmap must be sized from the frame, got ${built.element.width}`);
    assert(drawn.includes("stroke"), `a stroke must be drawn, got ${JSON.stringify(drawn)}`);
    assert(drawn.includes("fillText"), `text must be drawn, got ${JSON.stringify(drawn)}`);

    // A frame that arrives again redraws, since the bitmap it was drawn into is a different size.
    renderer.apply([{ op: "frame", id: 4, x: 0, y: 0, width: 48, height: 48 }]);
    assert(built.element.width === 48 * renderer.scale,
        `a resized canvas must be redrawn into the new bitmap, got ${built.element.width}`);
}

// A surface dragged past its own top reports a pull, which the browser raises nothing of its own for.
{
    const built = node(5, "list", { onRefresh: true, refreshing: false });

    built.element.scrollTop = 0;
    built.element.dispatch("pointerdown", { clientY: 10 });
    built.element.dispatch("pointermove", { clientY: 20 });

    assert(events.filter((one) => one.name === "onRefresh").length === 0,
        "a short drag is not a pull");

    built.element.dispatch("pointermove", { clientY: 200 });

    assert(events.filter((one) => one.name === "onRefresh").length === 1,
        "a drag past the top reports a pull");

    // A surface already refreshing is not asked to again.
    renderer.apply([{ op: "update", id: 5, props: { refreshing: true } }]);
    built.element.dispatch("pointerdown", { clientY: 10 });
    built.element.dispatch("pointermove", { clientY: 200 });

    assert(events.filter((one) => one.name === "onRefresh").length === 1,
        "one already under way is not asked for again");
    assert(built.spinner !== undefined, "and says that one is under way");

    renderer.apply([{ op: "update", id: 5, props: { refreshing: false } }]);
    assert(built.spinner === undefined, "and stops saying so once it is done");
}

// A checkbox carries its caption beside it rather than inside a box that draws nothing.
{
    const built = node(6, "checkbox", { label: "Remember me", value: true });

    assert(built.control !== built.element, "a captioned control is the control and its text");
    assert(built.control.checked === true, "what belongs to the control reaches the control");
    assert(built.caption.textContent === "Remember me",
        `and the caption is shown, got "${built.caption.textContent}"`);
}

// A travel written as a percentage is a share of the node's own size, which is how a panel says it
// leaves by its own edge without the tree knowing how tall the layout made it.
{
    const built = node(7, "view", {
        style: { transform: { translateY: "100%", translateX: 0, scaleX: 1, scaleY: 1, rotate: 0 } },
    });

    assert(built.element.style.transform.includes("translate(0px, 100%)"),
        `a share of the node must reach the browser as one, got "${built.element.style.transform}"`);
}

// A travel written as a number is still points, which is what every other move is written in.
{
    const built = node(8, "view", {
        style: { transform: { translateY: 40, translateX: 0, scaleX: 1, scaleY: 1, rotate: 0 } },
    });

    assert(built.element.style.transform.includes("translate(0px, 40px)"),
        `a number must still be points, got "${built.element.style.transform}"`);
}

console.log("web.motion ok");
