// What a camera and a microphone are on the page: a stream the browser opens, a preview drawn from it,
// and what is captured out of it.
//
// The browser asks the reader for the camera and the microphone itself, so nothing here decides whether
// it may run. What it does decide is that what a reader sees is what a capture carries: the zoom is a
// crop and the filter is a colour matrix, and both are applied to the frame that is written to a file
// exactly as they are applied to the preview.

const MIME = {
    video: ["video/mp4", "video/webm;codecs=vp9", "video/webm"],
    audio: ["audio/mp4", "audio/webm;codecs=opus", "audio/webm"],
};

const ENDINGS = {
    "video/mp4": "mp4",
    "video/webm": "webm",
    "audio/mp4": "m4a",
    "audio/webm": "webm",
};

export class Capture {
    constructor(report) {
        this.report = report;
        this.streams = new Map();
        this.recordings = new Map();
    }

    // Answers whether the browser can open a camera at all, which a page served over http cannot.
    static available() {
        return typeof navigator !== "undefined" && navigator.mediaDevices?.getUserMedia !== undefined;
    }

    // Answers the first kind the browser will actually record, since no two of them record the same one.
    static recordable(kind) {
        for (const type of MIME[kind]) {
            if (MediaRecorder.isTypeSupported?.(type) === true) {
                return type;
            }
        }

        return "";
    }

    /** Answers the element the stream is drawn in, which for a camera is inside the box it was given. */
    static preview(node) {
        return node.control ?? node.element;
    }

    /** Opens the camera a node asked for and draws it into the node's own element. */
    async open(node) {
        if (!Capture.available()) {
            this.report(node.id, "onError", { message: "this browser has no camera" });
            return;
        }

        const wanted = {
            video: { facingMode: node.props.facing === "front" ? "user" : "environment" },
            audio: node.props.audio === true,
        };

        // The one already open is the one to close, since a reader who turned the camera round is asking
        // for a different device rather than for a second one.
        this.close(node);

        try {
            const stream = await navigator.mediaDevices.getUserMedia(wanted);

            // A node taken off the screen while the reader was being asked leaves a camera running with
            // nothing drawing it, which is a light left on over a screen nobody is looking at.
            const preview = Capture.preview(node);

            if (node.element.isConnected !== true) {
                Capture.stop(stream);
                return;
            }

            this.streams.set(node.id, stream);
            preview.srcObject = stream;
            preview.muted = true;
            preview.playsInline = true;
            await preview.play?.();

            this.report(node.id, "onReady", { facing: node.props.facing ?? "back" });
        } catch (problem) {
            this.report(node.id, "onError", { message: String(problem?.message ?? problem) });
        }
    }

    /** Lets the camera or the microphone go, which is what leaving the screen has to do. */
    close(node) {
        const stream = this.streams.get(node.id);

        if (stream !== undefined) {
            Capture.stop(stream);
            this.streams.delete(node.id);
        }

        const recording = this.recordings.get(node.id);

        if (recording !== undefined) {
            recording.recorder.stop();
            this.recordings.delete(node.id);
        }

        const preview = Capture.preview(node);

        if (preview.srcObject !== undefined) {
            preview.srcObject = null;
        }
    }

    static stop(stream) {
        for (const track of stream.getTracks()) {
            track.stop();
        }
    }

    /** Asks the device for the light and the zoom, which most of them have neither of. */
    async settle(node) {
        const track = this.streams.get(node.id)?.getVideoTracks()[0];

        if (track === undefined) {
            return;
        }

        const able = track.getCapabilities?.() ?? {};
        const advanced = [];

        if (able.torch === true) {
            advanced.push({ torch: node.props.torch === true });
        }

        if (advanced.length > 0) {
            await track.applyConstraints({ advanced }).catch(() => {});
        }
    }

