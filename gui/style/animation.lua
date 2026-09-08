local M = {}

--- The easings, as the control points of the curve rather than a name only one platform knows.
---
--- Every platform takes a cubic bezier: `cubic-bezier` in CSS, `UIViewPropertyAnimator` by its two
--- control points, and `PathInterpolator` by the same four numbers. Naming a curve here is what stops
--- three renderers disagreeing about what `easeOut` means.
M.easings = {
    linear = { 0, 0, 1, 1 },
    easeIn = { 0.42, 0, 1, 1 },
    easeOut = { 0, 0, 0.58, 1 },
    easeInOut = { 0.42, 0, 0.58, 1 },
    spring = { 0.34, 1.56, 0.64, 1 },
}

--- How long a change takes when the caller only says how quickly it should feel.
M.durations = { instant = 0, fast = 150, normal = 250, slow = 400 }

local DEFAULT = { duration = M.durations.normal, easing = "easeOut", delay = 0 }

--- Answers a transition in the one shape a renderer reads, whatever shape the caller wrote it in.
---
--- A caller writes a duration by name or by number and an easing by name, and a renderer receives a
--- duration in milliseconds, a delay in milliseconds and four control points.
function M.transition(declared)
    if declared == nil or declared == false then
        return nil
    end

    if type(declared) == "string" or type(declared) == "number" then
        declared = { duration = declared }
    end

    if type(declared) ~= "table" then
        error("a transition is a duration, an easing name or a table of both, got " .. type(declared), 2)
    end

    local duration = declared.duration or DEFAULT.duration

    if type(duration) == "string" then
        duration = M.durations[duration]

        if duration == nil then
            error("there is no duration named " .. tostring(declared.duration), 2)
        end
    end

    -- A component may normalise a transition of its own and hand it on, so a curve that is already
    -- four numbers is taken as it is rather than looked up by a name it no longer has.
    local name = declared.easing or DEFAULT.easing
    local easing = type(name) == "table" and name or M.easings[name]

    if easing == nil then
        error("there is no easing named " .. tostring(name), 2)
    end

    return {
        duration = duration,
        delay = declared.delay or DEFAULT.delay,
        easing = { easing[1], easing[2], easing[3], easing[4] },
    }
end

--- The states a node is animated from as it arrives and towards as it leaves, by the name of the move.
---
--- Only opacity and the transform are animated, since neither moves what the layout worked out, so a
--- node keeps the frame it was given however it is faded, slid or scaled.
M.transitions = {
    none = { enter = {}, exit = {} },
    fade = { enter = { opacity = 0 }, exit = { opacity = 0 } },
    scale = {
        enter = { opacity = 0, transform = { scale = 0.92 } },
        exit = { opacity = 0, transform = { scale = 0.92 } },
    },
    slideUp = {
        enter = { opacity = 0, transform = { translateY = 40 } },
        exit = { opacity = 0, transform = { translateY = 40 } },
    },
    slideDown = {
        enter = { opacity = 0, transform = { translateY = -40 } },
        exit = { opacity = 0, transform = { translateY = -40 } },
    },
    slideLeft = {
        enter = { opacity = 0, transform = { translateX = 40 } },
        exit = { opacity = 0, transform = { translateX = 40 } },
    },
    slideRight = {
        enter = { opacity = 0, transform = { translateX = -40 } },
        exit = { opacity = 0, transform = { translateX = -40 } },
    },
}

--- Answers the pair of states a named move is made of, or the pair a caller wrote out in full.
function M.states(declared)
    if declared == nil then
        return M.transitions.none
    end

    if type(declared) == "string" then
        local named = M.transitions[declared]

        if named == nil then
            error("there is no transition named " .. declared, 2)
        end

        return named
    end

    if type(declared) ~= "table" then
        error("a transition is a name or a table of an enter and an exit state, got " .. type(declared), 2)
    end

    return { enter = declared.enter or {}, exit = declared.exit or {} }
end

--- Answers the names a caller may write, which the reference and the demo are both built from.
function M.names()
    local found = {}

    for name in pairs(M.transitions) do
        found[#found + 1] = name
    end

    table.sort(found)
    return found
end

return M
