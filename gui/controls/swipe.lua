local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local View = structure.View
local Text = content.Text

--- A row a finger drags sideways to reach what can be done to it.
---
--- The actions are drawn behind the row rather than beside it, so the row slides over them and nothing
--- about the list's own layout changes. The row springs back when the finger leaves unless it was dragged
--- far enough to stay open, which is what both phones do.
theme.kind("swipe", {
    parts = { "action", "label" },
    default = {
        metrics = { action = 80, threshold = 0.4, radius = 0 },
        paint = {
            action = { rest = "primary", invalid = "danger" },
            label = { rest = "onPrimary", invalid = "onPrimary" },
        },
        motion = { duration = 200 },
        press = "highlight",
    },
})

return component.define({
    name = "DrawnSwipe",
    state = { at = 0, open = false },

    --- Answers how far the row may travel, which is the room the actions on that side need.
    reachOf = function(self, side)
        local given = side == "leading" and self.props.leading or self.props.trailing

        return #(given or {}) * self.props.theme:metric("swipe", "action")
    end,

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local height = wearing:metric("swipe", "action")

        local function row(given, side)
            local built = {}

            for index = 1, #(given or {}) do
                local entry = given[index]
                local about = { invalid = entry.destructive == true }

                built[index] = Pressable {
                    key = tostring(entry.key or index),
                    accessibilityLabel = entry.label,
                    accessibilityRole = "button",
                    focusable = true,
                    style = {
                        width = height,
                        align = "center",
                        justify = "center",
                        gap = 4,
                        background = parts.paint(wearing, "swipe", "action", about),
                    },
                    onPress = function()
                        self:setState({ at = 0, open = false })

                        if props.onAction ~= nil then
                            props.onAction(entry.key or index)
                        end
                    end,

                    entry.icon ~= nil and content.Icon {
                        name = entry.icon,
                        size = 20,
                        color = parts.paint(wearing, "swipe", "label", about),
                    } or false,

                    Text {
                        text = entry.label,
                        numberOfLines = 1,
                        style = {
                            fontSize = "caption",
                            color = parts.paint(wearing, "swipe", "label", about),
                        },
                    },
                }
            end

            return View {
                key = side,
                style = {
                    position = "absolute",
                    top = 0,
                    bottom = 0,
                    left = side == "leading" and 0 or nil,
                    right = side == "leading" and nil or 0,
                    direction = "row",
                },

                table.unpack(built),
            }
        end

        return View {
            testID = props.testID,
            style = { { overflow = "hidden", radius = wearing:metric("swipe", "radius") }, props.style },

            props.leading ~= nil and row(props.leading, "leading") or false,
            props.trailing ~= nil and row(props.trailing, "trailing") or false,

            Pressable {
                key = "row",
                panAxis = "horizontal",
                transition = self.state.open ~= nil and parts.motion(wearing, "swipe") or false,
                style = { transform = { translateX = self.state.at } },
                onPanMove = function(where)
                    local reach = where.dx < 0 and self:reachOf("trailing") or self:reachOf("leading")

                    self:setState({ at = math.max(-reach, math.min(reach, where.dx)) })
                end,
                onPanEnd = function(where)
                    local reach = where.dx < 0 and self:reachOf("trailing") or self:reachOf("leading")
                    local far = reach > 0 and math.abs(where.dx) / reach > wearing:metric("swipe", "threshold")

                    self:setState({
                        at = far and (where.dx < 0 and -reach or reach) or 0,
                        open = far,
                    })
                end,

                table.unpack(self.children),
            },
        }
    end,
})
