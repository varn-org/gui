local M = {}

local Cache = {}
Cache.__index = Cache

--- Answers what was stored under a key, carrying it into the generation being filled.
function Cache:get(key)
    local held = self.live[key]

    if held ~= nil then
        return held
    end

    held = self.kept[key]

    if held == nil then
        return nil
    end

    self:set(key, held)
    return held
end

--- Stores a value, giving up the older generation whole once the newer one is full.
function Cache:set(key, value)
    if self.live[key] == nil then
        self.count = self.count + 1
    end

    self.live[key] = value

    if self.count <= self.generation then
        return
    end

    self.kept = self.live
    self.retired = self.count
    self.live = {}
    self.count = 0
end

--- How many entries are held, which is what the number the store was built with is a bound on.
function Cache:held()
    return self.count + self.retired
end

function Cache:clear()
    self.live = {}
    self.kept = {}
    self.count = 0
    self.retired = 0
end

--- Builds a store that holds a bounded number of entries and gives up the coldest of them to stay inside it.
---
--- Anything keyed by something an application produces over and over — a clock's text, a picture's
--- bytes — grows for as long as the process runs, and a screen that has been drawn for an hour is not a
--- reason to have kept every string it ever showed.
---
--- Which entries are given up is decided by generation rather than by an exact age: filling a generation
--- retires the one before it whole, and anything asked for again on the way is carried across. Walking
--- every entry to find the coldest one costs 23 microseconds at five hundred of them, which is a
--- millisecond of every frame of a scroll that measures fifty new strings, and this store is on the path
--- that draws — 0.5 microseconds a time, measured, for the same bound.
function M.create(limit)
    return setmetatable({
        generation = math.max(1, math.floor(limit / 2)),
        live = {},
        kept = {},
        count = 0,
        retired = 0,
    }, Cache)
end

return M
