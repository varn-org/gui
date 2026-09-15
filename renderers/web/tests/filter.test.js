// How the browser draws a picture through the colour matrix a filter came to.
//
// A page usually writes the shorthand functions, but the engine works out one matrix so that three
// platforms cannot each round their own way, and a matrix reaches the browser only through a filter
// element the style points at. A filter left declared beside a page whose node has gone is a leak that
// grows with every picture a reader scrolls past.

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

/** Answers the filter declared for a node, which is what its style points at. */
function declared(node) {
    return node.filterMatrix?.getAttribute("values") ?? null;
}

// A picture given a matrix is drawn through a filter of its own, in the colours it was given.
{
    const built = node(1, "image", { source: "logo.png", filter: GREY });

    assert(built.element.style.filter === "url(#varn-filter-1)",
        `a filtered picture points at its own filter, got "${built.element.style.filter}"`);
    assert(declared(built) === GREY.join(" "),
        `and the filter carries the matrix it was sent, got "${declared(built)}"`);
    assert(built.filter.getAttribute("color-interpolation-filters") === "sRGB",
        "declared to work in the colours it was given, since a filter primitive works in linear light");
}

// A filter taken away leaves nothing behind, and one changed is the new one rather than a second.
{
    const built = node(2, "image", { source: "logo.png", filter: GREY });

    renderer.apply([{ op: "update", id: 2, props: { filter: [...GREY.slice(0, 19), 0.5] } }]);

    assert(declared(built).endsWith("0.5"), `a changed matrix is written into the filter it had, got "${declared(built)}"`);

    renderer.apply([{ op: "update", id: 2, props: { filter: "__varn_removed__" } }]);

    assert(built.element.style.filter === "", "a picture no longer filtered is drawn as it is");
    assert(built.filter === undefined, "and the filter it was drawn through is gone");
}

// A node removed takes its filter with it, since a filter is declared beside the page rather than in it.
{
    const built = node(3, "image", { source: "logo.png", filter: GREY });
    const holder = built.filter.parentNode;

    assert(holder !== null, "a filter is declared in the drawing the page keeps for them");

    renderer.apply([{ op: "remove", id: 3 }]);

    assert(built.filter.parentNode === null, "and it goes when the node it belonged to goes");
}

// A film is drawn through the same filter a picture is, since a look is one thing.
{
    const built = node(7, "video", { source: "clip.mp4", filter: GREY });

    assert(built.element.style.filter === "url(#varn-filter-7)",
        `a filtered film points at its own filter, got "${built.element.style.filter}"`);
    assert(declared(built) === GREY.join(" "), "and the filter carries the matrix it was sent");
}

// A node that paints a picture of its own keeps it when a style is applied over it.
//
// A style names a colour and the shorthand it was written through clears the picture with it: every
// gradient in the framework was painted and then wiped by the style that followed it in the same batch.
{
    const built = node(8, "gradient", {
        colors: ["#3f7fd8ff", "#89bff0ff"],
        direction: "down",
        style: { radius: 8 },
    });

    assert(built.element.style.backgroundImage.includes("linear-gradient"),
        `a gradient paints its own run of colours, got "${built.element.style.backgroundImage}"`);

    renderer.apply([{ op: "update", id: 8, props: { style: { radius: 12 } } }]);

    assert(built.element.style.backgroundImage.includes("linear-gradient"),
        "and keeps it when a style is applied over it");
}

console.log("web.filter ok");
