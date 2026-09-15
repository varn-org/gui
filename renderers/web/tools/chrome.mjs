// Drives a headless browser over the DevTools protocol, which is how the web renderer is looked at the
// way a person looks at it rather than the way a stub answers.
//
// Nothing here is installed. The protocol is JSON over a socket the runtime already speaks, and the
// browser is the one the machine already has, so the renderer is checked in a real engine with real
// fonts, real form controls and real layout.

import { spawn } from "node:child_process";
import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Where a browser is on the machines this is run on, tried in turn. A name in the environment wins,
// which is what a machine with the browser somewhere else is told with.
const BROWSERS = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
];

// How long the browser has to answer that it is listening before it counts as failed to start.
//
// Twenty seconds is plenty on an idle laptop and not enough on one that is also driving a simulator,
// and a bound this size costs nothing on every run where the browser starts at once.
const STARTING = 45000;

// How long one question to the browser may take before the browser counts as no longer answering.
const ANSWERING = 30000;

// How long a browser has to go once it has been asked to, before it is ended rather than asked again.
const CLOSING = 5000;

// How long the browser has to answer that the connection is closed before it is left to the kill.
const HANGING_UP = 2000;

// Every browser this process launched and has not closed, ended when the process itself ends.
//
// A run that is interrupted or that throws before it closes one would otherwise leave it holding the
// machine for good, which is the same leak by another route.
const RUNNING = new Set();

process.on("exit", () => {
    for (const chrome of RUNNING) {
        try {
            process.kill(-chrome.process.pid, "SIGKILL");
        } catch (problem) {
            if (problem.code !== "ESRCH") {
                throw problem;
            }
        }
    }
});

export class Chrome {
    constructor(process, profile) {
        this.process = process;
        this.profile = profile;
        this.next = 0;
        this.waiting = new Map();
        this.pages = new Set();
    }

    // Answers the browser to drive, or nothing at all when the machine has none.
    static async find() {
        const named = process.env.CHROME;

        for (const path of named === undefined ? BROWSERS : [named]) {
            try {
                await access(path);
                return path;
            } catch {
                continue;
            }
        }

        return null;
    }

    /**
     * Starts a browser, optionally with a camera and a microphone of its own rather than the machine's.
     *
     * A headless browser has neither device and a real one asks a person for both, so a page that opens a
     * camera can only be driven against the pattern the browser generates for itself.
     */
    static async launch(options = {}) {
        const binary = await Chrome.find();

        if (binary === null) {
            throw new Error("no browser was found: name one in CHROME");
        }

        const profile = await mkdtemp(join(tmpdir(), "varn-chrome-"));

        // The browser is asked for a port of its own choosing and writes it into the profile it was
        // given, so a browser somebody left running is never the one this drives.
        const started = spawn(binary, [
            "--headless=new",
            "--remote-debugging-port=0",
            `--user-data-dir=${profile}`,
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            ...(options.devices === true
                ? ["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream"]
                : []),
        ], { stdio: "ignore", detached: true });

        // The child is let go of, which stops it holding this process open. A detached child keeps the
        // event loop alive until it exits, and the suite went on running with every test passed and the
        // browsers all closed, because node was still waiting on a handle nothing needed. Nothing is
        // lost by it: the group is still signalled by its id and waited for by asking whether it is
        // there, rather than by listening for an exit.
        started.unref();

        const chrome = new Chrome(started, profile);
        RUNNING.add(chrome);

        try {
            await chrome.connect();
        } catch (problem) {
            await chrome.close();
            throw problem;
        }

        return chrome;
    }

    async connect() {
        const until = Date.now() + STARTING;
        const listening = join(this.profile, "DevToolsActivePort");

        while (Date.now() < until) {
            const [port, path] = await readFile(listening, "utf8").then(
                (said) => said.split("\n"),
                () => [],
            );

            if (port !== undefined && path !== undefined) {
                this.socket = new WebSocket(`ws://127.0.0.1:${port.trim()}${path.trim()}`);

                await new Promise((done, failed) => {
                    this.socket.addEventListener("open", done, { once: true });
                    this.socket.addEventListener("error", () => failed(new Error("the browser refused the socket")), { once: true });
                });

                this.listen();
                return;
            }

            await new Promise((done) => setTimeout(done, 100));
        }

        throw new Error(`the browser never said which port it is listening on within ${STARTING}ms`);
    }

