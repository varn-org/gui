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
    assert(text:find("Second", 1, true) ~= nil, "the bar must carry the title of the screen it shows")
    assert(text:find("First", 1, true) ~= nil, "the way back must name where it goes")
    assert(pushed == nil, "nothing is popped until the way back is pressed")

    -- The screen underneath stays where it was, covered rather than taken down, and takes no touches
    -- while it is covered. Taking it down is what emptied it of everything a reader had put into it.
    assert(text:find("the first screen", 1, true) ~= nil, "the screen beneath must still be there")

    local covered = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.pointerEvents == "none" and node.props.style ~= nil
            and node.props.style.position == "absolute" then
            covered = node
        end
    end

    assert(covered ~= nil, "the screen beneath must take no touches while it is covered")
    assert(covered.props.style.opacity == 0,
        "and it must not be drawn, since a screen over it is not required to be opaque")
end

-- A screen keeps everything a reader put into it while another one is over it.
--
-- Only the top screen was ever built, so going back mounted one that had never been used: a list back at
-- the top and a field emptied of what was typed into it.
do
    local Typed = gui.component({
        name = "Typed",
        state = { text = "" },
        render = function(self)
            return gui.TextInput {
                value = self.state.text,
                onChange = function(value) self:setState({ text = value }) end,
            }
        end,
    })

    local Stack = gui.component({
        name = "Stack",
        state = { index = 1 },
        render = function(self)
            return gui.NavigationStack {
                index = self.state.index,
                onIndexChange = function(index) self:setState({ index = index }) end,
                screens = {
                    { key = "form", title = "Form", content = Typed {} },
                    { key = "detail", title = "Detail", content = gui.Text { text = "detail" } },
                },
            }
        end,
    })

    local runtime, renderer = start(Stack {})
    local field = renderer:find("textinput")

    assert(field ~= nil, "the first screen must carry a field")
    field.props.onChange("Ada")

    for _ = 1, 4 do
        runtime:commit()
    end

    runtime.root.instance:setState({ index = 2 })

    for _ = 1, 4 do
        runtime:commit()
    end

    runtime.root.instance:setState({ index = 1 })

    for _ = 1, 4 do
        runtime:commit()
    end

    local back = renderer:find("textinput")

    assert(back ~= nil, "coming back must show the field again")
    assert(back.props.value == "Ada",
        "and it must still hold what was typed into it, holds " .. tostring(back.props.value))
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

    -- The order is marked with a drawing, so it is the same shape and size on every platform, and the
    -- title is a text of its own so a long one truncates without taking the mark with it.
    assert(text:find("⌃", 1, true) == nil and text:find("⌄", 1, true) == nil,
        "the order is not written as a character, showing\n" .. text)
    assert(text:find("Name", 1, true) ~= nil, "and the column keeps its own title")

    local marks = renderer:findAll("canvas")
    assert(#marks == 1, "the column being sorted by carries one drawn mark, found " .. #marks)
end

-- A heading sits over its own column's data, whichever edge that column is aligned to.
--
-- Both were laid out by one line meaning two different things: a heading is a row, so centring it
-- centred the title across the column, and a cell is a column, so the same word centred it vertically
-- and left the text against the leading edge. A table nobody can read down.
do
    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Table {
            style = { height = 280 },
            columns = {
                { key = "name", title = "Name" },
                { key = "seeds", title = "Seeds", align = "end" },
            },
            rows = { { name = "Apple", seeds = 10 } },
        },
    })

    local function placed(node)
        local x = node.frame.x
        local up = renderer.nodes[node.parent]

        while up ~= nil and up.frame ~= nil do
            x = x + up.frame.x
            up = renderer.nodes[up.parent]
        end

        return x
    end

    local found = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" and node.frame ~= nil then
            found[node.props.text] = placed(node)
        end
    end

    assert(found["Name"] ~= nil and found["Apple"] ~= nil, "the leading column must carry both")
    assert(found["Name"] == found["Apple"],
        "a heading against the leading edge sits over data against it, " .. found["Name"]
            .. " against " .. found["Apple"])

    assert(found["Seeds"] ~= nil and found["10"] ~= nil, "the trailing column must carry both")
    assert(found["Seeds"] > found["Name"], "a trailing column sits after the leading one")
