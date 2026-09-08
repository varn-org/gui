// The map and the location fix, which are the two things a browser draws from where a reader is.
//
// A browser has no map control, so the map is the tiles themselves: a raster layer from OpenStreetMap
// under marks the tree placed, panned and zoomed by pointer. The projection is the one every raster map
// on the web is served in, so the same centre and zoom put the same place on screen here as MapKit and
// the Android view put it there.

const TILE = 256;
const TILES = "https://tile.openstreetmap.org";
const CREDIT = "© OpenStreetMap";

// How far a finger may travel and still have pressed the map rather than dragged it.
const TRAVEL = 6;

export class VarnTileMap {
    constructor(element, report) {
        this.element = element;
        this.report = report;

        this.center = { latitude: 0, longitude: 0 };
        this.zoom = 14;
        this.markers = [];
        this.interactive = true;
        this.size = { width: 0, height: 0 };

        this.tiles = new Map();
        this.marks = new Map();
        this.pointers = new Map();
        this.travelled = 0;
        this.pinch = null;

        element.style.overflow = "hidden";
        element.style.background = "#e8e5e0";
        element.style.touchAction = "none";

        this.layer = VarnTileMap.layer();
        this.pins = VarnTileMap.layer();
        this.credit = VarnTileMap.credit();

        element.appendChild(this.layer);
        element.appendChild(this.pins);
        element.appendChild(this.credit);

        this.watch();
    }

    static layer() {
        const layer = document.createElement("div");

        layer.style.position = "absolute";
        layer.style.left = "0";
        layer.style.top = "0";
        layer.style.right = "0";
        layer.style.bottom = "0";

        return layer;
    }

    static credit() {
        const credit = document.createElement("span");

        credit.textContent = CREDIT;
        credit.style.position = "absolute";
        credit.style.right = "4px";
        credit.style.bottom = "2px";
        credit.style.font = "10px system-ui, sans-serif";
        credit.style.color = "rgba(0, 0, 0, 0.6)";
        credit.style.background = "rgba(255, 255, 255, 0.7)";
        credit.style.padding = "0 4px";
        credit.style.borderRadius = "3px";

        return credit;
    }

    // The web mercator the tiles are cut in, which is what makes a centre mean the same thing everywhere.
    static project(latitude, longitude, zoom) {
        const world = TILE * Math.pow(2, zoom);
        const sine = Math.sin((latitude * Math.PI) / 180);

        return {
            x: ((longitude + 180) / 360) * world,
            y: (0.5 - Math.log((1 + sine) / (1 - sine)) / (4 * Math.PI)) * world,
        };
    }

    static unproject(x, y, zoom) {
        const world = TILE * Math.pow(2, zoom);
        const share = 0.5 - y / world;

        return {
            latitude: (Math.atan(Math.sinh(2 * Math.PI * share)) * 180) / Math.PI,
            longitude: (x / world) * 360 - 180,
        };
    }

    setCenter(center) {
        this.center = { latitude: center.latitude, longitude: center.longitude };
    }

    setZoom(zoom) {
        this.zoom = Math.min(20, Math.max(1, zoom));
    }

    setMarkers(markers) {
        this.markers = markers ?? [];
    }

    setInteractive(interactive) {
        this.interactive = interactive !== false;
    }

    resize(width, height) {
        this.size = { width, height };
        this.draw();
    }

    // Draws what the props a batch carried add up to, which is once however many of them changed.
    settle() {
        this.draw();
    }

    draw() {
        if (this.size.width === 0 || this.size.height === 0) {
            return;
        }

        this.drawTiles();
        this.drawMarks();
    }

