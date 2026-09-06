local M = {}

local ELEMENT = {}

M.marker = ELEMENT

--- Answers whether a value is an element rather than a prop or a plain table.
function M.isElement(value)
    return type(value) == "table" and rawget(value, "__element") == ELEMENT
end

local function collect(spec)
    local props = {}
    local children = {}
    local highest = 0

    for key, value in pairs(spec) do
        if type(key) == "number" then
            if key > highest then
                highest = key
            end
        else
            props[key] = value
        end
    end

    for index = 1, highest do
        local child = spec[index]

        -- A nil among the children cuts the list short at that point and everything after it is lost
        -- without a word, so a child that is there only sometimes is written as false.
        if child == nil then
            error("the child at position " .. index .. " is nil, which drops every child after it,"
                .. " so a conditional child is written as false rather than nil", 3)
        end

        if child ~= false then
            children[#children + 1] = child
        end
    end

    return props, children
end

local function flatten(children, into)
    for index = 1, #children do
        local child = children[index]

        if M.isElement(child) then
            into[#into + 1] = child
        elseif type(child) == "table" then
            flatten(child, into)
        elseif type(child) == "string" or type(child) == "number" then
            into[#into + 1] = M.new("text", { text = tostring(child) }, {})
        else
            error("a child must be an element, a list of them, or a string, got " .. type(child), 3)
        end
    end

    return into
end

--- Builds an element of the given type from already separated props and children.
function M.new(kind, props, children)
    return {
        __element = ELEMENT,
        type = kind,
        props = props,
        children = children,
        key = props.key,
    }
end

--- Returns a constructor for a node type, taking props and children in one table.
---
--- The array part of the table becomes the children and everything else becomes the props, so a
--- tree is written the way it is read rather than as nested calls with two arguments each.
function M.define(kind)
    return function(spec)
        if spec == nil then
            return M.new(kind, {}, {})
        end

        if type(spec) ~= "table" then
            error("a " .. kind .. " takes a table of props and children, got " .. type(spec), 2)
        end

        local props, children = collect(spec)
        return M.new(kind, props, flatten(children, {}))
    end
end

return M
