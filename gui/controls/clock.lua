local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- Answers the hour and the minute a written time carries, or noon when it carries none.
local function readTime(value)
    local hour, minute = tostring(value or ""):match("^(%d%d):(%d%d)$")

    if hour == nil then
        return 12, 0
    end

    return tonumber(hour), tonumber(minute)
end

local function written(hour, minute)
    return string.format("%02d:%02d", hour % 24, minute % 60)
end

--- A time drawn as two columns of numbers, which is what a design draws where the system draws a wheel.
---
--- A time is written as `HH:MM` on a twenty-four hour clock, since that is the one way of writing one
--- that means the same thing everywhere, and how it is shown to a reader is the screen's to decide.
return component.define({
    name = "DrawnClock",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local hour, minute = readTime(props.value)
        local step = theme:metric("clock", "minutes")

        local function column(name, count, at, span, said)
            local rows = {}

            for index = 0, count - 1, span do
                local on = index == at
                local about = { on = on }

                rows[#rows + 1] = Pressable {
                    key = name .. index,
                    accessibilityLabel = said(index),
                    accessibilityRole = "button",
                    accessibilityState = { selected = on },
                    focusable = true,
                    transition = parts.motion(theme, "clock"),
                    style = {
                        height = theme:metric("clock", "row"),
                        align = "center",
                        justify = "center",
                        radius = theme:metric("clock", "radius"),
                        background = parts.paint(theme, "clock", "face", about),
                    },
                    onPress = function()
                        if props.onChange ~= nil then
                            props.onChange(name == "hour" and written(index, minute) or written(hour, index))
                        end
                    end,
                    onKeyDown = function(key)
                        if parts.chooses(key.key) and props.onChange ~= nil then
                            props.onChange(name == "hour" and written(index, minute) or written(hour, index))
                        end
                    end,
                    onFocus = function() self:setState({ focused = name .. index }) end,
                    onBlur = function() self:setState({ focused = component.none }) end,

                    Text {
                        text = string.format("%02d", index),
                        style = {
                            color = parts.paint(theme, "clock", "number", about),
                            fontWeight = on and "700" or "400",
                        },
                    },
                }
            end

            return structure.ScrollView {
                key = name,
                style = { width = theme:metric("clock", "column"), height = theme:metric("clock", "size") },
                contentStyle = { gap = 2 },

                table.unpack(rows),
            }
        end

        return View {
            accessibilityRole = "none",
            accessibilityLabel = props.accessibilityLabel,
            accessibilityValue = { text = written(hour, minute) },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    alignSelf = "start",
                    gap = theme:metric("clock", "gap"),
                },
                props.style,
            },

            column("hour", 24, hour, 1, function(index) return index .. " o'clock" end),
            column("minute", 60, minute, step, function(index) return index .. " minutes past" end),
        }
    end,
})