    drawTiles() {
        const level = Math.max(1, Math.min(19, Math.round(this.zoom)));
        const scale = Math.pow(2, this.zoom - level);
        const span = TILE * scale;
        const middle = VarnTileMap.project(this.center.latitude, this.center.longitude, this.zoom);
        const across = Math.pow(2, level);

        const left = middle.x - this.size.width / 2;
        const top = middle.y - this.size.height / 2;

        const first = { x: Math.floor(left / span), y: Math.floor(top / span) };
        const last = {
            x: Math.floor((left + this.size.width) / span),
            y: Math.floor((top + this.size.height) / span),
        };

        const wanted = new Set();

        for (let y = first.y; y <= last.y; y += 1) {
            for (let x = first.x; x <= last.x; x += 1) {
                if (y < 0 || y >= across) {
                    continue;
                }

                const around = ((x % across) + across) % across;
                const name = `${level}/${around}/${y}`;

                wanted.add(name);
                this.tile(name, level, around, y).style.transform =
                    `translate(${Math.round(x * span - left)}px, ${Math.round(y * span - top)}px)`;
            }
        }

        for (const [name, tile] of this.tiles) {
            if (!wanted.has(name)) {
                tile.remove();
                this.tiles.delete(name);
            }
        }

        for (const tile of this.tiles.values()) {
            tile.style.width = `${Math.ceil(span) + 1}px`;
            tile.style.height = `${Math.ceil(span) + 1}px`;
        }
    }

    tile(name, level, x, y) {
        const held = this.tiles.get(name);

        if (held !== undefined) {
            return held;
        }

        const tile = document.createElement("img");

        tile.src = `${TILES}/${level}/${x}/${y}.png`;
        tile.alt = "";
        tile.draggable = false;
        tile.style.position = "absolute";
        tile.style.left = "0";
        tile.style.top = "0";
        tile.style.transformOrigin = "0 0";
        tile.style.pointerEvents = "none";

        this.tiles.set(name, tile);
        this.layer.appendChild(tile);

        return tile;
    }

    drawMarks() {
        const middle = VarnTileMap.project(this.center.latitude, this.center.longitude, this.zoom);
        const wanted = new Set();

        for (const marker of this.markers) {
            const at = VarnTileMap.project(marker.latitude, marker.longitude, this.zoom);
            const mark = this.mark(marker);

            wanted.add(marker.key);
            mark.element.style.left = `${at.x - middle.x + this.size.width / 2}px`;
            mark.element.style.top = `${at.y - middle.y + this.size.height / 2}px`;
            mark.title.textContent = marker.title ?? "";
            mark.title.style.display = marker.title === undefined ? "none" : "block";
        }

        for (const [key, mark] of this.marks) {
            if (!wanted.has(key)) {
                mark.element.remove();
                this.marks.delete(key);
            }
        }
    }

    mark(marker) {
        const drawn = this.marks.get(marker.key);

        if (drawn !== undefined) {
            return drawn;
        }

        const mark = document.createElement("div");
        const pin = document.createElement("div");
        const title = document.createElement("span");

        mark.style.position = "absolute";
        mark.style.transform = "translate(-50%, -100%)";
        mark.style.display = "flex";
        mark.style.flexDirection = "column";
        mark.style.alignItems = "center";
        mark.style.cursor = "pointer";

        title.style.font = "600 11px system-ui, sans-serif";
        title.style.color = "#1c1c1e";
        title.style.background = "rgba(255, 255, 255, 0.9)";
        title.style.borderRadius = "4px";
        title.style.padding = "1px 5px";
        title.style.whiteSpace = "nowrap";

        pin.style.width = "14px";
        pin.style.height = "14px";
        pin.style.borderRadius = "50%";
        pin.style.background = "#e5484d";
        pin.style.border = "2px solid #ffffff";
        pin.style.boxShadow = "0 1px 3px rgba(0, 0, 0, 0.4)";
        pin.style.order = "2";

        mark.appendChild(pin);
        mark.appendChild(title);
        mark.addEventListener("pointerup", (event) => {
            event.stopPropagation();
            this.report("onMarkerPress", { key: marker.key });
        });

        const held = { element: mark, title };

        this.marks.set(marker.key, held);
        this.pins.appendChild(mark);

        return held;
    }

    watch() {
        this.element.addEventListener("pointerdown", (event) => this.landed(event));
        this.element.addEventListener("pointermove", (event) => this.moved(event));
        this.element.addEventListener("pointerup", (event) => this.lifted(event));
        this.element.addEventListener("pointercancel", (event) => this.pointers.delete(event.pointerId));
        this.element.addEventListener("wheel", (event) => this.wheeled(event), { passive: false });
    }

