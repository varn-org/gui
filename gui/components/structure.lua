local component = require("gui.component")
local environment = require("gui.environment")
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

local DIRECTIONS = { "down", "up", "right", "left", "diagonal" }

--- A box painted with a run of colours rather than one, which is what a screen with a header is.
---
--- The colours are theme names like every other colour, and the direction is one of a fixed set, so the
--- same run of colour comes out at the same angle on every platform rather than at whatever each one
--- makes of an angle in degrees.
M.Gradient = support.host("gradient", {
    props = { "colors", "locations", "direction" },
    events = { "onLayout", "onPress" },
    defaults = { direction = "down" },
    validate = function(spec)
        if type(spec.colors) ~= "table" or #spec.colors < 2 then
            return "needs colors, a list of at least two"
        end

        if spec.locations ~= nil and #spec.locations ~= #spec.colors then
            return "locations must give one stop per colour"
        end

        if not support.oneOf(spec.direction, DIRECTIONS) then
            return support.expected("direction", spec.direction, DIRECTIONS)
        end
    end,
})

--- A box that blurs what is behind it, which is what a bar over a scrolling screen is made of.
---
--- iOS and the browser blur the screen behind it. Android has no blur of a view's own backdrop at all,
--- so what it draws is the tint alone, which is why the tint is what carries the colour rather than the
--- blur carrying it.
M.Blur = support.host("blur", {
    props = { "intensity", "tint" },
    events = { "onLayout" },
    defaults = { intensity = 0.85 },
    validate = function(spec)
        if type(spec.intensity) ~= "number" or spec.intensity < 0 or spec.intensity > 1 then
            return "intensity is a share between 0 and 1, got " .. tostring(spec.intensity)
        end
    end,
})

M.ScrollView = support.host("scroll", {
    props = {
        "horizontal", "paging", "showsIndicator", "bounces",
        "scrollEnabled", "keyboardDismissMode", "refreshing", "contentStyle",
    },
    events = { "onScroll", "onScrollEnd", "onRefresh", "onLayout" },
    defaults = { horizontal = false, showsIndicator = true, bounces = true, scrollEnabled = true },
})

--- The area the system draws nothing of its own over, and what the strips it does draw over sit on.
---
--- A status bar and a home indicator are drawn by the system over the top and the bottom of the screen,
--- and what shows through behind them is the application's. Left to the background of the screen it is
--- a different colour from the bar under it, which is what a navigation bar ending in a hard edge below
--- the clock was. `barStyle` says what fills those two strips, so a bar can run all the way up.
---
--- Saying nothing about `barContent` is the right answer for almost every screen: each platform already
--- draws its own bars from the appearance, so they follow light and dark with nothing in the tree
--- restating it. Naming one pins it whichever way the device is set, which is what a screen with a bar
--- of its own colour wants and what every other screen gets wrong.
local CONTENTS = { "light", "dark" }

local Area = support.host("safearea", {
    props = { "edges", "barContent" },
    defaults = { edges = { "top", "bottom", "left", "right" } },
})

M.SafeArea = support.component("SafeArea", {
    props = { "edges", "barStyle", "barContent" },
    defaults = { edges = { "top", "bottom", "left", "right" } },
    validate = function(spec)
        if spec.barContent ~= nil and not support.oneOf(spec.barContent, CONTENTS) then
            return support.expected("barContent", spec.barContent, CONTENTS)
        end
    end,
}, component.define({
    name = "SafeArea",

    --- Answers the strip one edge of the system covers, or nothing when it covers none of it.
    Strip = function(self, edge, extent)
        if extent <= 0 or self.props.barStyle == nil then
            return false
        end

        local box = { position = "absolute", left = 0, right = 0, height = extent }
        box[edge] = 0

        return M.View { key = edge, style = { box, self.props.barStyle } }
    end,

    render = function(self)
        local insets = environment:read(self).insets

        return M.View {
            style = { { grow = 1 }, self.props.style },

            Area {
                key = "area",
                edges = self.props.edges,
                barContent = self.props.barContent,
                style = { grow = 1 },
                table.unpack(self.children),
            },

            self:Strip("top", insets.top),
            self:Strip("bottom", insets.bottom),
        }
    end,
}))

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
