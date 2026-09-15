local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local structure = require("gui.components.structure")

local View = structure.View

--- How much of the track an indeterminate band covers, which every design draws at about a third.
local BAND = 0.35

--- A progress bar drawn by the engine, straight or round.
---
--- A circular progress is the same control rather than a second one: the value is the same number and
--- what changes is the path it is drawn along, so a design that draws one draws both. The round one is a
--- run of straight lines rather than a rotating box, which is the one shape every renderer agrees on.
return component.define({
    name = "DrawnProgress",
    state = { at = 0 },

    onMount = function(self)
        if self.props.indeterminate then
            self:every(60, function(instance)
                instance:setState({ at = (instance.state.at + 0.02) % 1 })
            end)
        end
    end,

    render = function(self)
        local props = self.props
        local theme = props.theme
        local kind = props.round and "progresscircle" or "progress"
        local thickness = props.thickness or theme:metric(kind, "thickness")
        local value = math.max(0, math.min(1, props.value or 0))
        local painted = props.color or parts.paint(theme, kind, "fill", {})
        local track = props.trackColor or parts.paint(theme, kind, "track", {})

        if props.round then
            local size = theme:metric(kind, "circle")
            local shown = props.indeterminate and BAND or value
            local from = props.indeterminate and self.state.at * 360 or -90

            return View {
                accessibilityRole = "progressbar",
                accessibilityLabel = props.accessibilityLabel,
                accessibilityValue = props.indeterminate and nil or { now = value, least = 0, most = 1 },
                testID = props.testID,
                style = { { width = size, height = size }, props.style },

                content.Canvas {
                    key = "track",
                    style = { position = "absolute", left = 0, top = 0, width = size, height = size },
                    commands = parts.arc(size, thickness, track, 0, 360),
                },

                content.Canvas {
                    key = "fill",
                    style = { position = "absolute", left = 0, top = 0, width = size, height = size },
                    commands = parts.arc(size, thickness, painted, from, from + shown * 360),
                },
            }
        end

        local band = {}

        if props.indeterminate then
            band.left = string.format("%.1f%%", self.state.at * (1 + BAND) * 100 - BAND * 100)
            band.width = string.format("%.1f%%", BAND * 100)
        else
            band.left = 0
            band.width = string.format("%.1f%%", value * 100)
        end

        return View {
            accessibilityRole = "progressbar",
            accessibilityLabel = props.accessibilityLabel,
            accessibilityValue = props.indeterminate and nil or { now = value, least = 0, most = 1 },
            testID = props.testID,
            style = {
                {
                    height = thickness,
                    radius = thickness / 2,
                    background = track,
                    overflow = "hidden",
                },
                props.style,
            },

            View {
                key = "fill",
                transition = props.indeterminate and false or parts.motion(theme, kind),
                style = {
                    position = "absolute",
                    top = 0,
                    bottom = 0,
                    left = band.left,
                    width = band.width,
                    radius = thickness / 2,
                    background = painted,
                },
            },
        }
    end,
})
