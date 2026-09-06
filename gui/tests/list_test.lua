local gui = require("gui")

local function rows(count)
    local data = {}

    for index = 1, count do
        data[index] = { id = index, label = "row " .. index, kind = index % 10 == 1 and "header" or "row" }
    end

    return data
end

--- Starts a description and lets it settle, since the first layout is what tells a list its viewport.
local function start(description, size)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = size or { width = 320, height = 480 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- Answers a child of a node, since the renderer keeps children by id rather than by reference.
local function childOf(renderer, node, index)
    local id = node.children[index < 0 and #node.children + 1 + index or index]
    return renderer.nodes[id]
end

--- Answers the surface node a list rendered, which is the one a renderer scrolls.
local function surfaceOf(renderer, kind)
    local found = renderer:findAll(kind or "list")
    assert(#found == 1, "the tree must carry exactly one " .. (kind or "list"))
    return found[1]
end

-- Only the visible range plus the margin is realised, however long the data is.
do
    local _, renderer = start(gui.List {
        data = rows(50000),
        itemExtent = 40,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    local realised = #renderer:findAll("text")

    assert(surface.props.itemCount == 50000, "the surface must know how long the data is")
    assert(surface.props.contentExtent == 50000 * 40, "the content extent must cover every entry")
    assert(realised > 0 and realised < 40, "a bounded set of cells serves fifty thousand rows, got " .. realised)
end

-- Scrolling moves the realised set rather than growing it.
do
    local runtime, renderer = start(gui.List {
        data = rows(50000),
        itemExtent = 40,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    local before = #renderer:findAll("text")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 40000 })
    runtime:commit()

    -- The window at the top is clipped by the start of the data, so it holds one margin rather than two.
    local labels = renderer:findAll("text")
    assert(#labels <= before + 2, "the realised count must not grow with the offset")

    local seen = false
    for index = 1, #labels do
        if labels[index].props.text == "row 1001" then
            seen = true
        end
    end

    assert(seen, "the entry at the new offset must be realised")
end

-- With reuse on, a cell that scrolls away is handed to the entry that takes its place.
do
    local runtime, renderer = start(gui.List {
        data = rows(2000),
        itemExtent = 40,
        recycle = true,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)

    -- The window is clipped at the top, so it reaches its full size only once the list has left it.
    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 4000 })
    runtime:commit()

    local settled = #renderer.batches
    local created = 0

    for offset = 101, 140 do
        runtime:dispatch(surface.id, "onScroll", { x = 0, y = offset * 40 })
        runtime:commit()
    end

    for index = settled + 1, #renderer.batches do
        for position = 1, #renderer.batches[index] do
            if renderer.batches[index][position].op == "create" then
                created = created + 1
            end
        end
    end

    assert(created == 0, "forty entries scrolling past must build nothing, got " .. created .. " creations")
end

-- With reuse off, an entry that leaves the window takes its cell with it.
do
    local runtime, renderer = start(gui.List {
        data = rows(2000),
        itemExtent = 40,
        recycle = false,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    local before = #renderer.batches

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 4000 })
    runtime:commit()

    local removed = false
    for index = before + 1, #renderer.batches do
        for position = 1, #renderer.batches[index] do
            if renderer.batches[index][position].op == "remove" then
                removed = true
            end
        end
    end

    assert(removed, "without reuse a departing cell is destroyed")
end

-- One reuse pool serves each item type, so a header cell is never handed to a row.
do
    local kinds = {}

    local runtime, renderer = start(gui.List {
        data = rows(500),
        itemExtent = 40,
        itemType = function(item) return item.kind end,
        renderItem = function(item)
            kinds[#kinds + 1] = item.kind
            return gui.Text { text = item.label, style = { fontWeight = item.kind == "header" and "700" or "400" } }
        end,
    })

    local surface = surfaceOf(renderer)
    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 2000 })
    runtime:commit()

    local labels = renderer:findAll("text")
    for index = 1, #labels do
        local text = labels[index].props.text
        local number = tonumber(text:match("%d+"))
        local expected = number % 10 == 1 and "700" or "400"

        assert(labels[index].props.style.fontWeight == expected,
            text .. " took a cell of the wrong type")
    end
end

-- A list along the horizontal axis is the same component with one field changed.
do
    local _, renderer = start(gui.List {
        data = rows(500),
        horizontal = true,
        itemExtent = 120,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    assert(surface.props.horizontal == true, "the surface must know its axis")

    local cell = childOf(renderer, surface, 1)
    assert(cell.props.style.left == 0, "a horizontal cell is placed along x")
    assert(cell.props.style.width == 120, "a horizontal cell takes its extent as a width")
end

-- Reaching the end is reported once, and again only after leaving it.
do
    local reached = 0

    local runtime, renderer = start(gui.List {
        data = rows(100),
        itemExtent = 40,
        onEndReached = function() reached = reached + 1 end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 3600 })
    runtime:commit()
    assert(reached == 1, "reaching the end must be reported")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 3620 })
    runtime:commit()
    assert(reached == 1, "staying at the end must not report again")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 0 })
    runtime:commit()
    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 3600 })
    runtime:commit()
    assert(reached == 2, "coming back to the end must report again")
end

-- An entry appearing and disappearing is told to the handler after the commit that moved it.
do
    local appeared = {}
    local disappeared = {}

    local runtime, renderer = start(gui.List {
        data = rows(1000),
        itemExtent = 40,
        onItemAppear = function(event) appeared[#appeared + 1] = event.index end,
        onItemDisappear = function(event) disappeared[#disappeared + 1] = event.index end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    assert(#appeared > 0, "the first realised set must be reported as appearing")
    assert(#disappeared == 0, "nothing has left the window yet")

    local surface = surfaceOf(renderer)
    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 2000 })
    runtime:commit()

    assert(#disappeared > 0, "an entry that left the window must be reported")
end

-- Selecting an entry answers the entry rather than a node id.
do
    local chosen = nil

    local runtime, renderer = start(gui.List {
        data = rows(20),
        itemExtent = 40,
        onSelect = function(event) chosen = event end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    runtime:dispatch(childOf(renderer, surface, 2).id, "onPress", {})

    assert(chosen ~= nil and chosen.index == 2, "a selection carries the entry it belongs to")
    assert(chosen.item.label == "row 2", "a selection carries the item itself")
end

-- A ref scrolls the list to an index, which is arithmetic on this side and one call on the other.
do
    local handle = gui.ref()

    local runtime, renderer = start(gui.List {
        ref = handle,
        data = rows(1000),
        itemExtent = 40,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)
    handle.current.scrollToIndex({ index = 100, animated = false })

    local calls = renderer.calls
    local last = calls[#calls]

    assert(last.method == "scrollTo", "scrolling to an index becomes a scroll to an offset")
    assert(last.id == surface.id, "the call reaches the surface the list owns")
    assert(last.arguments.y == 3960, "the offset is the sum of the extents above the entry")

    assert(handle.current.indexAt({ offset = 3960 }) == 100, "an offset answers the entry at it")
    assert(handle.current.contentExtent() == 40000, "the content extent covers every entry")
    assert(runtime ~= nil)
end

-- A header, a footer and a separator take their place without disturbing the entries between them.
do
    local _, renderer = start(gui.List {
        data = rows(8),
        itemExtent = 40,
        header = gui.Text { text = "header" },
        headerExtent = 60,
        footer = gui.Text { text = "footer" },
        footerExtent = 30,
        separator = gui.Divider {},
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer)

    assert(surface.props.contentExtent == 60 + 8 * 40 + 30, "the content covers the header and the footer")
    assert(childOf(renderer, surface, 1).props.style.top == 0, "the header sits at the start")
    assert(childOf(renderer, surface, 1).props.style.height == 60, "the header takes the extent it declared")
    assert(childOf(renderer, surface, 2).props.style.top == 60, "the first entry starts below the header")

    local divider = renderer:findAll("divider")
    assert(#divider == 7, "a separator sits between entries and not after the last, got " .. #divider)
end

-- An empty list shows what it was told to show instead of nothing.
do
    local _, renderer = start(gui.List {
        data = {},
        itemExtent = 40,
        empty = gui.Text { text = "nothing here" },
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local labels = renderer:findAll("text")
    assert(#labels == 1 and labels[1].props.text == "nothing here", "an empty list shows its empty state")
end

-- A section list flattens its groups, and the header of the section on screen stays pinned to the edge.
do
    local sections = {
        { key = "a", title = "First", data = rows(30) },
        { key = "b", title = "Second", data = rows(30) },
    }

    local runtime, renderer = start(gui.SectionList {
        sections = sections,
        itemExtent = 40,
        headerExtent = 30,
        renderHeader = function(section) return gui.Text { text = section.title } end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer, "sectionlist")
    assert(surface.props.itemCount == 62, "the sections flatten into one array of entries")
    assert(surface.props.stickyHeaders == true, "headers stick unless the caller says otherwise")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 400 })
    runtime:commit()

    local pinned = childOf(renderer, surface, -1)
    assert(pinned.props.style.top == 400, "the pinned header follows the edge")

    local labels = renderer:findAll("text")
    local titled = false
    for index = 1, #labels do
        if labels[index].props.text == "First" then
            titled = true
        end
    end

    assert(titled, "the pinned header shows the section it belongs to")
end

-- The header that is pinned belongs to the section on screen, not to the one before it.
--
-- The realised range starts a margin of cells above the top of the viewport, so a search that went only
-- that far kept the header of the section above pinned over the rows of the section being read.
do
    local sections = {
        { key = "a", title = "First", data = rows(4) },
        { key = "b", title = "Second", data = rows(30) },
    }

    local runtime, renderer = start(gui.SectionList {
        sections = sections,
        itemExtent = 40,
        headerExtent = 30,
        renderHeader = function(section) return gui.Text { text = section.title } end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer, "sectionlist")

    -- The second section's header sits at 30 + 4 * 40 and is one entry above the top of the viewport,
    -- which is inside the margin the realised range starts at.
    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 230 })
    runtime:commit()

    local pinned = childOf(renderer, surface, -1)
    local shown = nil

    for _, node in pairs(renderer.nodes) do
        if node.parent == pinned.id and node.type == "text" then
            shown = node.props.text
        end
    end

    assert(shown == "Second", "the section being read is the one whose header is pinned, got " .. tostring(shown))
end

-- A header still in its own place is not pinned as well, or it would be drawn twice.
do
    local sections = {
        { key = "a", title = "First", data = rows(30) },
        { key = "b", title = "Second", data = rows(30) },
    }

    local _, renderer = start(gui.SectionList {
        sections = sections,
        itemExtent = 40,
        headerExtent = 30,
        renderHeader = function(section) return gui.Text { text = section.title } end,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local titles = 0
    local labels = renderer:findAll("text")

    for index = 1, #labels do
        if labels[index].props.text == "First" then
            titles = titles + 1
        end
    end

    assert(titles == 1, "a header at the top must be drawn once, was drawn " .. titles .. " times")
end

-- A grid arranges its entries in rows of the column count it was given.
do
    local _, renderer = start(gui.Grid {
        data = rows(100),
        columns = 3,
        rowExtent = 80,
        spacing = 0,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer, "grid")
    assert(surface.props.columns == 3, "the surface carries the column count")

    local row = childOf(renderer, surface, 1)
    assert(#row.children == 3, "a row holds one cell per column")
    assert(childOf(renderer, row, 1).props.style.left == "0.0%", "the first column starts at the left edge")
    assert(childOf(renderer, row, 2).props.style.width == (100 / 3) .. "%", "each column takes an equal share")
end

-- A carousel is a list whose entries fill the viewport, paged along its axis.
do
    local _, renderer = start(gui.Carousel {
        data = rows(10),
        itemExtent = 320,
        renderItem = function(item) return gui.Text { text = item.label } end,
    })

    local surface = surfaceOf(renderer, "carousel")
    assert(surface.props.paging == true, "a carousel pages")
    assert(surface.props.horizontal == true, "a carousel runs along x unless told otherwise")
    assert(childOf(renderer, surface, 2).props.style.left == 320, "each page starts where the last one ended")
end

print("gui.list ok")
