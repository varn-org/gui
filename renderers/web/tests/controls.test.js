// What the controls the browser has none of are made of, and what they report when they are used.
//
// A segmented control, a rating and a stepper have no element behind them, so the renderer builds each
// out of parts of its own the way UIKit builds the segments of a UISegmentedControl. All three drew as
// an empty box and reported nothing at all, which is what "I touch it and nothing happens" was on the
// page. A chooser had the same hole: its options were declared structural and never applied.

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

/** Builds one control and answers the element the renderer made for it. */
function control(id, type, props) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id).element;
}

function reported(id) {
    return events.filter((event) => event.id === id).map((event) => event.payload);
}

// A chooser lists what it may be set to.
{
    const element = control(1, "picker", {
        options: [{ label: "One", value: "1" }, { label: "Two", value: "2" }],
        value: "2",
        onChange: true,
    });

    assert(element.children.length === 2, `a chooser must list its options, has ${element.children.length}`);
    assert(element.children[0].textContent === "One", "an option is labelled with what it says");
    assert(element.children[1].value === "2", "an option carries the value it stands for");
}

// A segmented control is built of the segments it was given, and each reports where it sits.
{
    const element = control(2, "segmented", { segments: ["Day", "Week", "Month"], selectedIndex: 2, onChange: true });

    assert(element.children.length === 3, `a segmented control must build its segments, has ${element.children.length}`);
    assert(element.children[1].textContent === "Week", "a segment is labelled with what it says");
    assert(element.children[1].style.opacity === "1", "the chosen segment stands out from the others");
    assert(element.children[0].style.opacity !== "1", "a segment that is not chosen does not");

    element.children[2].dispatch("click", {});
    assert(reported(2).length === 1, "choosing a segment must report it");
    assert(reported(2)[0] === 3, `a segment reports where it sits, got ${reported(2)[0]}`);
}

// A rating is built of its stars, and each reports the score it stands for.
{
    const element = control(3, "rating", { count: 5, value: 2, onChange: true });

    assert(element.children.length === 5, `a rating must build its stars, has ${element.children.length}`);
    assert(element.children[1].style.opacity === "1", "a star up to the value is filled");
    assert(element.children[2].style.opacity !== "1", "a star past the value is not");

    element.children[3].dispatch("click", {});
    assert(reported(3)[0] === 4, `a star reports the score it stands for, got ${reported(3)[0]}`);
}

// A stepper counts in the step it was given and stays inside the bounds it was given.
{
    const element = control(4, "stepper", { value: 5, step: 5, minimum: 0, maximum: 10, onChange: true });

    assert(element.children.length === 3, "a stepper is two buttons and a readout");
    assert(element.children[1].textContent === "5", `a stepper shows what it holds, got ${element.children[1].textContent}`);

    element.children[2].dispatch("click", {});
    assert(reported(4)[0] === 10, `a stepper counts in the step it was given, got ${reported(4)[0]}`);

    element.children[2].dispatch("click", {});
    assert(reported(4)[1] === 10, `a stepper stops at the most it may hold, got ${reported(4)[1]}`);

    element.children[0].dispatch("click", {});
    assert(reported(4)[2] === 5, `a stepper counts back down, got ${reported(4)[2]}`);
}

// A slider stands where its value asks within the range it was given, whatever order the props arrived
// in. A range input takes nought to a hundred until it is told otherwise, so a value applied before the
// range is clamped to nought and stays there.
{
    const element = control(7, "slider", { value: 0.4, minimum: 0, maximum: 1, step: 0.01 });

    assert(element.max === 1, `a slider must take the range it was given, got ${element.max}`);
    assert(Number(element.value) === 0.4, `a slider must stand where its value asks, got ${element.value}`);
}

// A control the tree is not listening to reports nothing, since a handler travels as a marker and the
// props the node holds are what say whether one was bound.
{
    const element = control(5, "rating", { count: 3, value: 0 });

    element.children[0].dispatch("click", {});
    assert(reported(5).length === 0, "a control nobody is listening to must report nothing");
}

// A structural prop applied again replaces what it built rather than adding to it.
{
    const element = control(6, "segmented", { segments: ["One", "Two"] });

    renderer.apply([{ op: "update", id: 6, props: { segments: ["Only"] } }]);
    assert(element.children.length === 1, `rebuilding must replace the segments, has ${element.children.length}`);
}

console.log("web.controls ok");
