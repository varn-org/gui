// What the page answers the engine when something on this side fails.
//
// The engine calls the page from inside a wasm frame. A JavaScript exception raised in one of those
// calls unwinds frames no C++ handler can catch: the call never returns, the Lua stack is left in the
// middle of a call and the runtime is dead. Every call has to answer, and a failure has to be told
// rather than thrown.

import { install } from "../dom.js";
import { WebHost } from "../host.js";

const surface = install();

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

/** Stands in for the engine, keeping what the page registered so a test can call it the way wasm does. */
function engine() {
    const calls = new Map();

    return {
        calls,
        varnRegister: (name, work) => calls.set(name, work),
        varnEmit: () => {},
        varnPoll: () => {},
    };
}

const module = engine();
const host = new WebHost(module, surface);

host.register();

// A call that fails answers the engine and names what went wrong.
{
    const problems = [];
    host.onProblem = (problem) => problems.push(problem);

    const answer = module.calls.get("gui_apply")("{ this is not json");

    assert(answer === "null", `a call that failed must still answer, got ${answer}`);
    assert(problems.length === 1, `and it must be reported once, got ${problems.length}`);
    assert(problems[0].startsWith("drawing the screen failed:"), `named by what it was, got ${problems[0]}`);
}

// A listener that refuses to be told is not a way to throw out of the frame that must not throw.
{
    host.onProblem = () => {
        throw new Error("a listener that will not be told");
    };

    const answer = module.calls.get("gui_measure")("{ this is not json");

    assert(answer === "null", "a listener that failed must not raise out of the call either");
}

// What the engine asks for is answered as it always was, so containment costs nothing when nothing fails.
{
    host.onProblem = (problem) => {
        console.error(`failed: nothing must be reported here, got ${problem}`);
        process.exit(1);
    };

    const measured = JSON.parse(module.calls.get("gui_measure")(JSON.stringify({
        text: "hello",
        style: { fontSize: 15 },
    })));

    assert(typeof measured.width === "number", "a measurement must come back as a size");

    const declared = JSON.parse(module.calls.get("gui_capabilities")());
    assert(declared.text === true, "the page must declare what it can draw");
}

// A problem is shown over the application rather than in place of it.
{
    surface.appendChild(globalThis.document.createElement("div"));

    host.onProblem = (problem) => host.show(problem);
    host.show("the first problem");

    assert(surface.children.length === 1, "the screen the reader is looking at must still be there");
    assert(host.banner.textContent === "the first problem", `the banner says it, got ${host.banner.textContent}`);

    host.show("the second problem");
    assert(host.banner.textContent.includes("(2 problems)"), `and counts them, got ${host.banner.textContent}`);

    host.banner.listeners.get("click")[0]();
    assert(host.banner.isConnected === false, "and it goes when it is pressed");
}

// An engine that stops answering leaves a page that outlives it, which must not read as a live screen.
{
    const stopping = engine();
    stopping.varnPoll = () => {
        throw new Error("memory access out of bounds");
    };

    const dead = new WebHost(stopping, install());
    const problems = [];

    dead.onProblem = (problem) => problems.push(problem);
    dead.running = true;
    dead.pump();

    assert(dead.running === false, "the pump stops rather than failing the same way every frame");
    assert(problems.length === 1 && problems[0].startsWith("the application stopped:"),
        `and says the application stopped, got ${problems[0]}`);
    assert(dead.container.dataset.varnStopped === "true",
        "and what it drew is marked as no longer alive rather than left looking like a screen");
}

// The page says where it is, in the three states the engine has, and says it when it changes.
//
// A browser has four ways of saying it: a page that is hidden, a window that has lost focus, and
// `pagehide`, which is the last word a page is ever given. A page that never says goes on being treated
// as though the reader were looking at it, and a screen is never told to save.
{
    const emitted = [];
    const module = engine();

    module.varnEmit = (name, payload) => emitted.push([name, payload]);

    const host = new WebHost(module, surface);
    host.running = true;

    assert(host.state() === "active", `a visible focused page is in front, said ${host.state()}`);

    host.observeLifecycle();

    document.visibilityState = "hidden";
    document.dispatch("visibilitychange");

    const lifecycle = emitted.filter(([name]) => name === "gui.lifecycle");

    assert(lifecycle.length === 1, `a hidden page says so once, said ${lifecycle.length} times`);
    assert(JSON.parse(lifecycle[0][1]).state === "background",
        `and says it is out of sight, said ${lifecycle[0][1]}`);

    assert(emitted.some(([name]) => name === "gui.memory"),
        "and a hidden page is a browser asking for memory back, since it asks by discarding rather than by saying so");

    document.visibilityState = "visible";
    document.dispatch("visibilitychange");

    const back = emitted.filter(([name]) => name === "gui.lifecycle");

    assert(JSON.parse(back[back.length - 1][1]).state === "active",
        `and says it is back, said ${back[back.length - 1][1]}`);
}

// Saying the same thing twice is not saying anything, and the engine is not told twice.
{
    const emitted = [];
    const module = engine();

    module.varnEmit = (name, payload) => emitted.push([name, payload]);

    const host = new WebHost(module, surface);
    host.running = true;
    host.observeLifecycle();

    document.visibilityState = "hidden";
    document.dispatch("visibilitychange");
    document.dispatch("pagehide");

    const said = emitted.filter(([name]) => name === "gui.lifecycle");

    assert(said.length === 1, `a page already out of sight says so once, said ${said.length} times`);

    document.visibilityState = "visible";
}

console.log("web.host ok");
