local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- A stepper drawn by the engine, which is two presses either side of what they change.
---
--- A value that is already at the end it is being moved towards is a press that does nothing, so the
--- press is refused rather than answered with the same number: a screen watching `onChange` would
--- otherwise be told the value changed on every press at the end of the range.
return component.define({
    name = "DrawnStepper",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local disabled = props.disabled == true
        local step = props.step or 1
        local value = props.value or 0
        local width = theme:metric("stepper", "valueWidth")

        local function bounded(wanted)
            if props.minimum ~= nil and wanted < props.minimum then
                return nil
            end

            if props.maximum ~= nil and wanted > props.maximum then
                return nil
            end

            return wanted
        end

        local function key(name, mark, wanted)
            local at = bounded(wanted)
            local about = { disabled = disabled or at == nil }

            -- The press is taken through a box the size of a finger, and what is drawn inside it is the
            -- size the design draws it at, which is smaller on every one of them.
            return Pressable {
                key = name,
                disabled = disabled or at == nil,
                accessibilityLabel = name == "less" and "Less" or "More",
                accessibilityRole = "button",
                accessibilityState = { disabled = about.disabled },
                style = {
                    width = math.max(theme:metric("stepper", "button"), theme:metric("stepper", "touch")),
                    height = theme:metric("stepper", "touch"),
                    align = "center",
                    justify = "center",
                },
                focusable = true,
                onFocus = function() self:setState({ focused = name }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                onPress = function()
                    if props.onChange ~= nil and at ~= nil then
                        props.onChange(at)
                    end
                end,
                onKeyDown = function(key)
                    if props.onChange == nil then
                        return
                    end

                    if parts.chooses(key.key) and at ~= nil then
                        props.onChange(at)
                        return
                    end

                    local nudge = parts.nudges(key.key)

                    if nudge == "least" and props.minimum ~= nil then
                        props.onChange(props.minimum)
                        return
                    end

                    if nudge == "most" and props.maximum ~= nil then
                        props.onChange(props.maximum)
                        return
                    end

                    if type(nudge) ~= "number" then
                        return
                    end

                    local wanted = bounded(value + nudge * (props.step or 1))

                    if wanted ~= nil then
                        props.onChange(wanted)
                    end
                end,

                content.Canvas {
                    style = { width = 20, height = 20 },
                    commands = parts.mark(mark, 20, parts.paint(theme, "stepper", "button", about), 2),
                },
            }
        end

        local inside = { key("less", "minus", value - step) }

        if width > 0 then
            inside[#inside + 1] = Text {
                key = "value",
                text = tostring(value),
                numberOfLines = 1,
                style = {
                    width = width,
                    color = parts.paint(theme, "stepper", "value", { disabled = disabled }),
                    textAlign = "center",
                    fontWeight = "600",
                },
            }
        end

        inside[#inside + 1] = key("more", "plus", value + step)

        return View {
            accessibilityRole = "none",
            accessibilityValue = { now = value, least = props.minimum, most = props.maximum },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    alignSelf = "start",
                    gap = theme:metric("stepper", "gap"),
                    height = theme:metric("stepper", "height"),
                    radius = theme:metric("stepper", "radius"),
                    border = theme:metric("stepper", "border"),
                    borderColor = parts.paint(theme, "stepper", "container", { disabled = disabled }),
                    background = theme:metric("stepper", "border") > 0 and "transparent"
                        or parts.paint(theme, "stepper", "container", { disabled = disabled }),
                },
                props.style,
            },

            table.unpack(inside),
        }
    end,
})
