local component = require("gui.component")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local presence = require("gui.components.presence")
local structure = require("gui.components.structure")
local support = require("gui.components.support")
local theme = require("gui.controls.theme")

local View = structure.View
local Portal = structure.Portal

--- A panel anchored to whatever opened it, with an arrow pointing back at it.
---
--- A menu drops from the top of the screen and a popover comes out of the thing that was pressed, which
--- is what a pointer expects and what a tablet does. Where the thing that was pressed is, is something
--- only the layout knows, so the anchor is a frame the caller reports from `onLayout`.
theme.kind("popover", {
    parts = { "container", "arrow", "scrim" },
    default = {
        metrics = { radius = "md", padding = 8, arrow = 8, elevation = "lg", gap = 8, width = 240 },
        paint = {
            container = { rest = "elevated" },
            arrow = { rest = "elevated" },
            scrim = { rest = "overlay" },
        },
        motion = { duration = 150 },
        press = "none",
    },
})

return component.define({
    name = "DrawnPopover",

    --- Answers where the panel sits, which is under the anchor unless there is no room below it.
    placed = function(self, surface)
        local anchor = self.props.anchor
        local wearing = self.props.theme
        local width = wearing:metric("popover", "width")
        local gap = wearing:metric("popover", "gap")

        if anchor == nil then
            return { top = 0, left = 0, width = width, below = true }
        end

        local below = anchor.y + anchor.height + gap
        local room = surface.height - below
        local goes = room > 160

        return {
            top = goes and below or nil,
            bottom = goes and nil or math.max(gap, surface.height - anchor.y + gap),
            left = math.max(gap, math.min(surface.width - width - gap,
                anchor.x + anchor.width / 2 - width / 2)),
            width = width,
            below = goes,
            middle = anchor.x + anchor.width / 2,
        }
    end,

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local environment = require("gui.environment")
        local surface = environment:read(self)
        local at = self:placed(surface)
        local arrow = wearing:metric("popover", "arrow")

        return Portal {
            presence.Presence {
                visible = props.visible == true,
                enter = { opacity = 0, transform = { scale = 0.96 } },
                transition = parts.motion(wearing, "popover"),

                Pressable {
                    key = "scrim",
                    accessibilityLabel = props.dismissLabel or "Close",
                    style = support.cover({ background = parts.paint(wearing, "popover", "scrim", {}) }),
                    onPress = props.onDismiss,
                },

                View {
                    key = "panel",
                    accessibilityRole = "none",
                    testID = props.testID,
                    style = {
                        position = "absolute",
                        left = at.left,
                        top = at.top,
                        bottom = at.bottom,
                        width = at.width,
                        padding = wearing:metric("popover", "padding"),
                        radius = wearing:metric("popover", "radius"),
                        background = parts.paint(wearing, "popover", "container", {}),
                        shadow = wearing:metric("popover", "elevation"),
                    },

                    table.unpack(self.children),
                },

                at.middle ~= nil and View {
                    key = "arrow",
                    pointerEvents = "none",
                    style = {
                        position = "absolute",
                        left = at.middle - arrow,
                        top = at.below and (at.top - arrow) or nil,
                        bottom = at.below and nil or (at.bottom - arrow),
                        width = arrow * 2,
                        height = arrow * 2,
                        radius = 2,
                        background = parts.paint(wearing, "popover", "arrow", {}),
                        transform = { rotate = 45 },
                    },
                } or false,
            },
        }
    end,
})