    /**
     * Takes a picture out of the stream, as the reader is seeing it rather than as the device sees it.
     *
     * The zoom is a crop and the filter is a colour matrix, and a canvas applies neither of them on its
     * own, so both are applied here: a picture taken while the preview was zoomed and in black and white
     * is zoomed and in black and white.
     */
    async photograph(node) {
        const stream = this.streams.get(node.id);
        const video = Capture.preview(node);

        if (stream === undefined || !(video.videoWidth > 0)) {
            this.report(node.id, "onError", { message: "the camera has nothing to take a picture of yet" });
            return;
        }

        // Taking a picture runs over several turns of the loop, so nothing above this catches what goes
        // wrong in it: a failure here would be an unhandled rejection and a reader pressing a button that
        // does nothing at all.
        try {
            const zoom = Math.max(1, Number(node.props.zoom) || 1);
            const width = Math.round(video.videoWidth / zoom);
            const height = Math.round(video.videoHeight / zoom);

            const canvas = document.createElement("canvas");
            canvas.width = width;
            canvas.height = height;

            const context = canvas.getContext("2d");
            context.drawImage(video, (video.videoWidth - width) / 2, (video.videoHeight - height) / 2,
                width, height, 0, 0, width, height);

            Capture.paint(context, node.props.filter, width, height);

            const file = await Capture.written(canvas);

            if (file === null) {
                this.report(node.id, "onError", { message: "the picture could not be written" });
                return;
            }

            this.report(node.id, "onCapture", { path: file, width, height });
        } catch (problem) {
            this.report(node.id, "onError", { message: String(problem?.message ?? problem) });
        }
    }

    /** Draws the colour matrix a filter came to over what a canvas holds. */
    static paint(context, matrix, width, height) {
        if (matrix === undefined || matrix === null || matrix.length !== 20) {
            return;
        }

        const picture = context.getImageData(0, 0, width, height);
        const pixels = picture.data;

        for (let at = 0; at < pixels.length; at += 4) {
            const r = pixels[at] / 255;
            const g = pixels[at + 1] / 255;
            const b = pixels[at + 2] / 255;
            const a = pixels[at + 3] / 255;

            for (let channel = 0; channel < 4; channel += 1) {
                const row = channel * 5;
                const value = matrix[row] * r + matrix[row + 1] * g + matrix[row + 2] * b
                    + matrix[row + 3] * a + matrix[row + 4];

                pixels[at + channel] = Math.max(0, Math.min(255, Math.round(value * 255)));
            }
        }

        context.putImageData(picture, 0, 0);
    }

    /** Answers the address a canvas can be opened at, which is what a page has instead of a path. */
    static written(canvas) {
        return new Promise((answer) => {
            canvas.toBlob((blob) => answer(blob === null ? null : URL.createObjectURL(blob)), "image/png");
        });
    }

    /** Starts recording what the node is carrying, which is a camera's frames or a microphone's sound. */
    start(node, kind) {
        const stream = this.streams.get(node.id);

        if (stream === undefined) {
            this.report(node.id, "onError", { message: "there is nothing to record yet" });
            return;
        }

        if (this.recordings.has(node.id)) {
            return;
        }

        const type = Capture.recordable(kind);
        const recorder = new MediaRecorder(stream, type === "" ? undefined : { mimeType: type });
        const parts = [];

        recorder.ondataavailable = (event) => {
            if (event.data?.size > 0) {
                parts.push(event.data);
            }
        };

        recorder.onstop = () => {
            const recording = this.recordings.get(node.id);
            this.recordings.delete(node.id);

            const blob = new Blob(parts, { type: recorder.mimeType || type });
            const seconds = (Date.now() - (recording?.began ?? Date.now())) / 1000;

            this.report(node.id, kind === "audio" ? "onFinish" : "onRecord", {
                path: URL.createObjectURL(blob),
                duration: seconds,
                type: blob.type,
                extension: ENDINGS[(blob.type ?? "").split(";")[0]] ?? "webm",
            });
        };

        this.recordings.set(node.id, { recorder, began: Date.now() });
        recorder.start();
    }

    /** Stops a recording, which is what produces the file rather than starting one. */
    stop(node) {
        const recording = this.recordings.get(node.id);

        if (recording === undefined) {
            return;
        }

        recording.recorder.stop();
    }

    /** Answers whether a node is recording, which is what a prop-driven recorder is told to be or not. */
    recording(node) {
        return this.recordings.has(node.id);
    }

    /** Opens the microphone a recorder needs, which is asked for the first time it is told to record. */
    async listen(node) {
        if (!Capture.available()) {
            this.report(node.id, "onError", { message: "this browser has no microphone" });
            return false;
        }

        if (this.streams.has(node.id)) {
            return true;
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

            if (node.element.isConnected !== true) {
                Capture.stop(stream);
                return false;
            }

            this.streams.set(node.id, stream);
            this.report(node.id, "onReady", {});
            return true;
        } catch (problem) {
            this.report(node.id, "onError", { message: String(problem?.message ?? problem) });
            return false;
        }
    }
}
