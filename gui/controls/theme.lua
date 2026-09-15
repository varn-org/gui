local M = {}

--- The kinds of control there are, and the parts each of them is painted in.
---
--- This is a register rather than a list. A control the library does not ship is declared through `kind`
--- and is then a control in every sense: a control theme may carry an entry for it, `define` checks that
--- entry exactly as it checks a switch, and nothing about it is a second class of thing. The ones that
--- ship register themselves through the same call.
---
--- A theme that leaves a kind out draws nothing where that control was written, and one that names a part
--- its kind has not got is a field nothing reads. Both are mistakes in a table rather than states to
--- recover from, so both are refused where the theme is written.
local CONTROLS = {}

--- The states a part may be painted differently in, which every paint table is keyed by.
---
--- `rest` is what a part is when nothing is happening to it and is the one state a paint table must
--- carry, since every other state falls back to it rather than to nothing.
local STATES = { "rest", "on", "pressed", "hovered", "focused", "disabled", "disabledOn", "invalid" }

--- The value a control theme names where the platform draws the control rather than the engine.
M.platform = setmetatable({}, { __tostring = function() return "platform" end })

--- How a press is answered, which is the one part of a control theme that is behaviour rather than paint.
local PRESSES = { "ripple", "highlight", "scale", "none" }

local Theme = {}
Theme.__index = Theme

--- Answers what a control is drawn from, which is what this theme says or what the kind declared.
---
--- The fallback is read here rather than folded in when the theme is built, since a kind registered after
--- a theme was written has to reach the themes that already exist — including the four the library ships,
--- which are built the moment the library is loaded.
function Theme:of(control)
    local entry = self.controls[control] or M.defaultOf(control)

    if entry == nil then
        error("the " .. self.name .. " controls say nothing about a " .. control, 2)
    end

    return entry
end

--- Answers whether the platform draws this control rather than the engine.
function Theme:isPlatform(control)
    return self:of(control) == M.platform
end

--- Answers the colour role a part takes in the state it is in, falling back through to `rest`.
---
--- A state is a refinement rather than a separate painting: a switch that is on and pressed is painted
--- as one that is on unless the theme says what pressing does to it, so a theme carries only what it
--- actually changes.
function Theme:paint(control, part, state)
    local entry = self:of(control)
    local painted = entry.paint[part]

    if painted == nil then
        error("the " .. self.name .. " controls paint no part named " .. part .. " on a " .. control, 2)
    end

    for index = 1, #state do
        local named = painted[state[index]]

        if named ~= nil then
            return named
        end
    end

    return painted.rest
end

--- Answers a measurement a control is drawn at, refusing one the theme does not carry.
function Theme:metric(control, name)
    local value = self:of(control).metrics[name]

    if value == nil then
        error("the " .. self.name .. " controls carry no " .. name .. " for a " .. control, 2)
    end

    return value
end

--- Answers how a control moves between its states, which is a duration and a curve.
function Theme:motion(control)
    return self:of(control).motion
end

--- Answers the ring drawn around whatever the keyboard has reached, which is one thing for a whole design.
---
--- A focus ring is the same on every control a design draws, so it is carried once rather than as a
--- state on every part of every control. A design that wants none says a width of nothing.
function Theme:focus()
    return self.focusRing
end

--- Answers what a finger does to a control, which is the theme's rather than the control's.
function Theme:press(control)
    return self:of(control).press
end

--- Answers the component this theme draws a control with, or nothing where the library's own draws it.
---
--- Metrics and paint reshape a control and cannot rebuild one. A design that wants a switch with its
--- words inside the track, or a slider drawn as a dial, writes the component and changes nothing else
--- about the theme it came from.
function Theme:drawing(control)
    local entry = self:of(control)

    if entry == M.platform then
        return nil
    end

    return entry.draw
end

