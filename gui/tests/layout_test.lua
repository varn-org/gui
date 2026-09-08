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

-- A margin moves a pinned box off the edge it is pinned to.
--
-- That is how a box of a known size is centred on one: pinned at half the width and pulled back by half
-- its own. Ignored, it sits with its leading edge on the middle instead, which is a round cover in the
-- middle of a tab bar drawn over the tab beside it.
do
    local cover = node({ position = "absolute", left = "50%", marginLeft = -34, top = 0, width = 68, height = 68 })
    local root = node({ width = 400, height = 100 }, { cover })

    local frames = flex.compute(root, { width = 400, height = 100 })

    box(frames, cover, 166, 0, 68, 68)
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


-- A child of a fixed width in a row is aligned by its height, never by that width.
--
-- Written as one `and`/`or` the cross size read the width whenever the child declared no height, so a
-- table's fixed column sat above every row it belonged to by half the difference between the two.
do
    local frames = flex.compute({
        style = { direction = "row", align = "center", width = 300, height = 44 },
        children = {
            { style = { grow = 1 }, measure = function() return { width = 40, height = 20 } end },
            { style = { width = 64 }, measure = function() return { width = 30, height = 20 } end },
        },
    }, { width = 300, height = 44 })

    local placed = {}

    for node, frame in pairs(frames) do
        placed[#placed + 1] = frame.y
    end

    for index = 1, #placed do
        assert(placed[index] >= 0, "a row's child is never placed above the row, got y = " .. placed[index])
    end
end



-- A child of a row that declares only a height is not that many points wide.
--
-- The same `and`/`or` that broke the cross size broke the main one: a row read the child's height
-- whenever it declared no width, so a box forty points tall came out forty points wide.
do
    local frames = flex.compute({
        style = { direction = "row", width = 300, height = 100 },
        children = { { style = { height = 40 } }, { style = { width = 50, height = 10 } } },
    }, { width = 300, height = 100 })

    local widths = {}

    for _, frame in pairs(frames) do
        widths[#widths + 1] = frame.width
    end

    table.sort(widths)
    assert(widths[1] == 0, "a child with no width of its own takes none, got " .. widths[1])
    assert(widths[2] == 50, "and one that declares a width takes that, got " .. widths[2])
end



-- A tree laid out again and again answers what one laid out from nothing answers.
--
-- The engine keeps what a pass produced so a repeat of the same question is cheap, and a memo that
-- answers a question the box was not last laid out for hands back a size while everything below it
-- still holds what some other question produced: a row stretched to its container with text inside it
-- that kept the width it would have had on its own. Sixty trees of random shape, each laid out at ten
-- sizes that come back around, against a copy that has never been laid out at all. A size is asked for
-- again after others have been, since what a box remembers is only worth anything the second time.
do
    math.randomseed(7)

    local DIRECTIONS = { "row", "column", "row-reverse", "column-reverse" }
    local JUSTIFY = { "start", "center", "end", "space-between", "space-around", "space-evenly" }
    local ALIGN = { "start", "center", "end", "stretch" }
    local SIZES = {
        { 390, 844 }, { 844, 390 }, { 320, 640 }, { 390, 844 }, { 1024, 768 },
        { 844, 390 }, { 512, 768 }, { 390, 844 }, { 1024, 768 }, { 320, 640 },
    }

    local function pick(list) return list[math.random(#list)] end

    --- A tree as plain data, so the same shape can be built twice.
    local function describe(depth)
        local style = {
            direction = pick(DIRECTIONS), justify = pick(JUSTIFY), align = pick(ALIGN),
            gap = math.random(0, 12), padding = math.random(0, 10),
        }

        if math.random() < 0.4 then style.width = math.random(20, 200) end
        if math.random() < 0.4 then style.height = math.random(20, 120) end
        if math.random() < 0.3 then style.grow = 1 end
        if math.random() < 0.2 then style.wrap = true end
        if math.random() < 0.2 then style.position = "absolute" end

        local spec = { style = style }

        -- A box that scrolls gives its children all the room they ask for along that axis, so it asks
        -- them something no other box asks, and a list is where this matters most.
        if math.random() < 0.15 then
            spec.scrolls = math.random() < 0.5 and "vertical" or "horizontal"
        end

        if depth == 0 or math.random() < 0.3 then
            spec.natural = math.random(30, 140)
            spec.line = math.random(12, 40)
            return spec
        end

        spec.children = {}
        for index = 1, math.random(1, 4) do spec.children[index] = describe(depth - 1) end
        return spec
    end

    local function build(spec)
        local node = { style = spec.style, scrolls = spec.scrolls }

        if spec.children == nil then
            node.measure = function(_, bound)
                local width = bound ~= nil and math.min(spec.natural, bound) or spec.natural
                return { width = width, height = spec.line * math.ceil(spec.natural / math.max(1, width)) }
            end

            return node
        end

        node.children = {}
        for index = 1, #spec.children do node.children[index] = build(spec.children[index]) end
        return node
    end

    local function shot(node, path, into)
        local frame = flex.frameOf(node)

        into[path] = frame ~= nil
            and string.format("%.2f %.2f %.2f %.2f", frame.x, frame.y, frame.width, frame.height)
            or "none"

        for index = 1, #(node.children or {}) do
            shot(node.children[index], path .. "." .. index, into)
        end

        return into
    end

    for trial = 1, 60 do
        local spec = describe(5)
        local kept = build(spec)

        for _, size in ipairs(SIZES) do
            flex.compute(kept, { width = size[1], height = size[2] })

            local fresh = build(spec)
            flex.compute(fresh, { width = size[1], height = size[2] })

            local before = shot(kept, "0", {})
            local after = shot(fresh, "0", {})

            for path, value in pairs(after) do
                assert(before[path] == value, "trial " .. trial .. " at " .. size[1] .. "x" .. size[2] ..
                    ", node " .. path .. ": laid out again gave " .. tostring(before[path]) ..
                    ", laid out from nothing gave " .. value)
            end
        end
    end
end

-- What a box worked out is worth nothing once something under it has changed.
--
-- The trees above are laid out at several sizes and never touched, so nothing in them ever goes out of
-- date. A screen is the other way round: it holds still and its contents change, and a box above the
-- change keeps every answer it gave before it — the shape of a label growing and the row around it
-- staying the width of the old one. Each tree here is laid out, one leaf is grown, and it is laid out
-- again against a tree built with that leaf already grown.
do
    math.randomseed(11)

    local DIRECTIONS = { "row", "column", "row-reverse", "column-reverse" }
    local ALIGN = { "start", "center", "end", "stretch" }

    local function pick(list) return list[math.random(#list)] end

    local function describe(depth)
        local spec = {
            style = {
                direction = pick(DIRECTIONS), align = pick(ALIGN),
                gap = math.random(0, 8), padding = math.random(0, 8),
            },
        }

        if depth == 0 or math.random() < 0.35 then
            spec.natural = math.random(30, 120)
            return spec
        end

        spec.children = {}
        for index = 1, math.random(1, 3) do spec.children[index] = describe(depth - 1) end
        return spec
    end

    local function measurer(natural)
        return function(bound)
            local width = bound ~= nil and math.min(natural, bound) or natural
            return { width = width, height = 16 * math.ceil(natural / math.max(1, width)) }
        end
    end

    local function build(spec)
        local node = { style = spec.style, revision = 1 }

        if spec.children == nil then
            node.measure = measurer(spec.natural)
            return node
        end

        node.children = {}
        for index = 1, #spec.children do node.children[index] = build(spec.children[index]) end
        return node
    end

    --- Answers the first leaf under a node, and the same one in a tree built from the same spec.
    local function firstLeaf(node)
        if node.children == nil then
            return node
        end

        return firstLeaf(node.children[1])
    end

    local function firstLeafSpec(spec)
        if spec.children == nil then
            return spec
        end

        return firstLeafSpec(spec.children[1])
    end

    local function shot(node, path, into)
        local frame = flex.frameOf(node)

        into[path] = frame ~= nil
            and string.format("%.2f %.2f %.2f %.2f", frame.x, frame.y, frame.width, frame.height)
            or "none"

        for index = 1, #(node.children or {}) do
            shot(node.children[index], path .. "." .. index, into)
        end

        return into
    end

    for trial = 1, 120 do
        local spec = describe(4)
        local kept = build(spec)

        -- Laid out at sizes that come back around, so every box above the leaf remembers more than one.
        for _, size in ipairs({ { 300, 500 }, { 200, 400 }, { 300, 500 }, { 260, 460 } }) do
            flex.compute(kept, { width = size[1], height = size[2] })
        end

        local grown = math.random(140, 260)

        firstLeafSpec(spec).natural = grown

        local leaf = firstLeaf(kept)
        leaf.revision = 2
        leaf.measure = measurer(grown)

        flex.compute(kept, { width = 300, height = 500 })

        local fresh = build(spec)
        flex.compute(fresh, { width = 300, height = 500 })

        local before = shot(kept, "0", {})
        local after = shot(fresh, "0", {})

        for path, value in pairs(after) do
            assert(before[path] == value, "trial " .. trial .. ", node " .. path ..
                ": a tree whose leaf grew gave " .. tostring(before[path]) ..
                ", one built with it already grown gave " .. value)
        end
    end
end


-- A control the platform gave a size to keeps it, however much room it is offered.
--
-- A switch is fifty-one points across because that is what a switch is. Stretched down a tablet it is a
-- control drawn in the corner of a box the whole width of the pane, with every point of that box
-- answering a finger meant for the switch. A platform with no opinion about an axis answers nothing for
-- it, and those still fill the room they are given.
--
-- The rule was written twice — once where a child is measured and once where it is placed — and the
-- second copy did not know about it, so a control was left alone and then stretched anyway.
do
    local gui = require("gui")

    local function laid(node)
        local renderer = gui.headless()
        local runtime = gui.start(gui.View { style = { grow = 1 }, node }, renderer,
            { size = { width = 652, height = 768 }, platform = "ios" })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        for _, found in pairs(renderer.nodes) do
            if found.frame ~= nil and found.type ~= "view" then
                local natural = renderer:measureControl(found.type)
                runtime:stop()
                return found.frame, natural
            end
        end
    end

    local switch, switchNatural = laid(gui.Switch { value = true })

    assert(switchNatural.width > 0, "the platform must have an opinion about how wide a switch is")
    assert(switch.width == switchNatural.width,
        "a switch is as wide as the platform draws one, is " .. switch.width)

    local stepper, stepperNatural = laid(gui.Stepper { value = 1 })

    assert(stepper.width == stepperNatural.width,
        "and so is a stepper, is " .. stepper.width)

    -- A platform that answers nothing for an axis has no opinion about it, and those still fill.
    local slider, sliderNatural = laid(gui.Slider { value = 0.5 })

    assert(sliderNatural.width == 0, "the platform has no opinion about how wide a slider is")
    assert(slider.width == 652, "so a slider fills the room it is given, is " .. slider.width)
end

print("gui.layout ok")
