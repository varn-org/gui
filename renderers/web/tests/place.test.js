// The map the browser has none of, and the fix it does have.
//
// A page has no map control, so the renderer draws the tiles itself, and everything a tree relies on
// comes out of that: the tiles it asks for, where a mark lands, and which gesture is a press rather
// than a drag. The fix is the browser's own, so what matters is that a one-off is asked for once and a
// watch is let go of when the node goes.

import { install } from "../dom.js";
import { WebRenderer } from "../renderer.js";

const surface = install();
const events = [];
const renderer = new WebRenderer(surface, (id, name, payload) => events.push({ id, name, payload }));

function assert(condition, message) {
    if (!condition) {
        console.error(`failed: ${message}`);
        process.exit(1);
    }
}

function build(id, type, props, frame) {
    renderer.apply([
        { op: "create", id, type, props },
        { op: "insert", id, parent: 0, index: 1 },
    ]);

    if (frame !== undefined) {
        renderer.apply([{ op: "frame", id, x: 0, y: 0, width: frame.width, height: frame.height }]);
    }

    return renderer.nodes.get(id);
}

// Node keeps a navigator of its own that cannot be assigned over, so the one a test stands up is defined.
function browser(navigator) {
    Object.defineProperty(globalThis, "navigator", { value: navigator, configurable: true });
}

function reported(id, name) {
    return events.filter((event) => event.id === id && event.name === name).map((event) => event.payload);
}

// A map is the tiles that cover it, asked for at the zoom it was given.
{
    const node = build(1, "map", {
        center: { latitude: 51.5074, longitude: -0.1278 },
        zoom: 12,
        markers: [],
        interactive: true,
    }, { width: 300, height: 300 });

    const tiles = [...node.place.tiles.values()];

    assert(tiles.length >= 4, `a 300 by 300 map is covered by tiles, it has ${tiles.length}`);
    assert(tiles.every((tile) => tile.src.startsWith("https://tile.openstreetmap.org/12/")),
        `every tile is asked for at the zoom the map is at, one was ${tiles[0].src}`);

    // London is a little west of the meridian and a little north of the middle, which is the tile the
    // whole projection stands or falls on.
    assert(tiles.some((tile) => tile.src === "https://tile.openstreetmap.org/12/2045/1362.png"),
        "the tile London sits in is one of them");
}

// A mark stands where its coordinate is, and reports itself when it is pressed.
{
    const node = renderer.nodes.get(1);

    renderer.apply([{ op: "update", id: 1, props: {
        markers: [
            { key: "here", latitude: 51.5074, longitude: -0.1278, title: "London" },
            { key: "there", latitude: 51.5074, longitude: 0.1278 },
        ],
        onMarkerPress: true,
    } }]);

    const here = node.place.marks.get("here");
    const there = node.place.marks.get("there");

    assert(here !== undefined && there !== undefined, "every marker is drawn");
    assert(here.element.style.left === "150px" && here.element.style.top === "150px",
        `a mark on the centre sits in the middle, this one is at ${here.element.style.left}`);
    assert(parseFloat(there.element.style.left) > 150, "a mark to the east sits to the right of it");
    assert(here.title.textContent === "London", "a mark says what it was named");
    assert(there.title.style.display === "none", "and one with no name says nothing");

    here.element.dispatch("pointerup", { stopPropagation() {} });
    assert(reported(1, "onMarkerPress").length === 1, "pressing a mark reports it");
    assert(reported(1, "onMarkerPress")[0].key === "here", "and it reports which one");

    renderer.apply([{ op: "update", id: 1, props: { markers: [] } }]);
    assert(node.place.marks.size === 0, "a marker the tree dropped is taken off the map");
}

