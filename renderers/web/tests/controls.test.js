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

// A colour that reaches a part of a control no element stands for is handed to the rule that draws it.
//
// A placeholder, a range thumb and a switch's track are pseudo-elements, so nothing can set a property
// on them from script. The rule is in the stylesheet and the value arrives on the node it reads from.
{
    const off = control(20, "switch", { value: false, onColor: "#34c759ff", offColor: "#ff3b30ff", thumbColor: "#ffffffff" });

    assert(off.style.getPropertyValue("--varn-off-color") === "#ff3b30ff",
        `a switch must carry the colour it shows while it is off, got ${off.style.getPropertyValue("--varn-off-color")}`);
    assert(off.style.getPropertyValue("--varn-on-color") === "#34c759ff", "and the one it shows while it is on");
    assert(off.style.getPropertyValue("--varn-thumb-color") === "#ffffffff", "and the one its thumb is drawn in");

    const slider = control(21, "slider", { value: 0.5, thumbColor: "#0a84ffff", trackColor: "#d1d1d6ff" });

    assert(slider.style.getPropertyValue("--varn-thumb-color") === "#0a84ffff", "a slider's thumb takes its colour");
    assert(slider.style.getPropertyValue("--varn-track-color") === "#d1d1d6ff", "and so does its track");

    const field = control(22, "textinput", { placeholder: "Search", placeholderColor: "#8e8e93ff" });

    assert(field.style.getPropertyValue("--varn-placeholder-color") === "#8e8e93ff",
        "a field must carry the colour its placeholder is drawn in");
}

// A spinner is drawn here, so it is stopped by holding the animation rather than by being taken away.
{
    const spinner = control(23, "activity", { animating: true, color: "#8e8e93ff" });

    assert(spinner.dataset.varnStill === "false", "a spinner that is playing is not held");

    renderer.apply([{ op: "update", id: 23, props: { animating: false } }]);
    assert(spinner.dataset.varnStill === "true", "one that is not playing is held rather than hidden");
}

// A press is answered from an area larger than the box, which a small control needs to be reachable.
{
    const pressable = control(25, "pressable", { hitSlop: 12 });

    assert(pressable.dataset.varnSlop === "true", "a box with slop is marked for the rule that draws it");
    assert(pressable.style.getPropertyValue("--varn-hit-slop") === "12px",
        `and carries how far it reaches, got ${pressable.style.getPropertyValue("--varn-hit-slop")}`);

    renderer.apply([{ op: "update", id: 25, props: { hitSlop: 0 } }]);
    assert(pressable.dataset.varnSlop === undefined, "and reaches no further than its box once it is taken away");
}

// A paragraph held to a number of lines is cut off at the last one it may run to.
{
    const held = control(26, "text", { text: "long enough to wrap twice over", numberOfLines: 2 });

    assert(held.style.getPropertyValue("-webkit-line-clamp") === "2",
        `a paragraph must be held to the lines it was given, got "${held.style.getPropertyValue("-webkit-line-clamp")}"`);
    assert(held.style.overflow === "hidden", "and what runs past them is cut off");

    renderer.apply([{ op: "update", id: 26, props: { numberOfLines: null } }]);
    assert(held.style.getPropertyValue("-webkit-line-clamp") === "",
        "and it runs as far as it likes once the count is taken away");
}

// A radio says which one was chosen, which is the whole of what a radio group is built on.
{
    const radio = control(27, "radio", { value: "monthly", onSelect: true });

    // A radio is a label holding the control and its caption, so what is ticked is the control.
    renderer.nodes.get(27).control.checked = true;
    radio.dispatch("change", {});

    const chosen = events.filter((event) => event.id === 27);

    assert(chosen.length === 1, `choosing a radio must be reported, got ${chosen.length} events`);
    assert(chosen[0].name === "onSelect", `and reported as a choice, got ${chosen[0].name}`);
    assert(chosen[0].payload === true, "carrying that it is the one now chosen");
}

// A surface that pages comes to rest on a whole one.
{
    const pages = control(28, "carousel", { paging: true, horizontal: true });

    assert(pages.dataset.varnPaging === "true", "a paging surface is marked for the rule that rests it");
    assert(pages.style.scrollSnapType.startsWith("x"),
        `and rests along the axis it scrolls, got "${pages.style.scrollSnapType}"`);
}

