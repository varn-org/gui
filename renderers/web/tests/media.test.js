// What a sound and a film are asked to do, which is asked rather than described.
//
// Moving to a moment is asked for rather than described. A prop carrying a moment is sent only when it differs from
// the last one: a reader who drags a scrubber back to where they already were is answered by nothing.
// Clearing it when the drag ended removed the prop, which two renderers read as a seek to the beginning.

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

function build(id, type, props) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    return renderer.nodes.get(id).element;
}

// A sound is moved to the moment it was asked for, and asking twice moves it twice.
{
    const element = build(1, "audio", { source: "loop.mp3", playing: false });

    element.duration = 184;

    renderer.invoke(1, "seek", { seconds: 90 });
    assert(element.currentTime === 90, `a seek moves the sound, got ${element.currentTime}`);

    element.currentTime = 91;
    renderer.invoke(1, "seek", { seconds: 90 });
    assert(element.currentTime === 90, "and asking for the same moment again moves it again");
}

// A moment past the end of what is loaded is held to it rather than left past it.
{
    const element = build(2, "audio", { source: "loop.mp3", playing: false });

    element.duration = 10;

    renderer.invoke(2, "seek", { seconds: 400 });
    assert(element.currentTime === 10, `a seek past the end stops at the end, got ${element.currentTime}`);

    renderer.invoke(2, "seek", { seconds: -5 });
    assert(element.currentTime === 0, `and one before the start stops at the start, got ${element.currentTime}`);
}

// A film takes the same action, since a scrubber over one is the same scrubber.
{
    const element = build(3, "video", { source: "film.mp4" });

    element.duration = 60;
    renderer.invoke(3, "seek", { seconds: 12 });

    assert(element.currentTime === 12, `a film is moved the same way, got ${element.currentTime}`);
}

// An action asked of a node that cannot do it is refused by name rather than doing nothing.
{
    build(4, "text", { text: "nothing to play" });

    let refused = false;

    try {
        renderer.invoke(4, "seek", { seconds: 1 });
    } catch (problem) {
        refused = String(problem.message).includes("seek");
    }

    assert(refused, "seeking a label must be refused");

    refused = false;

    try {
        renderer.invoke(1, "seek", { seconds: Number.NaN });
    } catch (problem) {
        refused = String(problem.message).includes("seconds");
    }

    assert(refused, "and a seek to no number at all must be refused");
}

console.log("web.media ok");
