import { WebHost } from "../../renderers/web/host.js";
import createModule from "./varn_wasm.js";

// The framework and the gallery both arrive as bytes, since a browser shares no filesystem with the
// engine. The gallery is the same archive the two phones load.
const FRAMEWORK = "./framework.zip";
const ARCHIVE = "./gallery.vap";

async function main() {
    const module = await createModule();
    const host = new WebHost(module, document.getElementById("surface"));

    await host.installFramework(FRAMEWORK);
    await host.install(ARCHIVE, "gallery.vap");
    host.start();
}

main().catch((error) => {
    document.body.textContent = `the gallery failed to start: ${error.message}`;
});
