local gui = require("gui")

local function fails(build, needle)
    local ok, message = pcall(build)
    assert(not ok, "the call should have been refused")

    if needle ~= nil then
        assert(tostring(message):find(needle, 1, true), "expected a message about " .. needle .. ", got " .. tostring(message))
    end
end

-- Every family reaches the public surface, and no two families claim the same name.
do
    local names = gui.components()
    assert(#names > 40, "the library must expose the whole set, found " .. #names)

    local seen = {}
    for index = 1, #names do
        assert(seen[names[index]] == nil, "duplicate name " .. names[index])
        seen[names[index]] = true
        assert(type(gui[names[index]]) == "function", names[index] .. " must be a constructor")
    end
end

-- A prop a renderer does not honour is refused at the call rather than ignored three times over.
do
    fails(function() return gui.View { padding = 8 } end, "padding")
    fails(function() return gui.Text { text = "x", colour = "red" } end, "colour")
end

-- Style, key, ref and testID are accepted everywhere.
do
    local node = gui.View { style = { padding = 8 }, key = "a", testID = "root" }
    assert(node.props.style.padding == 8, "style must pass through")
    assert(node.key == "a", "a key must reach the element")
end

-- Defaults are filled in so a renderer never has to invent one.
do
    local button = gui.Button { title = "Save" }
    assert(button.props.variant == "filled", "a button defaults to filled")
    assert(button.props.disabled == false, "a button defaults to enabled")

    local input = gui.TextInput {}
    assert(input.props.keyboard == "default", "an input defaults to the plain keyboard")
    assert(input.props.returnKey == "done", "an input defaults to the done key")

    local list = gui.List { data = {}, renderItem = function() end }
    assert(list.props.recycle == true, "a list reuses cells by default")
    assert(list.props.horizontal == false, "a list is vertical by default")
end

-- A prop with a fixed set of values refuses anything outside it, naming what was allowed.
do
    fails(function() return gui.Button { title = "x", variant = "sparkly" } end, "sparkly")
    fails(function() return gui.Image { source = "a", resizeMode = "squish" } end, "squish")
    fails(function() return gui.TextInput { keyboard = "morse" } end, "morse")
    fails(function() return gui.TabBar { tabs = { {} }, position = "sideways" } end, "sideways")
end

-- A component that cannot do its job without a prop says which one is missing.
do
    fails(function() return gui.Image {} end, "source")
    fails(function() return gui.Text {} end, "text")
    fails(function() return gui.Icon {} end, "name")
    fails(function() return gui.Button {} end, "title")
    fails(function() return gui.WebView {} end, "url")
    fails(function() return gui.Tooltip {} end, "text")
end

-- Text may carry its content as a prop or as its child.
do
    local asProp = gui.Text { text = "hello" }
    assert(asProp.props.text == "hello", "the text prop must carry it")

    local asChild = gui.Text { "hello" }
    assert(#asChild.children == 1, "a string child must be kept")
end

-- A list refuses data or a renderer of the wrong shape rather than failing at the first cell.
do
    fails(function() return gui.List { data = "nope", renderItem = function() end } end, "data")
    fails(function() return gui.List { data = {} } end, "renderItem")
    fails(function() return gui.List { data = {}, renderItem = function() end, itemType = "row" } end, "itemType")
end

-- A grid takes a fixed column count or a minimum width, never both.
do
    fails(function()
        return gui.Grid { data = {}, renderItem = function() end, columns = 2, minColumnWidth = 100 }
    end, "not both")
end

-- A slider with an inverted range is refused rather than laid out backwards.
do
    fails(function() return gui.Slider { minimum = 10, maximum = 1 } end, "minimum")
end

-- A determinate progress bar needs a value, and an indeterminate one does not.
do
    fails(function() return gui.ProgressBar {} end, "value")
    assert(gui.ProgressBar { indeterminate = true } ~= nil, "an indeterminate bar needs no value")
end

-- A list carries everything the requirement asks of it.
do
    local list = gui.List {
        data = { 1, 2, 3 },
        renderItem = function(item) return gui.Text { text = tostring(item) } end,
        itemType = function(item) return item % 2 == 0 and "even" or "odd" end,
        horizontal = true,
        recycle = false,
        itemExtent = 44,
        separator = gui.Divider {},
        header = gui.Text { text = "top" },
        footer = gui.Text { text = "bottom" },
        empty = gui.Text { text = "nothing here" },
        onEndReached = function() end,
        onSelect = function() end,
    }

    assert(list.props.horizontal == true, "a list lays out along either axis")
    assert(list.props.recycle == false, "reuse is opt-out")
    assert(type(list.props.itemType) == "function", "the item type is decided per entry")
    assert(list.props.itemExtent == 44, "a fixed extent skips measuring")
end

-- A cell may hold anything a component can build, including another list.
do
    local renderer = gui.headless()

    gui.start(gui.List {
        data = { "a" },
        itemExtent = 40,
        renderItem = function()
            return gui.View {
                gui.List {
                    data = { 1 },
                    itemExtent = 20,
                    renderItem = function() return gui.Text { text = "inner" } end,
                },
            }
        end,
    }, renderer, { size = { width = 320, height = 480 } })

    assert(#renderer:findAll("list") == 2, "a cell may contain another list")

    local labels = renderer:findAll("text")
    assert(#labels == 1 and labels[1].props.text == "inner", "the inner list realised its own cell")
end

print("gui.components ok")
