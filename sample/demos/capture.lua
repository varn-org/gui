local gui = require("gui")
local parts = require("parts")
local async = require("async")

--- The looks a preview is drawn through, which is also what a capture is written with.
local LOOKS = { "none", "mono", "noir", "sepia", "vivid", "cool", "warm" }

--- Answers a length of time the way a person reads one.
local function clocked(seconds)
    return string.format("%d:%02d", math.floor((seconds or 0) / 60), math.floor((seconds or 0) % 60))
end

local Camera = gui.component({
    name = "CameraDemo",
    state = {
        on = false,
        facing = "back",
        look = "none",
        zoom = 1,
        torch = false,
        recording = false,
        taken = nil,
        clip = nil,
        said = "The camera is off",
    },

    --- Answers the look the preview is drawn through, which is nothing at all when none was chosen.
    look = function(self)
        return self.state.look ~= "none" and gui.filter.looks[self.state.look] or nil
    end,

    --- The row of looks a reader chooses between, drawn as the names rather than as pictures.
    Looks = function(self)
        local row = {}

        for _, name in ipairs(LOOKS) do
            row[#row + 1] = gui.Chip {
                key = name,
                label = name,
                selected = self.state.look == name,
                onPress = function() self:setState({ look = name }) end,
            }
        end

        return row
    end,

    --- Keeps what was captured where the platform keeps pictures, or hands it to what sends one.
    Keep = function(self, action)
        local file = self.state.clip or self.state.taken

        if file == nil then
            return
        end

        self:setState({ said = action == "share" and "Sharing" or "Keeping" })

        async.spawn(function()
            local answer = gui.files[action](file, { title = "From the camera" }):await()

            if answer.problem ~= nil then
                self:setState({ said = answer.problem })
                return
            end

            self:setState({ said = action == "share" and "Shared it" or "Kept it" })
        end)
    end,

    --- What was captured, shown as the picture or the film it turned out to be.
    Taken = function(self)
        if self.state.clip ~= nil then
            return gui.Video {
                source = self.state.clip,
                controls = true,
                filter = self:look(),
                style = { height = 200, radius = "md", background = "surface" },
            }
        end

        if self.state.taken ~= nil then
            return gui.Image {
                source = self.state.taken,
                resizeMode = "contain",
                style = { height = 200, radius = "md", background = "surface" },
            }
        end

        return gui.Text {
            text = "Nothing captured yet",
            style = { color = "textMuted", textAlign = "center", paddingVertical = "lg" },
        }
    end,

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "What the camera sees",
                summary = "Opened when it is asked for and let go the moment it is not",

                gui.Button {
                    title = self.state.on and "Turn the camera off" or "Turn the camera on",
                    accessibilityLabel = self.state.on and "Turn the camera off" or "Turn the camera on",
                    variant = self.state.on and "outlined" or "filled",
                    onPress = function()
                        self:setState({
                            on = not self.state.on,
                            recording = false,
                            said = self.state.on and "The camera is off" or "Opening the camera",
                        })
                    end,
                },

                not self.state.on and gui.View {
                    style = {
                        height = 260, radius = "md", background = "surface",
                        align = "center", justify = "center",
                    },
                    gui.Icon { name = "camera", size = 32, color = "textMuted" },
                } or gui.Camera {
                    ref = self:ref("camera"),
                    facing = self.state.facing,
                    zoom = self.state.zoom,
                    torch = self.state.torch,
                    audio = true,
                    filter = self:look(),
                    style = { height = 260, radius = "md", background = "surface" },
                    onReady = function(ready)
                        self:setState({ said = "Looking " .. (ready.facing or "back") })
                    end,
                    onError = function(problem)
                        self:setState({ said = problem.message or "the camera would not open" })
                    end,
                    onCapture = function(photo)
                        self:setState({ taken = photo.path, clip = gui.none, said = "Took a picture" })
                    end,
                    onRecord = function(clip)
                        self:setState({
                            clip = clip.path,
                            taken = gui.none,
                            recording = false,
                            said = "Recorded " .. clocked(clip.duration),
                        })
                    end,
                },
                gui.Text { text = self.state.said, style = { color = "textMuted", fontSize = "caption" } },
            },

            parts.Block {
                title = "A look over what it sees",
                summary = "Drawn over the preview, written into a picture, and drawn over a film as it plays",
                gui.ScrollView {
                    horizontal = true,
                    showsIndicator = false,
                    style = { height = 44 },
                    contentStyle = { direction = "row", gap = "xs", align = "center" },
                    table.unpack(self:Looks()),
                },
            },

            parts.Block {
                title = "The camera itself",
                gui.View { style = { direction = "row", gap = "sm", align = "center" },
                    gui.Button {
                        title = self.state.facing == "back" and "Turn to me" or "Turn away",
                        variant = "tinted",
                        onPress = function()
                            self:setState({ facing = self.state.facing == "back" and "front" or "back" })
                        end,
                    },
                    gui.Button {
                        title = self.state.torch and "Light off" or "Light on",
                        variant = "outlined",
                        onPress = function() self:setState({ torch = not self.state.torch }) end,
                    },
                },
                gui.View { style = { gap = "xs" },
                    gui.Text { text = "Zoom " .. string.format("%.1f", self.state.zoom) .. "x",
                        style = { fontSize = "caption", color = "textMuted" } },
                    gui.Slider {
                        value = self.state.zoom,
                        minimum = 1,
                        maximum = 4,
                        step = 0.1,
                        onChange = function(zoom) self:setState({ zoom = math.max(1, zoom or 1) }) end,
                    },
                },
            },

            parts.Block {
                title = "Taking one",
                gui.View { style = { direction = "row", gap = "sm" },
                    gui.Button {
                        title = "Take a picture",
                        accessibilityLabel = "Take a picture",
                        onPress = function() self:ref("camera"):call("capturePhoto") end,
                    },
                    gui.Button {
                        title = self.state.recording and "Stop" or "Record",
                        accessibilityLabel = self.state.recording and "Stop" or "Record",
                        variant = "tinted",
                        onPress = function()
                            if self.state.recording then
                                self:ref("camera"):call("stopRecording")
                                return
                            end

                            self:setState({ recording = true, said = "Recording" })
                            self:ref("camera"):call("startRecording")
                        end,
                    },
                },
            },

            parts.Block {
                title = "What it captured",
                summary = "Written where the application may write, which is nowhere a reader can open it",
                self:Taken(),

                gui.View { style = { direction = "row", gap = "sm" },
                    gui.Button {
                        title = "Keep it",
                        accessibilityLabel = "Keep it",
                        disabled = self.state.taken == nil and self.state.clip == nil,
                        onPress = function() self:Keep("save") end,
                    },
                    gui.Button {
                        title = "Share it",
                        accessibilityLabel = "Share it",
                        variant = "tinted",
                        disabled = self.state.taken == nil and self.state.clip == nil,
                        onPress = function() self:Keep("share") end,
                    },
                },
            },
        }
    end,
})

