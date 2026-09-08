local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local input = require("gui.components.input")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

local Pressable = input.Pressable
local Text = content.Text
local View = structure.View

--- What each size of a spinner measures, which is what the platforms themselves draw them at.
local SPINNERS = { small = 20, medium = 32, large = 44 }

M.ActivityIndicator = support.host("activity", {
    natural = { size = function(props)
        local side = SPINNERS[props.size] or SPINNERS.medium
        return { width = side, height = side }
    end },
    props = { "animating", "size", "color" },
    defaults = { animating = true, size = "medium" },
    validate = function(spec)
        local choices = { "small", "medium", "large" }
        if not support.oneOf(spec.size, choices) then
            return support.expected("size", spec.size, choices)
        end
    end,
})

M.ProgressBar = support.host("progress", {
    natural = { size = function(props) return { height = props.thickness } end },
    style = function(spec) return { radius = spec.thickness / 2 } end,
    props = { "value", "indeterminate", "color", "trackColor", "thickness" },
    defaults = { indeterminate = false, thickness = 4 },
    validate = function(spec)
        if not spec.indeterminate and spec.value == nil then
            return "a determinate bar needs a value between zero and one"
        end
    end,
})

--- One shaded box standing in for something that has not arrived, which is what a skeleton is made of.
local Shade = support.host("skeleton", {
    natural = { size = function(props) return { height = props.extent } end },
    style = function(spec)
        local corners = "sm"

        if spec.shape == "circle" then
            corners = "pill"
        end

        return { background = "surface", radius = corners }
    end,
    props = { "shape", "extent" },
    defaults = { shape = "rect", extent = 16 },
})

local SHAPES = { "rect", "circle", "text" }

--- The shape of what is coming, drawn before it is there.
---
--- A count of lines is lines: one box for a count of one, and for more than that a stack of them, the
--- last one short the way the last line of a paragraph is. Drawn as a single box the height of all of
--- them it reads as a component somebody left behind rather than as text that has not arrived.
M.Skeleton = support.component("Skeleton", {
    props = { "shape", "lines" },
    defaults = { shape = "rect", lines = 1 },
    validate = function(spec)
        if not support.oneOf(spec.shape, SHAPES) then
            return support.expected("shape", spec.shape, SHAPES)
        end

        if type(spec.lines) ~= "number" or spec.lines < 1 then
            return "lines is how many lines are coming, at least one"
        end
    end,
}, component.define({
    name = "Skeleton",

    render = function(self)
        local lines = self.props.lines

        if lines == 1 then
            return Shade { shape = self.props.shape, style = self.props.style }
        end

        local bars = {}

        for index = 1, lines do
            bars[#bars + 1] = Shade {
                key = "line:" .. index,
                shape = self.props.shape,
                style = { width = index == lines and "60%" or "100%" },
            }
        end

        return View { style = { { gap = "xs" }, self.props.style }, table.unpack(bars) }
    end,
}))

--- Answers what a badge shows, which is a count held to a ceiling or nothing at all when it is a dot.
local function counted(props)
    if props.dot then
        return ""
    end

    local value = tonumber(props.value)
    local ceiling = tonumber(props.max)

    if value ~= nil and ceiling ~= nil and value > ceiling then
        return ceiling .. "+"
    end

    if props.value == nil then
        return nil
    end

    return tostring(props.value)
end

--- The pill itself, which is handed the count already written out rather than the number behind it.
local Pill = support.host("badge", {
    natural = { text = "text", minWidth = 20, minHeight = 20 },
    style = function(spec)
        local look = {
            background = spec.color or "danger",
            color = spec.textColor or "onPrimary",
            fontSize = "caption",
            fontWeight = "600",
            radius = "pill",
            paddingHorizontal = 6,
            textAlign = "center",
        }

        if spec.dot then
            look.width = 10
            look.height = 10
            look.paddingHorizontal = 0
        end

        return look
    end,
    props = { "text", "dot", "color", "textColor" },
    defaults = { dot = false },
})

--- A count on the corner of the thing it counts, held to a ceiling it is not allowed to run past.
---
--- The count is written out here rather than by each renderer, or a ceiling is three implementations
--- and a badge shows the number it was told to hide.
M.Badge = support.component("Badge", {
    props = { "value", "max", "dot", "color", "textColor" },
    defaults = { dot = false, max = 99 },
}, component.define({
    name = "Badge",
    render = function(self)
        return Pill {
            -- A badge is as wide as what it says, never as wide as the box it happens to sit in.
            style = { { alignSelf = "start" }, self.props.style },
            text = counted(self.props),
            dot = self.props.dot,
            color = self.props.color,
            textColor = self.props.textColor,
        }
    end,
}))

