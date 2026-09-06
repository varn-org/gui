local M = {}

local Ref = {}
Ref.__index = Ref

--- Answers the node this ref points at, or nil while it is not mounted.
function Ref:get()
    return self.current
end

--- Calls an imperative action on the node, which is how a field is focused or a list scrolled.
function Ref:call(method, arguments)
    if self.current == nil then
        error("the ref points at nothing, so " .. method .. " has nowhere to go", 2)
    end

    return self.current.call(method, arguments)
end

--- Builds a handle a component holds to reach one node imperatively.
function M.create()
    return setmetatable({ current = nil }, Ref)
end

--- Answers whether a value is a ref, which the runtime checks before filling one in.
function M.isRef(value)
    return getmetatable(value) == Ref
end

M.metatable = Ref

return M
