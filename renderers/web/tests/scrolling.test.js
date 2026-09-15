// What a scrolling type must keep about itself, whatever style it was given.
//
// A list is created with an overflow of its own and then has its props applied, and applying a style
// that names no overflow cleared it, so every list in the gallery — each of which carries a style —
// stopped scrolling in the browser entirely.

import { install } from "../dom.js";
import { WebRenderer } from "../renderer.js";
import { WebHost } from "../host.js";

const surface = install();
const renderer = new WebRenderer(surface, () => {});

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

function build(id, type, props) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id).element;
}

const SCROLLING = ["scroll", "list", "sectionlist", "grid", "carousel"];

// A scrolling type keeps its overflow through a style that names none.
for (const [at, type] of SCROLLING.entries()) {
    const element = build(at + 1, type, { style: { grow: 1 } });

    assert(element.style.overflow === "auto", `a ${type} carrying a style must still scroll, got "${element.style.overflow}"`);
}

// A style that names an overflow of its own still wins.
{
    const element = build(10, "scroll", { style: { overflow: "hidden" } });

    assert(element.style.overflow === "hidden", `a named overflow must win, got "${element.style.overflow}"`);
}

// Turning scrolling off stops it, and turning it back on restores it.
{
    const element = build(11, "list", { style: { grow: 1 }, scrollEnabled: false });
    assert(element.style.overflow === "hidden", `a list told not to scroll must not, got "${element.style.overflow}"`);

    renderer.apply([{ op: "update", id: 11, props: { scrollEnabled: true } }]);
    assert(element.style.overflow === "auto", `a list told to scroll again must, got "${element.style.overflow}"`);
}

// The rubber band is the caller's to turn off.
{
    const element = build(12, "list", { style: { grow: 1 }, bounces: false });
    assert(element.style.overscrollBehavior === "contain", "a list told not to bounce must say so");

    renderer.apply([{ op: "update", id: 12, props: { bounces: true } }]);
    assert(element.style.overscrollBehavior === "", "a list that bounces leaves the browser to it");
}

// So is the indicator, which is marked rather than styled, since the bar WebKit draws is a
// pseudo-element and no property on the element itself reaches it.
{
    const element = build(13, "list", { style: { grow: 1 }, showsIndicator: false });
    assert(element.getAttribute("data-varn-indicator") === "false",
        "a list told to hide its indicator must be marked as hiding it");

    renderer.apply([{ op: "update", id: 13, props: { showsIndicator: true } }]);
    assert(element.getAttribute("data-varn-indicator") === "true",
        "and marked again when it is told to show one");
}

// The rule that mark exists for is in the sheet, on both spellings, or it reaches only one engine.
{
    const rules = document.getElementById("varn-renderer-rules").textContent;

    assert(rules.includes('[data-varn-indicator="false"]::-webkit-scrollbar'),
        "the sheet must take the bar away in WebKit, which has no scrollbar-width");
    assert(rules.includes("scrollbar-width: none"),
        "and in the engines that do have one");
}

// A box the tree pinned is held against the leading edge by the surface, not by the tree.
//
// A commit follows a finger rather than leading it, so a header placed from the tree drifts across the
// rows it is meant to cover on every flick.
{
    const list = build(20, "list", { style: { grow: 1 }, contentExtent: 4000 });

    renderer.apply([
        { op: "create", id: 21, type: "view", props: { pinned: { from: 0, to: 1200 } } },
        { op: "insert", id: 21, parent: 20, index: 1 },
        { op: "frame", id: 21, x: 0, y: 0, width: 390, height: 30 },
    ]);

    const header = renderer.nodes.get(21).element;

    assert(header.style.top === "0px", `it starts where the tree put it, got ${header.style.top}`);
    assert(header.style.animationName === "varn-pin-block",
        `it travels with the surface rather than with the tree, got ${header.style.animationName}`);
    assert(header.style.animationTimeline === "scroll(nearest block)",
        `driven by the surface it is held in, got ${header.style.animationTimeline}`);

    // It travels with the surface from the surface's own start, so it stands at the edge whatever the
    // tree has caught up with, and stops where the section beneath pushes it off.
    assert(header.style.animationRange === "0px 1170px",
        `over the range the tree named, got ${header.style.animationRange}`);
    assert(header.style.getPropertyValue("--varn-pin-to") === "1170px",
        `as far as the range runs, got ${header.style.getPropertyValue("--varn-pin-to")}`);

    // A row realised while the surface scrolls is inserted where the tree puts it, which is after the
    // header it belongs under, so the header has to be drawn over what arrives beneath it.
    renderer.apply([
        { op: "create", id: 22, type: "view", props: {} },
        { op: "insert", id: 22, parent: 20, index: 2 },
        { op: "frame", id: 22, x: 0, y: 1200, width: 390, height: 44 },
    ]);

    assert(header.style.zIndex === "1", `a held box is drawn over what arrives beneath it, got ${header.style.zIndex}`);
}

// What a host set up to watch the page is given back when it stops.
//
// A resize observer and a listener on the visual viewport go on reporting into an engine that has
// stopped answering, which is a page that keeps working after the application it was showing has gone.
{
    let polled = 0;
    let observing = 0;
    let listening = 0;
    let removed = 0;

    globalThis.ResizeObserver = class {
        observe() { observing += 1; }
        disconnect() { observing -= 1; }
    };

    globalThis.requestAnimationFrame = () => {};
    globalThis.window = { innerHeight: 800, visualViewport: null };
    globalThis.matchMedia = () => ({
        addEventListener: (_name, _handler, options) => {
            listening += 1;
            options?.signal?.addEventListener("abort", () => { removed += 1; });
        },
        matches: false,
    });

    const page = install();
    const host = new WebHost({ varnEmit: () => { polled += 1; }, varnPoll: () => {} }, page);

    host.observeSize();
    host.observeAppearance();

    assert(observing === 1, "the host watches the page it draws into");
    assert(listening === 1, "and what the reader set their device to");

    host.stop();

    assert(observing === 0, "and gives the observer back when it stops");
    assert(removed === 1, "along with every listener it added");
}

// An engine that stops answering is said out loud rather than left as a frozen screen.
{
    const page = install();
    let said = null;

    globalThis.requestAnimationFrame = () => {};
    globalThis.ResizeObserver = class { observe() {} disconnect() {} };
    globalThis.matchMedia = () => ({ addEventListener: () => {}, matches: false });

    const host = new WebHost({
        varnEmit: () => {},
        varnPoll: () => { throw new Error("memory access out of bounds"); },
    }, page);

    host.onProblem = (problem) => { said = problem; };
    host.running = true;
    host.pump();

    assert(said !== null && said.includes("the application stopped"),
        `a page whose engine died says so, it said ${said}`);
    assert(host.running === false, "and stops pumping, since every tick after the first fails the same way");
}

console.log("web.scrolling ok");
