local M = {}

local Observable = {}
Observable.__index = Observable

--- Answers what it holds without listening, which is what a handler between renders asks.
function Observable:get()
    return self.value
end

--- Answers what it holds and remembers who asked, so a change renders that component again.
---
--- Reading it from a render is what binds the two: the component that drew the value is the only one
--- rendered when it changes, rather than the one that happens to own it and everything under that.
function Observable:read(instance)
    if type(instance) ~= "table" or instance.node == nil then
        error("an observable is read by a component, which is what self is inside render", 2)
    end

    self.readers[instance] = true
    return self.value
end

--- Writes what it holds and tells whoever was reading it.
---
--- Writing the same value is not a change, so a handler that answers with what is already there costs
--- nothing rather than a commit. What is on screen and what is gone are told apart here as well: a
--- component that has been unmounted is dropped rather than marked dirty in a tree it left.
function Observable:set(value)
    if self.value == value then
        return value
    end

    local was = self.value
    self.value = value

    for instance in pairs(self.readers) do
        if not instance.mounted then
            self.readers[instance] = nil
        elseif instance.scheduler ~= nil then
            instance.scheduler.markDirty(instance.node)
        end
    end

    -- A listener may write, and a listener may stop listening from inside itself, so what is called is
    -- the set as it stood rather than the set as it is being changed.
    local listening = {}

    for listener in pairs(self.listeners) do
        listening[#listening + 1] = listener
    end

    for index = 1, #listening do
        if self.listeners[listening[index]] then
            listening[index](value, was)
        end
    end

    return value
end

--- Writes what the work makes of what is there, which is what a counter and a toggle both want.
function Observable:update(work)
    if type(work) ~= "function" then
        error("an observable is updated with a function of what it holds, got a " .. type(work), 2)
    end

    return self:set(work(self.value))
end

--- Listens from outside a component, answering the function that stops listening.
---
--- A screen binds by reading, and everything else — a player, a socket, a game loop — subscribes. What
--- is subscribed is held until it is let go of, so a subscription is released with whatever opened it.
function Observable:subscribe(listener)
    if type(listener) ~= "function" then
        error("an observable is subscribed to with a function, got a " .. type(listener), 2)
    end

    self.listeners[listener] = true

    return function()
        self.listeners[listener] = nil
    end
end

--- Answers a value a screen can bind to, which anything may write and only what read it is drawn again.
function M.create(value)
    return setmetatable({
        value = value,
        readers = setmetatable({}, { __mode = "k" }),
        listeners = {},
    }, Observable)
end

--- Answers whether something is one, which is what a component asks before it binds to a prop.
function M.is(value)
    return type(value) == "table" and getmetatable(value) == Observable
end

return M
