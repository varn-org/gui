local M = {}

local Ref = {}
Ref.__index = Ref

--- Answers the node this ref points at, or nil while it is not mounted.
function Ref:get()
    return self.current
end

--- Calls an imperative action on the node, answering whether there was anything to call it on.
---
--- A ref is held across time — a timer that scrolls a list, a handler that focuses a field after an
--- answer comes back — and by then the screen may have gone. That is life rather than a mistake, so an
--- empty ref answers no, and `get` is there for a caller that wants to look first.
function Ref:call(method, arguments)
    if self.current == nil then
        return false
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


return M