    listen() {
        this.socket.addEventListener("message", (message) => {
            const answer = JSON.parse(message.data);

            if (answer.id !== undefined && this.waiting.has(answer.id)) {
                const { resolve, reject } = this.waiting.get(answer.id);
                this.waiting.delete(answer.id);

                if (answer.error !== undefined) {
                    reject(new Error(answer.error.message));
                    return;
                }

                resolve(answer.result);
                return;
            }

            if (answer.sessionId !== undefined) {
                for (const page of this.pages) {
                    if (page.sessionId === answer.sessionId) {
                        page.saw(answer);
                    }
                }
            }
        });
    }

    send(method, params = {}, sessionId) {
        this.next += 1;
        const id = this.next;

        return new Promise((resolve, reject) => {
            // A browser that stops answering would otherwise hold whatever is driving it for good, and
            // a run that never ends says far less about what is wrong than one that says what it asked.
            const gave = setTimeout(() => {
                this.waiting.delete(id);
                reject(new Error(`the browser never answered ${method}`));
            }, ANSWERING);

            this.waiting.set(id, {
                resolve: (answer) => { clearTimeout(gave); resolve(answer); },
                reject: (problem) => { clearTimeout(gave); reject(problem); },
            });

            this.socket.send(JSON.stringify({ id, method, params, sessionId }));
        });
    }

    // Opens a tab the size of the device the page is judged on, in the appearance the system is in.
    async open({ width = 390, height = 844, scale = 2, mobile = true, appearance = "dark" } = {}) {
        const { targetId } = await this.send("Target.createTarget", { url: "about:blank" });
        const { sessionId } = await this.send("Target.attachToTarget", { targetId, flatten: true });
        const page = new Page(this, targetId, sessionId);

        this.pages.add(page);

        await this.send("Runtime.enable", {}, sessionId);
        await this.send("Log.enable", {}, sessionId);
        await this.send("Page.enable", {}, sessionId);
        await this.send("Emulation.setDeviceMetricsOverride",
            { width, height, deviceScaleFactor: scale, mobile }, sessionId);
        await this.send("Emulation.setEmulatedMedia",
            { features: [{ name: "prefers-color-scheme", value: appearance }] }, sessionId);

        return page;
    }

    // The browser is asked to stop and waited for, since the profile it was given is taken away after it
    // and a browser still writing into one is a browser that leaves the directory behind.
    async close() {
        RUNNING.delete(this);
        await this.hangUp();

        if (!await this.ended("SIGTERM") && !await this.ended("SIGKILL")) {
            throw new Error(`the browser would not go, ${this.process.pid} is still running`);
        }

        await rm(this.profile, { recursive: true, force: true });
    }

    // Closes the connection to the browser and waits for it to have closed, before the browser is
    // signalled rather than after.
    //
    // Closing a web socket is a conversation, and the other side has to answer. Hanging up after killing
    // the browser leaves a socket that is neither open nor closed and a handle node will wait on for
    // ever: the suite ran every case, passed every one, and then sat there with nothing left to do.
    async hangUp() {
        const socket = this.socket;

        if (socket === undefined || socket.readyState === WebSocket.CLOSED) {
            return;
        }

        const closed = new Promise((done) => {
            const gave = setTimeout(done, HANGING_UP);

            socket.addEventListener("close", () => {
                clearTimeout(gave);
                done();
            }, { once: true });
        });

        socket.close();
        await closed;
    }

    // Answers whether anything of the browser is still running, which is a question about the whole
    // group rather than about the process that was spawned.
    running() {
        try {
            process.kill(-this.process.pid, 0);
            return true;
        } catch (problem) {
            if (problem.code === "ESRCH") {
                return false;
            }

            throw problem;
        }
    }

