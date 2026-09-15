local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- A segmented control drawn by the engine, which is a row of pressables over one track.
---
--- Every segment is the same width, so the one that is chosen is drawn where it is rather than travelling
--- to it: a raised pill laid out over the track would need the row's own width, which the engine knows
--- and the tree does not until it has been laid out once.
return component.define({
    name = "DrawnSegmented",
    state = { pressed = nil, focused = nil },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local disabled = props.disabled == true
        local segments = props.segments
        local chosen = props.selectedIndex or 1
        local moves = parts.motion(theme, "segmented")
        local radius = theme:metric("segmented", "radius")
        local mark = theme:metric("segmented", "mark")

        -- A design draws this control shorter than the smallest target every system publishes, and a
        -- segment is what a finger lands on, so the row is a finger tall and the ink keeps its own height.
        local height = math.max(theme:metric("segmented", "height"), theme:metric("segmented", "touch"))
        local border = theme:metric("segmented", "border")

        local built = {}

        for index = 1, #segments do
            local on = index == chosen
            local about = {
                on = on,
                disabled = disabled,
                pressed = self.state.pressed == index,
                focused = self.state.focused == index,
            }

            local inside = {}

            if mark > 0 and on then
                inside[#inside + 1] = content.Canvas {
                    key = "mark",
                    style = { width = 18, height = 18 },
                    commands = parts.mark("tick", 18, parts.paint(theme, "segmented", "label", about), mark),
                }
            end

            inside[#inside + 1] = Text {
                key = "label",
                text = tostring(segments[index]),
                numberOfLines = 1,
                style = {
                    color = parts.paint(theme, "segmented", "label", about),
                    fontSize = "footnote",
                    fontWeight = on and "600" or "500",
                    textAlign = "center",
                },
            }

            built[index] = Pressable {
                key = tostring(index),
                disabled = props.disabled,
                accessibilityLabel = tostring(segments[index]),
                accessibilityRole = "tab",
                accessibilityState = { selected = on, disabled = disabled },
                transition = moves,
                style = {
                    grow = 1,
                    basis = 0,
                    direction = "row",
                    align = "center",
                    justify = "center",
                    gap = 4,
                    height = height - border * 2,
                    radius = radius,
                    background = parts.paint(theme, "segmented", "segment", about),
                    paddingHorizontal = theme:metric("segmented", "paddingHorizontal"),
                },
                onPress = function()
                    if props.onChange ~= nil and not on then
                        props.onChange(index)
                    end
                end,
                onKeyDown = function(key)
                    local step = parts.steps(key.key, "horizontal")

                    if step == nil or props.onChange == nil then
                        return
                    end

                    if step == "first" then
                        props.onChange(1)
                        return
                    end

                    if step == "last" then
                        props.onChange(#segments)
                        return
                    end

                    props.onChange(math.max(1, math.min(#segments, index + step)))
                end,
                focusable = true,
                onFocus = function() self:setState({ focused = index }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                onPressIn = function() self:setState({ pressed = index }) end,
                onPressOut = function() self:setState({ pressed = component.none }) end,

                table.unpack(inside),
            }
        end

        return View {
            accessibilityRole = "none",
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    gap = theme:metric("segmented", "gap"),
                    padding = border,
                    height = height,
                    radius = radius,
                    border = border,
                    borderColor = parts.paint(theme, "segmented", "track", { disabled = disabled }),
                    background = theme:metric("segmented", "border") > 0 and "transparent"
                        or parts.paint(theme, "segmented", "track", { disabled = disabled }),
                },
                props.style,
            },

            table.unpack(built),
        }
    end,
})
