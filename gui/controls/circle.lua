local component = require("gui.component")
local progress = require("gui.controls.progress")
local theme = require("gui.controls.theme")

--- A progress drawn round, which is the straight one along a different path.
---
--- It is a kind of its own rather than a shape of the straight one, because neither phone draws one: what
--- a system draws round is a spinner, which says something is happening rather than how much is done. A
--- kind no platform draws carries the entry it is drawn with, so every control theme has it without
--- having been written for it — including the ones that shipped before it existed.
theme.kind("progresscircle", {
    parts = { "track", "fill" },
    default = {
        metrics = { thickness = 4, circle = 40 },
        paint = { track = { rest = "surfaceVariant" }, fill = { rest = "primary" } },
        motion = { duration = 200 },
        press = "none",
    },
})

return component.define({
    name = "DrawnProgressCircle",

    render = function(self)
        local given = { round = true }

        for key, value in pairs(self.props) do
            given[key] = value
        end

        return progress(given)
    end,
})