local Sound = gui.component({
    name = "RecorderDemo",
    state = { recording = false, playing = false, clip = nil, length = 0, at = 0, said = "Nothing recorded yet" },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "The microphone on its own",
                summary = "A voice note, with no picture and nothing drawn by the platform",

                gui.Recorder {
                    recording = self.state.recording,
                    onReady = function()
                        self:setState({ said = "Recording" })
                    end,
                    onFinish = function(clip)
                        self:setState({
                            recording = false,
                            clip = clip.path,
                            length = clip.duration or 0,
                            at = 0,
                            said = "Recorded " .. clocked(clip.duration),
                        })
                    end,
                    onError = function(problem)
                        self:setState({ recording = false, said = problem.message or "the microphone would not open" })
                    end,
                },

                gui.Button {
                    title = self.state.recording and "Stop" or "Record",
                    accessibilityLabel = self.state.recording and "Stop" or "Record",
                    onPress = function()
                        self:setState({
                            recording = not self.state.recording,
                            playing = false,
                            said = self.state.recording and "Stopping" or "Asking for the microphone",
                        })
                    end,
                },

                gui.Text { text = self.state.said, style = { color = "textMuted", fontSize = "caption" } },
            },

            parts.Block {
                title = "What it recorded",
                summary = "Played back through the same sound the rest of the gallery plays",

                self.state.clip ~= nil and gui.Audio {
                    source = self.state.clip,
                    playing = self.state.playing,
                    onProgress = function(about) self:setState({ at = about.position }) end,
                    onEnd = function() self:setState({ playing = false, at = 0 }) end,
                    onError = function(problem)
                        self:setState({ playing = false, said = problem.message or "it would not play" })
                    end,
                } or false,

                self.state.clip == nil and gui.Text {
                    text = "Nothing yet",
                    style = { color = "textMuted" },
                } or gui.View { style = { gap = "sm" },
                    gui.View { style = { direction = "row", align = "center", gap = "md" },
                        gui.Button {
                            title = self.state.playing and "Pause" or "Play",
                            accessibilityLabel = self.state.playing and "Pause" or "Play",
                            variant = "tinted",
                            onPress = function() self:setState({ playing = not self.state.playing }) end,
                        },
                        gui.Text {
                            text = clocked(self.state.at) .. " of " .. clocked(self.state.length),
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },

                    gui.View { style = { direction = "row", gap = "sm" },
                        gui.Button {
                            title = "Keep it",
                            accessibilityLabel = "Keep the note",
                            variant = "outlined",
                            onPress = function() self:Keep("save") end,
                        },
                        gui.Button {
                            title = "Share it",
                            accessibilityLabel = "Share the note",
                            variant = "outlined",
                            onPress = function() self:Keep("share") end,
                        },
                    },
                },
            },
        }
    end,

    --- Keeps the note where the platform keeps one, or hands it to whatever sends one.
    Keep = function(self, action)
        if self.state.clip == nil then
            return
        end

        self:setState({ said = action == "share" and "Sharing" or "Keeping" })

        async.spawn(function()
            local answer = gui.files[action](self.state.clip, { title = "A voice note" }):await()

            self:setState({ said = answer.problem or (action == "share" and "Shared it" or "Kept it") })
        end)
    end,
})

return {
    {
        key = "camera",
        title = "A camera",
        summary = "A preview, a look over it, and the pictures and films it takes",
        render = function() return Camera {} end,
    },
    {
        key = "sound",
        title = "A voice note",
        summary = "The microphone with nothing to draw",
        render = function() return Sound {} end,
    },
}
