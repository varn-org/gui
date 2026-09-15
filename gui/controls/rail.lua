local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local View = structure.View
local Text = content.Text

--- The tab bar of a wide screen, which is a column against the leading edge rather than a row along the
--- bottom.
---
--- It takes the same `tabs` a bar takes, so a screen that changes shape with the room it has changes one
--- prop rather than two trees.
theme.kind("rail", {
    parts = { "container", "indicator", "icon", "label" },
    default = {
        metrics = { width = 80, item = 56, indicator = 32, gap = 4, radius = "pill", touch = 48 },
        paint = {
            container = { rest = "surface" },
            indicator = { rest = "surface", on = "secondaryContainer" },
            icon = { rest = "onSurfaceVariant", on = "onSecondaryContainer" },
            label = { rest = "onSurfaceVariant", on = "onSecondaryContainer" },
        },
        motion = { duration = 200 },
        press = "ripple",
    },
})

return component.define({
    name = "DrawnRail",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local at = props.selectedIndex or 1
        local tabs = props.tabs or {}
        local built = {}

        for index = 1, #tabs do
            local tab = tabs[index]
            local on = index == at
            local about = { on = on }

            built[index] = Pressable {
                key = tostring(tab.key or index),
                accessibilityLabel = tab.label,
                accessibilityRole = "tab",
                accessibilityState = { selected = on },
                focusable = true,
                onFocus = function() self:setState({ focused = index }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                style = {
                    height = wearing:metric("rail", "item"),
                    align = "center",
                    justify = "center",
                    gap = wearing:metric("rail", "gap"),
                },
                onPress = function()
                    if props.onChange ~= nil and not on then
                        props.onChange(index)
                    end
                end,
                onKeyDown = function(held)
                    local step = parts.steps(held.key, "vertical")

                    if props.onChange == nil then
                        return
                    end

                    if parts.chooses(held.key) then
                        props.onChange(index)
                        return
                    end

                    if type(step) == "number" then
                        props.onChange(math.max(1, math.min(#tabs, index + step)))
                    end
                end,

                View {
                    key = "indicator",
                    transition = parts.motion(wearing, "rail"),
                    style = {
                        width = wearing:metric("rail", "indicator") * 2,
                        height = wearing:metric("rail", "indicator"),
                        radius = wearing:metric("rail", "radius"),
                        align = "center",
                        justify = "center",
                        background = parts.paint(wearing, "rail", "indicator", about),
                    },

                    tab.icon ~= nil and content.Icon {
                        name = tab.icon,
                        size = 24,
                        color = parts.paint(wearing, "rail", "icon", about),
                    } or false,
                },

                tab.label ~= nil and Text {
                    key = "label",
                    text = tab.label,
                    numberOfLines = 1,
                    style = {
                        fontSize = "caption",
                        fontWeight = on and "600" or "500",
                        color = parts.paint(wearing, "rail", "label", about),
                    },
                } or false,
            }
        end

        return View {
            accessibilityRole = "none",
            testID = props.testID,
            style = {
                {
                    width = wearing:metric("rail", "width"),
                    gap = wearing:metric("rail", "gap"),
                    paddingVertical = "sm",
                    background = parts.paint(wearing, "rail", "container", {}),
                },
                props.style,
            },

            props.header or false,
            table.unpack(built),
        }
    end,
})
