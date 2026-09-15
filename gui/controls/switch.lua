local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View

--- A switch drawn by the engine, which is a track with a thumb that travels along it.
---
--- The thumb is moved rather than laid out where it lands, since what a renderer animates is the
--- transform and the opacity: laid out at its new place it would arrive there between one frame and the
--- next. The mark inside the thumb is what Material 3 draws on a switch that is on and the other two
--- leave out, which a mark of no width says.
return component.define({
    name = "DrawnSwitch",
    state = { pressed = false, hovered = false, focused = false },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            on = props.value == true,
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local width = theme:metric("switch", "width")
        local height = theme:metric("switch", "height")
        local inset = theme:metric("switch", "inset")
        local thumb = about.on and theme:metric("switch", "thumbOn") or theme:metric("switch", "thumb")
        local mark = theme:metric("switch", "mark")
        local moves = parts.motion(theme, "switch")

        local inside = {}

        if mark > 0 and about.on then
            local size = thumb * 0.62

            inside[1] = content.Canvas {
                key = "mark",
                style = { width = size, height = size },
                commands = parts.mark("tick", size, parts.paint(theme, "switch", "mark", about), mark),
            }
        end

        local ring = parts.ring(theme, about, theme:metric("switch", "radius"))

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel,
            accessibilityRole = "switch",
            accessibilityState = { checked = about.on, disabled = about.disabled },
            testID = props.testID,
            style = { parts.touch(theme, "switch", width), props.style },
            onPress = function()
                if props.onChange ~= nil then
                    props.onChange(not about.on)
                end
            end,
            onKeyDown = function(key)
                if parts.chooses(key.key) then
                    if props.onChange ~= nil then
                        props.onChange(not about.on)
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
                key = "track",
                transition = moves,
                style = {
                    width = width,
                    height = height,
                    radius = theme:metric("switch", "radius"),
                    background = parts.paint(theme, "switch", "track", about),
                    border = theme:metric("switch", "border"),
                    borderColor = parts.paint(theme, "switch", "track", { on = true, disabled = about.disabled }),
                    justify = "center",
                },

                View {
                    key = "thumb",
                    transition = moves,
                    style = {
                        position = "absolute",
                        left = inset,
                        width = thumb,
                        height = thumb,
                        radius = 999,
                        background = parts.paint(theme, "switch", "thumb", about),
                        shadow = theme:metric("switch", "shadow"),
                        align = "center",
                        justify = "center",
                        transform = { translateX = about.on and width - thumb - inset * 2 or 0 },
                    },

                    table.unpack(inside),
                },
            },

            ring or false,
        }
    end,
})
