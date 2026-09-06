// The conformance cases of gui/bridge/conformance.lua, run against the real DOM renderer.
//
// The names match the Lua suite exactly, and gui/tests/conformance_test.lua asserts that they still do,
// so a case added on one side cannot be forgotten on the other.

import { WebRenderer } from "./renderer.js";

const REMOVED = "__varn_removed__";

// The tree a renderer built, read back the way the Lua suite reads its own.
function tree(renderer, element) {
    const holder = element ?? renderer.container;
    const children = [];

    for (const child of holder.children) {
        const id = Number(child.dataset.varnId);
        if (Number.isNaN(id)) {
            continue;
        }

        const node = renderer.nodes.get(id);
        children.push({
            id,
            type: node.type,
            props: node.props,
            element: child,
            children: tree(renderer, node.content ?? child),
        });
    }

    return children;
}

function only(list) {
    if (list.length !== 1) {
        throw new Error(`expected one root, found ${list.length}`);
    }

    return list[0];
}

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function refuses(run, message) {
    let refused = false;

    try {
        run();
    } catch {
        refused = true;
    }

    assert(refused, message);
}

export const CAPABILITIES = [
    "text", "image", "list", "scroll", "input", "video", "webview", "canvas",
    "picker", "datepicker", "haptics", "safearea", "fontBytes",
];

