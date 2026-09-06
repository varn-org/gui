local flex = require("gui.layout.flex")

local function node(style, children)
    return { style = style, children = children or {} }
end

local function frameOf(frames, target)
    local frame = frames[target]
    assert(frame ~= nil, "the node was never placed")
    return frame
end

local function near(actual, expected, what)
    assert(math.abs(actual - expected) < 0.01, (what or "value") .. ": expected " .. expected .. ", got " .. actual)
end

local function box(frames, target, x, y, width, height)
    local frame = frameOf(frames, target)
    near(frame.x, x, "x")
    near(frame.y, y, "y")
    near(frame.width, width, "width")
    near(frame.height, height, "height")
end

-- A column stacks its children and each one stretches across.
do
    local a = node({ height = 30 })
    local b = node({ height = 20 })
    local root = node({ width = 100, height = 100 }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, a, 0, 0, 100, 30)
    box(frames, b, 0, 30, 100, 20)
end

-- A row places its children side by side.
do
    local a = node({ width = 40 })
    local b = node({ width = 30 })
    local root = node({ direction = "row", width = 100, height = 50 }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 50 })
    box(frames, a, 0, 0, 40, 50)
    box(frames, b, 40, 0, 30, 50)
end

-- Padding insets the content without changing the box.
do
    local child = node({ height = 10 })
    local root = node({ width = 100, height = 100, padding = 10 }, { child })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, root, 0, 0, 100, 100)
    box(frames, child, 10, 10, 80, 10)
end

-- Padding given per edge insets each side on its own.
do
    local child = node({ height = 10 })
    local root = node({ width = 100, height = 100, paddingLeft = 20, paddingTop = 5 }, { child })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, child, 20, 5, 80, 10)
end

-- A margin pushes a child away from its neighbour and its parent.
do
    local a = node({ height = 10, margin = 5 })
    local root = node({ width = 100, height = 100 }, { a })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, a, 5, 5, 90, 10)
end

-- Gap separates children without needing a margin on each one.
do
    local a = node({ height = 10 })
    local b = node({ height = 10 })
    local root = node({ width = 100, height = 100, gap = 8 }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, b, 0, 18, 100, 10)
end

-- Grow shares the free space in the proportion each child asked for.
do
    local a = node({ grow = 1 })
    local b = node({ grow = 2 })
    local root = node({ direction = "row", width = 90, height = 10 }, { a, b })

    local frames = flex.compute(root, { width = 90, height = 10 })
    box(frames, a, 0, 0, 30, 10)
    box(frames, b, 30, 0, 60, 10)
end

-- Shrink takes space back from children that together asked for too much.
do
    local a = node({ width = 80, shrink = 1 })
    local b = node({ width = 80, shrink = 1 })
    local root = node({ direction = "row", width = 100, height = 10 }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 10 })
    local first = frameOf(frames, a)
    local second = frameOf(frames, b)

    near(first.width + second.width, 100, "the children must fit the row")
    near(first.width, second.width, "equal shrink takes the same from each")
end

-- Justify places the whole line inside the space that is left.
do
    local a = node({ width = 20 })
    local root = node({ direction = "row", width = 100, height = 10, justify = "center" }, { a })

    local frames = flex.compute(root, { width = 100, height = 10 })
    box(frames, a, 40, 0, 20, 10)
end

-- Space between pushes the first and last to the edges.
do
    local a = node({ width = 20 })
    local b = node({ width = 20 })
    local root = node({ direction = "row", width = 100, height = 10, justify = "space-between" }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 10 })
    box(frames, a, 0, 0, 20, 10)
    box(frames, b, 80, 0, 20, 10)
end

-- Align positions a child across the axis it does not flow along.
do
    local a = node({ width = 20, height = 10 })
    local root = node({ direction = "row", width = 100, height = 50, align = "center" }, { a })

    local frames = flex.compute(root, { width = 100, height = 50 })
    box(frames, a, 0, 20, 20, 10)
end

-- A child may override the alignment its parent set.
do
    local a = node({ width = 20, height = 10, alignSelf = "end" })
    local root = node({ direction = "row", width = 100, height = 50, align = "start" }, { a })

    local frames = flex.compute(root, { width = 100, height = 50 })
    box(frames, a, 0, 40, 20, 10)
end

-- Wrapping starts a new line once the current one is full.
do
    local a = node({ width = 60, height = 10 })
    local b = node({ width = 60, height = 10 })
    local root = node({ direction = "row", width = 100, height = 100, wrap = true }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, a, 0, 0, 60, 10)
    box(frames, b, 0, 10, 60, 10)
end