local function wrongEntry(control, entry)
    if entry == M.platform then
        return nil
    end

    if type(entry) ~= "table" then
        return "a " .. control .. " is drawn from a table of parts, or by the platform, got a " .. type(entry)
    end

    if type(entry.metrics) ~= "table" then
        return "a " .. control .. " carries the sizes it is drawn at under metrics"
    end

    if type(entry.paint) ~= "table" then
        return "a " .. control .. " carries a colour role per part under paint"
    end

    if not M.oneOf(entry.press, PRESSES) then
        return "a " .. control .. " answers a press with one of " .. table.concat(PRESSES, ", ")
            .. ", got " .. tostring(entry.press)
    end

    if type(entry.motion) ~= "table" or type(entry.motion.duration) ~= "number" then
        return "a " .. control .. " moves over a duration in milliseconds"
    end

    if entry.draw ~= nil and type(entry.draw) ~= "function" then
        return "a " .. control .. " is drawn by a component, which is what gui.component() answers"
    end

    local parts = CONTROLS[control]

    for part, painted in pairs(entry.paint) do
        if not parts[part] then
            return "a " .. control .. " has no part named " .. part
        end

        if type(painted) ~= "table" or painted.rest == nil then
            return "the " .. part .. " of a " .. control .. " is painted per state, and rest is the one it needs"
        end

        for state in pairs(painted) do
            if not M.oneOf(state, STATES) then
                return "the " .. part .. " of a " .. control .. " is painted in no state named " .. state
            end
        end
    end

    return nil
end

--- Answers whether a value is one of a set, which is what a field with a fixed set of values needs.
function M.oneOf(value, choices)
    for index = 1, #choices do
        if value == choices[index] then
            return true
        end
    end

    return false
end

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, held in pairs(value) do
        result[key] = copy(held)
    end

    return result
end

local function merge(base, over)
    if over == nil then
        return copy(base)
    end

    if type(base) ~= "table" or type(over) ~= "table" or base == M.platform or over == M.platform then
        return copy(over)
    end

    local result = copy(base)

    for key, value in pairs(over) do
        result[key] = merge(result[key], value)
    end

    return result
end

--- What a kind is drawn with where a control theme says nothing about it.
---
--- A kind registered after a control theme was written would otherwise make that theme incomplete, so a
--- control somebody adds would break the four the library ships and every one an application had already
--- written. A kind brings the entry it is drawn with by default and a theme writes over what it wants to
--- change, so adding a control breaks nothing and shaping it stays the theme's to do.
local DEFAULTS = {}

--- Answers how a kind is drawn where a control theme says nothing about it, or nothing when none was given.
function M.defaultOf(control)
    return DEFAULTS[control]
end

--- Declares a kind of control and the parts it is painted in, answering the name it was given.
---
--- A kind is declared once for the process. Declaring one twice with the same parts is the same
--- declaration arriving again, which a module loaded from two places is, and declaring one twice with
--- different parts is two controls fighting over a name.
function M.kind(name, declaration)
    if type(name) ~= "string" or name == "" then
        error("a kind of control is named with a string", 2)
    end

    local parts = declaration ~= nil and declaration.parts or nil

    if type(parts) ~= "table" or #parts == 0 then
        error("a " .. name .. " is painted in parts, which is a list of at least one name", 2)
    end

    local held = {}

    for index = 1, #parts do
        if type(parts[index]) ~= "string" then
            error("a part of a " .. name .. " is named with a string", 2)
        end

        held[parts[index]] = true
    end

    local existing = CONTROLS[name]

    if existing ~= nil then
        for part in pairs(held) do
            if not existing[part] then
                error("a " .. name .. " is already a kind of control, painted in other parts", 2)
            end
        end

        for part in pairs(existing) do
            if not held[part] then
                error("a " .. name .. " is already a kind of control, painted in other parts", 2)
            end
        end

        return name
    end

    CONTROLS[name] = held

    if declaration.default ~= nil then
        local wrong = wrongEntry(name, declaration.default)

        if wrong ~= nil then
            CONTROLS[name] = nil
            error("a " .. name .. " is drawn by default as: " .. wrong, 2)
        end

        DEFAULTS[name] = declaration.default
    end

    return name
