local M = {}

local Pool = {}
Pool.__index = Pool

--- Takes a cell of the given type, reusing one that is free when reuse is on.
---
--- A pool is kept per type, so a cell built as a header is never handed back as a row. With reuse
--- off, every entry keeps its own cell, which is what a short list and a cell holding its own state
--- both want.
function Pool:acquire(kind, index)
    if not self.recycle then
        local fresh = { kind = kind, index = index, fresh = true }
        self.live[index] = fresh
        return fresh
    end

    local free = self.free[kind]
    if free ~= nil and #free > 0 then
        local cell = table.remove(free)
        cell.index = index
        cell.fresh = false
        self.live[index] = cell
        return cell
    end

    local cell = { kind = kind, index = index, fresh = true, id = self:claim() }
    self.live[index] = cell
    return cell
end

--- Gives a cell back, so a later entry of the same type may take it.
function Pool:release(index)
    local cell = self.live[index]
    if cell == nil then
        return
    end

    self.live[index] = nil

    if not self.recycle then
        return
    end

    local free = self.free[cell.kind]
    if free == nil then
        free = {}
        self.free[cell.kind] = free
    end

    free[#free + 1] = cell
end

function Pool:claim()
    self.nextId = self.nextId + 1
    return self.nextId
end

--- Answers the cell serving an entry, or nil when that entry is not realised.
function Pool:cellFor(index)
    return self.live[index]
end

--- Answers how many cells of a type are waiting to be reused, which a test reads to prove reuse happened.
function Pool:freeCount(kind)
    local free = self.free[kind]
    return free ~= nil and #free or 0
end

--- Answers how many entries are realised right now.
function Pool:liveCount()
    local total = 0
    for _ in pairs(self.live) do
        total = total + 1
    end

    return total
end

--- Moves the realised set to a new range, releasing what left it and taking cells for what entered.
---
--- Answers the entries that arrived and the ones that left, which is what a renderer applies.
function Pool:reconcile(range, typeOf)
    local wanted = {}
    for index = range.first, range.last do
        wanted[index] = true
    end

    local left = {}
    for index in pairs(self.live) do
        if not wanted[index] then
            left[#left + 1] = index
        end
    end

    table.sort(left)
    for position = 1, #left do
        self:release(left[position])
    end

    local arrived = {}
    for index = range.first, range.last do
        if self.live[index] == nil then
            arrived[#arrived + 1] = { index = index, cell = self:acquire(typeOf(index), index) }
        end
    end

    return arrived, left
end

--- Builds the reuse pools one list owns.
function M.create(options)
    return setmetatable({
        recycle = options.recycle ~= false,
        free = {},
        live = {},
        nextId = 0,
    }, Pool)
end

return M