-- A reversed row lays its children out from the far edge.
do
    local a = node({ width = 20 })
    local b = node({ width = 20 })
    local root = node({ direction = "row-reverse", width = 100, height = 10 }, { a, b })

    local frames = flex.compute(root, { width = 100, height = 10 })
    box(frames, b, 0, 0, 20, 10)
    box(frames, a, 20, 0, 20, 10)
end

-- A percentage resolves against the space the parent offers.
do
    local a = node({ width = "50%", height = 10 })
    local root = node({ width = 200, height = 100 }, { a })

    local frames = flex.compute(root, { width = 200, height = 100 })
    box(frames, a, 0, 0, 100, 10)
end

-- A minimum and a maximum bound what any other rule would have produced.
do
    local a = node({ grow = 1, maxWidth = 40 })
    local root = node({ direction = "row", width = 100, height = 10 }, { a })

    local frames = flex.compute(root, { width = 100, height = 10 })
    near(frameOf(frames, a).width, 40, "a maximum must bound growth")
end

-- An absolute child leaves the flow and positions against its parent's content box.
do
    local flowing = node({ height = 10 })
    local pinned = node({ position = "absolute", right = 5, bottom = 5, width = 20, height = 20 })
    local root = node({ width = 100, height = 100 }, { flowing, pinned })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, flowing, 0, 0, 100, 10)
    box(frames, pinned, 75, 75, 20, 20)
end

-- An absolute child pinned on both sides is stretched between them.
do
    local pinned = node({ position = "absolute", left = 10, right = 10, top = 0, height = 5 })
    local root = node({ width = 100, height = 100 }, { pinned })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, pinned, 10, 0, 80, 5)
end

-- A leaf answers its own size through the measure the caller supplied.
do
    local label = node({})
    label.measure = function() return { width = 42, height = 17 } end
    local root = node({ direction = "row", width = 100, height = 100, align = "start" }, { label })

    local frames = flex.compute(root, { width = 100, height = 100 })
    box(frames, label, 0, 0, 42, 17)
end

