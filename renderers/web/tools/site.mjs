// Serves the assembled page on a port of the system's choosing, since a browser loads neither a module
// nor a wasm from a file path, and a port named here is a port something else may already be on.

import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize, sep } from "node:path";

const TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json",
    ".wasm": "application/wasm",
    ".zip": "application/zip",
    ".vap": "application/zip",
    ".png": "image/png",
};

export class Site {
    constructor(server, root) {
        this.server = server;
        this.root = root;
    }

    static async open(root) {
        const server = createServer((request, answer) => Site.answer(root, request, answer));

        await new Promise((done) => server.listen(0, "127.0.0.1", done));

        return new Site(server, root);
    }

    static async answer(root, request, answer) {
        const asked = new URL(request.url, "http://127.0.0.1").pathname;
        const wanted = join(root, normalize(asked === "/" ? "/index.html" : asked));

        // A path that climbs out of what is being served is a path nothing here answers, since the page
        // is served out of a directory rather than out of the machine it was built on.
        if (!wanted.startsWith(root + sep)) {
            answer.writeHead(403).end();
            return;
        }

        let served = wanted;
        let content = await readFile(served).catch(() => null);

        // An address a router pushed names no file, and a reader who reloads there is asking a static
        // host for it. A host that answers 404 is one where every link is broken on arrival.
        if (content === null && !asked.split("/").pop().includes(".")) {
            served = join(root, "index.html");
            content = await readFile(served).catch(() => null);
        }

        if (content === null) {
            answer.writeHead(404).end();
            return;
        }

        answer.writeHead(200, { "content-type": TYPES[extname(served)] ?? "application/octet-stream" });
        answer.end(content);
    }

    get url() {
        return `http://127.0.0.1:${this.server.address().port}/`;
    }

    // What is still connected is dropped rather than waited for, since a browser holds a connection open
    // for the next request it might make and a server waiting for that one never closes at all.
    close() {
        this.server.closeAllConnections();
        return new Promise((done) => this.server.close(done));
    }
}
