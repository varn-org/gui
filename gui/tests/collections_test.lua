local window = require("gui.collections.window")
local pool = require("gui.collections.pool")

local function data(count)
    local entries = {}
    for index = 1, count do
        entries[index] = { id = index, label = "row " .. index }
    end

    return entries
end

-- A fixed extent gives every offset without measuring anything.
do
    local view = window.create({ data = data(1000), itemExtent = 50 })

    assert(view:offsetOf(1) == 0, "the first entry starts at zero")
    assert(view:offsetOf(3) == 100, "the third entry starts after two others")
    assert(view:totalExtent() == 50000, "the total is the count times the extent")
end

-- An extent given per entry is asked for each one.
do
    local view = window.create({
        data = data(4),
        itemExtent = function(_, index) return index * 10 end,
    })

    assert(view:offsetOf(1) == 0, "the first entry starts at zero")
    assert(view:offsetOf(2) == 10, "the second starts after the first")
    assert(view:offsetOf(3) == 30, "the third starts after both")
    assert(view:totalExtent() == 100, "the total is the sum of them all")
end

-- Without an extent, an estimate stands in until an entry has been measured.
do
    local view = window.create({ data = data(10), estimatedItemExtent = 20 })
    assert(view:totalExtent() == 200, "the estimate covers what has not been measured")

    view:measure(1, 60)
    assert(view:offsetOf(2) == 60, "a measured entry replaces its estimate")
    assert(view:totalExtent() == 240, "the total follows the measurement")
end

-- Only the visible range plus the margin is realised.
do
    local view = window.create({ data = data(1000), itemExtent = 50, windowMargin = 2 })
    local range = view:visible(0, 200)

    assert(range.first == 1, "the range starts at the first visible entry")
    assert(range.last == 6, "the range covers the viewport plus the margin, got " .. range.last)
end

-- Scrolling moves the range, and the margin reaches behind as well as ahead.
do
    local view = window.create({ data = data(1000), itemExtent = 50, windowMargin = 2 })
    local range = view:visible(5000, 200)

    assert(range.first == 99, "the margin reaches behind the viewport, got " .. range.first)
    assert(range.last == 106, "the margin reaches ahead of it, got " .. range.last)
end

-- The range never runs past the ends of the data.
do
    local view = window.create({ data = data(3), itemExtent = 50, windowMargin = 5 })
    local range = view:visible(0, 500)

    assert(range.first == 1 and range.last == 3, "a short list realises all of it")
end

-- An empty list realises nothing rather than one phantom row.
do
    local view = window.create({ data = {}, itemExtent = 50 })
    local range = view:visible(0, 500)

    assert(range.last < range.first, "an empty list has no range")
    assert(view:totalExtent() == 0, "an empty list has no extent")
end

-- An offset resolves to the entry that covers it, which is what a paged carousel lands on.
do
    local view = window.create({ data = data(10), itemExtent = 100 })

    assert(view:indexAt(0) == 1, "the start is the first entry")
    assert(view:indexAt(150) == 2, "an offset inside the second entry is the second")
    assert(view:indexAt(99999) == 10, "past the end is the last entry")
end

-- The type of an entry decides its pool, and without a rule everything shares one.
do
    local view = window.create({
        data = data(4),
        itemType = function(_, index) return index % 2 == 0 and "even" or "odd" end,
    })

    assert(view:typeOf(1) == "odd", "the rule decides the type")
    assert(view:typeOf(2) == "even", "the rule decides the type")

    local plain = window.create({ data = data(2) })
    assert(plain:typeOf(1) == "default", "without a rule every entry shares one type")
end

-- Replacing the data keeps the measurements of entries that kept their identity.
do
    local view = window.create({
        data = data(3),
        keyExtractor = function(item) return item.id end,
    })

    view:measure(1, 30)
    view:measure(2, 40)

    view:setData({ { id = 2, label = "row 2" }, { id = 3, label = "row 3" } })
    assert(view:extentAt(1) == 40, "the entry that survived must keep its measurement")
end

-- A cell is reused, and only by an entry of its own type.
do
    local cells = pool.create({ recycle = true })

    local first = cells:acquire("row", 1)
    assert(first.fresh, "the first cell of a type is built")

    cells:release(1)
    assert(cells:freeCount("row") == 1, "a released cell waits to be reused")

    local second = cells:acquire("row", 2)
    assert(not second.fresh, "the next entry of that type takes the free cell")
    assert(second.id == first.id, "reuse means the same cell, not an equal one")

    local header = cells:acquire("header", 3)
    assert(header.fresh, "a different type never takes another type's cell")
end

-- With reuse off every entry keeps its own cell.
do
    local cells = pool.create({ recycle = false })

    cells:acquire("row", 1)
    cells:release(1)
    assert(cells:freeCount("row") == 0, "nothing is pooled when reuse is off")

    local second = cells:acquire("row", 2)
    assert(second.fresh, "every entry is built fresh when reuse is off")
end

-- Moving the realised range releases what left and takes cells for what arrived.
do
    local cells = pool.create({ recycle = true })
    local typeOf = function() return "row" end

    cells:reconcile({ first = 1, last = 5 }, typeOf)
    assert(cells:liveCount() == 5, "the first range realises five entries")

    local arrived, left = cells:reconcile({ first = 3, last = 7 }, typeOf)
    assert(#left == 2, "two entries left the range, got " .. #left)
    assert(#arrived == 2, "two entries entered it, got " .. #arrived)
    assert(cells:liveCount() == 5, "the realised count stays bounded")
    assert(cells:freeCount("row") == 0, "the cells that left were taken straight back")
end

-- A long scroll never grows the number of cells that exist.
do
    local view = window.create({ data = data(50000), itemExtent = 44, windowMargin = 2 })
    local cells = pool.create({ recycle = true })
    local typeOf = function(index) return view:typeOf(index) end

    for offset = 0, 100000, 500 do
        cells:reconcile(view:visible(offset, 800), typeOf)
    end

    assert(cells:liveCount() <= 24, "the realised set stays bounded, got " .. cells:liveCount())
    assert(cells:freeCount("default") <= 24, "the pool stays bounded, got " .. cells:freeCount("default"))
end

print("gui.collections ok")