end

--- Answers every kind there is, which is what a theme is checked against and what the docs are built from.
function M.kinds()
    local found = {}

    for name in pairs(CONTROLS) do
        found[#found + 1] = name
    end

    table.sort(found)
    return found
end

--- Answers the parts a kind is painted in.
function M.partsOf(name)
    local held = CONTROLS[name]

    if held == nil then
        error("there is no kind of control called " .. tostring(name), 2)
    end

    local found = {}

    for part in pairs(held) do
        found[#found + 1] = part
    end

    table.sort(found)
    return found
end

--- The kinds nothing hands to a platform, which carry the entry they are drawn with.
---
--- None of these is a control any system draws: what a platform has instead is a different control with
--- a different behaviour, or nothing. Each is drawn by the engine under every control theme, so each
--- brings a neutral design and a theme writes over what it wants to change — which is also what keeps a
--- theme written before one of them existed from being incomplete.
local ALWAYS = {
    tabbar = {
        parts = { "container", "indicator", "icon", "label" },
        default = {
            metrics = { height = 56, indicator = 0, indicatorWidth = 0, radius = "pill", gap = 2, rule = 1 },
            paint = {
                container = { rest = "background" },
                indicator = { rest = "background", on = "primary" },
                icon = { rest = "textMuted", on = "primary" },
                label = { rest = "textMuted", on = "primary" },
            },
            motion = { duration = 200 },
            press = "highlight",
        },
    },

    chip = {
        parts = { "container", "label", "outline" },
        default = {
            metrics = { height = 32, radius = "pill", border = 1, paddingHorizontal = 12, gap = 6 },
            paint = {
                container = { rest = "surface", on = "primary", disabled = "disabledSurface" },
                label = { rest = "text", on = "onPrimary", disabled = "disabledText" },
                outline = { rest = "border", on = "primary" },
            },
            motion = { duration = 150 },
            press = "highlight",
        },
    },

    badge = {
        parts = { "container", "label" },
        default = {
            metrics = { size = 18, radius = "pill", paddingHorizontal = 5, dot = 8 },
            paint = { container = { rest = "danger" }, label = { rest = "onPrimary" } },
            motion = { duration = 150 },
            press = "none",
        },
    },

    avatar = {
        parts = { "container", "label" },
        default = {
            metrics = { radius = "pill", border = 0 },
            paint = { container = { rest = "surface" }, label = { rest = "textMuted" } },
            motion = { duration = 150 },
            press = "none",
        },
    },

    skeleton = {
        parts = { "block", "shimmer" },
        default = {
            metrics = { radius = "sm", height = 14, gap = 8 },
            paint = { block = { rest = "surface" }, shimmer = { rest = "background" } },
            motion = { duration = 1200 },
            press = "none",
        },
    },

    accordion = {
        parts = { "row", "label", "chevron" },
        default = {
            metrics = { row = 52, radius = "md", gap = 8, chevron = 20, paddingHorizontal = 12 },
            paint = {
                row = { rest = "surface", on = "surface" },
                label = { rest = "text", on = "text" },
                chevron = { rest = "textMuted" },
            },
            motion = { duration = 200 },
            press = "highlight",
        },
    },

    collection = {
        parts = { "separator", "dot", "header" },
        default = {
            metrics = { separator = 1, separatorInset = 0, dot = 7, dotGap = 6, header = 36 },
            paint = {
                separator = { rest = "separator" },
                dot = { rest = "separator", on = "primary" },
                header = { rest = "textMuted" },
            },
            motion = { duration = 200 },
            press = "none",
        },
    },

    overlay = {
        parts = { "panel", "scrim", "title", "message", "action" },
        default = {
            metrics = { radius = "lg", padding = 20, gap = 12, elevation = "lg", sheetRadius = "lg" },
            paint = {
                panel = { rest = "elevated" },
                scrim = { rest = "overlay" },
                title = { rest = "text" },
                message = { rest = "textMuted" },
                action = { rest = "primary", invalid = "danger" },
            },
            motion = { duration = 250 },
            press = "highlight",
        },
    },
}

for name, declaration in pairs(ALWAYS) do
    M.kind(name, declaration)
end

--- Answers whether a kind is one no platform draws, which a theme handing everything over has to skip.
function M.alwaysDrawn(name)
    return ALWAYS[name] ~= nil or DEFAULTS[name] ~= nil
end

--- The kinds the library ships, declared the same way anything else declares one.
for name, parts in pairs({
    button = { "container", "label", "ripple", "tint", "outline" },
    checkbox = { "box", "mark", "label" },
    radio = { "ring", "dot", "label" },
    switch = { "track", "thumb", "mark" },
    slider = { "track", "fill", "thumb", "tick" },
    stepper = { "container", "button", "value" },
    segmented = { "track", "segment", "label" },
    select = { "field", "label", "indicator", "menu", "option" },
    rating = { "mark" },
    field = { "container", "label", "text", "helper", "indicator" },
    progress = { "track", "fill" },
    swatches = { "swatch", "mark", "outline" },
    card = { "container", "outline" },
    tooltip = { "container", "label" },
    calendar = { "day", "number", "weekday" },
    clock = { "face", "number", "hand" },

    spinner = { "arc" },
}) do
    M.kind(name, { parts = parts })
end

--- Builds a control theme, refusing one that is not a complete set of controls.
function M.define(spec)
    if type(spec) ~= "table" or type(spec.name) ~= "string" then
        error("a control theme is a table carrying a name and an entry per control", 2)
    end

    local controls = {}

    for control in pairs(CONTROLS) do
        local entry = spec.controls ~= nil and spec.controls[control] or nil

        if entry == nil and DEFAULTS[control] == nil then
            error("the " .. spec.name .. " controls say nothing about a " .. control, 2)
        end

        if entry ~= nil and entry ~= M.platform and DEFAULTS[control] ~= nil then
            entry = merge(DEFAULTS[control], entry)
        end

        if entry ~= nil then
            local wrong = wrongEntry(control, entry)

            if wrong ~= nil then
                error("the " .. spec.name .. " controls: " .. wrong, 2)
            end

            controls[control] = entry
        end
    end

    for control in pairs(spec.controls) do
        if CONTROLS[control] == nil then
            error("the " .. spec.name .. " controls describe a " .. control .. ", which is not a control", 2)
        end
    end

    local ring = spec.focus or { width = 2, color = "primary", offset = 2 }

    if type(ring) ~= "table" or type(ring.width) ~= "number" or type(ring.color) ~= "string" then
        error("the " .. spec.name .. " controls draw a focus ring of a width in points and a colour role", 2)
    end

    return setmetatable({
        name = spec.name,
        controls = controls,
        focusRing = { width = ring.width, color = ring.color, offset = ring.offset or 2 },
    }, Theme)
end

--- Builds a control theme from another one with whatever it changes written over it.
---
--- A design somebody wants is nearly always one that ships with a few things different, and writing the
--- whole set again to change a corner radius is how two of them drift apart.
function M.extend(base, spec)
    if getmetatable(base) ~= Theme then
        error("a control theme is extended from another control theme", 2)
    end

    return M.define({
        name = spec.name or base.name,
        focus = spec.focus or base.focusRing,
        controls = merge(base.controls, spec.controls),
    })
end

--- Answers whether a value is a control theme rather than a table that looks like one.
function M.isTheme(value)
    return getmetatable(value) == Theme
end

M.states = STATES

return M
