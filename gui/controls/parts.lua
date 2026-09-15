local theming = require("gui.theming")

local M = {}

--- Answers the control theme a component is drawn under, which is what the runtime holds.
function M.themeOf(instance)
    return theming:read(instance).controls
end

--- Answers the states a part is painted in, most particular first.
---
--- The order is what makes a theme carry only what it changes: a switch that is on and pressed is
--- painted as one that is on unless the theme says what pressing does to it, so the list runs from the
--- state that says most about this moment to the one that says least.
function M.states(about)
    local found = {}

    if about.disabled then
        if about.on then
            found[#found + 1] = "disabledOn"
        end

        found[#found + 1] = "disabled"
        return found
    end

    if about.invalid then
        found[#found + 1] = "invalid"
    end

    if about.pressed then
        found[#found + 1] = "pressed"
    end

    if about.focused then
        found[#found + 1] = "focused"
    end

    if about.hovered then
        found[#found + 1] = "hovered"
    end

    if about.on then
        found[#found + 1] = "on"
    end

    return found
end

--- Answers the colour a part is painted in right now, which is a role the look turns into a colour.
function M.paint(theme, control, part, about)
    return theme:paint(control, part, M.states(about))
end

--- Answers how a change to this control is drawn, which a node carries as its transition.
---
--- What a renderer animates is the opacity and the transform, since neither moves what the layout
--- worked out, so a part that travels does it by being moved rather than by being laid out elsewhere.
function M.motion(theme, control)
    local moves = theme:motion(control)
    return { duration = moves.duration, easing = moves.easing }
end

--- The marks a drawn control puts inside a box, written in a box of one and scaled to the size asked for.
---
--- Every renderer draws a run of straight lines and nothing else, which is the one shape all three agree
--- on, so a tick and a dash are points rather than glyphs and they are the same on every platform.
local SHAPES = {
    tick = { { { 0.22, 0.52 }, { 0.42, 0.72 }, { 0.78, 0.3 } } },
    dash = { { { 0.24, 0.5 }, { 0.76, 0.5 } } },
    minus = { { { 0.28, 0.5 }, { 0.72, 0.5 } } },
    plus = { { { 0.28, 0.5 }, { 0.72, 0.5 } }, { { 0.5, 0.28 }, { 0.5, 0.72 } } },
    chevron = { { { 0.3, 0.42 }, { 0.5, 0.62 }, { 0.7, 0.42 } } },
}

--- Answers the drawing instructions for one of those marks at a size, in a colour.
function M.mark(name, size, paint, width)
    local shape = SHAPES[name]

    if shape == nil then
        error("there is no mark named " .. tostring(name), 2)
    end

    local commands = {}

    for run = 1, #shape do
        local path = {}

        for index = 1, #shape[run] do
            path[index] = { shape[run][index][1] * size, shape[run][index][2] * size }
        end

        commands[run] = { op = "stroke", path = path, color = paint, width = width }
    end

    return commands
end

--- Answers a filled disc of a size, which is what a radio's dot and a rating's mark are drawn as.
function M.disc(size, paint)
    local radius = size / 2
    local steps = 24
    local path = {}

    for index = 0, steps do
        local angle = math.rad(360 * index / steps)
        path[#path + 1] = { radius + radius * math.cos(angle), radius + radius * math.sin(angle) }
    end

    return { { op = "fill", path = path, color = paint } }
end

--- Answers an arc drawn as a stroked run of points, which is what a round progress and a spinner are.
---
--- Every renderer draws a run of straight lines and nothing else, so a curve is written as enough of them
--- that nobody can tell at the size one is drawn. A ring that is rotated rather than redrawn would be a
--- transform on a box, and a box cannot be an arc of part of a circle.
function M.arc(size, thickness, paint, from, to)
    local radius = (size - thickness) / 2
    local middle = size / 2
    local sweep = to - from

    if math.abs(sweep) < 0.01 then
        return {}
    end

    local steps = math.max(4, math.floor(math.abs(sweep) / 6))
    local path = {}

    for index = 0, steps do
        local angle = math.rad(from + sweep * index / steps)
        path[#path + 1] = { middle + radius * math.cos(angle), middle + radius * math.sin(angle) }
    end

    return { { op = "stroke", path = path, color = paint, width = thickness, cap = "round" } }
end

--- Answers a star of a size, which is what a rating draws one of per mark.
function M.star(size, paint, filled)
    local middle = size / 2
    local outer = size / 2
    local inner = outer * 0.42
    local path = {}

    for index = 0, 9 do
        local radius = index % 2 == 0 and outer or inner
        local angle = math.rad(-90 + index * 36)
        path[#path + 1] = { middle + radius * math.cos(angle), middle + radius * math.sin(angle) }
    end

    path[#path + 1] = path[1]

    return { { op = filled and "fill" or "stroke", path = path, color = paint, width = math.max(1, size * 0.08) } }
end

--- The keys that mean "use this control", which every system agrees on and neither reports for a box.
---
--- A control the platform draws answers these itself. One the engine draws is a box, and a box answers
--- nothing, so using a drawn control from a keyboard would be pressing keys at a screen that never moves.
--- Each control answers the keys its own kind owns and the behaviour is then the same on all three
--- platforms rather than three platforms' worth of defaults.
local CHOOSING = { [" "] = true, Enter = true }

--- Answers whether a key is the one that uses a control, which is space or return everywhere.
function M.chooses(key)
    return CHOOSING[key] == true
end

--- Answers which way a key moves through a set, or nothing when it is not one of them.
---
--- A radio group, a segmented control and a slider are all walked with the arrows, and home and end go
--- to either end of the set. Which axis a control reads is the control's, since a row and a column are
--- walked with different arrows and a slider reads both.
function M.steps(key, axis)
    local across = axis ~= "vertical"
    local down = axis ~= "horizontal"

    if (across and key == "ArrowRight") or (down and key == "ArrowDown") then
        return 1
    end

    if (across and key == "ArrowLeft") or (down and key == "ArrowUp") then
        return -1
    end

    if key == "Home" then
        return "first"
    end

    if key == "End" then
        return "last"
    end

    return nil
end

--- Answers what one of a set of pressables carries to say the keyboard has reached it.
---
--- A control made of several pressables — a stepper's two keys, a rating's marks, a row of pages — holds
--- which of them the keyboard is on rather than whether it is on any of them, so the ring is drawn around
--- the one that was actually reached.
function M.reachable(instance, name)
    return {
        focusable = true,
        onFocus = function() instance:setState({ focused = name }) end,
        onBlur = function() instance:setState({ focused = require("gui.component").none }) end,
    }
end

--- Answers the ring drawn around a control the keyboard has reached, or nothing when it has not.
---
--- It is a box of its own outside the control rather than a border on it, since a border changes what
--- the layout gave the control and a control that grew when it was reached would move the page.
function M.ring(theme, about, radius)
    local drawn = theme:focus()

    if not about.focused or about.disabled or drawn.width <= 0 then
        return nil
    end

    local structure = require("gui.components.structure")

    return structure.View {
        key = "focus",
        pointerEvents = "none",
        style = {
            position = "absolute",
            left = -drawn.offset,
            right = -drawn.offset,
            top = -drawn.offset,
            bottom = -drawn.offset,
            radius = type(radius) == "number" and radius + drawn.offset or radius,
            border = drawn.width,
            borderColor = drawn.color,
        },
    }
end

--- Answers which way a key moves a number, or nothing when it is not one of them.
---
--- A set and a number are walked by the same keys meaning opposite things: the up arrow goes back through
--- a row of segments and forward through a number, which is what every system does and what a reader
--- expects of each. `steps` is for a set and this is for a value.
function M.nudges(key)
    if key == "ArrowUp" or key == "ArrowRight" then
        return 1
    end

    if key == "ArrowDown" or key == "ArrowLeft" then
        return -1
    end

    if key == "Home" then
        return "least"
    end

    if key == "End" then
        return "most"
    end

    return nil
end

--- Answers the box a control is touched through, which is larger than the control is drawn.
---
--- Every system publishes a smallest touch target and it is larger than a checkbox or a radio is drawn,
--- so the drawn control sits in the middle of a box that size and the box is what takes the finger.
---
--- A control with a size of its own is given it here rather than left to stretch. A control the platform
--- draws declares that size and the layout reads it off the declaration, and a drawn one is a box the
--- layout knows nothing about: left to itself it fills the column it was written in, which is a switch
--- as wide as the screen.
function M.touch(theme, control, width)
    local size = theme:metric(control, "touch")

    return {
        width = math.max(width, size),
        height = size,
        align = "center",
        justify = "center",
    }
end

return M
