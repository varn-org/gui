local element = require("gui.element")

local M = {}

local scheduler = nil

--- The value a caller sets a state field to when it wants the field gone.
---
--- A nil in a table is invisible to `pairs`, so a state field could otherwise never be cleared: the
--- change would simply not be seen.
M.none = setmetatable({}, { __tostring = function() return "none" end })

--- Points the component layer at the scheduler that owns commits.
function M.useScheduler(value)
    scheduler = value
end

local function copy(source)
    local result = {}

    if source ~= nil then
        for key, value in pairs(source) do
            result[key] = value
        end
    end

    return result
end

local RESERVED = {
    render = true,
    state = true,
    name = true,
    onMount = true,
    onUpdate = true,
    onUnmount = true,
}

local Instance = {}
Instance.__index = Instance

--- Merges the given fields into the state and asks for a commit, which happens once however often this is called.
function Instance:setState(changes)
    if self.rendering then
        error("setState cannot be called from inside render, since a commit would then run inside a commit", 2)
    end

    for key, value in pairs(changes) do
        self.state[key] = value ~= M.none and value or nil
    end

    if self.mounted and scheduler ~= nil then
        scheduler.markDirty(self.node)
    end
end

function Instance:render()
    self.rendering = true
    local ok, rendered = pcall(self.definition.render, self)
    self.rendering = false

    if not ok then
        error(rendered, 0)
    end

    return rendered
end

--- Declares a component, answering a constructor that takes props and children like any other element.
---
--- The definition carries `render`, an optional initial `state`, and the optional `onMount`, `onUpdate`
--- and `onUnmount` callbacks. A definition without state is a component that only describes.
function M.define(definition)
    if type(definition) == "function" then
        definition = { render = definition }
    end

    if type(definition.render) ~= "function" then
        error("a component needs a render function", 2)
    end

    -- A definition may carry helper methods beside render, and an instance reaches them like any other.
    local methods = setmetatable({}, { __index = Instance })
    for key, value in pairs(definition) do
        if type(value) == "function" and not RESERVED[key] then
            methods[key] = value
        end
    end

    local metatable = { __index = methods }

    local kind = {
        name = definition.name,
        definition = definition,
    }

    function kind.instantiate(props, children, node)
        local instance = setmetatable({
            definition = definition,
            props = props,
            children = children,
            state = copy(definition.state),
            node = node,
            mounted = true,
            rendering = false,
        }, metatable)

        instance.onMount = definition.onMount
        instance.onUpdate = definition.onUpdate
        instance.onUnmount = definition.onUnmount
        return instance
    end

    local build = element.define(kind)

    local constructor = function(spec)
        return build(spec)
    end

    -- The kind is what the retained tree stores as a node's type, so a context reads it to find its provider.
    kind.constructor = constructor
    return constructor, kind
end

return M
