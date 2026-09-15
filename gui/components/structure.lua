local component = require("gui.component")
local environment = require("gui.environment")
local support = require("gui.components.support")

local M = {}

local OVERFLOW = { "visible", "hidden", "scroll" }

--- A box, which is what most of a tree is made of.
---
--- `onEnterView` and `onExitView` say when the reader can see the box and when they no longer can, which
--- is not what a screen appearing means: a stack keeps a screen mounted and shown while a box inside it
--- is scrolled a thousand points out of sight. The engine works it out from the frames it laid out and
--- the offsets the surfaces report, so the answer is the same on every platform.
M.View = support.host("view", {
    props = { "pointerEvents", "overflow", "opacity", "transform" },
    events = { "onPress", "onDoublePress", "onLongPress", "onHoverIn", "onHoverOut", "onLayout",
        "onEnterView", "onExitView" },
    validate = function(spec)
        if not support.oneOf(spec.overflow, OVERFLOW) then
            return support.expected("overflow", spec.overflow, OVERFLOW)
        end
    end,
})

--- Draws what it holds over the whole application rather than inside the box it was written in.
---
--- An overlay written where it belongs covers only what surrounds it: a drawer raised inside a screen
--- opens under the bar the screen sits below, and an alert raised from a panel is trapped in the panel.
--- What is inside a portal is laid out against the surface and drawn above everything else, while it
--- stays where it was written for everything else — the state it reads, the context it is under, and
--- the commit that takes it down when its screen goes.
M.Portal = support.host("layer", {
    events = { "onLayout" },
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

--- The states a frame may carry artwork of its own for, beside the one every state falls back to.
local STATES = { "pressed", "disabled", "hovered", "focused" }

--- Answers the four cuts a slice names, or nothing when what was written is not a slice.
local function cuts(slice)
    if type(slice) == "number" then
        return { top = slice, right = slice, bottom = slice, left = slice }
    end

    if type(slice) ~= "table" then
        return nil
    end

    local read = {}

    for _, edge in ipairs({ "top", "right", "bottom", "left" }) do
        if type(slice[edge]) ~= "number" then
            return nil
        end

        read[edge] = slice[edge]
    end

    return read
end

--- A box painted with a picture cut into nine, which is what a frame drawn from artwork is.
---
--- The four corners are never stretched, each edge stretches along its own axis and the middle stretches
--- both ways, so one small picture draws a panel of any size without the ornament on its corners being
--- pulled out of shape. It holds what is written inside it the way a view does, which is what makes the
--- same component a window, a dialogue and a button.
---
--- The cuts are written in the pixels of the picture that was named, so the runtime hands the renderer
--- that picture rather than a density variant of it. A frame that has to be crisper is shipped larger
--- and drawn smaller with `sliceScale`, which says how many points one pixel of the border comes out at.
---
--- A frame is also how a button is drawn from artwork, and a button is a different picture while a finger
--- is on it. `sources` names one per state — `pressed`, `disabled`, `hovered`, `focused` — and a state
--- with no artwork of its own is drawn with `source`, so a frame that is only ever one picture says so by
--- naming none of them.
M.NineSlice = support.host("nineslice", {
    natural = {
        minWidth = function(props)
            return props.slice ~= nil and (props.slice.left + props.slice.right) * props.sliceScale or nil
        end,
        minHeight = function(props)
            return props.slice ~= nil and (props.slice.top + props.slice.bottom) * props.sliceScale or nil
        end,
    },
    props = { "source", "sources", "slice", "sliceScale", "disabled", "hitSlop" },
    events = { "onLayout", "onPress", "onLongPress", "onPressIn", "onPressOut" },
    defaults = { sliceScale = 1 },
    normalise = function(spec)
        spec.slice = cuts(spec.slice)
    end,
    validate = function(spec)
        if spec.source == nil then
            return "needs a source, either an asset name or a url"
        end

        if spec.sources ~= nil then
            if type(spec.sources) ~= "table" then
                return "sources names a picture per state, got a " .. type(spec.sources)
            end

            for state, named in pairs(spec.sources) do
                if not support.oneOf(state, STATES) then
                    return support.expected("the state in sources", state, STATES)
                end

                if type(named) ~= "string" then
                    return "sources." .. state .. " is an asset name or a url, got a " .. type(named)
                end
            end
        end

        if spec.slice == nil then
            return "needs a slice, either one number of pixels or { top, right, bottom, left }"
        end

        for _, edge in ipairs({ "top", "right", "bottom", "left" }) do
            local cut = spec.slice[edge]

            if cut < 0 or cut % 1 ~= 0 then
                return "slice." .. edge .. " is a whole number of pixels, got " .. tostring(cut)
            end
        end

        if type(spec.sliceScale) ~= "number" or spec.sliceScale <= 0 then
            return "sliceScale is how many points one pixel of the border is drawn at, above nothing"
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
    actions = { "scrollTo" },
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
--- `bars` says which of the system's own bars the reader still sees, and naming fewer hides the rest.
--- A game takes the whole glass with `bars = {}`. Hiding one changes the room a screen has, so the
--- insets it is avoiding change with it and a screen stays correct across the change without doing
--- anything. A platform with no such bar to hide honours what it can and says so through its
--- capabilities rather than pretending.
local CONTENTS = { "light", "dark" }
local BARS = { "status", "navigation" }

local Area = support.host("safearea", {
    props = { "edges", "barContent", "bars" },
    defaults = { edges = { "top", "bottom", "left", "right" }, bars = BARS },
})

--- Answers the insets a subtree still has to keep clear of, which is what the one above it did not take.
---
--- A bar that runs up to the top of the glass adds the strip the status bar is over to itself, and one
--- drawn inside a safe area must not, or the room is kept twice and the bar is a band of nothing with a
--- title at the bottom of it. Neither can be worked out from a prop, since it depends on what stands
--- above the bar rather than on what the bar was told, so a safe area says what is left of the insets.
local function remaining(insets, edges)
    local left = { top = insets.top, right = insets.right, bottom = insets.bottom, left = insets.left }

    for index = 1, #edges do
        left[edges[index]] = 0
    end

    return left
end

M.SafeArea = support.component("SafeArea", {
    props = { "edges", "barStyle", "barContent", "bars" },
    defaults = { edges = { "top", "bottom", "left", "right" }, bars = BARS },
    validate = function(spec)
        if spec.barContent ~= nil and not support.oneOf(spec.barContent, CONTENTS) then
            return support.expected("barContent", spec.barContent, CONTENTS)
        end

        if type(spec.bars) ~= "table" then
            return "bars is the list of the system's own bars a reader still sees, got a " .. type(spec.bars)
        end

        for index = 1, #spec.bars do
            if not support.oneOf(spec.bars[index], BARS) then
                return support.expected("bars", spec.bars[index], BARS)
            end
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
        local surface = environment:read(self)
        local insets = surface.insets

        local inside = {}

        for key, value in pairs(surface) do
            inside[key] = value
        end

        inside.insets = remaining(insets, self.props.edges)

        return M.View {
            style = { { grow = 1 }, self.props.style },

            Area {
                key = "area",
                edges = self.props.edges,
                barContent = self.props.barContent,
                bars = self.props.bars,
                style = { grow = 1 },

                environment.Provider {
                    value = inside,
                    style = { grow = 1 },
                    table.unpack(self.children),
                },
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

--- Draws everything under it in another control theme, which is what a chooser showing two of them needs.
M.Controls = support.component("Controls", {
    props = { "value" },
}, require("gui.controls.provider"))

--- Draws everything under it in another look, which is what a screen holding something with its own colours needs.
M.Look = support.component("Look", {
    props = { "value" },
}, require("gui.style.provider"))

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
