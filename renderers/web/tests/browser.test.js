// The renderer in a real browser, driving the gallery the way a reader drives it.
//
// Everything this catches is layout, and a document without layout cannot catch any of it: a control
// measured as nothing and drawn as a dot, a caption stacked on the box beside it, a header pinned by a
// scroll event that arrives a frame after the reader has already seen the next one. Each of those
// passed every test there was and was visible on the page the moment it opened.
//
// The suite is skipped where the machine has no browser, since the rest of it still has to run there.

import { strict as assert } from "node:assert";
import test from "node:test";
import { join, resolve } from "node:path";
import { mkdtemp, readdir, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

import { Chrome } from "../tools/chrome.mjs";
import { Site } from "../tools/site.mjs";

const root = resolve(fileURLToPath(new URL("../../..", import.meta.url)));
const page = resolve(root, "apps/web/dist");
const browser = await Chrome.find();

// Where a browser told to keep a file writes it, so a run can see that one actually arrived.
const kept = await mkdtemp(resolve(tmpdir(), "varn-kept-"));

// The row of the first screen each part of this opens, by the label it carries.
const TOGGLES = "Toggles and choices";
const SLIDERS = "Sliders and steppers";

class Gallery {
    constructor(site, chrome, screen) {
        this.site = site;
        this.chrome = chrome;
        this.screen = screen;
    }

    static async open() {
        const site = await Site.open(page);
        const chrome = await Chrome.launch();
        const screen = await chrome.open({ appearance: "dark" });

        await screen.go(site.url);
        await screen.settle();

        return new Gallery(site, chrome, screen);
    }

    async close() {
        await this.chrome.close();
        await this.site.close();
    }

    // Leaves whatever is open, so the next row is pressed from the first screen rather than through it.
    async back() {
        await this.screen.ask(`(() => {
            const way = document.querySelector('[aria-label="Varn GUI"], [aria-label="Back"]');
            return way === null ? false : (way.click(), true);
        })()`);

        await this.screen.settle();
    }

    // Presses a row of the first screen, scrolling down to it the way a reader scrolls to it.
    async press(label) {
        await this.screen.ask(`document.querySelector('[data-varn-type="sectionlist"]').scrollTop = 0`);
        await new Promise((done) => setTimeout(done, 300));

        for (let reach = 0; reach < 40; reach += 1) {
            const pressed = await this.screen.ask(`(() => {
                const row = document.querySelector('[aria-label=${JSON.stringify(label)}]');

                if (row === null) {
                    return false;
                }

                row.click();
                return true;
            })()`);

            if (pressed) {
                await this.screen.settle();
                return;
            }

            await this.screen.ask(`(() => {
                const list = document.querySelector('[data-varn-type="sectionlist"]');
                list.scrollTop += list.clientHeight;
            })()`);

            await new Promise((done) => setTimeout(done, 300));
        }

        throw new Error(`the first screen carries no row named ${label}`);
    }
}

// A browser is a tree of processes, and closing one has to take the whole tree.
//
// Signalling only the process that was spawned left seven helpers of every browser holding the machine.
// A few runs of this suite and the next browser could not start inside the time it is given, which was
// reported as three defects in the renderer — the three cases that launch one, failing together.
test("a browser that is closed leaves nothing of itself running", { skip: browser === null }, async () => {
    const chrome = await Chrome.launch();
    const group = chrome.process.pid;

    const running = () => {
        try {
            process.kill(-group, 0);
            return true;
        } catch (problem) {
            if (problem.code === "ESRCH") {
                return false;
            }

            throw problem;
        }
    };

    assert.ok(running(), "a browser that was launched is running");

    await chrome.close();

    assert.ok(!running(), "and nothing of it is left once it has been closed");
});

test("the gallery draws in a browser the way it draws on a phone", { skip: browser === null }, async (t) => {
    const gallery = await Gallery.open();
    const screen = gallery.screen;

    t.after(() => gallery.close());

    await t.test("the first screen draws and says nothing went wrong", async () => {
        const drawn = await screen.ask(`document.querySelectorAll("[data-varn-id]").length`);

        assert.ok(drawn > 0, "the page drew nothing at all");
        assert.deepEqual(screen.problems, [], "the page reported something went wrong");
    });

    // A header held by a scroll event is a header a frame behind the surface it is held in, which is the
    // trembling a reader sees. The browser follows the surface itself, so where it ends up is what says
    // it is being followed at all.
    await t.test("a section header is held by the surface it scrolls in", async () => {
        const held = await screen.ask(`(async () => {
            const wait = (ms) => new Promise((done) => setTimeout(done, ms));
            const list = document.querySelector('[data-varn-type="sectionlist"]');
            const held = async (top) => {
                list.scrollTop = top;
                await wait(300);

                const pinned = [...list.firstElementChild.children]
                    .find((child) => child.style.animationName === "varn-pin-block");

                if (pinned === undefined) {
                    return null;
                }

                return {
                    timeline: pinned.style.animationTimeline,
                    y: Math.round(pinned.getBoundingClientRect().top - list.getBoundingClientRect().top),
                };
            };

            return { inside: await held(150), past: await held(320) };
        })()`);

        assert.ok(held.inside?.timeline.startsWith("scroll("), "the surface is what drives it");
        assert.equal(held.inside.y, 0, "it stands at the edge for as long as its range lasts");
        assert.ok(held.past.y < 0, `and the section beneath pushes it off, sat at ${held.past?.y}`);
    });

    await t.test("a control is drawn at the size the platform draws it", async () => {
        await gallery.press(TOGGLES);

        const boxes = await screen.ask(`(() => {
            const box = (element) => {
                const rect = element.getBoundingClientRect();
                return { x: Math.round(rect.x), width: Math.round(rect.width), height: Math.round(rect.height) };
            };

            const checkbox = document.querySelector('[data-varn-type="checkbox"]');
            const segmented = document.querySelector('[data-varn-type="segmented"]');

            return {
                toggle: box(document.querySelector('[data-varn-type="switch"]')),
                mark: box(checkbox.querySelector("input")),
                caption: box(checkbox.querySelector("span")),
                segments: [...segmented.children].map((one) => ({
                    chosen: one.dataset.varnChosen,
                    width: Math.round(one.getBoundingClientRect().width),
                })),
                track: getComputedStyle(segmented).backgroundColor,
            };
        })()`);

        assert.equal(boxes.toggle.width, 51,
            `a switch is as wide as a switch, got ${boxes.toggle.width}`);
        assert.equal(boxes.toggle.height, 31,
            `and as tall as one, got ${boxes.toggle.height}`);

        // A page that positions every box inside the surface reaches the parts a control is built from
        // and stacks the words of a checkbox on the box they belong beside.
        assert.ok(boxes.caption.x >= boxes.mark.x + boxes.mark.width,
            "the words of a checkbox stand beside its box rather than on it");

        assert.ok(boxes.segments.length > 1, "a segmented control is built of its segments");
        assert.equal(boxes.segments.filter((one) => one.chosen === "true").length, 1,
            "one of them is the chosen one");
        assert.notEqual(boxes.track, "rgba(0, 0, 0, 0)", "and they sit in a track of their own");
    });


    // A folding phone, a tablet, a window shared with another application and a phone turned sideways are
    // one thing to a tree: a width that changed. What proves it is that the screen rearranges itself
    // around the new width and keeps what the reader had already put into it, since a tree rebuilt from
    // nothing looks the same in a screenshot and has lost everything.
    await t.test("unfolding the window rearranges the screen and keeps what is on it", async () => {
        const ticked = await screen.ask(`(() => {
            const box = document.querySelector('[data-varn-type="checkbox"] input');
            box.click();
            return box.checked;
        })()`);

        assert.equal(ticked, true, "the checkbox was ticked to have something to lose");

        const at = () => screen.ask(`(() => {
            const box = document.querySelector('[data-varn-type="checkbox"]');
            return { x: Math.round(box.getBoundingClientRect().x), ticked: box.querySelector("input").checked };
        })()`);

        const folded = await at();

        await screen.send("Emulation.setDeviceMetricsOverride",
            { width: 900, height: 844, deviceScaleFactor: 2, mobile: true });
        await screen.settle();

        const opened = await at();

        assert.ok(opened.x > folded.x + 100,
            `the screen makes room for what the width now fits, sat at ${opened.x} against ${folded.x}`);
        assert.equal(opened.ticked, true, "and what the reader had put into it is still there");

        await screen.send("Emulation.setDeviceMetricsOverride",
            { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
        await screen.settle();
    });

    // A bar drawn over the screen rather than under it is laid out against the surface, so a screen that
    // rearranges itself under it must leave it exactly where it was. Half of what read as a broken bar
    // was a page still holding the frames it had when the engine died, which is why this is driven live.
    await t.test("a floating bar keeps its shape on every tab", async () => {
        await gallery.press("A floating bar");

        const shape = () => screen.ask(`(() => {
            const tabs = [...document.querySelectorAll('[data-varn-type="pressable"]')]
                .filter((one) => ["Home", "Search", "Saved", "You"].includes(one.getAttribute("aria-label")));

            return tabs.map((one) => {
                const box = one.getBoundingClientRect();
                return [one.getAttribute("aria-label"), Math.round(box.x), Math.round(box.y),
                    Math.round(box.width), Math.round(box.height)];
            });
        })()`);

        const opened = await shape();

        assert.equal(opened.length, 4, "the bar carries its four tabs");

        for (const label of ["Search", "Saved", "You", "Home"]) {
            await screen.ask(`document.querySelector('[aria-label=${JSON.stringify(label)}]').click()`);
            await screen.settle();

            assert.deepEqual(await shape(), opened, `the bar moved when ${label} was pressed`);
        }
    });

    // Which axes a platform decides is the declaration's to say, and a browser answers for both.
    //
    // A range input is 129 across until something tells it otherwise and takes whole numbers until
    // something tells it otherwise, so a slider running from nought to one was drawn a third of the
    // width it had with its thumb stuck at the left however far through it was. Neither is anything a
    // tree-based case can see: the engine sent the right frame and the right value both times.
    await t.test("a slider runs the width it is given and sits where its value says", async () => {
        await gallery.back();
        await gallery.press(SLIDERS);

        const slider = await screen.ask(`(() => {
            const element = document.querySelector('[data-varn-type="slider"]');
            const room = element.parentElement.getBoundingClientRect().width;

            return {
                width: Math.round(element.getBoundingClientRect().width),
                room: Math.round(room),
                value: Number(element.value),
                step: element.step,
            };
        })()`);

        assert.ok(slider.width > slider.room * 0.9,
            `a slider fills the row it sits in, got ${slider.width} of ${slider.room}`);
        assert.equal(slider.step, "any", "and moves continuously unless a step says otherwise");
        assert.ok(slider.value > 0.3 && slider.value < 0.5,
            `and sits where its value says, got ${slider.value}`);
    });

    await t.test("nothing on the screen said it went wrong", () => {
        assert.deepEqual(screen.problems, [], "the page reported something went wrong");
    });
});

// A sound a page starts, a microphone it opens and a file it keeps are each gated behind a press a
// person actually made: none of them can be driven by an event a script raised, however faithfully it is
// shaped, so all three are driven by asking the browser itself to press.
test("a note is recorded, played back and kept", { skip: browser === null }, async (t) => {
    const site = await Site.open(page);
    const chrome = await Chrome.launch({ devices: true });
    const screen = await chrome.open({ appearance: "dark" });

    t.after(async () => {
        await chrome.close();
        await site.close();
    });

    const wait = (ms) => new Promise((done) => setTimeout(done, ms));
    const gallery = new Gallery(site, chrome, screen);

    // Waits for the thing rather than for the clock.
    //
    // A fixed sleep is a race a busy machine wins: two seconds is plenty for a recording to be written
    // on an idle laptop and not enough while the same machine is building an application for a phone,
    // and a suite that fails there is a gate nobody trusts. Waiting for what is being waited on costs
    // nothing when it happens at once and gives a loaded machine the room it needs when it does not.
    const until = async (answered, patience = 15000) => {
        for (let waited = 0; waited < patience; waited += 100) {
            if (await answered()) {
                return true;
            }

            await wait(100);
        }

        return false;
    };

    await screen.go(site.url);
    await screen.settle();
    await gallery.press("A voice note");

    assert.ok(await until(async () =>
        await screen.ask(`document.querySelector('[aria-label="Record"]') !== null`)),
        "the screen never offered to record");

    const said = () => screen.ask(`[...document.querySelectorAll('[data-varn-type="text"]')]
        .map((one) => one.textContent).join(" | ")`);

    await t.test("the microphone records for as long as it is told to", async () => {
        await screen.ask(`document.querySelector('[aria-label="Record"]').click()`);
        await wait(2200);

        assert.match(await said(), /Recording/, "the screen says it is recording");

        await screen.ask(`document.querySelector('[aria-label="Stop"]').click()`);

        assert.ok(await until(async () => /Recorded \d+:\d\d/.test(await said())),
            `stopping it is what produces the note, the screen says ${await said()}`);
    });

    await t.test("what it recorded plays back", async () => {
        await screen.ask(`document.querySelector('[aria-label="Play"]').dataset.varnProbe = "play"`);
        await screen.press('[data-varn-probe="play"]');

        const moving = async () => await screen.ask(`(() => {
            const sound = document.querySelector('[data-varn-type="audio"]');
            return sound !== null && !sound.paused && sound.currentTime > 0.2;
        })()`);

        assert.ok(await until(moving), "the note plays and moves through itself");
    });

    await t.test("nothing on the screen said it went wrong", () => {
        assert.deepEqual(screen.problems, [], "the page reported something went wrong");
    });
});

// A camera cannot be driven anywhere but in a browser, and a browser has one only when it is given one.
//
// A headless browser has no camera and a real one asks a person for it, so this drives the pattern the
// browser generates for itself: what the page does with the frames is the same either way, and taking a
// picture out of one is the whole of what the demo does.
test("a camera draws what it sees and writes what it captures", { skip: browser === null }, async (t) => {
    const site = await Site.open(page);
    const chrome = await Chrome.launch({ devices: true });
    const screen = await chrome.open({ appearance: "dark" });

    t.after(async () => {
        await chrome.close();
        await site.close();
    });

    const wait = (ms) => new Promise((done) => setTimeout(done, ms));

    await screen.go(site.url);
    await screen.settle();

    const gallery = new Gallery(site, chrome, screen);
    await gallery.press("A camera");

    // A camera is opened when it is asked for rather than the moment a screen is drawn, so a reader
    // browsing the demos is never asked for their camera by a screen they are only reading.
    const until = async (expression, what) => {
        for (let tries = 0; tries < 40; tries += 1) {
            if (await screen.ask(expression) === true) {
                return;
            }

            await wait(250);
        }

        assert.fail(what);
    };

    await until(`document.querySelector('[aria-label="Turn the camera on"]') !== null`,
        "the screen never offered to turn the camera on");

    await screen.ask(`document.querySelector('[aria-label="Turn the camera on"]').click()`);

    await until(`(document.querySelector('[data-varn-type="camera"] video')?.videoWidth ?? 0) > 0`,
        "the camera never produced a frame");

    await t.test("the preview is what the camera is producing", async () => {
        const drawn = await screen.ask(`(() => {
            const box = document.querySelector('[data-varn-type="camera"]');
            const preview = box?.querySelector("video");

            return { there: box !== null, width: preview?.videoWidth ?? 0 };
        })()`);

        assert.ok(drawn.there, "the screen carries a camera");
        assert.ok(drawn.width > 0, `and it is drawing frames, at ${drawn.width} across`);
    });

    await t.test("a look is drawn over the preview and written into the picture", async () => {
        await screen.ask(`[...document.querySelectorAll("[data-varn-id]")]
            .find((one) => one.textContent.trim() === "mono" && one.dataset.varnType !== "text")?.click()`);

        await until(`/^url\\(/.test(document.querySelector('[data-varn-type="camera"] video')?.style.filter ?? "")`,
            "the look never reached the preview");

        const looking = await screen.ask(
            `document.querySelector('[data-varn-type="camera"] video').style.filter`);
        assert.match(looking, /^url\("?#varn-filter-\d+"?\)$/,
            `the preview is drawn through one, got "${looking}"`);

        await screen.ask(`document.querySelector('[aria-label="Take a picture"]').click()`);

        await until(`document.querySelector('[data-varn-type="image"][src^="blob:"]') !== null`,
            "the picture never reached the screen");

        const taken = await screen.ask(`(() => {
            const shown = document.querySelector('[data-varn-type="image"][src^="blob:"]');

            return {
                shown: shown !== null,
                said: [...document.querySelectorAll('[data-varn-type="text"]')]
                    .map((one) => one.textContent).find((one) => one.includes("Took")) ?? null,
            };
        })()`);

        assert.ok(taken.shown, "what was taken is shown as a picture the tree can open");
        assert.equal(taken.said, "Took a picture", "and the screen was told it was taken");
    });

    await t.test("a film is recorded and stopping it is what produces the file", async () => {
        await screen.ask(`document.querySelector('[aria-label="Record"]').click()`);
        await wait(2200);
        await screen.ask(`document.querySelector('[aria-label="Stop"]').click()`);

        await until(`(document.querySelector('[data-varn-type="video"]')?.src ?? "").startsWith("blob:")`,
            "the film never reached the screen");

        const recorded = await screen.ask(`(() => {
            const shown = document.querySelector('[data-varn-type="video"]');

            return {
                shown: shown !== null && (shown.src ?? "").startsWith("blob:"),
                said: [...document.querySelectorAll('[data-varn-type="text"]')]
                    .map((one) => one.textContent).find((one) => one.startsWith("Recorded")) ?? null,
            };
        })()`);

        assert.ok(recorded.shown, "what was recorded is shown as a film the tree can play");
        assert.ok(recorded.said !== null, "and the screen was told how long it ran for");

        // A film keeps the pixels the camera produced, so the look a reader chose is drawn over it as it
        // plays rather than written into the file the hardware encoder wrote.
        const looking = await screen.ask(`document.querySelector('[data-varn-type="video"]').style.filter`);

        assert.match(looking, /^url\("?#varn-filter-\d+"?\)$/,
            `the film is drawn through the look that was chosen, got "${looking}"`);
    });

    await t.test("what it took is kept where the platform keeps one", async () => {
        await screen.send("Browser.setDownloadBehavior", { behavior: "allow", downloadPath: kept });
        await screen.ask(`document.querySelector('[aria-label="Keep it"]').click()`);

        await until(`[...document.querySelectorAll('[data-varn-type="text"]')]
            .some((one) => one.textContent.includes("Kept it"))`, "the screen never said it was kept");

        // A download that landed as an empty file, or as the browser's own half-written `.crdownload`,
        // is the reader pressing keep and getting nothing, which is what this is here to catch. The
        // browser writes the file after the page is told, so what is waited on is the file itself.
        const landed = async () =>
            (await readdir(kept)).some((name) => !name.endsWith(".crdownload"));

        for (let waited = 0; waited < 15000 && !(await landed()); waited += 100) {
            await wait(100);
        }

        const written = (await readdir(kept)).filter((name) => !name.endsWith(".crdownload"));

        assert.equal(written.length, 1, `one file was kept, got ${JSON.stringify(written)}`);
        assert.match(written[0], /\.(webm|mp4)$/, `and it is the film that was recorded, got ${written[0]}`);

        const size = (await stat(join(kept, written[0]))).size;

        assert.ok(size > 1024, `with the film in it rather than nothing, is ${size} bytes`);
    });

    await t.test("nothing on the screen said it went wrong", () => {
        assert.deepEqual(screen.problems, [], "the page reported something went wrong");
    });
});

// An editor holds a tree of elements rather than a string, which is the one control a document with no
// layout cannot stand in for at all.
//
// What is read back out of it, what a mark does to a selection and where the caret is counted to are all
// answered by the browser's own selection and by the elements it wrote. A stand-in has none of that, so a
// case written against one would be a suite agreeing with itself about an editor nobody has ever typed in.
test("an editor holds a document and the toolbar marks it", { skip: browser === null }, async (t) => {
    const gallery = await Gallery.open();
    const screen = gallery.screen;

    t.after(() => gallery.close());

    await screen.go(gallery.site.url);
    await screen.settle();
    await gallery.press("Writing");

    const editor = `document.querySelector('[data-varn-type="richeditor"]')`;
    const said = () => screen.ask(`[...document.querySelectorAll('[data-varn-type="text"]')]
        .map((one) => one.textContent).join(" | ")`);

    await t.test("the editor is one box holding the document it was given", async () => {
        assert.ok(await screen.ask(`${editor} !== null`), "the screen draws no editor at all");

        assert.equal(await screen.ask(`${editor}.isContentEditable`), true,
            "an editor a reader cannot type into is a preview");

        assert.match(await screen.ask(`${editor}.textContent`), /A rich editor is one box/,
            "the document it was given is what it holds");

        assert.ok(await screen.ask(`${editor}.querySelector("b") !== null`),
            "and a run marked bold is drawn bold rather than as plain text");
    });

    await t.test("marking a selection changes the document rather than a copy of it", async () => {
        await screen.ask(`(() => {
            const held = ${editor};
            const range = document.createRange();

            range.selectNodeContents(held.childNodes[0]);

            const selection = document.getSelection();

            selection.removeAllRanges();
            selection.addRange(range);
        })()`);

        await screen.press('[data-varn-type="pressable"][aria-label="Italic"]');
        await screen.settle();

        assert.ok(await screen.ask(`${editor}.querySelector("i") !== null`),
            "what was selected is marked where the words are");

        assert.match(await said(), /characters over [1-9]/,
            `the screen reads the document back off the editor, it says ${await said()}`);
    });

    await t.test("the caret is counted in characters the way every platform counts it", async () => {
        await screen.ask(`(() => {
            const held = ${editor};
            const range = document.createRange();

            range.setStart(held.firstChild.firstChild ?? held.firstChild, 0);
            range.collapse(true);

            const selection = document.getSelection();

            selection.removeAllRanges();
            selection.addRange(range);
            held.dispatchEvent(new Event("keyup", { bubbles: true }));
        })()`);

        await screen.settle();

        assert.match(await said(), /caret at 0|with a selection/,
            `the screen is told where the caret is, it says ${await said()}`);
    });

    await t.test("nothing on the screen said it went wrong", () => {
        assert.deepEqual(screen.problems, [], "the page reported something went wrong");
    });
});
