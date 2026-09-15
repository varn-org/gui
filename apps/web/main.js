import { WebHost } from "./host.js";
import createModule from "./varn_wasm.js";

// The framework and the gallery both arrive as bytes, since a browser shares no filesystem with the
// engine. The gallery is the same archive the two phones load.
//
// Every name here is written as it sits beside the page, and assembling the page stamps each one with
// the hash of what it holds, so a deploy is never half the old files and half the new.
const FRAMEWORK = "./framework.zip";
const ARCHIVE = "./gallery.vap";
const WASM = "./varn_wasm.wasm";

async function main() {
    // The engine's own loader works the wasm out from where its script was fetched, which is a name it
    // no longer has once the file carries a hash.
    const module = await createModule({ locateFile: (path) => (path.endsWith(".wasm") ? WASM : path) });
    const host = new WebHost(module, document.getElementById("surface"));

    await host.installFramework(FRAMEWORK);
    await host.install(ARCHIVE, "gallery.vap");
    host.start();
}

main().catch((error) => {
    document.body.textContent = `the gallery failed to start: ${error.message}`;
});
