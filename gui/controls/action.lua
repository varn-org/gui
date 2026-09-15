local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local theme = require("gui.controls.theme")

local Text = content.Text

--- The three sizes Material publishes one at, and how large the icon inside each is drawn.
local SIZES = { small = { box = 40, icon = 24 }, medium = { box = 56, icon = 24 }, large = { box = 96, icon = 36 } }

--- A button that floats over the screen rather than sitting in it.
---
--- Apple's system has no such control, and a design that refused to draw one would be faithful and
--- unusable — an application built around one would have a hole in it under `cupertino`. It is drawn as
--- a round filled button there instead, which is the nearest thing that system does have.
theme.kind("action", {
    parts = { "container", "icon", "label", "ripple" },
    default = {
        metrics = { radius = "lg", elevation = "md", gap = 8, paddingHorizontal = 16, ripple = 0.12 },
        paint = {
            container = { rest = "secondaryContainer", pressed = "primaryHover", disabled = "disabledSurface" },
            icon = { rest = "onSecondaryContainer", disabled = "disabledText" },
            label = { rest = "onSecondaryContainer", disabled = "disabledText" },
            ripple = { rest = "onSecondaryContainer" },
        },
        motion = { duration = 200 },
        press = "ripple",
    },
})

return component.define({
    name = "DrawnAction",
    state = { pressed = false, hovered = false, focused = false },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local about = {
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local size = SIZES[props.size] or SIZES.medium
        local spread = props.label ~= nil
        local radius = wearing:metric("action", "radius")

        local inside = {}

        if props.icon ~= nil then
            inside[#inside + 1] = content.Icon {
                key = "icon",
                name = props.icon,
                size = size.icon,
                color = parts.paint(wearing, "action", "icon", about),
            }
        end

        if spread then
            inside[#inside + 1] = Text {
                key = "label",
                text = props.label,
                numberOfLines = 1,
                style = {
                    color = parts.paint(wearing, "action", "label", about),
                    fontWeight = "600",
                },
            }
        end

        local ring = parts.ring(wearing, about, radius)

        if ring ~= nil then
            inside[#inside + 1] = ring
        end

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel or props.label or props.icon,
            accessibilityRole = "button",
            accessibilityState = { disabled = about.disabled },
            testID = props.testID,
            focusable = true,
            transition = parts.motion(wearing, "action"),
            style = {
                {
                    height = size.box,
                    width = spread and nil or size.box,
                    minWidth = spread and size.box or nil,
                    paddingHorizontal = spread and wearing:metric("action", "paddingHorizontal") or 0,
                    gap = wearing:metric("action", "gap"),
                    direction = "row",
                    align = "center",
                    justify = "center",
                    alignSelf = "start",
                    radius = radius,
                    background = parts.paint(wearing, "action", "container", about),
                    shadow = wearing:metric("action", "elevation"),
                    opacity = about.disabled and 0.5 or 1,
                },
                props.style,
            },
            onPress = props.onPress,
            onKeyDown = function(key)
                if parts.chooses(key.key) and props.onPress ~= nil then
                    props.onPress()
                end
            end,
            onFocus = function() self:setState({ focused = true }) end,
            onBlur = function() self:setState({ focused = false }) end,
            onPressIn = function() self:setState({ pressed = true }) end,
            onPressOut = function() self:setState({ pressed = false }) end,
            onHoverIn = function() self:setState({ hovered = true }) end,
            onHoverOut = function() self:setState({ hovered = false }) end,

            table.unpack(inside),
        }
    end,
})
