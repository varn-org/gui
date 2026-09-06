local gui = require("gui")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- Answers the text of every label on screen, which is what a reader sees.
local function shown(renderer)
    local labels = renderer:findAll("text")
    local text = {}

    for index = 1, #labels do
        text[#text + 1] = tostring(labels[index].props.text)
    end

    return table.concat(text, "\n")
end

-- A container builds what it was given into the tree, which is what a screen written as an element is.
--
-- A prop is never mounted by the diff, since only the array part of a spec becomes children. A container
-- that took its screens as a prop and handed them to a renderer therefore showed nothing at all.
do
    local pushed = nil

    local _, renderer = start(gui.NavigationStack {
        index = 2,
        onIndexChange = function(index) pushed = index end,
        screens = {
            { key = "first", title = "First", content = gui.Text { text = "the first screen" } },
            { key = "second", title = "Second", content = gui.Text { text = "the second screen" } },
        },
    })

    local text = shown(renderer)
    assert(text:find("the second screen", 1, true) ~= nil, "the screen at the index must be built, showing\n" .. text)
    assert(text:find("the first screen", 1, true) == nil, "the screen beneath it must not be")
    assert(text:find("Second", 1, true) ~= nil, "the bar must carry the title of the screen it shows")
    assert(text:find("First", 1, true) ~= nil, "the way back must name where it goes")
    assert(pushed == nil, "nothing is popped until the way back is pressed")
end

-- The way back reports where it goes rather than moving on its own, since the caller owns the index.
do
    local popped = nil
    local _, renderer = start(gui.NavigationStack {
        index = 2,
        onIndexChange = function(index) popped = index end,
        screens = {
            { key = "first", title = "First", content = gui.Text { text = "one" } },
            { key = "second", title = "Second", content = gui.Text { text = "two" } },
        },
    })

    local pressables = renderer:findAll("pressable")
    assert(#pressables == 1, "a stack showing its second screen offers one way back, found " .. #pressables)

    pressables[1].props.onPress()
    assert(popped == 1, "pressing the way back must ask for the screen beneath, asked for " .. tostring(popped))
end

-- A stack showing its first screen offers no way back, since there is nowhere to go.
do
    local _, renderer = start(gui.NavigationStack {
        index = 1,
        screens = { { key = "only", title = "Only", content = gui.Text { text = "alone" } } },
    })

    assert(#renderer:findAll("pressable") == 0, "the first screen of a stack has nowhere back to go")
end

-- An accordion builds the content of the section that is open, and only that one.
do
    local chosen = nil

    local _, renderer = start(gui.Accordion {
        expanded = "second",
        onChange = function(key) chosen = key end,
        sections = {
            { key = "first", title = "The first", content = gui.Text { text = "inside the first" } },
            { key = "second", title = "The second", content = gui.Text { text = "inside the second" } },
        },
    })

    local text = shown(renderer)
    assert(text:find("inside the second", 1, true) ~= nil, "the open section must be built, showing\n" .. text)
    assert(text:find("inside the first", 1, true) == nil, "a closed section holds nothing on screen")

    local headers = renderer:findAll("pressable")
    assert(#headers == 2, "every section is a header that can be pressed, found " .. #headers)

    headers[2].props.onPress()
    assert(chosen == nil, "pressing the open section must close it, asked for " .. tostring(chosen))

    headers[1].props.onPress()
    assert(chosen == "first", "pressing a closed section must open it, asked for " .. tostring(chosen))
end

-- An accordion that opens several at once answers the whole set rather than one key.
do
    local chosen = nil

    local _, renderer = start(gui.Accordion {
        multiple = true,
        expanded = { "first" },
        onChange = function(keys) chosen = keys end,
        sections = {
            { key = "first", title = "The first", content = gui.Text { text = "inside the first" } },
            { key = "second", title = "The second", content = gui.Text { text = "inside the second" } },
        },
    })

    renderer:findAll("pressable")[2].props.onPress()

    assert(type(chosen) == "table" and #chosen == 2, "opening a second section keeps the first open")
    assert(chosen[1] == "first" and chosen[2] == "second", "the set answers every section that is open")
end

-- A tab bar reports the tab that was pressed by where it sits, which is what a caller holds.
do
    local picked = nil

    local _, renderer = start(gui.TabBar {
        selectedIndex = 1,
        onChange = function(index) picked = index end,
        tabs = { { key = "home", label = "Home" }, { key = "you", label = "You" } },
    })

    local text = shown(renderer)
    assert(text:find("Home", 1, true) ~= nil and text:find("You", 1, true) ~= nil, "every tab is named")

    renderer:findAll("pressable")[2].props.onPress()
    assert(picked == 2, "a tab reports where it sits, reported " .. tostring(picked))
end

-- A drawer holds nothing on screen while it is closed, and its panel while it is open.
do
    local _, closed = start(gui.Drawer {
        open = false,
        content = gui.Text { text = "what the drawer holds" },
    })

    assert(shown(closed):find("what the drawer holds", 1, true) == nil, "a closed drawer holds nothing")

    local dismissed = false
    local _, open = start(gui.Drawer {
        open = true,
        onClose = function() dismissed = true end,
        content = gui.Text { text = "what the drawer holds" },
    })

    assert(shown(open):find("what the drawer holds", 1, true) ~= nil, "an open drawer builds what it holds")

    open:findAll("pressable")[1].props.onPress()
    assert(dismissed, "pressing outside an open drawer must ask for it to close")
end

-- A table is a header over a list, so what it holds is on screen and sorted the way it was asked for.
do
    local sorted = nil

    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Table {
            style = { height = 280 },
            sortBy = "name",
            onSort = function(key) sorted = key end,
            columns = { { key = "name", title = "Name" }, { key = "kind", title = "Kind" } },
            rows = {
                { name = "Grape", kind = "Berry" },
                { name = "Apple", kind = "Pome" },
                { name = "Cherry", kind = "Drupe" },
            },
        },
    })

    local text = shown(renderer)
    assert(text:find("Name", 1, true) ~= nil and text:find("Kind", 1, true) ~= nil, "every column is named")
    assert(text:find("Apple", 1, true) ~= nil, "every row is on screen, showing\n" .. text)
    assert(text:find("Berry", 1, true) ~= nil, "every cell of a row is on screen")

    local rows = renderer:findAll("list")
    assert(#rows == 1, "a table windows its rows the way any other list does")

    assert(text:find("Apple", 1, true) < text:find("Grape", 1, true),
        "the rows are ordered by the column that was named")

    local headers = renderer:findAll("pressable")
    assert(#headers >= 2, "a column heading can be pressed to sort by it")

    headers[1].props.onPress()
    assert(sorted == "name", "pressing a heading asks to sort by that column, asked for " .. tostring(sorted))
end

print("gui.containers ok")
