local element = require("gui.element")
local natural = require("gui.layout.natural")
local ref = require("gui.ref")

local M = {}

--- The whole surface, which is what anything shown over a screen is placed against.
local COVER = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0 }

--- Answers a style that fills the surface, with whatever else the caller asked for on top of it.
function M.cover(style)
    local box = {}

    for key, value in pairs(COVER) do
        box[key] = value
    end

    for key, value in pairs(style or {}) do
        box[key] = value
    end

    return box
end

--- What each component declares, keyed by the constructor a caller holds.
---
--- The declaration is what refuses an unknown prop, and it is also what the reference page is built
--- from, so a component cannot document a prop it does not accept.
---
--- `actions` names what a caller may ask of the node through a ref. An action is a promise like a prop,
--- so the suite holds every one of them to being answered by all three renderers rather than by one.
M.declarations = setmetatable({}, { __mode = "k" })

--- What a box says it is to a reader who cannot see it, which every platform has a name of its own for.
---
--- A control the platform draws says this for itself. One the engine draws is a box with a colour in it,
--- and to a screen reader that is what it stays unless the tree says otherwise — so a drawn checkbox
--- that names no role is a checkbox nobody using VoiceOver or TalkBack can find, let alone tick.
local ROLES = {
    "button", "link", "checkbox", "radio", "switch", "slider", "header", "image",
    "progressbar", "tab", "list", "listitem", "search", "none",
}

local ROLE = {}
for index = 1, #ROLES do
    ROLE[ROLES[index]] = true
end

--- What a box says about itself beyond its role, which is what makes a tick read as ticked.
local STATE = { checked = true, selected = true, disabled = true, expanded = true, busy = true }

--- What a box that holds a number says it is at, which is what lets a reader step a slider by voice.
local READING = { now = true, least = true, most = true, text = true }

--- The props every node takes whatever it is, and what each of them has to be.
---
--- A key that is not a string or a number is a node that never matches the one it was last time, since
--- what two renders build are two different tables: the node is replaced on every commit, losing its
--- state and everything under it. A label and a test name are read as strings by three renderers and
--- ignored as anything else, and a ref is what `gui.ref()` answers rather than any table at all.
local UNIVERSAL = {
    key = {
        shape = "a string or a number",
        is = function(value) return type(value) == "string" or type(value) == "number" end,
    },
    testID = {
        shape = "a string",
        is = function(value) return type(value) == "string" end,
    },
    accessibilityLabel = {
        shape = "a string",
        is = function(value) return type(value) == "string" end,
    },
    style = {
        shape = "a table of fields, or a list of them",
        is = function(value) return type(value) == "table" end,
    },
    ref = {
        shape = "what gui.ref() answers",
        is = ref.isRef,
    },
    accessibilityRole = {
        shape = "one of " .. table.concat(ROLES, ", "),
        is = function(value) return ROLE[value] == true end,
    },
    accessibilityState = {
        shape = "a table of checked, selected, disabled, expanded or busy",
        is = function(value)
            if type(value) ~= "table" then
                return false
            end

            for name in pairs(value) do
                if not STATE[name] then
                    return false
                end
            end

            return true
        end,
    },
    accessibilityValue = {
        shape = "a table of now, least, most or text",
        is = function(value)
            if type(value) ~= "table" then
                return false
            end

            for name in pairs(value) do
                if not READING[name] then
                    return false
                end
            end

            return true
        end,
    },
}

--- Answers the style a node draws with, which is what its type declares unless the caller said otherwise.
---
--- A control that carries no look of its own draws as bare text on every platform, so the look belongs
--- to the component rather than to each screen that happens to use it. It is written in theme names, so
--- a control follows the reader's appearance the way everything else does.
local function styled(declared, given)
    local merged = {}

    for key, value in pairs(declared) do
        merged[key] = value
    end

    if given == nil then
        return merged
    end

    local entries = { given }

    if given[1] ~= nil then
        entries = given
    end

    for index = 1, #entries do
        local entry = entries[index]

        if type(entry) == "table" then
            for key, value in pairs(entry) do
                merged[key] = value
            end
        end
    end

    return merged
end

