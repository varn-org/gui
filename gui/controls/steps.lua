local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local View = structure.View
local Text = content.Text

--- The numbered steps that say how far through something a reader is, across the top or down the side.
---
--- A step is one of three things and never two: done, the one they are on, or still to come. The rule
--- between two steps is drawn as done up to the one they are on, which is what makes the row read as a
--- path rather than as a row of circles.
theme.kind("steps", {
    parts = { "marker", "number", "label", "rule" },
    default = {
        metrics = { size = 28, gap = 8, rule = 2, touch = 44 },
        paint = {
            marker = { rest = "surfaceVariant", on = "primary", disabled = "success" },
            number = { rest = "onSurfaceVariant", on = "onPrimary", disabled = "onPrimary" },
            label = { rest = "textMuted", on = "text", disabled = "text" },
            rule = { rest = "surfaceVariant", on = "primary" },
        },
        motion = { duration = 200 },
        press = "none",
    },
})

return component.define({
    name = "DrawnSteps",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local at = props.step or 1
        local steps = props.steps or {}
        local down = props.direction == "vertical"
        local size = wearing:metric("steps", "size")
        local rule = wearing:metric("steps", "rule")

        local built = {}

        for index = 1, #steps do
            local entry = steps[index]
            local done = index < at
            local here = index == at

            -- A step already taken is painted as one and reads as a tick rather than as its number.
            local about = { on = here, disabled = done }

            if index > 1 then
                built[#built + 1] = View {
                    key = "rule" .. index,
                    transition = parts.motion(wearing, "steps"),
                    style = {
                        grow = down and 0 or 1,
                        width = down and rule or nil,
                        height = down and 16 or rule,
                        marginLeft = down and (size - rule) / 2 or 0,
                        background = parts.paint(wearing, "steps", "rule", { on = index <= at }),
                    },
                }
            end

            local inside = done
                and content.Canvas {
                    style = { width = size * 0.6, height = size * 0.6 },
                    commands = parts.mark("tick", size * 0.6,
                        parts.paint(wearing, "steps", "number", about), 2),
                }
                or Text {
                    text = tostring(index),
                    style = {
                        color = parts.paint(wearing, "steps", "number", about),
                        fontSize = "footnote",
                        fontWeight = "700",
                    },
                }

            local marker = View {
                key = "marker",
                transition = parts.motion(wearing, "steps"),
                style = {
                    width = size,
                    height = size,
                    radius = 999,
                    align = "center",
                    justify = "center",
                    background = parts.paint(wearing, "steps", "marker", about),
                },

                inside,
            }

            local words = entry.label ~= nil and Text {
                key = "label",
                text = entry.label,
                numberOfLines = 1,
                style = {
                    color = parts.paint(wearing, "steps", "label", about),
                    fontSize = "footnote",
                    fontWeight = here and "600" or "400",
                },
            } or false

            built[#built + 1] = Pressable {
                key = tostring(entry.key or index),
                disabled = props.onChange == nil,
                accessibilityLabel = entry.label or ("Step " .. index),
                accessibilityRole = "tab",
                accessibilityState = { selected = here },
                focusable = props.onChange ~= nil,
                onFocus = function() self:setState({ focused = index }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                style = {
                    direction = down and "row" or "column",
                    align = "center",
                    gap = wearing:metric("steps", "gap"),
                    minWidth = wearing:metric("steps", "touch"),
                    minHeight = wearing:metric("steps", "touch"),
                },
                onPress = function()
                    if props.onChange ~= nil then
                        props.onChange(index)
                    end
                end,
                onKeyDown = function(held)
                    if props.onChange == nil then
                        return
                    end

                    local step = parts.steps(held.key, down and "vertical" or "horizontal")

                    if parts.chooses(held.key) then
                        props.onChange(index)
                        return
                    end

                    if type(step) == "number" then
                        props.onChange(math.max(1, math.min(#steps, index + step)))
                    end
                end,

                marker,
                words,
            }
        end

        return View {
            accessibilityRole = "none",
            accessibilityValue = { now = at, least = 1, most = #steps },
            testID = props.testID,
            style = {
                {
                    direction = down and "column" or "row",
                    align = down and "start" or "center",
                    gap = wearing:metric("steps", "gap"),
                },
                props.style,
            },

            table.unpack(built),
        }
    end,
})
