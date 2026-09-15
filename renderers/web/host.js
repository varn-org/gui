// The web host. It owns the run loop, hands the engine one tick per frame, and carries the bridge
// the Lua side reaches through host.gui_apply and host.on.

import { Preferences } from "./preferences.js";
import { WebRenderer } from "./renderer.js";

// What the engine runs first, using only what the engine itself carries.
//
// A browser shares no filesystem with the engine, so the framework and the application both arrive as
// bytes over the bridge. This writes them into the filesystem the engine does have, and from there
// everything is ordinary files and the launcher is the same one the phones use.
const BOOTSTRAP = `
local async = require("async")
local crypto = require("crypto")
local fs = require("fs")
local zip = require("zip")

async.run(function()
    local framework = host.gui_framework()

    fs.writeFile("/framework.zip", crypto.base64Decode(framework.bytes)):await()
    zip.extract("/framework.zip", "/framework"):await()

    package.path = "/framework/?.lua;/framework/?/init.lua;" .. package.path

    require("gui.host.launch").start({
        framework = "/framework",
        cache = "/cache",
        onProblem = function(problem) host.gui_problem({ problem = problem }) end,
    })
end)
`;

export class WebHost {
    constructor(module, container) {
        this.module = module;
        this.renderer = new WebRenderer(container, (id, name, payload) => this.event(id, name, payload));
        this.container = container;
        this.running = false;
        this.keyboard = 0;
        this.queued = [];
        this.watching = new AbortController();
        this.banner = undefined;
        this.reported = 0;
        this.reportedState = "active";
        this.preferences = new Preferences();
        this.onProblem = (problem) => this.show(problem);
    }

    // Tells the reader what went wrong, over the application rather than in place of it.
    //
    // A message written into the container takes the screen away for good: the renderer's own nodes are
    // gone, every id it holds names an element that is no longer there, and one failed handler ends the
    // session. A banner stands over whatever is drawn, says the newest problem and how many came before
    // it, and goes when it is pressed.
    show(problem) {
        if (this.banner === undefined || !this.banner.isConnected) {
            this.banner = document.createElement("div");
            this.banner.setAttribute("role", "alert");
            this.banner.style.cssText = "position:fixed;left:12px;right:12px;bottom:12px;z-index:2147483647;"
                + "padding:12px 14px;border-radius:10px;background:#3a0f13;color:#ffdadd;cursor:pointer;"
                + "font:14px/1.45 system-ui,-apple-system,sans-serif;box-shadow:0 8px 28px rgba(0,0,0,.35)";
            this.banner.addEventListener("click", () => this.banner.remove());
            this.reported = 0;
        this.preferences = new Preferences();
            (document.body ?? document.documentElement).append(this.banner);
        }

        this.reported += 1;
        this.banner.textContent = this.reported === 1 ? problem : `${problem} (${this.reported} problems)`;
    }

    // Answers a call from the engine, turning what fails into a report rather than a throw.
    //
    // The engine calls the page from inside a wasm frame, and a JavaScript exception raised here unwinds
    // frames no C++ handler can catch: the call never returns, the Lua stack is left mid-call and the
    // runtime is dead. Every call answers something, and what went wrong is reported instead.
    answering(name, empty, work) {
        return (json) => {
            try {
                return work(json);
            } catch (error) {
                // Telling the reader is written by the application too, and this is the one frame that
                // must not throw, so a listener that refuses to be told is left to the console.
                try {
                    this.onProblem(`${name} failed: ${error.message}`);
                } catch (refused) {
                    console.error(`${name} failed: ${error.message}`, refused);
                }

                return empty;
            }
        };
    }

