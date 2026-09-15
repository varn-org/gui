local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- A radio drawn by the engine, which is a ring with a dot that grows inside it.
---
--- The dot is always there and is scaled to nothing when the radio is not chosen, since what a renderer
--- animates is the transform: built only when it is chosen it would appear at full size rather than
--- arrive, and every radio in a group would flick rather than move.
return component.define({
    name = "DrawnRadio",
    state = { pressed = false, hovered = false, focused = false },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            on = props.selected == true,
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local size = theme:metric("radio", "size")
        local dot = theme:metric("radio", "dot")
        local moves = parts.motion(theme, "radio")

        local beside = {}

        if ring ~= nil then
            beside[#beside + 1] = ring
        end

        if props.label ~= nil then
            beside[1] = Text {
                key = "label",
                text = props.label,
                style = { color = parts.paint(theme, "radio", "label", about) },
            }
        end

        local ring = parts.ring(theme, about, 999)

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel or props.label,
            accessibilityRole = "radio",
            accessibilityState = { checked = about.on, disabled = about.disabled },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    gap = theme:metric("radio", "gap"),
                    minHeight = theme:metric("radio", "touch"),
                },
                props.style,
            },
            onPress = function()
                if props.onSelect ~= nil then
                    props.onSelect(props.value)
                end
            end,
            onKeyDown = function(key)
                if parts.chooses(key.key) then
                    if props.onSelect ~= nil then
                        props.onSelect(props.value)
                    end
                end
            end,
            onPressIn = function() self:setState({ pressed = true }) end,
            onPressOut = function() self:setState({ pressed = false }) end,
            onHoverIn = function() self:setState({ hovered = true }) end,
            onHoverOut = function() self:setState({ hovered = false }) end,
            focusable = true,
            onFocus = function() self:setState({ focused = true }) end,
            onBlur = function() self:setState({ focused = false }) end,

            View {
                key = "ring",
                transition = moves,
                style = {
                    width = size,
                    height = size,
                    radius = 999,
                    border = theme:metric("radio", "border"),
                    borderColor = parts.paint(theme, "radio", "ring", about),
                    align = "center",
                    justify = "center",
                },

                View {
                    key = "dot",
                    transition = moves,
                    style = {
                        width = dot,
                        height = dot,
                        radius = 999,
                        background = parts.paint(theme, "radio", "dot", about),
                        opacity = about.on and 1 or 0,
                        transform = { scale = about.on and 1 or 0.2 },
                    },
                },
            },

            table.unpack(beside),
        }
    end,
})
