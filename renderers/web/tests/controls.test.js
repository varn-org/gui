// What the controls the browser has none of are made of, and what they report when they are used.
//
// A segmented control, a rating and a stepper have no element behind them, so the renderer builds each
// out of parts of its own the way UIKit builds the segments of a UISegmentedControl. A part the renderer
// does not build is an empty box that reports nothing, which is "I touch it and nothing happens" on the
// page, and a prop declared structural and never applied is the same hole seen from the other side.

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
    assert(element.children[1].dataset.varnChosen === "true", "the chosen segment stands out from the others");
    assert(element.children[0].dataset.varnChosen === "false", "a segment that is not chosen does not");

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

// A stepper is held to its bounds whatever order the props of one batch arrived in.
//
// A json object carries its fields in no order, so a value clamped as it arrives is clamped against
// whichever bound was applied before it, and the readout shows a number the tree said was out of reach.
{
    const element = control(5, "stepper", { value: 50 });

    assert(element.children[1].textContent === "50", `a stepper nobody bounded keeps what it was given, got ${element.children[1].textContent}`);

    renderer.apply([{ op: "update", id: 5, props: { value: 50, minimum: 0, maximum: 10 } }]);

    assert(element.children[1].textContent === "10",
        `and one that was bounded is held to them, got ${element.children[1].textContent}`);
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
    const button = control(40, "filepicker", {
        title: "Choose a file",
        accept: ["image/png", "application/pdf"],
        multiple: true,
        maxBytes: 16,
        onPick: true,
    });

    const chooser = renderer.nodes.get(40).control;

    // The browser's own chooser carries a caption of its choosing, in the browser's language rather than
    // the application's, so what a reader presses is the button the caller titled.
    assert(button.children[0].textContent === "Choose a file", "a chooser is the button it was titled");
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

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, pointerId: 1, buttons: 1 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(reported(50).length === 1, "a finger that stayed put is a press");

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, pointerId: 1, buttons: 1 });
    surface.dispatch("pointermove", { clientX: 120, clientY: 24, pointerId: 1, buttons: 1 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(reported(50).length === 2, "and one that wandered across it is still a press");
}

// A box the tree asked for a swipe on gives the press up to the swipe.
{
    const row = control(51, "pressable", { onPress: true, onSwipe: true });

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row, pointerId: 1, buttons: 1 });
    surface.dispatch("pointermove", { clientX: 160, clientY: 24, pointerId: 1, buttons: 1 });
    row.dispatch("click", { type: "click", detail: 1 });

    const swipes = events.filter((event) => event.id === 51 && event.name === "onSwipe");

    assert(swipes.length === 1, `a swipe across it is reported, got ${swipes.length}`);
    assert(swipes[0].payload.direction === "right", "with the direction the finger went");
    assert(events.filter((event) => event.id === 51 && event.name === "onPress").length === 0,
        "and the press it beat is not reported");

    // The press after a swipe stands on its own rather than on what the last finger did.
    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, pointerId: 1, buttons: 1 });
    row.dispatch("click", { type: "click", detail: 1 });

    assert(events.filter((event) => event.id === 51 && event.name === "onPress").length === 1,
        "and the press after it is a press again");
}

// A gesture ends when the pointer comes up, and a pointer moving with nothing held is not a gesture.
//
// The travel was armed on the way down and disarmed only by a swipe, so a mouse crossing the page minutes
// after a click was reported as a swipe on whatever it had last pressed.
{
    const row = control(53, "pressable", { onPress: true, onSwipe: true });
    const swipes = () => events.filter((event) => event.id === 53 && event.name === "onSwipe").length;

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row, pointerId: 1, buttons: 1 });
    surface.dispatch("pointerup", { clientX: 10, clientY: 20, pointerId: 1, buttons: 0 });
    surface.dispatch("pointermove", { clientX: 300, clientY: 400, pointerId: 1, buttons: 0 });

    assert(swipes() === 0, "a pointer moving after it came up is not a swipe");

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row, pointerId: 1, buttons: 1 });
    surface.dispatch("pointermove", { clientX: 300, clientY: 24, pointerId: 2, buttons: 1 });

    assert(swipes() === 0, "and neither is a second pointer moving somewhere else");

    surface.dispatch("pointermove", { clientX: 300, clientY: 24, pointerId: 1, buttons: 1 });

    assert(swipes() === 1, "the pointer that went down is the one that swipes");
}

// A control reached with the keyboard is pressed by the keyboard, whatever a finger did before it.
{
    const row = control(52, "pressable", { onPress: true, onSwipe: true });

    surface.dispatch("pointerdown", { clientX: 10, clientY: 20, target: row, pointerId: 1, buttons: 1 });
    surface.dispatch("pointermove", { clientX: 160, clientY: 24, pointerId: 1, buttons: 1 });
    row.dispatch("click", { type: "click", detail: 0 });

    assert(events.filter((event) => event.id === 52 && event.name === "onPress").length === 1,
        "a click with no pointer behind it is a press");
}

