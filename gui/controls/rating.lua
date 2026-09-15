local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View

--- A rating drawn by the engine, which is a row of marks filled up to the value.
---
--- Each mark is a path rather than a glyph, so a rating is the same shape at any size and on any
--- platform rather than whatever star the system font happens to carry.
return component.define({
    name = "DrawnRating",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local disabled = props.disabled == true
        local count = props.count or 5
        local value = props.value or 0
        local size = theme:metric("rating", "size")
        local editable = props.editable ~= false and not disabled

        local marks = {}

        for index = 1, count do
            local on = index <= value
            local about = { on = on, disabled = disabled }
            local paint = parts.paint(theme, "rating", "mark", about)

            local drawn = content.Canvas {
                key = "mark",
                style = { width = size, height = size },
                commands = parts.star(size, paint, on),
            }

            if not editable then
                marks[index] = View { key = tostring(index), style = { width = size, height = size }, drawn }
            else
                -- The press is taken through a box the size of a finger, which is larger than a mark
                -- is drawn at in any of the designs.
                marks[index] = Pressable {
                    key = tostring(index),
                    accessibilityLabel = tostring(index),
                    accessibilityRole = "button",
                    style = {
                        width = math.max(size, theme:metric("rating", "touch")),
                        height = theme:metric("rating", "touch"),
                        align = "center",
                        justify = "center",
                    },
                    focusable = true,
                    onFocus = function() self:setState({ focused = index }) end,
                    onBlur = function() self:setState({ focused = component.none }) end,
                    onPress = function()
                        if props.onChange ~= nil then
                            props.onChange(index)
                        end
                    end,
                    onKeyDown = function(key)
                        if props.onChange == nil then
                            return
                        end

                        if parts.chooses(key.key) then
                            props.onChange(index)
                            return
                        end

                        local nudge = parts.nudges(key.key)

                        if type(nudge) == "number" then
                            props.onChange(math.max(0, math.min(count, value + nudge)))
                        end
                    end,

                    drawn,
                }
            end
        end

        return View {
            accessibilityRole = "none",
            accessibilityLabel = props.accessibilityLabel,
            accessibilityValue = { now = value, least = 0, most = count },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    alignSelf = "start",
                    gap = theme:metric("rating", "gap"),
                },
                props.style,
            },

            table.unpack(marks),
        }
    end,
})
