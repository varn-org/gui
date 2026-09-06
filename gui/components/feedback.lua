local support = require("gui.components.support")

local M = {}

M.ActivityIndicator = support.host("activity", {
    natural = { size = { width = 24, height = 24 } },
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
    props = { "value", "indeterminate", "color", "trackColor", "thickness" },
    defaults = { indeterminate = false, thickness = 4 },
    validate = function(spec)
        if not spec.indeterminate and spec.value == nil then
            return "a determinate bar needs a value between zero and one"
        end
    end,
})

M.Skeleton = support.host("skeleton", {
    natural = { size = function(props) return { height = 16 * (props.lines or 1) + 8 * ((props.lines or 1) - 1) } end },
    style = function(spec)
        local corners = "sm"

        if spec.shape == "circle" then
            corners = "pill"
        end

        return { background = "surface", radius = corners }
    end,
    props = { "shape", "lines" },
    defaults = { shape = "rect", lines = 1 },
    validate = function(spec)
        local choices = { "rect", "circle", "text" }
        if not support.oneOf(spec.shape, choices) then
            return support.expected("shape", spec.shape, choices)
        end
    end,
})

M.RefreshControl = support.host("refresh", {
    natural = { size = { height = 44 } },
    props = { "refreshing", "tint", "title" },
    events = { "onRefresh" },
    defaults = { refreshing = false },
})

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

M.Badge = support.host("badge", {
    natural = { text = counted, padding = { horizontal = 12, vertical = 4 }, minWidth = 20, minHeight = 20 },
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
    props = { "value", "max", "dot", "color", "textColor" },
    defaults = { dot = false, max = 99 },
})

M.Chip = support.host("chip", {
    natural = { text = "label", padding = { horizontal = 24, vertical = 12 }, minHeight = 32 },
    style = function(spec)
        local look = { background = "surface", color = "text" }

        if spec.selected then
            look = { background = spec.color or "primary", color = "onPrimary" }
        end

        look.fontSize = "footnote"
        look.radius = "pill"
        look.paddingHorizontal = "md"
        look.textAlign = "center"
        return look
    end,
    props = { "label", "selected", "icon", "disabled", "color" },
    events = { "onPress" },
    defaults = { selected = false, disabled = false },
})

M.Avatar = support.host("avatar", {
    natural = { size = function(props) return { width = props.size, height = props.size } end },
    style = function(spec)
        local corners = "md"

        if spec.shape == "circle" then
            corners = (spec.size or 40) / 2
        end

        return {
            background = "surface",
            color = "textMuted",
            fontWeight = "600",
            radius = corners,
            overflow = "hidden",
            textAlign = "center",
        }
    end,
    props = { "source", "initials", "size", "shape", "badge" },
    defaults = { size = 40, shape = "circle" },
})

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
    natural = { text = "text", padding = { horizontal = 16, vertical = 8 } },
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
