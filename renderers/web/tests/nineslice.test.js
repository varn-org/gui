// A picture cut into nine, which the browser draws as a border image.
//
// What matters here is that the frame is painted over the box rather than inside it. A border with a
// width of its own would push every child the engine placed inward by the thickness of the frame, and
// the same tree would come out laid out one way in a browser and another way on a phone.

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

function frame(id, props) {
    renderer.apply([
        { op: "create", id, type: "nineslice", props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id).element;
}

// The cuts are written into the slice in the picture's own pixels, and into the width in points.
{
    const element = frame(1, {
        source: "/assets/window.png",
        slice: { top: 10, right: 20, bottom: 30, left: 40 },
        sliceScale: 2,
    });

    assert(element.style.borderImageSource === 'url("/assets/window.png")',
        `the picture is the source, got ${element.style.borderImageSource}`);

    assert(element.style.borderImageSlice === "10 20 30 40 fill",
        `the cuts are the picture's own pixels, and the middle is filled, got ${element.style.borderImageSlice}`);

    assert(element.style.borderImageWidth === "20px 40px 60px 80px",
        `how thick it comes out is the cuts drawn at the scale, got ${element.style.borderImageWidth}`);

    assert(element.style.borderImageRepeat === "stretch",
        `the edges stretch rather than repeating, got ${element.style.borderImageRepeat}`);
}

// The border itself takes no room, so nothing the engine placed inside one is moved by the frame.
{
    const element = frame(2, { source: "/assets/window.png", slice: { top: 8, right: 8, bottom: 8, left: 8 } });

    assert(element.style.borderWidth === "" || element.style.borderWidth === "0px",
        `a frame takes no room of its own, got ${element.style.borderWidth}`);
}

// Drawn at nothing in particular, one point is one pixel of the picture.
{
    const element = frame(3, { source: "/assets/button.png", slice: { top: 14, right: 14, bottom: 14, left: 14 } });

    assert(element.style.borderImageWidth === "14px 14px 14px 14px",
        `with no scale the border is the cuts themselves, got ${element.style.borderImageWidth}`);
}

// A cut that arrives before the picture, or a picture before the cuts, draws nothing rather than half.
{
    const element = frame(4, { slice: { top: 6, right: 6, bottom: 6, left: 6 } });

    assert(element.style.borderImageSource === "",
        `a frame with no picture paints nothing, got ${element.style.borderImageSource}`);

    renderer.apply([{ op: "update", id: 4, props: { source: "/assets/late.png" } }]);

    assert(element.style.borderImageSource === 'url("/assets/late.png")',
        "and paints as soon as the picture it was waiting for arrives");

    assert(element.style.borderImageSlice === "6 6 6 6 fill",
        "with the cuts it already had");
}

// The renderer says it draws one, so a screen can ask before it builds itself out of frames.
{
    assert(renderer.capabilities.nineSlice === true, "the browser declares that it draws a frame");
}

console.log("web.nineslice ok");

// A frame draws the artwork the state it is in names, and the plain one for a state that names none.
{
    const element = frame(9, {
        source: "/assets/plate.png",
        sources: { pressed: "/assets/plate-down.png", disabled: "/assets/plate-off.png" },
        slice: 8,
    });

    const node = renderer.nodes.get(9);

    assert(element.style.borderImageSource === 'url("/assets/plate.png")',
        `a frame nobody is touching draws the plain picture, got ${element.style.borderImageSource}`);

    element.dispatch("pointerdown", {});
    assert(element.style.borderImageSource === 'url("/assets/plate-down.png")',
        `a frame under a finger draws the pressed picture, got ${element.style.borderImageSource}`);

    element.dispatch("pointerup", {});
    assert(element.style.borderImageSource === 'url("/assets/plate.png")',
        `and comes back when the finger lifts, got ${element.style.borderImageSource}`);

    // A state the frame carries no artwork for is drawn with the plain picture rather than with nothing.
    element.dispatch("pointerenter", { pointerType: "mouse" });
    assert(element.style.borderImageSource === 'url("/assets/plate.png")',
        `a state with no artwork of its own keeps the plain picture, got ${element.style.borderImageSource}`);

    renderer.apply([{ op: "update", id: 9, props: { disabled: true } }]);
    assert(node.off === true, "the frame was told it may not be pressed");
    assert(element.style.borderImageSource === 'url("/assets/plate-off.png")',
        `a frame that may not be pressed draws the picture for that, got ${element.style.borderImageSource}`);
}