export const CASES = [
    {
        name: "creates and attaches a root",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
            ]);

            const root = only(tree(renderer));
            assert(root.type === "view", "the root must be the node that was created");
            assert(root.children.length === 0, "a fresh root has no children");
        },
    },
    {
        name: "nests children in the order they were inserted",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "create", id: 2, type: "text", props: { text: "a" } },
                { op: "insert", id: 2, parent: 1, index: 1 },
                { op: "create", id: 3, type: "text", props: { text: "b" } },
                { op: "insert", id: 3, parent: 1, index: 2 },
            ]);

            const root = only(tree(renderer));
            assert(root.children[0].props.text === "a", "the first child must come first");
            assert(root.children[1].props.text === "b", "the second child must come second");
        },
    },
    {
        name: "updates only the props it was given",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: { opacity: 1, testID: "root" } },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "update", id: 1, props: { opacity: 0.5 } },
            ]);

            const root = only(tree(renderer));
            assert(root.props.opacity === 0.5, "the changed prop must be applied");
            assert(root.props.testID === "root", "an untouched prop must survive");
        },
    },
    {
        name: "drops a prop an update marked removed",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: { opacity: 0.5 } },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "update", id: 1, props: { opacity: REMOVED } },
            ]);

            assert(only(tree(renderer)).props.opacity === undefined, "a removed prop must be gone");
        },
    },
    {
        name: "moves a child without rebuilding it",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "create", id: 2, type: "text", props: { text: "a" } },
                { op: "insert", id: 2, parent: 1, index: 1 },
                { op: "create", id: 3, type: "text", props: { text: "b" } },
                { op: "insert", id: 3, parent: 1, index: 2 },
            ]);

            const before = renderer.nodes.get(2).element;
            renderer.apply([{ op: "move", id: 2, parent: 1, index: 2 }]);

            const root = only(tree(renderer));
            assert(root.children[0].props.text === "b", "the moved node must leave its place");
            assert(root.children[1].props.text === "a", "the moved node must arrive at the new one");
            assert(renderer.nodes.get(2).element === before, "a move must keep the widget it moved");
        },
    },
    {
        name: "removes a subtree whole",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "create", id: 2, type: "view", props: {} },
                { op: "insert", id: 2, parent: 1, index: 1 },
                { op: "create", id: 3, type: "text", props: { text: "deep" } },
                { op: "insert", id: 3, parent: 2, index: 1 },
            ]);

            renderer.apply([
                { op: "remove", id: 3 },
                { op: "remove", id: 2 },
            ]);

            const root = only(tree(renderer));
            assert(root.children.length === 0, "the subtree must be gone");
            assert(renderer.nodes.get(2) === undefined, "a removed node must be forgotten");
        },
    },
    {
        name: "places a node at the frame it was given",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "frame", id: 1, x: 12, y: 24, width: 100, height: 40 },
            ]);

            const style = renderer.nodes.get(1).element.style;
            assert(style.left === "12px" && style.top === "24px", "the node must sit where it was placed");
            assert(style.width === "100px" && style.height === "40px", "the node must take the size it was given");
        },
    },
    {
        name: "reparents a node rather than duplicating it",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "view", props: {} },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "create", id: 2, type: "view", props: {} },
                { op: "insert", id: 2, parent: 0, index: 2 },
                { op: "create", id: 3, type: "text", props: { text: "moved" } },
                { op: "insert", id: 3, parent: 1, index: 1 },
            ]);

            renderer.apply([{ op: "move", id: 3, parent: 2, index: 1 }]);

            const roots = tree(renderer);
            assert(roots[0].children.length === 0, "the old parent must have let go");
            assert(roots[1].children.length === 1, "the new parent must have taken it");
            assert(roots[1].children[0].props.text === "moved", "the node itself must have moved");
        },
    },
    {
        name: "refuses a batch that breaks the contract",
        run(renderer) {
            refuses(() => renderer.apply([{ op: "update", id: 1 }]), "an update with no props must be refused");
            refuses(() => renderer.apply([{ op: "nonsense", id: 1 }]), "an unknown operation must be refused");
        },
    },
    {
        name: "answers a measurement for a string",
        run(renderer) {
            const size = renderer.measureText("hello", { fontSize: 16 }, null);

            assert(typeof size.width === "number" && size.width > 0, "a measurement must carry a width");
            assert(typeof size.height === "number" && size.height > 0, "a measurement must carry a height");
        },
    },
    {
        name: "answers a finite measurement however it is bounded",
        run(renderer) {
            for (const bound of [0, 1, 40, null]) {
                const size = renderer.measureText("a longer sentence", { fontSize: 16 }, bound);

                assert(Number.isFinite(size.width), `a width must be a finite number at bound ${bound}`);
                assert(Number.isFinite(size.height), `a height must be a finite number at bound ${bound}`);
                assert(size.height > 0, `a line of text is never zero high, at bound ${bound}`);
            }
        },
    },
    {
        name: "reports an event as what the event carries",
        run(renderer) {
            const reported = [];
            renderer.emit = (id, name, payload) => reported.push({ id, name, payload });

            renderer.apply([
                { op: "create", id: 1, type: "textinput", props: { value: "", onChange: true } },
                { op: "insert", id: 1, parent: 0, index: 1 },
            ]);

            const element = renderer.nodes.get(1).element;
            element.value = "typed";
            element.dispatch("input", {});

            assert(reported.length === 1, "a change must be reported once");
            assert(reported[0].name === "onChange", "a change is reported by the name of the prop that declared it");
            assert(reported[0].payload === "typed",
                `a change carries the value itself, got ${JSON.stringify(reported[0].payload)}`);
        },
    },
    {
        name: "reads a radio value as its identity rather than its state",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "radio", props: { value: "monthly", selected: true } },
                { op: "insert", id: 1, parent: 0, index: 1 },
                { op: "create", id: 2, type: "radio", props: { value: "yearly", selected: false } },
                { op: "insert", id: 2, parent: 0, index: 2 },
            ]);

            const chosen = renderer.nodes.get(1).element;
            const other = renderer.nodes.get(2).element;

            assert(chosen.checked === true, "the chosen radio must be the one marked selected");
            assert(other.checked === false, "the other radio must be left alone");
            assert(chosen.value === "monthly", "a radio keeps the value it reports when chosen");
        },
    },
    {
        name: "leaves a field alone when its value has not changed",
        run(renderer) {
            renderer.apply([
                { op: "create", id: 1, type: "textinput", props: { value: "Ada", onChange: true } },
                { op: "insert", id: 1, parent: 0, index: 1 },
            ]);

            const element = renderer.nodes.get(1).element;
            element.selectionStart = 1;
            element.selectionEnd = 1;

            renderer.apply([{ op: "update", id: 1, props: { value: "Ada" } }]);

            assert(element.value === "Ada", "the field must hold the value it was given");
            assert(element.selectionStart === 1, `the caret moved to ${element.selectionStart}`);
        },
    },
    {
        name: "declares what it can do",
        run(renderer) {
            assert(typeof renderer.capabilities === "object", "a renderer must declare its capabilities");

            for (const name of CAPABILITIES) {
                const value = renderer.capabilities[name];
                assert(value === undefined || typeof value === "boolean", `${name} must be declared as a boolean`);
            }
        },
    },
];

/** Runs every case against a freshly built renderer, answering the failures. */
export function run(build) {
    const failures = [];

    for (const testCase of CASES) {
        try {
            testCase.run(build());
        } catch (problem) {
            failures.push(`${testCase.name}: ${problem.message}`);
        }
    }

    return failures;
}

export { WebRenderer, tree };
