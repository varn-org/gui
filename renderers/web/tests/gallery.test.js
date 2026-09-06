// Runs the sample application the way a browser runs it: the released wasm engine, the whole Lua
// framework, the real DOM renderer, and the same archive the phones load.
//
// It needs the engine, which `python3 run.py fetch-native --platform web` puts in apps/web, and the
// framework and gallery that `python3 run.py web` assembles beside it. It skips rather than fails when
// any of them is absent, so this runs wherever they are available and stays quiet where they are not.

import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { install } from "../dom.js";
import { WebHost } from "../host.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const page = resolve(root, "apps/web");
const needed = ["varn_wasm.js", "varn_wasm.wasm", "framework.zip", "gallery.vap"].map((name) => resolve(page, name));

if (needed.some((path) => !existsSync(path))) {
    console.log("web.gallery skipped: run `python3 run.py fetch-native --platform web` then `python3 run.py web`");
    process.exit(0);
}

// The document the renderer draws into, plus what the host reads off the page around it.
const surface = install();
surface.clientWidth = 390;
surface.clientHeight = 844;

globalThis.document.getElementById = () => surface;
globalThis.btoa = (text) => Buffer.from(text, "binary").toString("base64");
globalThis.fetch = async (url) => ({
    ok: true,
    arrayBuffer: async () => readFileSync(resolve(page, url)),
});
globalThis.ResizeObserver = class {
    observe() {}
};
globalThis.requestAnimationFrame = (run) => setTimeout(run, 0);

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

/** Counts the nodes of a type the renderer built, which is what proves the tree reached the page. */
function counted(host, type) {
    let total = 0;

    for (const node of host.renderer.nodes.values()) {
        if (node.type === type) {
            total += 1;
        }
    }

    return total;
}

const factory = (await import(resolve(page, "varn_wasm.js"))).default;
const module = await factory({ wasmBinary: readFileSync(resolve(page, "varn_wasm.wasm")) });

const host = new WebHost(module, surface);

// Opening runs on a coroutine, so a failure there reaches the host rather than the log. Holding it here
// means a gallery that fails to open names the reason instead of asserting an empty page twelve times.
let problem;
host.onProblem = (reported) => { problem = reported; };

await host.installFramework("./framework.zip");
await host.install("./gallery.vap", "gallery.vap");
host.start();

// The engine is advanced the way the page advances it, one tick at a time, until the page has settled.
async function settle(until, ticks = 200) {
    for (let tick = 0; tick < ticks; tick += 1) {
        module.varnPoll();
        await new Promise((done) => setTimeout(done, 0));

        if (until()) {
            return;
        }
    }
}

await settle(() => counted(host, "text") > 0);

assert(problem === undefined, `the gallery must open without a problem, got ${problem}`);
assert(counted(host, "text") > 0, "the gallery must have drawn its labels");
assert(counted(host, "safearea") === 1, "the gallery must be inside a safe area");
assert(counted(host, "switch") === 0, "the gallery carries no appearance switch of its own");
assert(counted(host, "sectionlist") === 1, "the first screen is the index of what there is to see");
assert(surface.children.length === 1, "the surface must hold exactly one root");

// A frame reaches the page as a position, which is what proves layout crossed the bridge.
const root_ = surface.children[0];
assert(root_.style.width === "390px", `the root must fill the surface, got ${root_.style.width}`);
assert(root_.style.height === "844px", `the root must fill the surface, got ${root_.style.height}`);

// A style token reaches the page resolved, never as the name only the theme knows.
const painted = [...host.renderer.nodes.values()].find((node) => node.props.style?.background !== undefined);
assert(painted !== undefined, "something on the page must carry a background");
assert(
    painted.element.style.background.startsWith("#") || painted.element.style.background.startsWith("rgb"),
    `a colour must reach the page resolved, got ${painted.element.style.background}`,
);

// Opening a demo from the index reaches Lua and comes back as a different tree.
const rows = [...host.renderer.nodes.values()].filter((node) => node.type === "pressable");
assert(rows.length > 1, "the index must list the demos it carries");

const before = counted(host, "text");
rows[0].element.dispatch("click", {});
await settle(() => counted(host, "textinput") > 0 || counted(host, "button") > 0, 60);

assert(counted(host, "text") !== before, "opening a demo must reach the tree");

console.log("web.gallery ok");
process.exit(0);
