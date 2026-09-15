local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local View = structure.View
local Text = content.Text

--- A list of rows that hold rows, each opening and closing.
---
--- What is open is the caller's, kept as a set of the keys that are, so the tree is a description of the
--- data rather than a thing holding a copy of it: a node opened, then reloaded from somewhere else, is
--- still open.
theme.kind("tree", {
    parts = { "row", "label", "chevron" },
    default = {
        metrics = { row = 44, indent = 20, gap = 8, chevron = 20, radius = "sm" },
        paint = {
            row = { rest = "background", on = "secondaryContainer", hovered = "surfaceVariant" },
            label = { rest = "text", on = "onSecondaryContainer" },
            chevron = { rest = "onSurfaceVariant" },
        },
        motion = { duration = 150 },
        press = "highlight",
    },
})

return component.define({
    name = "DrawnTree",
    state = { hovered = nil, focused = nil },

    --- Walks the tree into the flat list of rows that are actually on screen.
    rows = function(self, nodes, depth, into)
        local open = self.props.open or {}

        for index = 1, #nodes do
            local node = nodes[index]

            into[#into + 1] = { node = node, depth = depth }

            if open[node.key] and node.children ~= nil then
                self:rows(node.children, depth + 1, into)
            end
        end

        return into
    end,

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local open = props.open or {}
        local shown = self:rows(props.nodes or {}, 0, {})
        local built = {}

        for index = 1, #shown do
            local held = shown[index].node
            local depth = shown[index].depth
            local branches = held.children ~= nil and #held.children > 0
            local on = held.key == props.selected
            local about = { on = on, hovered = self.state.hovered == held.key }

            built[index] = Pressable {
                key = tostring(held.key),
                accessibilityLabel = held.label,
                accessibilityRole = "listitem",
                accessibilityState = { selected = on, expanded = branches and open[held.key] == true or nil },
                focusable = true,
                onFocus = function() self:setState({ focused = held.key }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                transition = parts.motion(wearing, "tree"),
                style = {
                    direction = "row",
                    align = "center",
                    gap = wearing:metric("tree", "gap"),
                    minHeight = wearing:metric("tree", "row"),
                    paddingLeft = depth * wearing:metric("tree", "indent") + 8,
                    paddingRight = 8,
                    radius = wearing:metric("tree", "radius"),
                    background = parts.paint(wearing, "tree", "row", about),
                },
                onPress = function()
                    if branches and props.onOpen ~= nil then
                        props.onOpen(held.key, not (open[held.key] == true))
                    end

                    if props.onSelect ~= nil then
                        props.onSelect(held.key)
                    end
                end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) and props.onSelect ~= nil then
                        props.onSelect(held.key)
                        return
                    end

                    if key.key == "ArrowRight" and branches and props.onOpen ~= nil then
                        props.onOpen(held.key, true)
                    end

                    if key.key == "ArrowLeft" and branches and props.onOpen ~= nil then
                        props.onOpen(held.key, false)
                    end
                end,
                onHoverIn = function() self:setState({ hovered = held.key }) end,
                onHoverOut = function() self:setState({ hovered = component.none }) end,

                branches and content.Icon {
                    key = "chevron",
                    name = open[held.key] and "chevron-down" or "chevron-right",
                    size = wearing:metric("tree", "chevron"),
                    color = parts.paint(wearing, "tree", "chevron", about),
                } or View { key = "chevron", style = { width = wearing:metric("tree", "chevron") } },

                Text {
                    key = "label",
                    text = held.label,
                    numberOfLines = 1,
                    style = { grow = 1, color = parts.paint(wearing, "tree", "label", about) },
                },
            }
        end

        return View {
            accessibilityRole = "list",
            testID = props.testID,
            style = props.style,
            table.unpack(built),
        }
    end,
})
