local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- A checkbox drawn by the engine, which is a box, what is inside it, and the words beside it.
---
--- The mark is a path rather than a glyph, so it is the same shape on every platform and scales with the
--- box rather than with whatever face the system happens to draw a tick in. A box that is neither on nor
--- off draws a bar instead, which is what the state the declaration already carries means.
return component.define({
    name = "DrawnCheckbox",
    state = { pressed = false, hovered = false, focused = false },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            on = props.value == true or props.indeterminate == true,
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local size = theme:metric("checkbox", "size")
        local filled = props.value == true or props.indeterminate == true
        local moves = parts.motion(theme, "checkbox")
        local painted = parts.paint(theme, "checkbox", "box", about)

        local inside = {}

        if filled then
            local drawn = props.indeterminate and "dash" or "tick"

            inside[1] = content.Canvas {
                key = "mark",
                style = { width = size, height = size },
                commands = parts.mark(drawn, size, parts.paint(theme, "checkbox", "mark", about),
                    theme:metric("checkbox", "mark")),
            }
        end

        local beside = {}

        if ring ~= nil then
            beside[#beside + 1] = ring
        end

        if props.label ~= nil then
            beside[1] = Text {
                key = "label",
                text = props.label,
                style = { color = parts.paint(theme, "checkbox", "label", about) },
            }
        end

        local ring = parts.ring(theme, about, theme:metric("checkbox", "radius"))

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel or props.label,
            accessibilityRole = "checkbox",
            accessibilityState = { checked = props.value == true, disabled = about.disabled },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    gap = theme:metric("checkbox", "gap"),
                    minHeight = theme:metric("checkbox", "touch"),
                },
                props.style,
            },
            onPress = function()
                if props.onChange ~= nil then
                    props.onChange(not (props.value == true))
                end
            end,
            onKeyDown = function(key)
                if parts.chooses(key.key) then
                    if props.onChange ~= nil then
                        props.onChange(not (props.value == true))
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
                key = "box",
                transition = moves,
                style = {
                    width = size,
                    height = size,
                    radius = theme:metric("checkbox", "radius"),
                    border = filled and 0 or theme:metric("checkbox", "border"),
                    borderColor = painted,
                    background = filled and painted or "transparent",
                    align = "center",
                    justify = "center",
                },

                table.unpack(inside),
            },

            table.unpack(beside),
        }
    end,
})
