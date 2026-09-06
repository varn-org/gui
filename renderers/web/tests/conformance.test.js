// Runs the conformance cases against the real DOM renderer, which is what proves this renderer applies
// operations the way the other two do.

import { install } from "../dom.js";
import { run } from "../conformance.js";
import { WebRenderer } from "../renderer.js";

const failures = run(() => new WebRenderer(install(), () => {}));

for (const failure of failures) {
    console.error(`failed: ${failure}`);
}

if (failures.length > 0) {
    process.exit(1);
}

console.log("web.conformance ok");
