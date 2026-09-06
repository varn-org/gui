local gui = require("gui")

package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local app = require("app")
local catalogue = require("catalogue")

--- Counts what a commit asked the platform for, which is the cost a device actually pays.
local function watched()
    local renderer = gui.headless()
    local measure = renderer.measureText
    local counted = { measurements = 0 }

    renderer.measureText = function(self, text, style, bound)
        counted.measurements = counted.measurements + 1
        return measure(self, text, style, bound)
    end

    counted.renderer = renderer
    return counted
end

local function drain(runtime)
    for _ = 1, 8 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end
end

local function start(description, watch)
    local runtime = gui.start(description, watch.renderer, { size = { width = 390, height = 844 } })
    drain(runtime)
    return runtime
end

local function opsSince(watch, before, kind)
    local total = 0

    for index = before + 1, #watch.renderer.batches do
        local batch = watch.renderer.batches[index]

        for position = 1, #batch do
            if kind == nil or batch[position].op == kind then
                total = total + 1
            end
        end
    end

    return total
end

-- A deep tree costs what it holds, not what its depth raises it to.
--
-- Sizing a box asks each child for its size and asks again once it has handed out a share, so a subtree
-- that is worked out afresh every time it is asked costs three to the depth. At this depth that is a
-- number no machine finishes, and the test is here because the engine was written that way once.
do
    local DEPTH = 24
    local node = gui.Text { text = "deep", style = { fontSize = 14 } }

    for level = 1, DEPTH do
        node = gui.View { style = { padding = 1, direction = level % 2 == 0 and "row" or "column" }, node }
    end

    local watch = watched()
    local started = os.clock()
    start(gui.View { style = { grow = 1 }, node }, watch)
    local spent = (os.clock() - started) * 1000

    assert(spent < 250, "a tree " .. DEPTH .. " deep took " .. string.format("%.0f", spent) .. " ms to lay out")
    assert(watch.measurements < 32,
        "a tree " .. DEPTH .. " deep measured its one string " .. watch.measurements .. " times")
end

-- A render that produces the same tree reaches the platform with nothing at all.
do
    local watch = watched()
    local runtime = start(app.root, watch)
    local before = #watch.renderer.batches

    runtime:markDirty(runtime.root)
    runtime:commit()

    assert(opsSince(watch, before) == 0,
        "re-rendering the index sent " .. opsSince(watch, before) .. " operations for nothing")
end

-- Typing into a field costs the field, not the screen it sits on.
do
    local watch = watched()
    local demo = catalogue.find("inputs", "fields")
    local runtime = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) }, watch)

    local field = nil
    for _, node in pairs(runtime.byId) do
        if node.type == "textinput" and type(node.props.onChange) == "function" and field == nil then
            field = node
        end
    end

    assert(field ~= nil, "the demo must carry a field to type into")

    local before = #watch.renderer.batches
    field.props.onChange("Ada")
    drain(runtime)

    local ops = opsSince(watch, before)
    assert(ops <= 4, "one keystroke sent " .. ops .. " operations")
end

-- Scrolling a list of fifty thousand rows costs the rows that entered and left, and nothing else.
--
-- A cell is placed by a frame of its own, so a window that slides by one has no reason to reorder the
-- cells that stayed. The move operations are counted rather than the total, since the number of cells a
-- variable-height list realises genuinely changes as taller and shorter entries come into view.
do
    local watch = watched()
    local demo = catalogue.find("lists", "long")
    local runtime = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) }, watch)

    local list = nil
    for _, node in pairs(runtime.byId) do
        if node.type == "list" then
            list = node
        end
    end

    assert(list ~= nil, "the demo must carry the list")

    -- The realised set settles once the surface has been measured, so the budget is read after it has.
    for round = 1, 12 do
        list.props.onScroll({ x = 0, y = round * 64 })
        drain(runtime)
    end

    local before = #watch.renderer.batches
    local worst = 0

    for round = 13, 36 do
        local round_start = #watch.renderer.batches
        list.props.onScroll({ x = 0, y = round * 64 })
        drain(runtime)
        worst = math.max(worst, opsSince(watch, round_start))
    end

    local moves = opsSince(watch, before, "move")
    assert(moves == 0, "scrolling reordered cells that had not moved, " .. moves .. " times")
    assert(worst <= 48, "one scroll sent as many as " .. worst .. " operations")
end

-- A list whose entries are all one size scrolls a row at a time for the price of a row.
do
    local watch = watched()
    local rows = {}

    for index = 1, 50000 do
        rows[index] = { key = index, label = "Row " .. index }
    end

    local runtime = start(gui.List {
        style = { grow = 1 },
        data = rows,
        itemExtent = 44,
        keyExtractor = function(item) return item.key end,
        renderItem = function(item)
            return gui.View { style = { grow = 1, paddingHorizontal = "md", justify = "center" },
                gui.Text { text = item.label },
            }
        end,
    }, watch)

    for round = 1, 8 do
        runtime.root.instance:scrolled(runtime.root.instance.spec, { x = 0, y = round * 44 })
        drain(runtime)
    end

    local worst = 0

    for round = 9, 32 do
        local before = #watch.renderer.batches
        runtime.root.instance:scrolled(runtime.root.instance.spec, { x = 0, y = round * 44 })
        drain(runtime)
        worst = math.max(worst, opsSince(watch, before))
    end

    assert(worst <= 12, "scrolling a uniform list one row sent as many as " .. worst .. " operations")
end

print("gui.performance ok")
