// The web host. It owns the run loop, hands the engine one tick per frame, and carries the bridge
// the Lua side reaches through host.gui_apply and host.on.

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
        this.onProblem = (problem) => this.show(problem);
    }

    // An application that fails to open puts nothing on screen, so the reader is told there rather than
    // in a console they are not looking at.
    show(problem) {
        this.container.textContent = problem;
    }

    // Everything crossing the bridge is json, so a call arrives as text and answers as text.
    register() {
        const module = this.module;

        module.varnRegister("gui_apply", (json) => {
            this.renderer.apply(JSON.parse(json));
            return "null";
        });

        module.varnRegister("gui_measure", (json) => {
            const { text, style, bound } = JSON.parse(json);
            return JSON.stringify(this.renderer.measureText(text, style ?? {}, bound));
        });

        module.varnRegister("gui_measure_control", (json) => {
            const { type } = JSON.parse(json);
            return JSON.stringify(this.renderer.measureControl(type));
        });

        module.varnRegister("gui_invoke", (json) => {
            const { id, method, arguments: args } = JSON.parse(json);
            return JSON.stringify(this.renderer.invoke(id, method, args ?? {}));
        });

        module.varnRegister("gui_problem", (json) => {
            const { problem } = JSON.parse(json);
            this.onProblem(problem ?? "the application failed");
            return "null";
        });

        module.varnRegister("gui_capabilities", () => JSON.stringify(this.renderer.capabilities));

        module.varnRegister("gui_surface", () => JSON.stringify(this.surface()));

        module.varnRegister("gui_archive", () => {
            if (this.archive === undefined) {
                throw new Error("no archive was installed, so there is nothing to run");
            }

            return JSON.stringify(this.archive);
        });

        module.varnRegister("gui_framework", () => {
            if (this.framework === undefined) {
                throw new Error("no framework was installed, so there is nothing to run it with");
            }

            return JSON.stringify(this.framework);
        });

        module.varnRegister("gui_register_font", (json) => {
            const { family, bytes, weight, style } = JSON.parse(json);
            this.renderer.registerFont(family, bytes, { weight, style })
                .then(() => module.varnEmit("gui.fontsRegistered", "{}"))
                .catch((error) => console.error(`the font ${family} was refused: ${error.message}`));
            return "null";
        });
    }

    surface() {
        return {
            width: this.container.clientWidth,
            height: this.container.clientHeight,
            scale: this.renderer.scale,
            appearance: this.appearance(),
            safeArea: this.renderer.safeArea(),
        };
    }

    appearance() {
        return globalThis.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }

    event(id, name, payload) {
        this.module.varnEmit("gui.event", JSON.stringify({ id, name, payload }));
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
        this.pump();
    }

    observeSize() {
        const report = () => this.module.varnEmit("gui.resize", JSON.stringify({
            width: this.container.clientWidth,
            height: this.container.clientHeight,
            safeArea: this.renderer.safeArea(),
        }));

        new ResizeObserver(report).observe(this.container);
        report();
    }

    observeAppearance() {
        globalThis.matchMedia?.("(prefers-color-scheme: dark)").addEventListener?.("change", () => {
            this.module.varnEmit("gui.appearance", JSON.stringify({ appearance: this.appearance() }));
        });
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
                this.module.varnEmit("gui.keyboard", JSON.stringify({ height: this.keyboard }));
            }
        };

        viewport.addEventListener("resize", report);
        viewport.addEventListener("scroll", report);
    }

    // One tick per frame, on the thread that owns the interface, which is what keeps a scroll smooth
    // while a request is in flight.
    pump() {
        if (!this.running) {
            return;
        }

        this.module.varnPoll();
        requestAnimationFrame(() => this.pump());
    }

    stop() {
        this.running = false;
    }
}
