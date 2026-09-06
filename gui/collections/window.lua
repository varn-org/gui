local M = {}

local Window = {}
Window.__index = Window

--- Answers the extent one entry occupies along the scrolling axis.
function Window:extentAt(index)
    if self.uniform ~= nil then
        return self.uniform
    end

    if type(self.itemExtent) == "function" then
        return self.itemExtent(self.data[index], index)
    end

    local measured = self.measured[index]
    if measured ~= nil then
        return measured
    end

    return self.estimated
end

--- Records what an entry actually measured, so the offsets below it stop being an estimate.
function Window:measure(index, extent)
    if self.uniform ~= nil or self.measured[index] == extent then
        return false
    end

    self.measured[index] = extent
    self.dirtyFrom = math.min(self.dirtyFrom or index, index)
    return true
end

local function rebuild(self)
    local from = self.dirtyFrom or 1
    local running = 0

    if from > 1 then
        running = self.offsets[from - 1] + self:extentAt(from - 1)
    end

    for index = from, #self.data do
        self.offsets[index] = running
        running = running + self:extentAt(index)
    end

    self.total = running
    self.dirtyFrom = nil
end

local function settle(self)
    if self.uniform == nil and self.dirtyFrom ~= nil then
        rebuild(self)
    end
end

--- Answers the offset an entry starts at.
---
--- A list whose entries are all the same size needs no table of offsets at all, which is what keeps a
--- list of fifty thousand rows costing the same as a list of fifty.
function Window:offsetOf(index)
    if self.uniform ~= nil then
        return (index - 1) * self.uniform
    end

    settle(self)
    return self.offsets[index] or 0
end

--- Answers the extent of the whole list, which is what a scroll bar is sized against.
function Window:totalExtent()
    if self.uniform ~= nil then
        return #self.data * self.uniform
    end

    settle(self)
    return self.total or 0
end

--- Answers the first entry whose end is past an offset, without walking the ones before it.
function Window:indexAt(offset)
    local count = #self.data
    if count == 0 then
        return 1
    end

    if self.uniform ~= nil then
        local index = math.floor(offset / self.uniform) + 1
        return math.max(1, math.min(count, index))
    end

    settle(self)

    local low = 1
    local high = count

    while low < high do
        local middle = (low + high) // 2

        if self.offsets[middle] + self:extentAt(middle) > offset then
            high = middle
        else
            low = middle + 1
        end
    end

    return low
end

--- Answers the range of entries to realise for a viewport, plus the margin the list asked for.
---
--- Only what can be seen, and a margin either side of it, is built. That margin is what keeps a fast
--- scroll from showing an empty cell before the next one is ready.
function Window:visible(scrollOffset, viewportExtent)
    local count = #self.data
    if count == 0 then
        return { first = 1, last = 0, offset = 0 }
    end

    local first = self:indexAt(math.max(0, scrollOffset))
    local edge = scrollOffset + viewportExtent
    local last = first

    for index = first, count do
        if self:offsetOf(index) >= edge then
            break
        end

        last = index
    end

    local margin = self.margin
    local from = math.max(1, first - margin)

    return {
        first = from,
        last = math.min(count, last + margin),
        offset = self:offsetOf(from),
    }
end

--- Answers the type name of an entry, which decides the reuse pool a cell comes from.
function Window:typeOf(index)
    if self.itemType == nil then
        return "default"
    end

    return self.itemType(self.data[index], index)
end

--- Answers the identity of an entry, which is what keeps a cell attached to its data across a change.
function Window:keyOf(index)
    if self.keyExtractor ~= nil then
        return self.keyExtractor(self.data[index], index)
    end

    return index
end

--- Answers the fixed extent every entry shares, or nothing when they are not all the same.
local function uniformExtent(itemExtent)
    if type(itemExtent) == "number" then
        return itemExtent
    end

    return nil
end

--- Replaces the data, keeping every measurement whose entry kept its identity.
function Window:setData(data)
    self.uniform = uniformExtent(self.itemExtent)

    if self.uniform ~= nil then
        self.data = data
        self.measured = {}
        self.offsets = {}
        self.dirtyFrom = nil
        return
    end

    local carried = {}

    if self.keyExtractor ~= nil then
        local byKey = {}
        for index = 1, #self.data do
            byKey[self:keyOf(index)] = self.measured[index]
        end

        local previous = self.data
        self.data = data

        for index = 1, #data do
            local measured = byKey[self:keyOf(index)]
            if measured ~= nil then
                carried[index] = measured
            end
        end

        self.data = previous
    end

    self.data = data
    self.measured = carried
    self.offsets = {}
    self.dirtyFrom = 1
end

--- Builds the window a list scrolls through, which is what decides the cells that exist.
function M.create(options)
    local window = setmetatable({
        data = options.data or {},
        itemExtent = options.itemExtent,
        itemType = options.itemType,
        keyExtractor = options.keyExtractor,
        estimated = options.estimatedItemExtent or 44,
        margin = options.windowMargin or 2,
        measured = {},
        offsets = {},
        dirtyFrom = 1,
    }, Window)

    window.uniform = uniformExtent(window.itemExtent)

    if window.uniform ~= nil then
        window.dirtyFrom = nil
    end

    return window
end

return M
