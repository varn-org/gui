local support = require("gui.components.support")

local M = {}

local OVERFLOW = { "visible", "hidden", "scroll" }

M.View = support.host("view", {
    props = { "pointerEvents", "overflow", "opacity", "transform" },
    events = { "onPress", "onLongPress", "onLayout" },
    validate = function(spec)
        if not support.oneOf(spec.overflow, OVERFLOW) then
            return support.expected("overflow", spec.overflow, OVERFLOW)
        end
    end,
})

M.ScrollView = support.host("scroll", {
    props = {
        "horizontal", "paging", "showsIndicator", "bounces", "contentInset",
        "scrollEnabled", "keyboardDismissMode", "refreshing", "contentStyle",
    },
    events = { "onScroll", "onScrollEnd", "onRefresh", "onLayout" },
    defaults = { horizontal = false, showsIndicator = true, bounces = true, scrollEnabled = true },
})

M.SafeArea = support.host("safearea", {
    props = { "edges" },
    defaults = { edges = { "top", "bottom", "left", "right" } },
})

M.KeyboardAvoiding = support.host("keyboardavoiding", {
    props = { "behavior", "offset" },
    defaults = { behavior = "padding", offset = 0 },
    validate = function(spec)
        local choices = { "padding", "translate", "none" }
        if not support.oneOf(spec.behavior, choices) then
            return support.expected("behavior", spec.behavior, choices)
        end
    end,
})

M.Spacer = support.host("spacer", {
    natural = { size = function(props) return { width = props.size, height = props.size } end },
    props = { "size" },
})

--- A rule is a painted box rather than something a renderer draws, so it is the same rule on all three.
local function rule(spec)
    if spec.orientation == "vertical" then
        return { background = spec.color or "separator", width = spec.thickness, marginVertical = spec.inset }
    end

    return { background = spec.color or "separator", height = spec.thickness, marginLeft = spec.inset }
end

M.Divider = support.host("divider", {
    natural = { size = function(props) return { height = props.thickness } end },
    style = rule,
    props = { "orientation", "color", "thickness", "inset" },
    defaults = { orientation = "horizontal", thickness = 1 },
    validate = function(spec)
        local choices = { "horizontal", "vertical" }
        if not support.oneOf(spec.orientation, choices) then
            return support.expected("orientation", spec.orientation, choices)
        end
    end,
})

return M