// A string that says where its own lines end says it on the page too.
//
// A browser collapses a line break into a space and a run of spaces into one, and the phones keep both,
// so a label written in three lines was drawn as one and measured as one — everything below it sat two
// lines too high, on one platform out of three.
{
    const element = control(60, "text", { text: "one\ntwo\nthree" });

    assert(element.style.whiteSpace === "pre-wrap",
        `a line break is kept where it was written, got ${element.style.whiteSpace}`);

    const one = renderer.measureText("one", { fontSize: 16 }, 0);
    const three = renderer.measureText("one\ntwo\nthree", { fontSize: 16 }, 0);

    assert(Math.abs(three.height - one.height * 3) < 0.01,
        `and a label of three lines is three lines tall, got ${three.height} against ${one.height}`);
}

// A paragraph is broken where the browser breaks it, which is between words rather than by division.
{
    const paragraph = "the quick brown fox jumps over the lazy dog and keeps running";
    const measured = renderer.measureText(paragraph, { fontSize: 16 }, 160);
    const line = renderer.measureText("one", { fontSize: 16 }, 0).height;

    assert(measured.width === 160, `a wrapped paragraph fills the width it was given, got ${measured.width}`);
    assert(measured.height / line >= 3, `and takes the lines its words need, got ${measured.height / line}`);
}

// A box the tree listens to a press on is reached with a tab and worked with a return.
//
// A browser gives that to the controls it drew itself and to nothing else, so a row built out of a box
// was one a reader with no pointer could not open at all. A press that is taken away takes the tab stop
// with it, or the row is still reached by a reader it now does nothing for.
{
    const row = control(80, "pressable", { onPress: true });

    assert(row.getAttribute("tabindex") === "0",
        `a box that answers a press is reached with a tab, got ${row.getAttribute("tabindex")}`);
    assert(row.getAttribute("role") === "button", "and says what it is to whatever reads the screen");

    row.dispatch("keydown", { type: "keydown", key: "Enter", preventDefault() {} });
    assert(reported(80).length === 1, "a return on it is a press");

    renderer.apply([{ op: "update", id: 80, props: { onPress: "__varn_removed__" } }]);

    assert(row.getAttribute("tabindex") === null, "a press taken away takes the tab stop with it");
    assert(row.getAttribute("role") === null, "and what it said it was");

    row.dispatch("keydown", { type: "keydown", key: "Enter", preventDefault() {} });
    assert(reported(80).length === 1, "and a return on it is nothing at all");
}

// A string is drawn in the line it was measured in.
//
// The page it is served from sets a line height of its own on the body, so clearing the property when a
// style names none drew every label in a line taller than the box the engine had reserved: the glyphs
// sat low in it and the last line spilled past the bottom.
{
    const element = control(61, "text", { text: "Apple", style: { fontSize: 16, fontWeight: "600" } });
    const measured = renderer.measureText("Apple", { fontSize: 16, fontWeight: "600" }, 0);

    assert(element.style.lineHeight === `${measured.height}px`,
        `a label is drawn in the line it measured, got ${element.style.lineHeight} against ${measured.height}`);

    const declared = control(62, "text", { text: "Apple", style: { fontSize: 20, lineHeight: 1.5 } });

    assert(declared.style.lineHeight === "30px",
        `and in the one a style names when it names one, got ${declared.style.lineHeight}`);
}

// What a style does not name is cleared, never written as nothing of its own.
//
// A control the browser has none of is drawn by the stylesheet, and an element that writes its own
// border away cannot then be given one by a rule: every spinner on the page was a ring nothing drew.
{
    const spinner = control(63, "activity", { style: { width: 24, height: 24 } });

    assert(spinner.style.borderStyle === "",
        `a control a rule draws keeps the border of that rule, got "${spinner.style.borderStyle}"`);

    const outlined = control(64, "button", { title: "Outlined", style: { borderColor: "#8c9eff", border: 1 } });

    assert(outlined.style.borderStyle === "solid", "and a border a style names is drawn");
    assert(outlined.style.borderWidth === "1px", "as wide as it was named");
}

// A pointer resting over a box is a mouse, never a finger.
//
// A browser raises the same two events around every tap, so a row bound to them would light up under a
// finger and stay lit until the next one landed somewhere else.
{
    const row = control(70, "pressable", { onHoverIn: true, onHoverOut: true });

    row.dispatch("pointerenter", { type: "pointerenter", pointerType: "mouse" });
    assert(reported(70).length === 1, "a mouse arriving over a box is reported");

    row.dispatch("pointerleave", { type: "pointerleave", pointerType: "mouse" });
    assert(reported(70).length === 2, "and so is one leaving it");

    row.dispatch("pointerenter", { type: "pointerenter", pointerType: "touch" });
    assert(reported(70).length === 2, "a finger landing on it is not a pointer resting over it");
}

console.log("web.controls ok");
