local element = require("gui.element")
local natural = require("gui.layout.natural")

local M = {}

--- What each component declares, keyed by the constructor a caller holds.
---
--- The declaration is what refuses an unknown prop, and it is also what the reference page is built
--- from, so a component cannot document a prop it does not accept.
M.declarations = setmetatable({}, { __mode = "k" })

--- Wraps a constructor in the checks a declaration asks for, answering the constructor a caller uses.
local function guard(kind, declaration, build, host)
    declaration = declaration or {}

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

    -- Anything on screen can be named for a reader who cannot see it, so this is not a prop a component
    -- has to declare before it may be labelled.
    allowed.accessibilityLabel = true

    local constructor = function(spec)
        spec = spec or {}

        for name in pairs(spec) do
            if type(name) == "string" and not allowed[name] then
                error(kind .. " has no prop named " .. name, 2)
            end
        end

        if declaration.defaults ~= nil then
            for name, value in pairs(declaration.defaults) do
                if spec[name] == nil then
                    spec[name] = value
                end
            end
        end

        -- A control whose words live in a prop of its own is called by those words, so a reader who
        -- cannot see it hears what everyone else reads rather than nothing at all.
        if spec.accessibilityLabel == nil and declaration.natural ~= nil and declaration.natural.text ~= nil then
            spec.accessibilityLabel = natural.textOf(kind, spec)
        end

        if declaration.style ~= nil then
            local declared = declaration.style

            if type(declared) == "function" then
                declared = declared(spec)
            end

            spec.style = M.styled(declared, spec.style)
        end

        if declaration.validate ~= nil then
            local problem = declaration.validate(spec)
            if problem ~= nil then
                error(kind .. ": " .. problem, 2)
            end
        end

        return build(spec)
    end

    M.declarations[constructor] = {
        kind = kind,
        host = host,
        props = declaration.props or {},
        events = declaration.events or {},
        defaults = declaration.defaults or {},
        natural = declaration.natural,
    }

    natural.declare(kind, declaration.natural)

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
function M.component(name, declaration, constructor)
    return guard(name, declaration, constructor, false)
end

--- Answers the style a node draws with, which is what its type declares unless the caller said otherwise.
---
--- A control that carries no look of its own draws as bare text on every platform, so the look belongs
--- to the component rather than to each screen that happens to use it. It is written in theme names, so
--- a control follows the reader's appearance the way everything else does.
function M.styled(declared, given)
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
