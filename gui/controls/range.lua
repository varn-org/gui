local component = require("gui.component")
local slider = require("gui.controls.slider")
local theme = require("gui.controls.theme")

--- A slider with two thumbs, which is the one-thumb slider drawn with a span instead of a value.
---
--- It is a kind of its own because no platform draws one, so a control theme carries it without having
--- been written for it. What it is drawn at is the slider's own, since the two are one control with two
--- thumbs rather than two controls.
theme.kind("rangeslider", {
    parts = { "track", "fill", "thumb", "tick" },
    default = {
        metrics = { track = 4, touch = 48, radius = "pill", thumbWidth = 20, thumbHeight = 20, gap = 0, tick = 2 },
        paint = {
            track = { rest = "disabledOutline", disabled = "disabledSurface" },
            fill = { rest = "primary", disabled = "disabledOutline" },
            thumb = { rest = "primary", disabled = "disabledOutline" },
            tick = { rest = "onPrimary" },
        },
        motion = { duration = 100 },
        press = "none",
    },
})

return component.define({
    name = "DrawnRangeSlider",

    render = function(self)
        local given = { kind = "rangeslider" }

        for key, value in pairs(self.props) do
            given[key] = value
        end

        return slider(given)
    end,
})
