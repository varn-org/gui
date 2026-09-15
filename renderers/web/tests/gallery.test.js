// Runs the sample application the way a browser runs it: the released wasm engine, the whole Lua
// framework, the same archive the phones load, and the renderer as the page carries it.
//
// The host is imported out of `apps/web` rather than from the sources beside this file, since that
// folder is what a static host serves and what a browser loads: a page importing its way out of it is a
// blank screen and a 404 in a console nobody had open.
//
// It needs the engine, which `python3 run.py fetch-native --platform web` puts in apps/web, and the
// framework, the gallery and the renderer that `python3 run.py web` assembles beside it. It skips rather
// than fails when any of them is absent, so this runs wherever they are available and stays quiet where
// they are not.

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { install } from "../dom.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const page = resolve(root, "apps/web/dist");

// Every file the page loads carries the hash of what it holds, so what is asked for here is the kind of
// file rather than its name, which is what a browser reading the page does as well.
function assembled(kind, extension) {
    if (!existsSync(page)) {
        return undefined;
    }

    const name = readdirSync(page)
        .find((entry) => entry.startsWith(`${kind}.`) && entry.endsWith(extension));

    return name === undefined ? undefined : resolve(page, name);
}

const carried = [
    assembled("varn_wasm", ".js"),
    assembled("varn_wasm", ".wasm"),
    assembled("framework", ".zip"),
    assembled("gallery", ".vap"),
    assembled("host", ".js"),
];

if (carried.some((path) => path === undefined)) {
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

const { WebHost } = await import(assembled("host", ".js"));
const factory = (await import(assembled("varn_wasm", ".js"))).default;
const module = await factory({ wasmBinary: readFileSync(assembled("varn_wasm", ".wasm")) });

const host = new WebHost(module, surface);

// Opening runs on a coroutine, so a failure there reaches the host rather than the log. Holding it here
// means a gallery that fails to open names the reason instead of asserting an empty page twelve times.
let problem;
host.onProblem = (reported) => { problem = reported; };

await host.installFramework(assembled("framework", ".zip"));
await host.install(assembled("gallery", ".vap"), "gallery.vap");
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
    painted.element.style.backgroundColor.startsWith("#")
        || painted.element.style.backgroundColor.startsWith("rgb"),
    `a colour must reach the page resolved, got ${painted.element.style.backgroundColor}`,
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