// A finger that travels moves the map, and one that does not presses it.
{
    const node = renderer.nodes.get(1);

    renderer.apply([{ op: "update", id: 1, props: { onPress: true, onRegionChange: true } }]);

    const was = { ...node.place.center };

    node.element.dispatch("pointerdown", { pointerId: 1, clientX: 200, clientY: 200 });
    node.element.dispatch("pointermove", { pointerId: 1, clientX: 120, clientY: 200 });
    node.element.dispatch("pointerup", { pointerId: 1, clientX: 120, clientY: 200 });

    const region = reported(1, "onRegionChange");

    assert(region.length === 1, `a map that was dragged reports where it ended up, got ${region.length}`);
    assert(region[0].center.longitude > was.longitude, "dragging west moves the map east");
    assert(reported(1, "onPress").length === 0, "and a drag is not a press");

    node.element.dispatch("pointerdown", { pointerId: 2, clientX: 150, clientY: 150 });
    node.element.dispatch("pointerup", { pointerId: 2, clientX: 150, clientY: 150 });

    const pressed = reported(1, "onPress");

    assert(pressed.length === 1, "a finger that stays put presses the map");
    assert(Math.abs(pressed[0].latitude - node.place.center.latitude) < 0.5,
        "and it reports where on the map it landed");
}

// A map told it may not be moved is not moved.
{
    const node = build(2, "map", {
        center: { latitude: 0, longitude: 0 },
        zoom: 3,
        markers: [],
        interactive: false,
        onRegionChange: true,
    }, { width: 200, height: 200 });

    node.element.dispatch("pointerdown", { pointerId: 3, clientX: 100, clientY: 100 });
    node.element.dispatch("pointermove", { pointerId: 3, clientX: 40, clientY: 100 });
    node.element.dispatch("pointerup", { pointerId: 3, clientX: 40, clientY: 100 });

    assert(node.place.center.longitude === 0, "a map that is not interactive stays where it was put");
    assert(reported(2, "onRegionChange").length === 0, "and reports nothing, since nothing happened");
}

// A fix is asked for once, and a watch is let go of with the node that asked for it.
{
    const asked = [];
    let watching = 0;
    let cleared = 0;

    browser({
        geolocation: {
            getCurrentPosition(answer, _failed, options) {
                asked.push(options);
                answer({ coords: { latitude: 10, longitude: 20, accuracy: 5 } });
            },
            watchPosition(answer) {
                watching += 1;
                answer({ coords: { latitude: 11, longitude: 21, accuracy: 8 } });
                return watching;
            },
            clearWatch() {
                cleared += 1;
            },
        },
    });

    build(3, "location", { watch: false, accuracy: "fine", onChange: true, onError: true });

    const fixes = reported(3, "onChange");

    assert(asked.length === 1, `a one-off fix is asked for once, it was asked ${asked.length} times`);
    assert(asked[0].enableHighAccuracy === true, "a fine fix asks the browser for a fine one");
    assert(fixes.length === 1 && fixes[0].latitude === 10 && fixes[0].accuracy === 5,
        "and what came back is reported as it stands");

    build(4, "location", { watch: true, accuracy: "coarse", onChange: true, onError: true });

    assert(watching === 1, "a watch subscribes rather than asking once");
    assert(reported(4, "onChange")[0].latitude === 11, "and reports every fix it is given");

    renderer.apply([{ op: "remove", id: 4 }]);
    assert(cleared === 1, "a watch is let go of when the node that asked for it goes");
}

// A browser that answers nothing about where it is says so, rather than leaving a screen waiting.
{
    browser({});

    build(5, "location", { watch: false, accuracy: "fine", onChange: true, onError: true });

    assert(reported(5, "onError").length === 1, "a browser with no geolocation reports an error");
}

// What a node opened is given back when the node goes.
{
    build(6, "audio", { source: "loop.mp3", playing: true, onEnd: true });

    const sound = renderer.nodes.get(6).element;
    let paused = false;

    sound.pause = () => { paused = true; };

    renderer.apply([{ op: "remove", id: 6 }]);

    assert(paused, "a sound is stopped when the node that carried it goes");
    assert(renderer.nodes.get(6) === undefined, "and the renderer holds nothing for it");
}

console.log("web.place ok");
