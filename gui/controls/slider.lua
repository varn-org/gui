local component = require("gui.component")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View

--- A slider drawn by the engine, which is a track, the part of it that is filled, and one thumb or two.
---
--- A drag reports where the finger is against the track's own origin, so the value is worked out from
--- that rather than from how far the finger has travelled: a finger that lands halfway along the track
--- and does not move is asking for the middle, which is what every slider does.
return component.define({
    name = "DrawnSlider",
    state = { width = 0, holding = nil, pressed = false, hovered = false, focused = false },

    --- Answers the value a position along the track stands for, held to the range and to the step.
    valueAt = function(self, x)
        local props = self.props
        local least = props.minimum or 0
        local most = props.maximum or 1
        local width = math.max(1, self.state.width)
        local wanted = least + (most - least) * math.max(0, math.min(1, x / width))

        if props.step == nil then
            return wanted
        end

        return math.max(least, math.min(most, least + math.floor((wanted - least) / props.step + 0.5) * props.step))
    end,

    --- Answers the two ends of what is filled, as fractions of the track.
    filled = function(self)
        local props = self.props
        local least = props.minimum or 0
        local most = props.maximum or 1
        local span = most - least

        if span <= 0 then
            return 0, 0
        end

        if props.range ~= nil then
            return (props.range[1] - least) / span, (props.range[2] - least) / span
        end

        return 0, ((props.value or least) - least) / span
    end,

    --- Moves whichever thumb the finger is nearest to, which is what a range is dragged by.
    moveTo = function(self, x)
        local props = self.props
        local wanted = self:valueAt(x)

        if props.range == nil then
            if props.onChange ~= nil then
                props.onChange(wanted)
            end

            return
        end

        local holding = self.state.holding

        if holding == nil then
            holding = math.abs(props.range[1] - wanted) <= math.abs(props.range[2] - wanted) and 1 or 2
            self:setState({ holding = holding })
        end

        local moved = { props.range[1], props.range[2] }

        moved[holding] = wanted
        moved[1] = math.min(moved[1], moved[2])
        moved[2] = math.max(moved[1], moved[2])

        if props.onChange ~= nil then
            props.onChange(moved)
        end
    end,

    render = function(self)
        local props = self.props
        local theme = props.theme
        local disabled = props.disabled == true
        local about = {
            disabled = disabled,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local kind = props.kind or "slider"
        local thickness = theme:metric(kind, "track")
        local thumbWidth = theme:metric(kind, "thumbWidth")
        local thumbHeight = theme:metric(kind, "thumbHeight")
        local gap = theme:metric(kind, "gap")
        local from, to = self:filled()
        local moves = parts.motion(theme, kind)

        local thumbs = {}
        local at = props.range ~= nil and { from, to } or { to }

        for index = 1, #at do
            thumbs[index] = View {
                key = "thumb" .. index,
                transition = self.state.holding ~= nil and false or moves,
                style = {
                    position = "absolute",
                    left = string.format("%.2f%%", at[index] * 100),
                    top = (theme:metric(kind, "touch") - thumbHeight) / 2,
                    width = thumbWidth,
                    height = thumbHeight,
                    radius = 999,
                    background = parts.paint(theme, kind, "thumb", about),
                    transform = { translateX = -thumbWidth / 2 },
                    shadow = thumbWidth > 8 and "sm" or "none",
                },
            }
        end

        local ring = parts.ring(theme, about, 999)

        if ring ~= nil then
            thumbs[#thumbs + 1] = ring
        end

        local least = props.minimum or 0
        local most = props.maximum or 1
        local now = props.range ~= nil and props.range[2] or props.value or least

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel,
            accessibilityRole = "slider",
            accessibilityState = { disabled = disabled },
            accessibilityValue = { now = now, least = least, most = most },
            testID = props.testID,
            focusable = true,
            panAxis = "horizontal",
            style = {
                { height = theme:metric(kind, "touch"), justify = "center" },
                props.style,
            },
            onLayout = function(frame)
                if frame.width ~= self.state.width then
                    self:setState({ width = frame.width })
                end
            end,
            onFocus = function() self:setState({ focused = true }) end,
            onBlur = function() self:setState({ focused = false }) end,
            onHoverIn = function() self:setState({ hovered = true }) end,
            onHoverOut = function() self:setState({ hovered = false }) end,
            onPanStart = function(where)
                self:setState({ pressed = true, holding = component.none })
                self:moveTo(where.x)
            end,
            onPanMove = function(where) self:moveTo(where.x) end,
            onPanEnd = function(where)
                self:moveTo(where.x)
                self:setState({ pressed = false, holding = component.none })

                if props.onCommit ~= nil then
                    props.onCommit(props.range or self:valueAt(where.x))
                end
            end,
            onKeyDown = function(key)
                local nudge = parts.nudges(key.key)

                if nudge == nil or props.onChange == nil or props.range ~= nil then
                    return
                end

                local step = props.step or (most - least) / 10

                if nudge == "least" then
                    props.onChange(least)
                    return
                end

                if nudge == "most" then
                    props.onChange(most)
                    return
                end

                props.onChange(math.max(least, math.min(most, (props.value or least) + nudge * step)))
            end,

            View {
                key = "track",
                style = {
                    height = thickness,
                    radius = theme:metric(kind, "radius"),
                    background = parts.paint(theme, kind, "track", about),
                    justify = "center",
                },

                View {
                    key = "fill",
                    transition = self.state.holding ~= nil and false or moves,
                    style = {
                        position = "absolute",
                        top = 0,
                        bottom = 0,
                        left = string.format("%.2f%%", from * 100),
                        right = string.format("%.2f%%", (1 - to) * 100),
                        radius = theme:metric(kind, "radius"),
                        background = parts.paint(theme, kind, "fill", about),
                        marginLeft = from > 0 and gap or 0,
                        marginRight = to < 1 and gap or 0,
                    },
                },
            },

            table.unpack(thumbs),
        }
    end,
})