--- A label in a pill, chosen or not, and dismissed when it is one of a set somebody is building.
---
--- It is built here rather than handed to three renderers, since none of them draws anything of its own
--- for one: a chip is a pressable pill holding its label and, when there is somewhere to report it, the
--- mark that takes it away. A renderer given a `removable` flag would be three drawings of one glyph.
M.Chip = support.component("Chip", {
    props = { "label", "selected", "disabled", "color" },
    events = { "onPress", "onRemove" },
    defaults = { selected = false, disabled = false },
    validate = function(spec)
        if type(spec.label) ~= "string" then
            return "a chip carries a label"
        end
    end,
}, component.define({
    name = "Chip",

    render = function(self)
        local ground = "surface"
        local ink = "text"

        if self.props.selected then
            ground = self.props.color or "primary"
            ink = "onPrimary"
        end

        return Pressable {
            style = {
                { direction = "row", align = "center", gap = "xs", minHeight = chrome.touch,
                    paddingHorizontal = "md", radius = "pill", background = ground },
                self.props.style,
            },
            accessibilityLabel = self.props.label,
            disabled = self.props.disabled,
            onPress = self.props.onPress,

            Text {
                key = "label",
                text = self.props.label,
                numberOfLines = 1,
                style = { fontSize = "footnote", color = ink, shrink = 1 },
            },

            -- The mark is small and what a finger has to land on is not, which is what a hit slop is for.
            self.props.onRemove ~= nil and Pressable {
                key = "remove",
                style = { minWidth = 20, minHeight = 20, justify = "center", align = "center" },
                accessibilityLabel = "Remove " .. self.props.label,
                hitSlop = (chrome.touch - 20) / 2,
                onPress = self.props.onRemove,
                content.Icon { name = "close", size = 12, color = ink },
            } or nil,
        }
    end,
}))

--- A face, or the letters standing in for one, in a circle or a rounded square.
---
--- It is built here rather than handed to three renderers: a picture is an `Image` and letters are a
--- `Text`, and none of the three drew a picture for one at all, so every avatar carrying a source was
--- an empty circle. What hangs off its corner is placed outside the clipped box, or the badge would be
--- cut off by the very rounding that makes the avatar a circle.
M.Avatar = support.component("Avatar", {
    props = { "source", "initials", "size", "shape", "badge" },
    defaults = { size = 40, shape = "circle" },
    validate = function(spec)
        if spec.source == nil and spec.initials == nil then
            return "needs a source or the initials to stand in for one"
        end
    end,
}, component.define({
    name = "Avatar",

    render = function(self)
        local size = self.props.size or 40
        local corners = self.props.shape == "circle" and size / 2 or "md"

        return View {
            style = { { width = size, height = size }, self.props.style },

            View {
                key = "face",
                style = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0,
                    radius = corners, background = "surface", overflow = "hidden",
                    align = "center", justify = "center" },

                self.props.source ~= nil and content.Image {
                    key = "picture",
                    source = self.props.source,
                    resizeMode = "cover",
                    style = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0 },
                } or false,

                self.props.source == nil and Text {
                    key = "initials",
                    text = self.props.initials,
                    numberOfLines = 1,
                    style = { color = "textMuted", fontWeight = "600", fontSize = math.max(11, size / 2.6) },
                } or false,
            },

            self.props.badge ~= nil and M.Badge {
                key = "badge",
                value = self.props.badge,
                style = { position = "absolute", top = -4, right = -6 },
            } or false,
        }
    end,
}))

M.Card = support.host("card", {
    style = function(spec)
        local look = { background = "background", radius = "md", shadow = spec.elevation }

        if spec.padded then
            look.padding = "md"
        end

        if spec.outlined then
            look.border = 1
            look.borderColor = "border"
            look.shadow = nil
        end

        return look
    end,
    props = { "elevation", "padded", "outlined" },
    events = { "onPress" },
    defaults = { elevation = "sm", padded = true, outlined = false },
})

M.Tooltip = support.host("tooltip", {
    natural = { text = "text" },
    style = {
        background = "text",
        color = "background",
        fontSize = "footnote",
        radius = "sm",
        paddingHorizontal = "sm",
        paddingVertical = "xs",
        textAlign = "center",
    },
    props = { "text", "visible" },
    validate = function(spec)
        if spec.text == nil then
            return "needs the text to show"
        end
    end,
})

return M