// How the system draws its own bars over the page, which the browser takes from the colour scheme.
{
    control(29, "safearea", { barContent: "light" });
    assert(document.documentElement.style.colorScheme === "dark",
        `light bar content is a dark page, got "${document.documentElement.style.colorScheme}"`);

    renderer.apply([{ op: "update", id: 29, props: { barContent: "dark" } }]);
    assert(document.documentElement.style.colorScheme === "light", "and dark bar content is a light one");
}

// A file picker reports what was chosen, read and measured, which is what every renderer reports.
//
// The web was the only one that built a real chooser, and nothing read what it produced: the component
// declared no event at all, so a chosen file had nowhere to go on any of the three.
{
    const chooser = control(40, "filepicker", {
        title: "Choose a file",
        accept: ["image/png", "application/pdf"],
        multiple: true,
        maxBytes: 16,
        onPick: true,
    });

    assert(chooser.accept === "image/png,application/pdf", "what a chooser offers reaches it");
    assert(chooser.multiple === true, "and whether it takes more than one");

    chooser.files = [
        { name: "small.png", size: 4, type: "image/png", bytes: [1, 2, 3, 4] },
        { name: "huge.mov", size: 900, type: "video/quicktime", bytes: [] },
    ];

    chooser.dispatch("change", { type: "change" });

    await new Promise((resolve) => setTimeout(resolve, 0));

    // Each is reported as it is ready. Gathering the whole set first puts the bytes of every picture into
    // one message, decoded and written in a single turn, so nothing moves until the last one lands.
    const files = events.filter((one) => one.name === "onPick").map((one) => one.payload);

    assert(files.length === 2, `everything chosen is reported, got ${files.length}`);
    assert(files[0].name === "small.png" && files[0].type === "image/png", "each one is named and typed");
    assert(files[0].bytes === "AQIDBA==", `a file within the cap arrives read, got ${files[0].bytes}`);
    assert(files[1].bytes === null, "and one over it arrives named and measured but unread");
}

// A press is given up to the gesture that beat it, never to a distance.
//
// A finger on a screen is never still, and a press held to ten pixels of travel was a control a reader
// had to press three times to be heard once. What takes a press away is something else recognising the
// gesture: the swipe a tree asked for, or the scroll the browser answers itself.
{
    const row = control(50, "pressable", { onPress: true });

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(reported(50).length === 1, "a finger that stayed put is a press");

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20 });
    surface.dispatch("pointermove", { clientX: 120, clientY: 24 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(reported(50).length === 2, "and one that wandered across it is still a press");
}

// A box the tree asked for a swipe on gives the press up to the swipe.
{
    const row = control(51, "pressable", { onPress: true, onSwipe: true });

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row });
    surface.dispatch("pointermove", { clientX: 160, clientY: 24 });
    row.dispatch("click", { type: "click", detail: 1 });

    const swipes = events.filter((event) => event.id === 51 && event.name === "onSwipe");

    assert(swipes.length === 1, `a swipe across it is reported, got ${swipes.length}`);
    assert(swipes[0].payload.direction === "right", "with the direction the finger went");
    assert(events.filter((event) => event.id === 51 && event.name === "onPress").length === 0,
        "and the press it beat is not reported");

    // The press after a swipe stands on its own rather than on what the last finger did.
    surface.dispatch("pointerdown", { clientX: 10, clientY: 20 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(events.filter((event) => event.id === 51 && event.name === "onPress").length === 1,
        "and the press after it is a press again");
}

// A control reached with the keyboard is pressed by the keyboard, whatever a finger did before it.
{
    const row = control(52, "pressable", { onPress: true, onSwipe: true });

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row });
    surface.dispatch("pointermove", { clientX: 160, clientY: 24 });
    row.dispatch("click", { type: "click", detail: 0 });

    assert(events.filter((event) => event.id === 52 && event.name === "onPress").length === 1,
        "a click with no pointer behind it is a press");
}

console.log("web.controls ok");
