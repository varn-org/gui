local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local M = {}

local View = structure.View
local Text = content.Text

--- A panel holding something, which is chrome and nothing else.
---
--- Every design draws one differently and none of them draws anything else about it, so what separates a
--- card on Material from one on Apple's system is entirely the corner, the ground and whether the edge is
--- a shadow or an outline.
theme.kind("card", { parts = { "container", "outline" } })

--- The words that appear beside something a pointer has rested on.
theme.kind("tooltip", { parts = { "container", "label" } })

M.Card = component.define({
    name = "DrawnCard",
    state = { pressed = false, hovered = false },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local about = { pressed = self.state.pressed, hovered = self.state.hovered }

        local painted = {
            radius = wearing:metric("card", "radius"),
            background = parts.paint(wearing, "card", "container", about),
            padding = props.padded and wearing:metric("card", "padding") or nil,
        }

        if props.outlined then
            painted.border = wearing:metric("card", "border")
            painted.borderColor = parts.paint(wearing, "card", "outline", {})
        else
            painted.shadow = props.elevation or wearing:metric("card", "elevation")
        end

        if props.onPress == nil then
            return View {
                accessibilityLabel = props.accessibilityLabel,
                testID = props.testID,
                style = { painted, props.style },
                table.unpack(self.children),
            }
        end

        return Pressable {
            accessibilityLabel = props.accessibilityLabel,
            accessibilityRole = "button",
            testID = props.testID,
            focusable = true,
            transition = parts.motion(wearing, "card"),
            style = { painted, props.style },
            onPress = props.onPress,
            onKeyDown = function(key)
                if parts.chooses(key.key) then
                    props.onPress()
                end
            end,
            onPressIn = function() self:setState({ pressed = true }) end,
            onPressOut = function() self:setState({ pressed = false }) end,
            onHoverIn = function() self:setState({ hovered = true }) end,
            onHoverOut = function() self:setState({ hovered = false }) end,

            table.unpack(self.children),
        }
    end,
})

M.Tooltip = component.define({
    name = "DrawnTooltip",

    render = function(self)
        local props = self.props
        local wearing = props.theme

        return Text {
            accessibilityRole = "none",
            accessibilityLabel = props.text,
            testID = props.testID,
            text = props.text,
            transition = parts.motion(wearing, "tooltip"),
            style = {
                {
                    alignSelf = "start",
                    opacity = props.visible == false and 0 or 1,
                    radius = wearing:metric("tooltip", "radius"),
                    paddingHorizontal = wearing:metric("tooltip", "paddingHorizontal"),
                    paddingVertical = wearing:metric("tooltip", "paddingVertical"),
                    background = parts.paint(wearing, "tooltip", "container", {}),
                    color = parts.paint(wearing, "tooltip", "label", {}),
                    fontSize = "footnote",
                    textAlign = "center",
                },
                props.style,
            },
        }
    end,
})

return M