    // Everything crossing the bridge is json, so a call arrives as text and answers as text.
    register() {
        const module = this.module;

        module.varnRegister("gui_apply", this.answering("drawing the screen", "null", (json) => {
            this.renderer.apply(JSON.parse(json));
            return "null";
        }));

        module.varnRegister("gui_measure", this.answering("measuring a string", "null", (json) => {
            const { text, style, bound } = JSON.parse(json);
            return JSON.stringify(this.renderer.measureText(text, style ?? {}, bound));
        }));

        module.varnRegister("gui_measure_control", this.answering("measuring a control", "null", (json) => {
            const { type } = JSON.parse(json);
            return JSON.stringify(this.renderer.measureControl(type));
        }));

        module.varnRegister("gui_invoke", this.answering("reaching a node", "null", (json) => {
            const { id, method, arguments: args } = JSON.parse(json);
            return JSON.stringify(this.renderer.invoke(id, method, args ?? {}));
        }));

        module.varnRegister("gui_problem", this.answering("reporting a problem", "null", (json) => {
            const { problem } = JSON.parse(json);
            this.onProblem(problem ?? "the application failed");
            return "null";
        }));

        module.varnRegister("gui_files", this.answering("keeping a file", "null", (json) => {
            this.keep(JSON.parse(json));
            return "null";
        }));

        module.varnRegister("gui_preferences", this.answering("reaching a preference", "null", (json) => {
            this.preference(JSON.parse(json));
            return "null";
        }));

        module.varnRegister("gui_theme", this.answering("painting the page", "null", (json) => {
            this.renderer.showTheme(JSON.parse(json));
            return "null";
        }));

        module.varnRegister("gui_capabilities", this.answering("declaring what the page can do", "null",
            () => JSON.stringify(this.renderer.capabilities)));

        module.varnRegister("gui_surface", this.answering("describing the surface", "null",
            () => JSON.stringify(this.surface())));

        module.varnRegister("gui_archive", this.answering("opening the application", "null", () => {
            if (this.archive === undefined) {
                throw new Error("no archive was installed, so there is nothing to run");
            }

            return JSON.stringify(this.archive);
        }));

        module.varnRegister("gui_framework", this.answering("opening the framework", "null", () => {
            if (this.framework === undefined) {
                throw new Error("no framework was installed, so there is nothing to run it with");
            }

            return JSON.stringify(this.framework);
        }));

        // A browser keeps the address in its own history, so back and forward work the way a reader
        // expects them to rather than leaving the application somewhere the address bar disagrees with.
        module.varnRegister("gui_address", this.answering("keeping the address", "null", (json) => {
            const { address, mode } = JSON.parse(json);

            if (mode === "back") {
                history.back();
                return "null";
            }

            if (mode === "replace") {
                history.replaceState({}, "", this.located(address));
                return "null";
            }

            history.pushState({}, "", this.located(address));
            return "null";
        }));

        module.varnRegister("gui_register_font", this.answering("registering a font", "null", (json) => {
            const { family, bytes, weight, style } = JSON.parse(json);
            this.renderer.registerFont(family, bytes, { weight, style })
                .then(() => this.send("gui.fontsRegistered", "{}"))
                .catch((error) => this.onProblem(`the font ${family} was refused: ${error.message}`));
            return "null";
        }));
    }

    // What the page is at, under the base it is served from, which is what a router opens on.
    //
    // A page served from a sub-path is at that path before an application has gone anywhere, so the base
    // is taken off what is reported and put back on what is pushed. An application then names `/items/3`
    // wherever it is deployed rather than knowing where it was deployed to.
    address() {
        const base = new URL(document.baseURI).pathname.replace(/\/$/, "");
        const path = location.pathname.startsWith(base) ? location.pathname.slice(base.length) : location.pathname;

        return `${path === "" ? "/" : path}${location.search}`;
    }

    // Answers what the browser is told, which is the address under the base the page is served from.
    located(where) {
        return new URL(where.replace(/^\//, ""), document.baseURI).href;
    }

    surface() {
        return {
            platform: "web",
            address: this.address(),
            width: this.container.clientWidth,
            height: this.container.clientHeight,
            scale: this.renderer.scale,
            appearance: this.appearance(),
            state: this.state(),
            safeArea: this.renderer.safeArea(),
        };
    }

    appearance() {
        return globalThis.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }

    // A hidden page is out of sight and may be discarded without another word, which is the background.
    // A visible page whose window is not the one being typed into is in front and not taking input.
    state() {
        if (document.visibilityState === "hidden") {
            return "background";
        }

        return document.hasFocus?.() === false ? "inactive" : "active";
    }

    event(id, name, payload) {
        this.send("gui.event", JSON.stringify({ id, name, payload }));
    }

    // Fetches the application archive and holds it for the engine to take.
    async install(url, name) {
        this.archive = await this.fetchArchive(url, name);
        return this.archive;
    }

    // Fetches the framework the application is built on, which a browser has to be given.
    async installFramework(url) {
        this.framework = await this.fetchArchive(url, "framework.zip");
        return this.framework;
    }

    async fetchArchive(url, name) {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`the archive at ${url} could not be fetched: ${response.status}`);
        }

        const bytes = new Uint8Array(await response.arrayBuffer());
        return { name, bytes: WebHost.base64(bytes) };
    }