end

-- A table sorts by the column that was pressed, and turns around when it is pressed again.
--
-- Comparing every value as text puts ten before nine, which is a table that looks sorted and is not.
do
    local Screen = gui.component({
        name = "Sorted",
        state = { by = "seeds", order = "ascending" },
        render = function(self)
            return gui.Table {
                style = { height = 300 },
                sortBy = self.state.by,
                sortOrder = self.state.order,
                onSort = function(key)
                    if self.state.by ~= key then
                        self:setState({ by = key, order = "ascending" })
                        return
                    end

                    self:setState({ order = self.state.order == "ascending" and "descending" or "ascending" })
                end,
                columns = {
                    { key = "name", title = "Name" },
                    { key = "seeds", title = "Seeds" },
                },
                rows = {
                    { name = "Fig", seeds = 900 },
                    { name = "Apple", seeds = 10 },
                    { name = "Cherry", seeds = 9 },
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    --- Answers the numbers on screen in the order they are drawn down the table.
    local function column()
        local found = {}

        for _, node in ipairs(renderer:findAll("text")) do
            local value = tonumber(node.props.text)

            if value ~= nil and node.frame ~= nil then
                found[#found + 1] = { value = value, y = node.frame.y }
            end
        end

        table.sort(found, function(first, second) return first.y < second.y end)

        local ordered = {}
        for index = 1, #found do
            ordered[index] = found[index].value
        end

        return ordered
    end

    for _ = 1, 6 do
        runtime:commit()
    end

    local numbers = column()
    assert(numbers[1] == 9, "a number sorts as a number, not as the text of one, got " .. tostring(numbers[1]))

    -- Pressing the heading that is already sorting turns it around.
    local headings = renderer:findAll("pressable")
    assert(#headings >= 2, "a table's headings must be pressable")

    runtime:dispatch(headings[2].id, "onPress", nil)

    for _ = 1, 6 do
        runtime:commit()
    end

    local turned = column()
    assert(turned[1] == 900, "pressing the same heading turns the order around, got " .. tostring(turned[1]))
end

-- A tab shows a screen of its own, and each of them keeps what was put into it while another is shown.
--
-- The gallery had one plain bar and a label that changed colour, which shows what a tab bar looks like
-- and nothing about what one does. Every shape in the gallery now switches real screens.
do
    package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

    local catalogue = require("catalogue")

    for _, key in ipairs({ "standard", "floating", "cover", "paged" }) do
        local demo = catalogue.find("tabs", key)

        assert(demo ~= nil, "the gallery must carry the " .. key .. " tab bar")

        local runtime, renderer = start(gui.View { style = { grow = 1 }, demo.render() })
        local fields = renderer:findAll("textinput")

        -- A pager realises the window it can scroll to and no more, which is what a pager is, so what
        -- every one of them owes is a screen behind each tab rather than a fixed number of them.
        assert(#fields >= 3, key .. " must show a screen a tab at a time, found " .. #fields .. " of them")

        -- What is typed into one screen is still there once another has been shown and left.
        fields[1].props.onChange("kept")

        for _ = 1, 4 do
            runtime:commit()
        end

        local pressables = renderer:findAll("pressable")
        local switched = false

        for index = 1, #pressables do
            if pressables[index].props.accessibilityLabel == "Search" then
                pressables[index].props.onPress()
                switched = true
            end
        end

        assert(switched, key .. " must offer a way to the second tab")

        for _ = 1, 4 do
            runtime:commit()
        end

        local after = renderer:findAll("textinput")
        local held = false

        for index = 1, #after do
            if after[index].props.value == "kept" then
                held = true
            end
        end

        assert(held, key .. " must keep what a screen was holding when another is shown")

        runtime:stop()
    end
end

print("gui.containers ok")
