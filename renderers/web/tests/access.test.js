// What a box says about itself to a reader who cannot see it.
//
// A control the platform draws says this for itself. One the engine draws is a box with a colour in it,
// and that is what a screen reader hears, so a drawn checkbox that names no role is a checkbox nobody
// using one can find, let alone tick — which is a regression against the control it replaced.

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

function box(id, props) {
    renderer.apply([
        { op: "create", id, type: "pressable", props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id).element;
}

{
    const ticked = box(1, {
        accessibilityLabel: "Keep it",
        accessibilityRole: "checkbox",
        accessibilityState: { checked: true, disabled: false },
    });

    assert(ticked.getAttribute("role") === "checkbox", "the role reaches the page");
    assert(ticked.getAttribute("aria-label") === "Keep it", "and so does the name");
    assert(ticked.getAttribute("aria-checked") === "true", "and what it is doing");
    assert(ticked.getAttribute("aria-disabled") === "false", "including what it is not doing");

    renderer.apply([{ op: "update", id: 1, props: { accessibilityState: { checked: false } } }]);

    assert(ticked.getAttribute("aria-checked") === "false", "a state that changed is said again");
    assert(ticked.hasAttribute("aria-disabled") === false, "and one no longer given is taken off");
}

{
    const slider = box(2, {
        accessibilityRole: "slider",
        accessibilityValue: { now: 3, least: 0, most: 10 },
    });

    assert(slider.getAttribute("role") === "slider", "a slider says it is one");
    assert(slider.getAttribute("aria-valuenow") === "3", "and what it is at");
    assert(slider.getAttribute("aria-valuemin") === "0", "and where it starts");
    assert(slider.getAttribute("aria-valuemax") === "10", "and where it ends");

    // A box that is nothing in particular carries no role rather than one nobody reads.
    renderer.apply([{ op: "update", id: 2, props: { accessibilityRole: "none" } }]);

    assert(slider.hasAttribute("role") === false, "a box that is nothing carries no role");
}

{
    // A role the browser spells differently is written the way the browser spells it.
    const searching = box(3, { accessibilityRole: "search" });

    assert(searching.getAttribute("role") === "searchbox",
        `a search box is a searchbox on the page, it was ${searching.getAttribute("role")}`);
}

console.log("web.access ok");