    landed(event) {
        if (!this.interactive) {
            return;
        }

        this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
        this.travelled = 0;
        this.pinch = this.pointers.size === 2 ? { apart: this.apart(), zoom: this.zoom } : null;
        this.element.setPointerCapture?.(event.pointerId);
    }

    moved(event) {
        const held = this.pointers.get(event.pointerId);

        if (held === undefined) {
            return;
        }

        const moved = { x: event.clientX - held.x, y: event.clientY - held.y };

        this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
        this.travelled += Math.abs(moved.x) + Math.abs(moved.y);

        if (this.pinch !== null && this.pointers.size === 2) {
            this.setZoom(this.pinch.zoom + Math.log2(this.apart() / this.pinch.apart));
            return;
        }

        this.panBy(-moved.x, -moved.y);
    }

    lifted(event) {
        const held = this.pointers.get(event.pointerId);

        this.pointers.delete(event.pointerId);
        this.pinch = null;

        if (held === undefined) {
            return;
        }

        if (this.travelled > TRAVEL) {
            this.reportRegion();
            return;
        }

        const box = this.element.getBoundingClientRect();
        const middle = VarnTileMap.project(this.center.latitude, this.center.longitude, this.zoom);
        const at = VarnTileMap.unproject(
            middle.x + (event.clientX - box.left) - this.size.width / 2,
            middle.y + (event.clientY - box.top) - this.size.height / 2,
            this.zoom,
        );

        this.report("onPress", at);
    }

    wheeled(event) {
        if (!this.interactive) {
            return;
        }

        event.preventDefault();
        this.setZoom(this.zoom - Math.sign(event.deltaY));
        this.reportRegion();
    }

    apart() {
        const [first, second] = [...this.pointers.values()];

        return Math.max(1, Math.hypot(first.x - second.x, first.y - second.y));
    }

    panBy(x, y) {
        const middle = VarnTileMap.project(this.center.latitude, this.center.longitude, this.zoom);

        this.center = VarnTileMap.unproject(middle.x + x, middle.y + y, this.zoom);
        this.draw();
    }

    reportRegion() {
        this.report("onRegionChange", { center: this.center, zoom: this.zoom });
    }

    release() {
        this.tiles.clear();
        this.marks.clear();
        this.pointers.clear();
    }
}

// What the browser answers about where it is, which it only answers over a secure page and only once a
// reader has agreed to it.
export class VarnLocation {
    constructor(report) {
        this.report = report;
        this.watching = false;
        this.accuracy = "fine";
        this.asked = null;
        this.subscription = null;
        this.closed = false;
    }

    setWatch(watch) {
        this.watching = watch === true;
    }

    setAccuracy(accuracy) {
        this.accuracy = accuracy ?? "fine";
    }

    // Asks for what the props a batch carried add up to, and only when that is not what was asked for
    // already, since a handler arriving beside them is not a reason to ask the reader again.
    settle() {
        const wanted = `${this.watching}/${this.accuracy}`;

        if (wanted === this.asked) {
            return;
        }

        this.asked = wanted;
        this.ask();
    }

    ask() {
        this.stop();

        const geolocation = globalThis.navigator?.geolocation;

        if (geolocation === undefined) {
            this.report("onError", { message: "this browser does not answer where it is" });
            return;
        }

        const options = { enableHighAccuracy: this.accuracy === "fine", timeout: 15000 };

        // The browser answers a one-off fix long after the screen that asked for it may have gone.
        const answered = (position) => {
            if (!this.closed) {
                this.report("onChange", VarnLocation.fix(position));
            }
        };

        const failed = (problem) => {
            if (!this.closed) {
                this.report("onError", { message: problem.message });
            }
        };

        if (!this.watching) {
            geolocation.getCurrentPosition(answered, failed, options);
            return;
        }

        this.subscription = geolocation.watchPosition(answered, failed, options);
    }

    static fix(position) {
        return {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy ?? 0,
        };
    }

    // Gives up whatever is running, which asking again does before it asks.
    stop() {
        if (this.subscription === null) {
            return;
        }

        globalThis.navigator.geolocation.clearWatch(this.subscription);
        this.subscription = null;
    }

    release() {
        this.closed = true;
        this.stop();
    }
}
