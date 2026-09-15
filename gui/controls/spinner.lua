local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")

--- What each size measures, which is what the platforms themselves draw a spinner at.
local SIZES = { small = 20, medium = 32, large = 44 }

--- A spinner drawn by the engine, which is an arc that turns.
---
--- The arc is redrawn rather than a box rotated, since what turns is a part of a circle and a box cannot
--- be one. How much of the circle it covers and how fast it goes round are the control theme's.
return component.define({
    name = "DrawnSpinner",
    state = { at = 0 },

    onMount = function(self)
        self:every(60, function(instance)
            if instance.props.animating == false then
                return
            end

            instance:setState({ at = (instance.state.at + 0.06) % 1 })
        end)
    end,

    render = function(self)
        local props = self.props
        local theme = props.theme
        local size = SIZES[props.size] or SIZES.medium
        local thickness = theme:metric("spinner", "thickness")
        local sweep = theme:metric("spinner", "sweep")
        local painted = props.color or parts.paint(theme, "spinner", "arc", {})
        local from = self.state.at * 360

        return content.Canvas {
            accessibilityRole = "progressbar",
            accessibilityLabel = props.accessibilityLabel,
            testID = props.testID,
            style = { { width = size, height = size }, props.style },
            commands = parts.arc(size, thickness, painted, from, from + sweep),
        }
    end,
})
