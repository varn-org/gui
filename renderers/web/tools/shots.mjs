// Takes one screenshot per gallery screen in a real browser, so the web chrome is looked at beside the
// two phones rather than argued about.
//
// A screen is opened the way a reader opens it, by pressing its row on the first screen, since the page
// has no environment to be told which demo to draw the way an application on a phone does.

import { Chrome } from "./chrome.mjs";

// The first screen keeps only the rows it is showing, so a row further down is reached by scrolling to
// it rather than by asking for it, and each look at the list is one screenful further down.
const INDEX = '[data-varn-type="sectionlist"]';
const REACHES = 40;
const DRAWING = 300;

class Sweep {
    constructor({ url, output, demos, appearances }) {
        this.url = url;
        this.output = output;
        this.demos = demos;
        this.appearances = appearances;
    }

    static named(demo) {
        return demo.replace(/\//g, "-");
    }

    async run() {
        // A screen that opens the camera is a black box in a browser that has none, and a picture of a
        // refusal is not what the gallery is for, so the browser taking these carries one of its own.
        const chrome = await Chrome.launch({ devices: true });

        try {
            for (const appearance of this.appearances) {
                await this.sweep(chrome, appearance);
            }
        } finally {
            await chrome.close();
        }
    }

    async sweep(chrome, appearance) {
        const page = await chrome.open({ appearance });

        try {
            await this.open(page);
            await this.write(page, appearance, "index");

            for (const demo of this.demos) {
                await this.open(page);
                await Sweep.press(page, demo.title);
                await this.write(page, appearance, Sweep.named(demo.name));

                // A whole application has screens a reader only reaches by going into it, and a picture
                // of the one it opens on says nothing about any of them. The demo names what opens each.
                for (const step of demo.screens ?? []) {
                    await Sweep.press(page, step.press);
                    await this.write(page, appearance, `${Sweep.named(demo.name)}-${step.as}`);
                }
            }
        } finally {
            await page.close();
        }
    }

    // Presses the row a demo is opened by, scrolling the first screen down until the row is drawn.
    static async press(page, title) {
        const row = JSON.stringify(`[aria-label=${JSON.stringify(title)}]`);

        for (let reach = 0; reach < REACHES; reach += 1) {
            const pressed = await page.ask(`(() => {
                const row = document.querySelector(${row});

                if (row === null) {
                    return false;
                }

                row.click();
                return true;
            })()`);

            if (pressed) {
                return;
            }

            const moved = await page.ask(`(() => {
                const list = document.querySelector('${INDEX}');

                if (list === null) {
                    return false;
                }

                const was = list.scrollTop;
                list.scrollTop = was + list.clientHeight;

                return list.scrollTop > was;
            })()`);

            if (!moved) {
                break;
            }

            await new Promise((done) => setTimeout(done, DRAWING));
        }

        throw new Error(`the first screen carries no row named ${title}`);
    }

    // Opens the first screen afresh, since a demo may take the reader somewhere its own back does not
    // return from, and a page that is navigated again starts the engine over.
    async open(page) {
        await page.go(this.url);
        await page.settle();

        const drawn = await page.ask(`document.querySelectorAll("[data-varn-id]").length`);

        if (drawn === 0) {
            throw new Error(`the page drew nothing: ${page.problems.join(", ") || "and said nothing about why"}`);
        }
    }

    async write(page, appearance, name) {
        const target = `${this.output}/web-${appearance}-${name}.png`;

        await page.capture(target);
        console.log(`  ${target}`);

        for (const problem of page.problems) {
            console.log(`    ${problem}`);
        }
    }
}

await new Sweep(JSON.parse(process.argv[2])).run();