-- Text is measured through the callback the platform provides.
do
    local label = { style = {}, children = {}, text = "hello" }
    local root = node({ direction = "row", width = 100, height = 100, align = "start" }, { label })

    local frames = flex.compute(root, {
        width = 100,
        height = 100,
        measureText = function(text) return { width = #text * 8, height = 16 } end,
    })

    box(frames, label, 0, 0, 40, 16)
end

-- A frame is relative to the node it sits inside, which is where a renderer adds the view.
do
    local inner = node({ height = 10 })
    local middle = node({ padding = 10 }, { inner })
    local root = node({ width = 100, height = 100, padding = 5 }, { middle })

    local frames = flex.compute(root, { width = 100, height = 100 })

    box(frames, middle, 5, 5, 90, 30)
    box(frames, inner, 10, 10, 70, 10)
end

-- A row with no height is as tall as its tallest child, never as tall as the room it was offered.
do
    local short = node({ width = 20, height = 10 })
    local tall = node({ width = 20, height = 40 })
    local row = node({ direction = "row" }, { short, tall })
    local root = node({ width = 200, height = 500 }, { row })

    local frames = flex.compute(root, { width = 200, height = 500 })
    box(frames, row, 0, 0, 200, 40)
end

-- A box measured by its content does not grow its children, or it would swallow whatever it was given.
do
    local child = node({ grow = 1, height = 30 })
    local holder = node({}, { child })
    local after = node({ height = 25 })
    local root = node({ width = 100, height = 400 }, { holder, after })

    local frames = flex.compute(root, { width = 100, height = 400 })
    box(frames, holder, 0, 0, 100, 30)
    box(frames, after, 0, 30, 100, 25)
end

-- A share of a definite size is itself definite, so a chain of growing boxes fills the whole of it.
do
    local inner = node({ grow = 1 })
    local outer = node({ grow = 1 }, { inner })
    local root = node({ width = 100, height = 300 }, { outer })

    local frames = flex.compute(root, { width = 100, height = 300 })
    box(frames, outer, 0, 0, 100, 300)
    box(frames, inner, 0, 0, 100, 300)
end

-- A scrolling view is the size it was given, and its content runs off the edge rather than squeezing.
do
    local first = node({ width = 200, height = 40 })
    local second = node({ width = 200, height = 40 })
    local scroll = { style = { direction = "row" }, scrolls = "horizontal", children = { first, second } }
    local root = node({ width = 300, height = 300 }, { scroll })

    local frames = flex.compute(root, { width = 300, height = 300 })

    box(frames, scroll, 0, 0, 300, 40)
    box(frames, first, 0, 0, 200, 40)
    box(frames, second, 200, 0, 200, 40)
end

-- A vertical scrolling view asks for no height of its own, so what sits after it is not pushed away.
do
    local tall = node({ height = 900 })
    local scroll = { style = {}, scrolls = "vertical", children = { tall } }
    local after = node({ height = 20 })
    local root = node({ width = 100, height = 400 }, { scroll, after })

    local frames = flex.compute(root, { width = 100, height = 400 })

    box(frames, scroll, 0, 0, 100, 0)
    box(frames, after, 0, 0, 100, 20)
end

-- A wrapped row is as tall as every line it needed, not as tall as the first one.
do
    local children = {}
    for index = 1, 4 do children[index] = node({ width = 40, height = 30 }) end

    local row = node({ direction = "row", wrap = true, gap = 10 }, children)
    local root = node({ width = 150, height = 300 }, { row })

    local frames = flex.compute(root, { width = 150, height = 300 })

    box(frames, row, 0, 0, 150, 70)
    box(frames, children[4], 0, 40, 40, 30)
end

-- A percentage is measured against the box that holds it, even when that box was stretched into place.
do
    local third = node({ position = "absolute", left = 0, top = 0, width = "33%", height = "50%" })
    local holder = node({ position = "absolute", left = 0, right = 0, top = 0, height = 200 }, { third })
    local root = node({ width = 300, height = 400 }, { holder })

    local frames = flex.compute(root, { width = 300, height = 400 })

    box(frames, holder, 0, 0, 300, 200)
    box(frames, third, 0, 0, 99, 100)
end

-- A leaf takes the size its type is naturally worth when nothing else gives it one.
do
    local natural = require("gui.layout.natural")
    natural.declare("probe", { size = { width = 51, height = 31 } })

    local control = { style = {}, scrolls = nil, children = {}, natural = natural.sizeOf("probe", {}) }
    local root = node({ width = 200, height = 200, align = "start" }, { control })

    local frames = flex.compute(root, { width = 200, height = 200 })
    box(frames, control, 0, 0, 51, 31)
end

-- A node held to one line is measured as one, and trimmed to the room it has rather than wrapped.
do
    local held = { style = {}, children = {}, text = "a sentence with more in it than fits", lines = 1 }
    local wrapped = { style = {}, children = {}, text = "a sentence with more in it than fits" }
    local root = node({ width = 100, height = 200 }, { held, wrapped })

    local frames = flex.compute(root, {
        width = 100,
        height = 200,
        measureText = function(text, _, bound)
            if bound == nil then
                return { width = #text * 8, height = 16 }
            end

            local lines = math.ceil(#text * 8 / bound)
            return { width = bound, height = lines * 16 }
        end,
    })

    near(frameOf(frames, held).height, 16, "one line")
    near(frameOf(frames, held).width, 100, "trimmed to the room it has")
    assert(frameOf(frames, wrapped).height > 16, "a node that may wrap still does")
end

-- A control with a size of its own is not squeezed to make room for what is beside it.
do
    local natural = require("gui.layout.natural")
    natural.declare("gauge", { size = { width = 51, height = 31 } })

    local control = { style = {}, children = {}, natural = natural.sizeOf("gauge", {}) }
    local label = { style = {}, children = {}, text = "a label with a great deal to say for itself" }
    local row = node({ direction = "row", width = 120, height = 40 }, { label, control })
    local root = node({ width = 120, height = 40 }, { row })

    local frames = flex.compute(root, {
        width = 120,
        height = 40,
        measureText = function(text) return { width = #text * 8, height = 16 } end,
    })

    near(frameOf(frames, control).width, 51, "the control keeps its own width")
    assert(frameOf(frames, label).width < 120, "the label is what gives way instead")
end

-- A percentage laid out before its holder had a size is worked out again once it has one.
--
-- Zero is a size a box may have and a number is true in Lua, so a percentage kept the first answer it
-- was given for good: a grid laid out before its surface was measured stayed a column of slivers.
do
    local cell = node({ position = "absolute", left = "50%", width = "50%", top = 0, height = 40 })
    local root = node({}, { cell })

    flex.compute(root, { width = 0, height = 0 })
    local frames = flex.compute(root, { width = 200, height = 100 })

    box(frames, cell, 100, 0, 100, 40)
end

-- The same holds for a percentage that flows rather than one that is pinned.
do
    local half = node({ width = "50%", height = 20 })
    local root = node({}, { half })

    flex.compute(root, { width = 0, height = 0 })
    local frames = flex.compute(root, { width = 300, height = 100 })

    near(frameOf(frames, half).width, 150, "a flowing percentage is worked out against the size it now has")
end

print("gui.layout ok")
