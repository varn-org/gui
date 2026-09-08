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

M.Text = support.host("text", {
    style = BODY,
    props = { "text", "numberOfLines" },
    events = { "onPress", "onLongPress", "onLayout" },
    validate = function(spec)
        if spec.text == nil and #spec == 0 then
            return "needs text, either as the text prop or as its child"
        end
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
    end,
})

M.Image = support.host("image", {
    natural = { size = { height = 160 } },
    props = { "source", "resizeMode", "placeholder", "tint" },
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

M.Canvas = support.host("canvas", {
    props = { "commands" },
    events = { "onLayout" },
    validate = function(spec)
        if type(spec.commands) ~= "table" then
            return "commands must be a list of drawing instructions"
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

M.Video = support.host("video", {
    natural = { size = { height = 200 } },
    props = { "source", "poster", "muted", "loop", "autoplay", "controls", "resizeMode", "volume", "rate" },
    events = { "onEnd" },
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
M.Audio = support.host("audio", {
    natural = { size = { width = 0, height = 0 } },
    props = { "source", "playing", "loop", "volume", "rate", "position" },
    events = { "onProgress", "onReady", "onEnd" },
    defaults = { playing = false, loop = false, volume = 1, rate = 1 },
    validate = function(spec)
        if spec.source == nil then
            return "needs a source"
        end
    end,
})

M.WebView = support.host("webview", {
    natural = { size = { height = 240 } },
    props = { "url", "html", "scrollEnabled", "javaScriptEnabled" },
    events = {},
    defaults = { scrollEnabled = true, javaScriptEnabled = true },
    validate = function(spec)
        if spec.url == nil and spec.html == nil then
            return "needs a url or html"
        end
    end,
})

return M
