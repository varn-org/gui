local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local presence = require("gui.components.presence")
local structure = require("gui.components.structure")

local View = structure.View
local Portal = structure.Portal
local Text = content.Text

--- A select drawn by the engine, which is a field showing what is chosen and a list of what else there is.
---
--- This is the one control where what the platform draws is three different controls: a wheel on one
--- system, a dropped menu on another and a dialogue on the third, each behaving differently and none of
--- them looking like the others. Drawn, it is one control that behaves the same everywhere and is shaped
--- by the control theme — a menu under the field on Material, a sheet from the bottom edge on Apple's.
return component.define({
    name = "DrawnSelect",
    state = { open = false, pressed = false, focused = false },

    --- Answers what is chosen, which is the entry whose value the caller wrote rather than its position.
    chosen = function(self)
        local options = self.props.options or {}

        for index = 1, #options do
            if options[index].value == self.props.value then
                return options[index]
            end
        end

        return nil
    end,

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            focused = self.state.open or self.state.focused,
        }

        local chosen = self:chosen()
        local options = props.options or {}
        local said = chosen ~= nil and chosen.label or props.placeholder or ""

        local rows = {}

        for index = 1, #options do
            local entry = options[index]
            local on = entry.value == props.value

            rows[index] = Pressable {
                key = tostring(entry.value),
                accessibilityLabel = entry.label,
                accessibilityRole = "listitem",
                accessibilityState = { selected = on },
                style = {
                    minHeight = theme:metric("select", "option"),
                    justify = "center",
                    paddingHorizontal = theme:metric("select", "paddingHorizontal"),
                },
                onPress = function()
                    self:setState({ open = false })

                    if props.onChange ~= nil and not on then
                        props.onChange(entry.value)
                    end
                end,

                Text {
                    text = entry.label,
                    numberOfLines = 1,
                    style = {
                        color = parts.paint(theme, "select", "option", { on = on }),
                        fontWeight = on and "600" or "400",
                    },
                },
            }
        end

        return View { style = props.style,
            Pressable {
                key = "field",
                disabled = props.disabled,
                accessibilityLabel = props.accessibilityLabel or props.title or said,
                accessibilityRole = "button",
                accessibilityState = { expanded = self.state.open, disabled = about.disabled },
                testID = props.testID,
                transition = parts.motion(theme, "select"),
                style = {
                    direction = "row",
                    align = "center",
                    justify = "space-between",
                    gap = theme:metric("select", "gap"),
                    minHeight = theme:metric("select", "height"),
                    paddingHorizontal = theme:metric("select", "paddingHorizontal"),
                    radius = theme:metric("select", "radius"),
                    background = parts.paint(theme, "select", "field", about),
                    border = theme:metric("select", "border"),
                    borderColor = parts.paint(theme, "select", "indicator", about),
                },
                onPress = function() self:setState({ open = true }) end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) or key.key == "ArrowDown" then
                        self:setState({ open = true })
                        return
                    end

                    if key.key == "Escape" then
                        self:setState({ open = false })
                    end
                end,
                focusable = true,
                onFocus = function() self:setState({ focused = true }) end,
                onBlur = function() self:setState({ focused = false }) end,
                onPressIn = function() self:setState({ pressed = true }) end,
                onPressOut = function() self:setState({ pressed = false }) end,

                Text {
                    key = "label",
                    text = said,
                    numberOfLines = 1,
                    style = {
                        grow = 1,
                        color = chosen ~= nil
                            and parts.paint(theme, "select", "label", about)
                            or parts.paint(theme, "select", "indicator", about),
                    },
                },

                content.Canvas {
                    key = "indicator",
                    style = { width = 20, height = 20 },
                    commands = parts.mark("chevron", 20, parts.paint(theme, "select", "indicator", about), 2),
                },
            },

            Portal {
                key = "choices",

                presence.Presence {
                    visible = self.state.open,
                    enter = { opacity = 0, transform = { translateY = 24 } },
                    transition = parts.motion(theme, "select"),

                    Pressable {
                        key = "scrim",
                        accessibilityLabel = "Close",
                        style = {
                            position = "absolute",
                            left = 0,
                            right = 0,
                            top = 0,
                            bottom = 0,
                            background = "overlay",
                        },
                        onPress = function() self:setState({ open = false }) end,
                    },

                    View {
                        key = "menu",
                        accessibilityRole = "list",
                        style = {
                            position = "absolute",
                            left = 16,
                            right = 16,
                            bottom = 16,
                            paddingVertical = 8,
                            radius = theme:metric("select", "menuRadius"),
                            background = parts.paint(theme, "select", "menu", {}),
                            shadow = "lg",
                        },

                        table.unpack(rows),
                    },
                },
            },
        }
    end,
})