--- Wraps a constructor in the checks a declaration asks for, answering the constructor a caller uses.
local function guard(kind, declaration, build, host)
    declaration = declaration or {}

    local reported = {}
    for index = 1, #(declaration.events or {}) do
        reported[declaration.events[index]] = true
    end

    local allowed = {}
    for index = 1, #(declaration.props or {}) do
        allowed[declaration.props[index]] = true
    end

    for index = 1, #(declaration.events or {}) do
        allowed[declaration.events[index]] = true
    end

    allowed.key = true
    allowed.style = true
    allowed.ref = true
    allowed.testID = true

    -- Anything on screen may arrive and change over time rather than all at once, so how it moves is
    -- not a prop each type has to declare before it may be animated.
    allowed.transition = true
    allowed.enter = true

    -- Anything on screen can be named for a reader who cannot see it, and can say what it is, what it is
    -- doing and what it is at, so none of these is a prop a component has to declare before it may say so.
    allowed.accessibilityLabel = true
    allowed.accessibilityRole = true
    allowed.accessibilityState = true
    allowed.accessibilityValue = true

    -- Anything on screen may be told to let a finger through it, since what is drawn over a control is
    -- not always meant to take the press aimed at it: a picture over the button that chose it is one.
    allowed.pointerEvents = true

    -- Where a node ended up is answered by the engine's own layout rather than by any renderer, on every
    -- node that asks, so it is not a prop a component has to declare before it may ask.
    allowed.onLayout = true

    local constructor = function(spec)
        spec = spec or {}

        for name, value in pairs(spec) do
            if type(name) == "string" and not allowed[name] then
                error(kind .. " has no prop named " .. name, 2)
            end

            if reported[name] and type(value) ~= "function" then
                error(kind .. ": " .. name .. " is answered with a function, got a " .. type(value), 2)
            end

            local universal = UNIVERSAL[name]

            if universal ~= nil and not universal.is(value) then
                error(kind .. ": " .. name .. " is " .. universal.shape .. ", got a " .. type(value), 2)
            end
        end

        if declaration.defaults ~= nil then
            for name, value in pairs(declaration.defaults) do
                if spec[name] == nil then
                    spec[name] = value
                end
            end
        end

        if declaration.style ~= nil then
            local declared = declaration.style

            if type(declared) == "function" then
                declared = declared(spec)
            end

            spec.style = styled(declared, spec.style)
        end

        -- A prop a caller may write more than one way is written the one way before it goes anywhere,
        -- so the layout, the runtime and three renderers all read the same shape rather than each
        -- deciding for itself what a shorthand meant.
        if declaration.normalise ~= nil then
            declaration.normalise(spec)
        end

        if declaration.validate ~= nil then
            local problem = declaration.validate(spec)
            if problem ~= nil then
                error(kind .. ": " .. problem, 2)
            end
        end

        -- A control whose words live in a prop of its own is called by those words, so a reader who
        -- cannot see it hears what everyone else reads rather than nothing at all.
        --
        -- It is worked out after the checks rather than before them, since what a control says may be
        -- read out of props the checks are what refuse: a value that is not a document at all reached
        -- the arithmetic that reads its runs, and what a caller saw was an index into nothing.
        if spec.accessibilityLabel == nil and declaration.natural ~= nil and declaration.natural.text ~= nil then
            spec.accessibilityLabel = natural.textOf(declaration.platform or kind, spec)
        end

        return build(spec)
    end

    M.declarations[constructor] = {
        kind = kind,
        host = host,
        platform = declaration.platform,
        props = declaration.props or {},
        events = declaration.events or {},
        actions = declaration.actions or {},
        defaults = declaration.defaults or {},
        natural = declaration.natural,
    }

    -- A component the control theme may hand to the platform is drawn by that host node whenever it
    -- does, and the size the platform gives it belongs to the node rather than to the name above it.
    natural.declare(declaration.platform or kind, declaration.natural)

    return constructor
end

--- Declares a host component, answering a constructor that fills in defaults and refuses unknown props.
---
--- The declaration lists the props a renderer honours, so a typo becomes an error at the call rather
--- than a prop three renderers silently ignore.
function M.host(kind, declaration)
    return guard(kind, declaration, element.define(kind), true)
end

--- Declares a component the same way, so a list validates its props exactly as a host node does.
---
--- The component owns behaviour of its own and renders host nodes underneath, which is why the props
--- it takes never reach a renderer unchanged.
---
--- A component that names a `platform` type is one the control theme may hand to the platform instead of
--- drawing, so its props are held to being honoured by all three renderers as well as by the engine.
function M.component(name, declaration, constructor)
    if type(constructor) ~= "function" then
        error(name .. " is built by a component, got a " .. type(constructor), 2)
    end

    return guard(name, declaration, constructor, false)
end

--- Answers whether a value is one of the choices, which a prop with a fixed set of values needs.
function M.oneOf(value, choices)
    if value == nil then
        return true
    end

    for index = 1, #choices do
        if value == choices[index] then
            return true
        end
    end

    return false
end

--- Builds the message for a prop that was given something outside its set.
function M.expected(name, value, choices)
    return name .. " must be one of " .. table.concat(choices, ", ") .. ", got " .. tostring(value)
end

return M
