local component = require("gui.component")
local icons = require("gui.style.icons")
local support = require("gui.components.support")

local M = {}

local RESIZE = { "cover", "contain", "stretch", "center" }

--- What a string is drawn as when the caller named nothing, which the theme decides rather than a platform.
---
--- A renderer that fell back to its own default would draw at a size the engine never measured, and the
--- label would be given a frame a few points short of the text it holds.
local BODY = { fontSize = "body", color = "text" }

--- Answers what is wrong with the number of lines a label was told it may run to, or nothing.
---
--- Nought is what a platform reads as no limit at all, which is what a label with none of its own does.
local function wrongLines(spec)
    if spec.numberOfLines == nil then
        return nil
    end

    if type(spec.numberOfLines) ~= "number" or spec.numberOfLines < 0 or spec.numberOfLines % 1 ~= 0 then
        return "numberOfLines is a whole number of lines, at least nothing, which means no limit"
    end

    return nil
end

M.Text = support.host("text", {
    style = BODY,
    props = { "text", "numberOfLines" },
    events = { "onPress", "onLongPress", "onHoverIn", "onHoverOut", "onLayout" },
    validate = function(spec)
        if spec.text == nil and #spec == 0 then
            return "needs text, either as the text prop or as its child"
        end

        -- A number is what a renderer draws as nothing at all and what a measurement asks the length of,
        -- so what a label says is a string, written by whoever knows how it should read.
        if spec.text ~= nil and type(spec.text) ~= "string" then
            return "text is a string, got a " .. type(spec.text)
        end

        return wrongLines(spec)
    end,
})

M.RichText = support.host("richtext", {
    style = BODY,
    natural = {
        text = function(props)
            local parts = {}

            for index = 1, #(props.spans or {}) do
                parts[index] = props.spans[index].text or ""
            end

            return table.concat(parts)
        end,
    },
    props = { "spans", "numberOfLines" },
    events = { "onLayout" },
    validate = function(spec)
        if type(spec.spans) ~= "table" then
            return "spans must be a list of { text, style, onPress } entries"
        end

        return wrongLines(spec)
    end,
})

M.Image = support.host("image", {
    natural = { size = { height = 160 } },
    props = { "source", "resizeMode", "placeholder", "tint", "filter" },
    events = { "onLayout", "onLoad", "onError" },
    defaults = { resizeMode = "cover" },
    validate = function(spec)
        if spec.source == nil then
            return "needs a source, either an asset name or a url"
        end

        if not support.oneOf(spec.resizeMode, RESIZE) then
            return support.expected("resizeMode", spec.resizeMode, RESIZE)
        end
    end,
})

--- What a canvas may be told to draw, which is what all three renderers draw and nothing besides.
local DRAWINGS = { fill = true, stroke = true, text = true }

