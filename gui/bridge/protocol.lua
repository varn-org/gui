local M = {}

--- The value an update carries for a prop the new description no longer has.
---
--- A renderer answering this must clear the prop rather than set it, since nil cannot travel in a table.
M.removed = setmetatable({}, { __tostring = function() return "removed" end })


--- What each operation carries, and what each of those has to be.
---
--- A field of the wrong type reaches every renderer as something it reads as nothing: a width that is
--- a string is a node laid out at nowhere on three platforms rather than a failure named here.
local REQUIRED = {
    create = { id = "number", type = "string" },
    update = { id = "number", props = "table" },
    insert = { id = "number", parent = "number", index = "number" },
    move = { id = "number", parent = "number", index = "number" },
    remove = { id = "number" },
    frame = { id = "number", x = "number", y = "number", width = "number", height = "number" },
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

        for field, kind in pairs(required) do
            local carried = op[field]

            if carried == nil then
                return "operation " .. index .. " of kind " .. op.op .. " is missing " .. field
            end

            if type(carried) ~= kind then
                return "operation " .. index .. " of kind " .. op.op .. " carries " .. field .. " as a "
                    .. type(carried) .. " rather than a " .. kind
            end

            if kind == "number" and carried ~= carried then
                return "operation " .. index .. " of kind " .. op.op .. " carries " .. field
                    .. " as something that is not a number"
            end
        end
    end

    return nil
end

return M
