local M = {}

--- The wire version a renderer checks before it applies anything.
M.version = 1

--- The value an update carries for a prop the new description no longer has.
---
--- A renderer answering this must clear the prop rather than set it, since nil cannot travel in a table.
M.removed = setmetatable({}, { __tostring = function() return "removed" end })

--- The operations a commit can carry, which is the whole contract a renderer implements.
M.operations = {
    create = "create",
    update = "update",
    insert = "insert",
    move = "move",
    remove = "remove",
    frame = "frame",
}

local REQUIRED = {
    create = { "id", "type" },
    update = { "id", "props" },
    insert = { "id", "parent", "index" },
    move = { "id", "parent", "index" },
    remove = { "id" },
    frame = { "id", "x", "y", "width", "height" },
}

--- Checks a batch against the contract, answering the first thing wrong with it.
---
--- A renderer never has to guard against a malformed batch, because this runs before one is sent.
function M.validate(ops)
    for index = 1, #ops do
        local op = ops[index]
        local required = REQUIRED[op.op]

        if required == nil then
            return "operation " .. index .. " has an unknown op " .. tostring(op.op)
        end

        for field = 1, #required do
            if op[required[field]] == nil then
                return "operation " .. index .. " of kind " .. op.op .. " is missing " .. required[field]
            end
        end
    end

    return nil
end

return M
