local protocol = require("gui.bridge.protocol")

local M = {}

--- The text the removed sentinel travels as, since a table cannot carry nil across the bridge.
M.removed = "__varn_removed__"

--- The value a handler travels as, which tells a renderer to bind the event and report it back by name.
M.bound = true

local encodeValue

--- Encodes a table, keeping an array an array so a renderer reading json sees the shape Lua built.
local function encodeTable(value, seen)
    if seen[value] then
        error("a prop holds a cycle, which cannot cross the bridge", 0)
    end

    seen[value] = true
    local result = {}

    for key, entry in pairs(value) do
        local encoded = encodeValue(entry, seen)
        if encoded ~= nil then
            result[key] = encoded
        end
    end

    seen[value] = nil
    return result
end

encodeValue = function(value, seen)
    local kind = type(value)

    if value == protocol.removed then
        return M.removed
    end

    if kind == "function" then
        return M.bound
    end

    if kind == "table" then
        return encodeTable(value, seen)
    end

    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    end

    return nil
end

--- Encodes one batch into the shape a renderer receives, which is json and nothing else.
---
--- A handler becomes a marker rather than travelling, since the renderer reports an event by the name
--- of the prop that declared it and the runtime finds the function again on this side.
function M.encode(ops)
    local encoded = {}
    local seen = {}

    for index = 1, #ops do
        local op = ops[index]
        local copy = {}

        for key, value in pairs(op) do
            copy[key] = key == "props" and encodeTable(value, seen) or value
        end

        encoded[index] = copy
    end

    return encoded
end

return M
