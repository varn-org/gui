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
    props = { "source", "resizeMode", "placeholder", "tint" },
    events = { "onLayout" },
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

M.Icon = support.host("icon", {
    natural = { size = function(props) return { width = props.size, height = props.size } end },
    props = { "name", "family", "size", "color" },
    defaults = { size = 24 },
    validate = function(spec)
        if spec.name == nil then
            return "needs a name"
        end
    end,
})

M.Video = support.host("video", {
    props = { "source", "poster", "muted", "loop", "autoplay", "controls", "resizeMode", "volume", "rate" },
    events = { "onEnd" },
    defaults = { muted = false, loop = false, autoplay = false, controls = true, resizeMode = "contain" },
    validate = function(spec)
        if spec.source == nil then
            return "needs a source"
        end
    end,
})

M.WebView = support.host("webview", {
    props = { "url", "html", "scrollEnabled", "javaScriptEnabled" },
    events = {},
    defaults = { scrollEnabled = true, javaScriptEnabled = true },
    validate = function(spec)
        if spec.url == nil and spec.html == nil then
            return "needs a url or html"
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

return M