    // Signals the browser and answers whether the whole of it went within the time it is given to go.
    //
    // A browser is a tree of processes rather than one, and signalling only the process that was
    // spawned leaves its helpers holding the machine: a run left seven of them behind each time and
    // after a few runs the next browser could not start inside the time it is given, which the suite
    // reported as three defects in the renderer. So the group is signalled, the process that was
    // spawned is waited for through its own exit, and the helpers are waited for after that.
    //
    // The order matters. Waiting on its exit is what makes node collect it, and asking whether the group
    // is there is only the truth once it has been collected — a child that has gone and not been
    // collected is a corpse in the table whose group still answers, so asking about one answers yes for
    // ever. That turned a browser which had gone perfectly into a close that spent ten seconds and then
    // raised, and left the suite unable to finish at all.
    async ended(signal) {
        const collected = this.process.exitCode !== null || this.process.signalCode !== null;

        if (!collected) {
            const exited = new Promise((done) => {
                const gave = setTimeout(() => done(false), CLOSING);

                this.process.once("exit", () => {
                    clearTimeout(gave);
                    done(true);
                });
            });

            try {
                process.kill(-this.process.pid, signal);
            } catch (problem) {
                if (problem.code !== "ESRCH") {
                    throw problem;
                }
            }

            if (!await exited) {
                return false;
            }
        }

        for (let waited = 0; waited < CLOSING; waited += 25) {
            if (!this.running()) {
                return true;
            }

            await new Promise((done) => setTimeout(done, 25));
        }

        return !this.running();
    }
}

export class Page {
    constructor(chrome, targetId, sessionId) {
        this.chrome = chrome;
        this.targetId = targetId;
        this.sessionId = sessionId;
        this.problems = [];
    }

    saw(message) {
        if (message.method === "Log.entryAdded" && message.params.entry.level === "error") {
            this.problems.push(message.params.entry.text);
        }

        if (message.method === "Runtime.exceptionThrown") {
            this.problems.push(message.params.exceptionDetails.exception?.description ?? "an exception with no description");
        }
    }

    send(method, params) {
        return this.chrome.send(method, params, this.sessionId);
    }

    async go(url) {
        this.problems = [];
        await this.send("Page.navigate", { url });
    }

    // Answers what the expression evaluates to, and raises with what the page raised when it refuses.
    async ask(expression) {
        const { result, exceptionDetails } = await this.send("Runtime.evaluate", {
            expression, returnByValue: true, awaitPromise: true,
        });

        if (exceptionDetails !== undefined) {
            throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
        }

        return result.value;
    }

    async shoot() {
        const { data } = await this.send("Page.captureScreenshot", { format: "png" });
        return Buffer.from(data, "base64");
    }

    // Waits until the page has stopped changing rather than for a fixed while.
    //
    // A screen that fetches something is not finished when its tree is: a map draws its tiles, a picture
    // arrives from somewhere else and a font is registered after the first frame. A shot taken before
    // they land is a blank screen this tool exists to find rather than one it made.
    /**
     * Presses where a finger would, which is not the same as calling click on an element.
     *
     * A browser only lets a page start a sound, open a camera or go full screen off a press a person
     * actually made, and an event a script raised is not one however faithfully it is shaped. Anything
     * gated behind that can only be driven by asking the browser itself to press.
     */
    async press(selector) {
        const at = await this.ask(`(() => {
            const found = document.querySelector(${JSON.stringify(selector)});

            if (found === null) { return null; }

            const box = found.getBoundingClientRect();
            return { x: Math.round(box.x + box.width / 2), y: Math.round(box.y + box.height / 2) };
        })()`);

        if (at === null) {
            throw new Error(`nothing on the page matches ${selector}`);
        }

        for (const type of ["mousePressed", "mouseReleased"]) {
            await this.send("Input.dispatchMouseEvent", {
                type, x: at.x, y: at.y, button: "left", clickCount: 1,
            });
        }

        return at;
    }

    async settle({ every = 700, patience = 12000 } = {}) {
        let previous = null;
        let waited = 0;

        while (true) {
            await new Promise((done) => setTimeout(done, every));
            waited += every;

            const current = await this.shoot();

            if (previous !== null && current.equals(previous)) {
                return current;
            }

            if (waited >= patience) {
                return current;
            }

            previous = current;
        }
    }

    async capture(path) {
        await writeFile(path, await this.settle());
    }

    async close() {
        this.chrome.pages.delete(this);
        await this.chrome.send("Target.closeTarget", { targetId: this.targetId });
    }
}
