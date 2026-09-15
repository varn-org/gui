local component = require("gui.component")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local content = require("gui.components.content")
local structure = require("gui.components.structure")

local View = structure.View

--- The colours a picker that is not the system's own offers, which is a palette rather than a wheel.
---
--- A colour chosen from a grid is a colour somebody designed, and a colour chosen from a wheel is any of
--- sixteen million. A screen asking a reader to mark something wants the first.
local SWATCHES = {
    "#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3",
    "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39",
    "#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#795548", "#607d8b",
}

return component.define({
    name = "DrawnSwatches",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local size = wearing:metric("swatches", "size")
        local touch = wearing:metric("swatches", "touch")
        local given = SWATCHES
        local marks = {}

        for index = 1, #given do
            local colour = given[index]
            local on = colour == props.value
            local about = { on = on, disabled = props.disabled == true }

            marks[index] = Pressable {
                key = colour,
                disabled = props.disabled,
                accessibilityLabel = colour,
                accessibilityRole = "radio",
                accessibilityState = { checked = on, disabled = about.disabled },
                focusable = true,
                style = { width = touch, height = touch, align = "center", justify = "center" },
                onPress = function()
                    if props.onChange ~= nil then
                        props.onChange(colour)
                    end
                end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) and props.onChange ~= nil then
                        props.onChange(colour)
                    end
                end,
                onFocus = function() self:setState({ focused = colour }) end,
                onBlur = function() self:setState({ focused = component.none }) end,

                View {
                    key = "swatch",
                    transition = parts.motion(wearing, "swatches"),
                    style = {
                        width = size,
                        height = size,
                        radius = wearing:metric("swatches", "radius"),
                        background = props.disabled
                            and parts.paint(wearing, "swatches", "swatch", about)
                            or colour,
                        border = wearing:metric("swatches", "border"),
                        borderColor = parts.paint(wearing, "swatches", "outline", about),
                        align = "center",
                        justify = "center",
                    },

                    on and content.Canvas {
                        style = { width = size * 0.6, height = size * 0.6 },
                        commands = parts.mark("tick", size * 0.6,
                            parts.paint(wearing, "swatches", "mark", about),
                            wearing:metric("swatches", "mark")),
                    } or false,
                },
            }
        end

        return View {
            accessibilityRole = "none",
            accessibilityLabel = props.accessibilityLabel,
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    wrap = true,
                    gap = wearing:metric("swatches", "gap"),
                },
                props.style,
            },

            table.unpack(marks),
        }
    end,
})
