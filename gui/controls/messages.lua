local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local presence = require("gui.components.presence")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local M = {}

local View = structure.View
local Portal = structure.Portal
local Text = content.Text

--- A message along the bottom edge with one thing that can be done about it.
---
--- A toast says something and goes. A snackbar offers to undo it, which is why it waits longer and why
--- it is a control rather than a longer toast: something a reader has to be able to reach cannot be on a
--- timer they do not control.
theme.kind("snackbar", {
    parts = { "container", "label", "action" },
    default = {
        metrics = { radius = "sm", padding = 16, gap = 16, inset = 16, elevation = "md" },
        paint = {
            container = { rest = "elevated" },
            label = { rest = "text" },
            action = { rest = "primary" },
        },
        motion = { duration = 200 },
        press = "highlight",
    },
})

--- A message across the top of the content, which stays until it is answered.
theme.kind("banner", {
    parts = { "container", "label", "action", "indicator" },
    default = {
        metrics = { radius = "sm", padding = 16, gap = 12, border = 1 },
        paint = {
            container = { rest = "surfaceVariant", invalid = "danger" },
            label = { rest = "text", invalid = "onPrimary" },
            action = { rest = "primary", invalid = "onPrimary" },
            indicator = { rest = "outline", invalid = "danger" },
        },
        motion = { duration = 200 },
        press = "highlight",
    },
})

--- Answers the row of things a message offers, each of them drawn as words rather than as a button.
local function actions(wearing, kind, given, answer, about)
    local built = {}

    for index = 1, #(given or {}) do
        local entry = given[index]

        built[index] = Pressable {
            key = tostring(entry.key or index),
            accessibilityLabel = entry.label,
            accessibilityRole = "button",
            focusable = true,
            style = { minWidth = 44, minHeight = 44, justify = "center", paddingHorizontal = 8, shrink = 0 },
            onPress = function()
                if answer ~= nil then
                    answer(entry.key or index)
                end
            end,

            Text {
                text = entry.label,
                style = {
                    color = parts.paint(wearing, kind, "action", about),
                    fontWeight = "600",
                },
            },
        }
    end

    return built
end

M.Snackbar = component.define({
    name = "DrawnSnackbar",

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local inset = wearing:metric("snackbar", "inset")

        return Portal {
            presence.Presence {
                visible = props.visible == true,
                enter = { opacity = 0, transform = { translateY = 24 } },
                transition = parts.motion(wearing, "snackbar"),

                View {
                    accessibilityRole = "none",
                    accessibilityLabel = props.message,
                    testID = props.testID,
                    style = {
                        position = "absolute",
                        left = inset,
                        right = inset,
                        bottom = inset,
                        direction = "row",
                        align = "center",
                        gap = wearing:metric("snackbar", "gap"),
                        padding = wearing:metric("snackbar", "padding"),
                        radius = wearing:metric("snackbar", "radius"),
                        background = parts.paint(wearing, "snackbar", "container", {}),
                        shadow = wearing:metric("snackbar", "elevation"),
                    },

                    Text {
                        key = "message",
                        text = props.message or "",
                        style = { grow = 1, color = parts.paint(wearing, "snackbar", "label", {}) },
                    },

                    table.unpack(actions(wearing, "snackbar", props.actions, props.onAction, {})),
                },
            },
        }
    end,
})

M.Banner = component.define({
    name = "DrawnBanner",

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local about = { invalid = props.tone == "danger" }

        local inside = {}

        if props.icon ~= nil then
            inside[#inside + 1] = content.Icon {
                key = "icon",
                name = props.icon,
                size = 24,
                color = parts.paint(wearing, "banner", "label", about),
            }
        end

        inside[#inside + 1] = Text {
            key = "message",
            text = props.message or "",
            style = { grow = 1, color = parts.paint(wearing, "banner", "label", about) },
        }

        for _, row in ipairs(actions(wearing, "banner", props.actions, props.onAction, about)) do
            inside[#inside + 1] = row
        end

        -- A banner sits in the flow rather than over the screen, so what shows it is a box like any
        -- other: left to cover the surface it would be drawn over whatever was written after it.
        return presence.Presence {
            visible = props.visible ~= false,
            style = {},
            enter = { opacity = 0, transform = { translateY = -12 } },
            transition = parts.motion(wearing, "banner"),

            View {
                accessibilityRole = "none",
                accessibilityLabel = props.message,
                testID = props.testID,
                style = {
                    {
                        direction = "row",
                        align = "center",
                        gap = wearing:metric("banner", "gap"),
                        padding = wearing:metric("banner", "padding"),
                        radius = wearing:metric("banner", "radius"),
                        border = wearing:metric("banner", "border"),
                        borderColor = parts.paint(wearing, "banner", "indicator", about),
                        background = parts.paint(wearing, "banner", "container", about),
                    },
                    props.style,
                },

                table.unpack(inside),
            },
        }
    end,
})

return M