    // Encoded in blocks, since spreading a whole archive into one call overruns the argument limit.
    static base64(bytes) {
        const block = 0x8000;
        const parts = [];

        for (let at = 0; at < bytes.length; at += block) {
            parts.push(String.fromCharCode.apply(null, bytes.subarray(at, at + block)));
        }

        return btoa(parts.join(""));
    }

    start(source) {
        this.register();

        const result = this.module.varnLoadChunk(source ?? BOOTSTRAP);
        if (!result.ok) {
            throw new Error(result.error);
        }

        this.running = true;
        this.observeSize();
        this.observeKeyboard();
        this.observeAppearance();
        this.observeLifecycle();
        this.observeAddress();
        this.pump();
    }

    observeSize() {
        const report = () => this.send("gui.resize", JSON.stringify({
            width: this.container.clientWidth,
            height: this.container.clientHeight,
            safeArea: this.renderer.safeArea(),
        }));

        this.sizes = new ResizeObserver(report);
        this.sizes.observe(this.container);
        report();
    }

    // The reader may go back and forward through what the browser kept, which is an address arriving.
    observeAddress() {
        globalThis.addEventListener?.("popstate", () => {
            this.send("gui.address", JSON.stringify({ address: this.address() }));
        }, { signal: this.watching.signal });
    }

    observeAppearance() {

        globalThis.matchMedia?.("(prefers-color-scheme: dark)").addEventListener?.("change", () => {
            this.send("gui.appearance", JSON.stringify({ appearance: this.appearance() }));
        }, { signal: this.watching.signal });
    }

    // Where the page is, which a browser says four ways and which comes to the same three states a phone
    // has. `pagehide` is the last word a page is given before it is discarded, so it is reported as the
    // background whatever the visibility says.
    observeLifecycle() {
        // The engine is handed it and pumped in the same breath rather than at the next frame, because a
        // browser stops handing out frames to a page it has hidden. Queued for a pump that is not coming
        // is a screen that is never told it went away, and `pagehide` is the last word a page gets.
        const report = (state) => {
            if (state === this.reportedState) {
                return;
            }

            this.reportedState = state;
            this.send("gui.lifecycle", JSON.stringify({ state }));
            this.settle();
        };

        const reading = () => report(this.state());

        document.addEventListener("visibilitychange", reading, { signal: this.watching.signal });
        globalThis.addEventListener?.("focus", reading, { signal: this.watching.signal });
        globalThis.addEventListener?.("blur", reading, { signal: this.watching.signal });

        globalThis.addEventListener?.("pagehide", () => report("background"), { signal: this.watching.signal });

        // A browser asks for memory back by discarding the page rather than by saying so, so the one
        // moment it gives is the page being hidden, which is when what can be worked out again goes.
        document.addEventListener("visibilitychange", () => {
            if (document.visibilityState === "hidden") {
                this.send("gui.memory", "{}");
                this.settle();
            }
        }, { signal: this.watching.signal });
    }

    // A soft keyboard shrinks the visual viewport rather than the window, which is what the tree avoids.
    observeKeyboard() {
        const viewport = window.visualViewport;
        if (viewport === undefined || viewport === null) {
            return;
        }

        const report = () => {
            const height = Math.max(0, window.innerHeight - viewport.height - viewport.offsetTop);

            if (Math.round(height) !== this.keyboard) {
                this.keyboard = Math.round(height);
                this.send("gui.keyboard", JSON.stringify({ height: this.keyboard }));
            }
        };

        viewport.addEventListener("resize", report, { signal: this.watching.signal });
        viewport.addEventListener("scroll", report, { signal: this.watching.signal });
    }

    // One tick per frame, on the thread that owns the interface, which is what keeps a scroll smooth
    // while a request is in flight.
    /**
     * Keeps a file, or hands it to whatever the browser has for sending one.
     *
     * A page has no folder of its own to write into, so what a browser calls keeping is a download the
     * reader chooses where to put. Sharing is the same file through the system's own sheet, which phones
     * have and desktops mostly do not: what the browser cannot do is said rather than silently skipped.
     */
    async keep(request) {
        const answer = (reply) => this.send("gui.files", JSON.stringify({ ticket: request.ticket, ...reply }));

        try {
            const found = await fetch(request.path);
            const blob = await found.blob();
            const name = WebHost.named(request.path, blob.type);

            if (request.action === "share") {
                const file = new File([blob], name, { type: blob.type });

                if (navigator.canShare?.({ files: [file] }) !== true) {
                    answer({ problem: "this browser cannot share a file" });
                    return;
                }

                await navigator.share({ files: [file], title: request.title });
                answer({ path: request.path });
                return;
            }

            const link = document.createElement("a");

            link.href = URL.createObjectURL(blob);
            link.download = name;
            document.body.appendChild(link);
            link.click();
            link.remove();

            URL.revokeObjectURL(link.href);
            answer({ path: name });
        } catch (problem) {
            answer({ problem: String(problem?.message ?? problem) });
        }
    }

