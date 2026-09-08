local M = {}

local Cache = {}
Cache.__index = Cache

--- Answers what was stored under a key, and marks it as the most recently wanted.
function Cache:get(key)
    local held = self.values[key]

    if held == nil then
        return nil
    end

    self.age = self.age + 1
    self.ages[key] = self.age
    return held
end

--- Drops the entry that has gone longest without being asked for.
function Cache:evict()
    local oldest = nil
    local at = nil

    for key, age in pairs(self.ages) do
        if oldest == nil or age < oldest then
            oldest = age
            at = key
        end
    end

    if at ~= nil then
        self.values[at] = nil
        self.ages[at] = nil
        self.count = self.count - 1
    end
end

function Cache:set(key, value)
    if self.values[key] == nil then
        self.count = self.count + 1
    end

    self.age = self.age + 1
    self.values[key] = value
    self.ages[key] = self.age

    while self.count > self.limit do
        self:evict()
    end
end

function Cache:clear()
    self.values = {}
    self.ages = {}
    self.count = 0
end

--- Builds a store that holds a bounded number of entries and gives up the coldest one to stay inside it.
---
--- Anything keyed by something an application produces over and over — a clock's text, a picture's
--- bytes — grows for as long as the process runs, and a screen that has been drawn for an hour is not a
--- reason to have kept every string it ever showed.
function M.create(limit)
    return setmetatable({
        limit = limit,
        values = {},
        ages = {},
        count = 0,
        age = 0,
    }, Cache)
end

return M