--- Answers whether a value is a number a drawing can be placed at.
local function placed(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--- Answers what is wrong with a drawing instruction, or nothing when three renderers can draw it.
---
--- An instruction none of them knows is drawn by none of them and reported by none of them either: the
--- canvas comes out with a shape missing and nothing anywhere says which one or why.
local function wrongCommand(command, at)
    local where = "command " .. at

    if type(command) ~= "table" or not DRAWINGS[command.op] then
        return where .. " is a fill, a stroke or a text, got " .. tostring(type(command) == "table" and command.op)
    end

    if command.color ~= nil and type(command.color) ~= "string" then
        return where .. " carries a colour that is a name or a literal, got a " .. type(command.color)
    end

    if command.op == "text" then
        if type(command.text) ~= "string" then
            return where .. " is a text, which says what it draws, got a " .. type(command.text)
        end

        if not placed(command.x) or not placed(command.y) then
            return where .. " is drawn where it was told, which is two numbers"
        end

        if command.size ~= nil and (type(command.size) ~= "number" or command.size <= 0) then
            return where .. " is drawn at a size greater than nothing, got " .. tostring(command.size)
        end

        return nil
    end

    -- The points themselves are not walked: a chart is a thousand of them rebuilt on every render, and
    -- what goes wrong there is the shape of the instruction rather than the arithmetic inside it.
    local path = command.path

    if type(path) ~= "table" or #path < 2 then
        return where .. " draws a path of at least two points"
    end

    if type(path[1]) ~= "table" or not placed(path[1][1]) or not placed(path[1][2]) then
        return where .. " starts at a point that is not two numbers"
    end

    if command.op == "stroke" and command.width ~= nil
        and (type(command.width) ~= "number" or command.width <= 0) then
        return where .. " is drawn with a width greater than nothing, got " .. tostring(command.width)
    end

    return nil
end

M.Canvas = support.host("canvas", {
    props = { "commands" },
    events = { "onLayout" },
    validate = function(spec)
        if type(spec.commands) ~= "table" then
            return "commands must be a list of drawing instructions"
        end

        for index = 1, #spec.commands do
            local wrong = wrongCommand(spec.commands[index], index)

            if wrong ~= nil then
                return wrong
            end
        end
    end,
})

--- A drawing from the set the engine carries, in the size and colour it was asked for.
---
--- The engine owns the set so one name draws one thing everywhere. A phone that ships thousands of
--- symbols ships them under names no other platform has, which is how an icon came to be a picture on
--- one and an empty box on the other two.
M.Icon = support.component("Icon", {
    props = { "name", "size", "color" },
    defaults = { size = 24, color = "text" },
    validate = function(spec)
        if spec.name == nil then
            return "needs a name"
        end

        if not icons.has(spec.name) then
            return "does not know an icon called " .. tostring(spec.name)
        end
    end,
}, component.define({
    name = "Icon",
    render = function(self)
        local size = self.props.size

        return M.Canvas {
            style = { { width = size, height = size }, self.props.style },
            commands = icons.commands(self.props.name, size, self.props.color),
        }
    end,
}))

--- A film, played by the platform's own player and drawn where the tree put it.
---
--- Playing, pausing and moving to a moment are asked through a ref rather than written as props. A seek
--- is something a reader did once, so a value would be sent only when it differs from the last one and
--- dragging a scrubber back to a moment it has already been at would be silent.
M.Video = support.host("video", {
    natural = { size = { height = 200 } },
    props = { "source", "poster", "muted", "loop", "autoplay", "controls", "resizeMode", "volume", "rate",
        "filter" },
    events = { "onReady", "onProgress", "onEnd", "onError" },
    actions = { "play", "pause", "seek" },
    defaults = { muted = false, loop = false, autoplay = false, controls = true, resizeMode = "contain" },
    validate = function(spec)
        if spec.source == nil then
            return "needs a source"
        end
    end,
})

--- A sound, with no picture and no player of its own.
---
--- What draws a player is the tree, since nothing about a play button, a scrubber or a time is the
--- platform's to decide. This carries the sound: it is told whether it should be playing and where to be,
--- and it reports where it has got to and how long the whole thing is.
---
--- A platform may refuse to play at all — a browser will not start a sound a person did not ask for, and
--- a file may be one nothing can open — and it says so through `onError` rather than staying silent with
--- a play button that does nothing.
---
--- Moving to a moment is `seek`, asked through a ref, since it is a command rather than a state: a prop
--- carrying a moment is sent only when it differs, and a reader dragging back to one is still asking.
M.Audio = support.host("audio", {
    natural = { size = { width = 0, height = 0 } },
    props = { "source", "playing", "loop", "volume", "rate" },
    events = { "onProgress", "onReady", "onEnd", "onError" },
    actions = { "seek" },
    defaults = { playing = false, loop = false, volume = 1, rate = 1 },
    validate = function(spec)
        if spec.source == nil then
            return "needs a source"
        end
    end,
})

local FACING = { "back", "front" }

--- What the camera sees, drawn while it is on screen and let go when it leaves.
---
--- Asking is mounting one and letting go is unmounting it, so nothing keeps a camera running behind a
--- screen a reader has left. The permission each platform requires is asked for the first time one is
--- mounted, and a reader who refuses is reported through `onError` rather than left looking at a black
--- box. A filter is drawn over the preview and written into what is captured, so what a reader sees
--- before they take a picture is the picture they get.
---
--- What it captures is reported rather than answered, since a photo is taken over several frames on all
--- three: `capturePhoto`, `startRecording` and `stopRecording` are asked for through a ref, and what they
--- produced arrives at `onCapture` and `onRecord` as a file the tree can show.
---
--- A camera draws and takes pictures, and the microphone is a permission of its own on every platform, so
--- one that will record sound as well says `audio` and is the only one a reader is asked about it for.
M.Camera = support.host("camera", {
    natural = { size = { height = 320 } },
    props = { "facing", "zoom", "torch", "filter", "audio" },
    events = { "onReady", "onError", "onCapture", "onRecord" },
    actions = { "capturePhoto", "startRecording", "stopRecording" },
    defaults = { facing = "back", zoom = 1, torch = false, audio = false },
    validate = function(spec)
        if not support.oneOf(spec.facing, FACING) then
            return support.expected("facing", spec.facing, FACING)
        end

        if type(spec.zoom) ~= "number" or spec.zoom < 1 then
            return "zoom is how far in the camera is, which is at least 1, got " .. tostring(spec.zoom)
        end
    end,
})

--- A sound being recorded, which has nothing to draw and is told whether it should be running.
---
--- It is the microphone on its own, since a camera records its own sound: this is what a voice note, a
--- dictation or a message recorded without a picture is made of. Stopping it is what produces the file,
--- which arrives at `onFinish`.
---
--- Being told to record and recording are two moments, since the microphone has to be asked for and a
--- reader may be looking at a permission sheet in between: `onReady` is the one that says it is running.
M.Recorder = support.host("recorder", {
    natural = { size = { width = 0, height = 0 } },
    props = { "recording" },
    events = { "onReady", "onFinish", "onError", "onProgress" },
    defaults = { recording = false },
})

--- A page drawn by the platform's own browser, which reports both ends of every load.
---
--- A page takes as long as a page takes, so a screen that draws a spinner over one needs to be told when
--- it started and when it finished, and told rather than left waiting when it cannot be loaded at all.
M.WebView = support.host("webview", {
    natural = { size = { height = 240 } },
    props = { "url", "html", "scrollEnabled", "javaScriptEnabled" },
    events = { "onWillLoad", "onLoad", "onError" },
    defaults = { scrollEnabled = true, javaScriptEnabled = true },
    validate = function(spec)
        if spec.url == nil and spec.html == nil then
            return "needs a url or html"
        end
    end,
})

return M