    /**
     * Answers what the store holds, which is a value of whatever shape the tree wrote.
     *
     * Everything here is asynchronous — the key is read out of IndexedDB and the value is decrypted with
     * it — so the answer comes back as an event the way a file's does rather than as a return.
     */
    async preference(request) {
        const answer = (reply) =>
            this.send("gui.preferences", JSON.stringify({ ticket: request.ticket, ...reply }));

        try {
            switch (request.action) {
                case "set":
                    await this.preferences.set(request.name, request.value);
                    answer({});
                    return;

                case "get": {
                    const held = await this.preferences.get(request.name);

                    answer(held === undefined ? {} : { value: held });
                    return;
                }

                case "remove":
                    await this.preferences.remove(request.name);
                    answer({});
                    return;

                case "clear":
                    await this.preferences.clear();
                    answer({});
                    return;

                case "names":
                    answer({ value: await this.preferences.names() });
                    return;

                default:
                    answer({ problem: "a preference is set, read, removed, cleared or listed" });
            }
        } catch (problem) {
            answer({ problem: String(problem?.message ?? problem) });
        }
    }

    // Answers what a kept file is called, which a page has to invent since a blob carries no name.
    static named(path, type) {
        const known = path.split("/").pop() ?? "";

        if (known.includes(".")) {
            return known;
        }

        const ending = { "image/png": "png", "image/jpeg": "jpg", "video/mp4": "mp4",
            "video/webm": "webm", "audio/webm": "webm", "audio/mp4": "m4a" }[(type ?? "").split(";")[0]];

        return `varn-${Date.now()}.${ending ?? "bin"}`;
    }

    // Everything the page tells the engine is queued where it is raised and handed over here.
    //
    // The engine unwinds its own stack to wait and rewinds it from a callback of its own, so a call that
    // arrives from a click or a resize in the middle of that lands in a stack it is halfway through
    // rebuilding: the rewind reads what is no longer there and the engine dies with "memory access out
    // of bounds", which is every overlay in the gallery taking the application down with it. The pump is
    // the one place the engine is known to be between operations.
    send(name, payload) {
        // An engine that has stopped answering is never given anything again, or what the page goes on
        // reporting piles up behind a pump that will not run and is never drained.
        if (!this.running) {
            return;
        }

        this.queued.push([name, payload]);
    }

    deliver() {
        const waiting = this.queued;
        this.queued = [];

        for (const [name, payload] of waiting) {
            this.module.varnEmit(name, payload);
        }
    }

    // Hands the engine everything the page has said and gives it one turn, which is what a tick is made
    // of and what a moment the page will not get a frame for needs on its own.
    settle() {
        if (!this.running) {
            return;
        }

        try {
            this.deliver();
            this.module.varnPoll();
        } catch (error) {
            this.running = false;
            this.container.dataset.varnStopped = "true";
            this.onProblem(`the application stopped: ${error.message}`);
        }
    }

    pump() {
        if (!this.running) {
            return;
        }

        // An engine that has stopped answering leaves the last frame it drew on the screen, which reads
        // as a layout defect rather than as an application that died: a sidebar over a pane, a control
        // wider than the box it sits in, a screen that no longer answers a finger. It is said out loud,
        // what it drew is drained of colour and stops taking a finger, and the pump stops, since every
        // tick after the first failure fails the same way.
        this.settle();

        if (!this.running) {
            return;
        }

        requestAnimationFrame(() => this.pump());
    }

    // What was set up to watch the page is given back, or it goes on reporting into an engine that has
    // stopped answering.
    stop() {
        this.deliver();
        this.module.varnEmit("gui.stop", "{}");
        this.module.varnPoll();

        this.running = false;
        this.queued = [];
        this.sizes?.disconnect();
        this.watching.abort();
        this.banner?.remove();
    }
}
