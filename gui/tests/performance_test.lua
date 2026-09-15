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

-- A screen the size of a real one is laid out again for the price of laying it out.
--
-- Coming back off a screen felt slow on the phone and nothing here described a tree that size: the
-- budget above is one string twenty-four levels down, which says what recursion costs and nothing about
-- what a screen costs. This lays out the gallery's own index with a demo open on top of it, which is
-- about two hundred nodes, and relays the whole of it the way a rotation does.
--
-- The numbers are generous because a machine under load is the machine this runs on. What they catch is
-- an order of magnitude: a layout that stops memoising, a measurement cache that stops answering, or a
-- pass added over the whole tree.
do
    local watch = watched()
    local runtime = start(app.root, watch)

    local opened = nil

    for _, node in pairs(runtime.byId) do
        if node.props ~= nil and node.props.onPress ~= nil and node.type ~= "scroll" then
            opened = opened or node
        end
    end

    assert(opened ~= nil, "the index must carry something to open")

    runtime:dispatch(opened.id, "onPress", nil)
    drain(runtime)

    local held = 0

    for _ in pairs(runtime.byId) do
        held = held + 1
    end

    assert(held > 120, "the tree must be the size of a real screen, it holds " .. held)

    watch.measurements = 0

    local ROUNDS = 10
    local started = os.clock()

    for round = 1, ROUNDS do
        runtime:resize(round % 2 == 0 and 390 or 391, 844)
        drain(runtime)
    end

    local spent = (os.clock() - started) * 1000 / ROUNDS

    assert(spent < 120,
        "a screen of " .. held .. " nodes took " .. string.format("%.0f", spent) .. " ms to lay out again")

    -- Every string on the screen was measured on the way in, and a width one point different does not
    -- make any of them a different question. A cache too small for one screen answers none of them.
    assert(watch.measurements / ROUNDS < 12,
        "laying the screen out again measured " .. string.format("%.0f", watch.measurements / ROUNDS)
            .. " strings a commit, which the cache should have answered")
end

-- A prop written as a literal is compared by what it says, whichever prop it is.
--
-- A style was, and the four props that carry a list of their own were not: an icon's drawing, a rich
-- text's spans, a picker's options and a segmented control's segments are each built afresh by the
-- render that names them, so every one of them was an update over the bridge on every commit for a node
-- that had not changed at all. An index of twenty rows with a chevron each is twenty of those.
do
    local Literals = gui.component({
        name = "Literals",
        render = function()
            return gui.View { style = { grow = 1, gap = 8 },
                gui.Icon { name = "chevron-right", size = 16 },
                gui.RichText { spans = { { text = "one" }, { text = "two", weight = "700" } } },
                gui.SegmentedControl { segments = { "Day", "Week" }, selectedIndex = 1 },
            }
        end,
    })

    local watch = watched()
    local runtime = start(Literals {}, watch)
    local before = #watch.renderer.batches

    runtime:markDirty(runtime.root)
    runtime:commit()

    assert(opsSince(watch, before) == 0,
        "a tree built again from the same literals sent " .. opsSince(watch, before) .. " operations")
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

-- A scroll that puts nothing new on screen costs nothing at all.
--
-- A platform reports every pixel a finger moves and a commit lays the whole tree out, so a list that
-- re-rendered for each of them would spend a frame's budget on a window that has not moved.
do
    local watch = watched()
    local rows = {}

    for index = 1, 500 do
        rows[index] = { key = index, label = "Row " .. index }
    end

    local runtime = start(gui.List {
        style = { grow = 1 },
        data = rows,
        itemExtent = 44,
        keyExtractor = function(item) return item.key end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    }, watch)

    local instance = runtime.root.instance

    instance:scrolled(instance.spec, { x = 0, y = 440 })
    drain(runtime)

    local before = #watch.renderer.batches

    -- Ten reports a pixel apart, none of which reaches the next row.
    for step = 1, 10 do
        instance:scrolled(instance.spec, { x = 0, y = 440 + step })
        drain(runtime)
    end

    assert(opsSince(watch, before) == 0,
        "scrolling within one row sent " .. opsSince(watch, before) .. " operations")

    instance:scrolled(instance.spec, { x = 0, y = 440 + 44 * 4 })
    drain(runtime)

    assert(opsSince(watch, before) > 0, "scrolling onto new rows must reach the renderer")
end

-- A screen of drawn controls costs what a screen of the platform's own costs, near enough.
--
-- A drawn control is several nodes where a native one is one, so a screen of fifty of them is a few
-- hundred nodes rather than fifty. What matters is not the count but whether the layout and the bridge
-- still hold: a design chosen for how it looks cannot cost a reader the frame rate.
do
    local controls = require("gui.controls")

    local function screenOf(theme)
        local rows = {}

        for index = 1, 40 do
            rows[index] = gui.View {
                key = tostring(index),
                style = { direction = "row", align = "center", justify = "space-between", gap = "md" },

                gui.Text { text = "Row " .. index },
                gui.Switch { accessibilityLabel = "Row " .. index, value = index % 2 == 0 },
            }
        end

        local watch = watched()
        local runtime = gui.start(gui.ScrollView { style = { grow = 1 }, table.unpack(rows) },
            watch.renderer, { size = { width = 390, height = 844 }, controls = theme })

        drain(runtime)
        return runtime, watch
    end

    local held = {}

    for _, theme in ipairs({ controls.native, controls.material3 }) do
        local runtime, watch = screenOf(theme)
        local nodes = 0

        for _ in pairs(runtime.byId) do
            nodes = nodes + 1
        end

        watch.measurements = 0

        local ROUNDS = 10
        local started = os.clock()

        for round = 1, ROUNDS do
            runtime:resize(round % 2 == 0 and 390 or 391, 844)
            drain(runtime)
        end

        held[#held + 1] = {
            name = theme.name,
            nodes = nodes,
            spent = (os.clock() - started) * 1000 / ROUNDS,
        }

        runtime:stop()
    end

    local platform = held[1]
    local drawn = held[2]

    assert(drawn.nodes > platform.nodes,
        "a drawn control is more nodes than a native one, which is the cost being measured")

    assert(drawn.spent < 120, "a screen of " .. drawn.nodes .. " drawn nodes took "
        .. string.format("%.0f", drawn.spent) .. " ms to lay out again")

    -- The cost of drawing rather than handing over is the thing to watch, so it is asserted rather than
    -- left to be noticed: four times the layout for three times the nodes is the engine, not the design.
    assert(drawn.spent < math.max(24, platform.spent * 4),
        "drawing the controls cost " .. string.format("%.1f", drawn.spent) .. " ms against "
        .. string.format("%.1f", platform.spent) .. " ms for the platform's own")
end

-- One press on a drawn control sends what one press is worth, and nothing more.
do
    local controls = require("gui.controls")
    local watch = watched()
    local runtime = gui.start(gui.View {
        gui.Switch { accessibilityLabel = "One", value = false, onChange = function() end },
    }, watch.renderer, { size = { width = 390, height = 844 }, controls = controls.material3 })

    drain(runtime)

    local pressed = nil

    for _, node in pairs(runtime.byId) do
        if node.props.accessibilityRole == "switch" then
            pressed = node
        end
    end

    local before = #watch.renderer.batches

    runtime:dispatch(pressed.id, "onPressIn", nil)
    drain(runtime)

    local ops = opsSince(watch, before)

    assert(ops > 0, "pressing a drawn control reaches the renderer")
    assert(ops <= 6, "one press on a drawn control sent " .. ops .. " operations")
end

print("gui.performance ok")
