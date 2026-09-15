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

-- A step of nought is refused, since the platform's own stepper raises rather than answers.
--
-- A `UIStepper` handed a step that is not positive throws where nothing catches it, which is the whole
-- application gone for a prop nobody sanity checked. The same value is a control that cannot move
-- anywhere else, so it is refused for all three rather than guarded on one.
do
    fails(function() return gui.Stepper { value = 1, step = 0 } end, "step")
    fails(function() return gui.Stepper { value = 1, step = -2 } end, "step")
    fails(function() return gui.Stepper { value = 1, step = "one" } end, "step")
    fails(function() return gui.Slider { step = 0 } end, "step")
    fails(function() return gui.Stepper { value = 1, minimum = 8, maximum = 2 } end, "minimum")

    assert(gui.Stepper { value = 1, step = 0.5, minimum = 0, maximum = 10 } ~= nil,
        "a stepper told how far it goes and how far one press moves it is built")

    fails(function() return gui.Toast { message = "saved", duration = "a while" } end, "duration")

    -- A mark is a drawing a renderer builds, so a rating of a million of them is a screen that never
    -- comes back rather than a rating.
    fails(function() return gui.Rating { value = 3, count = 1000000 } end, "count")
    fails(function() return gui.Rating { value = 3, count = 0 } end, "count")
    fails(function() return gui.Rating { value = 3, count = 2.5 } end, "count")
    fails(function() return gui.Rating { value = 3, size = 0 } end, "size")
    fails(function() return gui.Rating { value = 3, size = "big" } end, "size")

    assert(gui.Rating { value = 3, count = 10, size = 18 } ~= nil, "a rating of ten marks is built")

    -- What a label says is a string. A number is drawn as nothing at all by a renderer that reads one,
    -- and is asked for its length by the measurement that sizes the box it goes in.
    fails(function() return gui.Text { text = 42 } end, "text is a string")
    fails(function() return gui.Text { text = "x", numberOfLines = -1 } end, "numberOfLines")
    fails(function() return gui.Text { text = "x", numberOfLines = 1.5 } end, "numberOfLines")

    -- Every section of a section list carries a header, so a list with nothing to draw one with dies
    -- inside the window on the first section it reaches rather than where it was written.
    local rows = { { id = 1 } }
    local draw = function() return gui.Text { text = "x" } end

    fails(function()
        return gui.SectionList { sections = { { key = "a", data = rows } }, renderItem = draw }
    end, "renderHeader")

    fails(function()
        return gui.SectionList { sections = { "a" }, renderItem = draw, renderHeader = draw }
    end, "section 1")

    fails(function()
        return gui.SectionList { sections = { { key = "a", data = rows, footer = "sum" } },
            renderItem = draw, renderHeader = draw }
    end, "renderFooter")
end

-- The props every node takes are held to their shape, whatever the node is.
--
-- A handler that is not a function is a control that looks pressable and answers nothing: it crosses the
-- bridge as what it is, the renderer binds nothing, and a press finds no function on this side. A key
-- that is a table never matches the one the last render built, so the node is replaced on every commit
-- and everything under it loses its state. A label and a test name are read as strings by three
-- renderers and ignored as anything else.
do
    fails(function() return gui.Button { title = "Go", onPress = "go" } end, "onPress")
    fails(function() return gui.Button { title = "Go", key = {} } end, "key")
    fails(function() return gui.Button { title = "Go", ref = {} } end, "ref")
    fails(function() return gui.Button { title = "Go", testID = 7 } end, "testID")
    fails(function() return gui.Button { title = "Go", accessibilityLabel = 7 } end, "accessibilityLabel")
    fails(function() return gui.Button { title = "Go", style = function() end } end, "style")

    assert(gui.Button { title = "Go", key = 3, testID = "go", onPress = function() end } ~= nil,
        "a key may be a number, since a list keyed by its own indices is a list")
end

-- A canvas draws a fill, a stroke or a text, and is told nothing else.
--
-- All three renderers walk the instructions and draw the three they know, so one none of them knows is
-- drawn by none of them and reported by none of them either: the canvas comes out with a shape missing
-- and nothing anywhere says which one or why. The same goes for a path of one point and a text with
-- nowhere to be drawn.
do
    local square = { { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } }

    fails(function() return gui.Canvas { commands = { { op = "circle", x = 4, y = 4 } } } end, "command 1")
    fails(function() return gui.Canvas { commands = { { op = "fill", path = { { 0, 0 } } } } } end, "two points")
    fails(function() return gui.Canvas { commands = { { op = "fill", path = { { 0 }, { 1, 1 } } } } } end, "starts at a point")
    fails(function() return gui.Canvas { commands = { { op = "text", x = 1, y = 1 } } } end, "says what it draws")
    fails(function() return gui.Canvas { commands = { { op = "text", text = "x", x = 1 } } } end, "two numbers")
    fails(function() return gui.Canvas { commands = { { op = "stroke", path = square, width = 0 } } } end, "width")
    fails(function() return gui.Canvas { commands = { { op = "fill", path = square, color = 7 } } } end, "colour")

    assert(gui.Canvas { commands = {
        { op = "fill", color = "primary", path = square },
        { op = "stroke", color = "#16a34a", width = 4, path = square },
        { op = "text", text = "drawn in Lua", x = 8, y = 8, size = 16 },
    } } ~= nil, "what all three draw is built")
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

print("gui.badges ok")

-- The reference page is what the declarations say, rather than what somebody remembered to write.
--
-- `docs/components.md` is generated from the declarations themselves, so a component added without
-- regenerating it documents a library that no longer exists. Comparing the file against the generator
-- is what keeps the page honest between the day it is written and the day somebody reads it.
do
    local async = require("async")
    local fs = require("fs")
    local reference = require("gui.tools.reference")

    async.run(function()
        local written = fs.readFile("docs/components.md"):await()
        local generated = reference.render()

        for line in generated:gmatch("[^\n]+") do
            if line:find("^| `") ~= nil then
                assert(written:find(line, 1, true) ~= nil,
                    "docs/components.md is behind the declarations, missing:\n  " .. line)
            end
        end

        for line in written:gmatch("[^\n]+") do
            if line:find("^| `") ~= nil then
                assert(generated:find(line, 1, true) ~= nil,
                    "docs/components.md carries a row nothing declares any more:\n  " .. line)
            end
        end

        -- The front page says how many there are, and a number nobody checks is a number that drifts.
        --
        -- It had already gone stale once and gone stale again by eleven, which is what a reader meets
        -- first: the count is read out of the same rows the reference is built from.
        local declared = 0

        for line in generated:gmatch("[^\n]+") do
            if line:find("^| `") ~= nil then
                declared = declared + 1
            end
        end

        -- Everything on the public table is written down where somebody reads before they use it.
        --
        -- A module reachable as `gui.X` is API, and three of them had no page at all: a caller could see
        -- `Router` in the table above and find nothing anywhere saying how a screen under one goes
        -- somewhere. The reference is generated, so what it cannot cover is what this asks about.
        local pages = ""

        for _, name in ipairs({ "components", "architecture", "styling", "layout", "assets", "animation",
            "lists", "forms", "writing", "events", "bridge", "porting", "controls" }) do
            pages = pages .. fs.readFile("docs/" .. name .. ".md"):await()
        end

        local silent = {}

        -- A component is a constructor, so what is left on the table as a table is a module.
        for name, value in pairs(gui) do
            if type(value) == "table" and pages:find("gui." .. name, 1, true) == nil then
                silent[#silent + 1] = "gui." .. name
            end
        end

        table.sort(silent)
        assert(#silent == 0, "these are on the public table and no page mentions them: "
            .. table.concat(silent, ", "))

        local readme = fs.readFile("README.md"):await()
        local said = tonumber(readme:match("There are (%d+), each declaring"))

        assert(said == declared,
            "the README says there are " .. tostring(said) .. " components and there are " .. declared)

        -- Every page is reachable from the front, since one nothing links to is one nobody reads.
        --
        -- A page on the control themes was written, tested and linked from nowhere at all, so the only
        -- way to it was knowing the filename. The index is what a reader arrives at, and the check is
        -- the index rather than the page itself.
        local orphaned = {}

        for _, page in ipairs(fs.readdir("docs"):await()) do
            if page:find("%.md$") ~= nil and readme:find("docs/" .. page, 1, true) == nil then
                orphaned[#orphaned + 1] = page
            end
        end

        table.sort(orphaned)
        assert(#orphaned == 0, "the README links to none of these pages, so nobody arrives at them: "
            .. table.concat(orphaned, ", "))

        print("gui.components ok")
    end)
end

-- A count is held to the ceiling it was given, and written out by the engine rather than by a renderer.
do
    local renderer = gui.headless()
    local app = gui.start(
        gui.View { style = { direction = "row" },
            gui.Badge { key = "over", value = 128, max = 99 },
            gui.Badge { key = "under", value = 3 },
            gui.Badge { key = "dot", dot = true },
        },
        renderer,
        { size = { width = 320, height = 200 } }
    )

    for _ = 1, 4 do
        if not app:needsCommit() then
            break
        end

        app:commit()
    end

    local said = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "badge" then
            said[#said + 1] = node.props.text
        end
    end

    table.sort(said)

    assert(said[1] == "" and said[2] == "3" and said[3] == "99+",
        "a badge says what it counts, held to its ceiling, got " .. table.concat(said, " "))
end

-- A control that draws its own text is as wide as that text plus its padding, counted once.
--
-- A control that draws its own text carries its padding twice over: once as what the type is naturally
-- worth and again in the style the renderer draws it with. Adding both makes a badge showing a single
-- digit 32 across for a pill that is 20 by 20, hanging off whatever it counts and covering what is
-- beside it.
do
    local function measured(node)
        local renderer = gui.headless()
        local runtime = gui.start(gui.View { style = { align = "start" }, node }, renderer,
            { size = { width = 390, height = 844 } })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        for _, found in pairs(renderer.nodes) do
            if found.frame ~= nil and found.type ~= "view" then
                return found, renderer
            end
        end
    end

    --- Answers what a control ought to measure: its own text, its own padding, and nothing else.
    local function expected(node, renderer, text)
        local style = node.props.style
        local size = renderer:measureText(text, style, nil)
        local padding = style.paddingHorizontal or 0

        return size.width + padding * 2
    end

    local badge, renderer = measured(gui.Badge { value = 1 })

    assert(badge.frame.width == 20 and badge.frame.height == 20,
        "a badge of one digit is the pill it declares, is " .. badge.frame.width .. "x" .. badge.frame.height)

    local many = measured(gui.Badge { value = 99 })

    assert(many.frame.width == expected(many, renderer, "99"),
        "and a wider count is that text plus its padding once, is " .. many.frame.width
            .. " against " .. expected(many, renderer, "99"))

    local tooltip = measured(gui.Tooltip { text = "Hi" })

    assert(tooltip.frame.width == expected(tooltip, renderer, "Hi"),
        "a tooltip is its text plus its padding once, is " .. tooltip.frame.width
            .. " against " .. expected(tooltip, renderer, "Hi"))
end

-- A chip carries its label, and the mark that takes it away when there is somewhere to report that.
--
-- The gallery showed one labelled `Removable` that could not be removed: there was no such prop and no
-- such event, so the label was a promise the component had never made.
do
    local removed = nil
    local renderer = gui.headless()

    local runtime = gui.start(gui.View { style = { align = "start" },
        gui.Chip { label = "Tag", onRemove = function() removed = "Tag" end },
        gui.Chip { key = "plain", label = "Plain" },
    }, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local marks = renderer:findAll("canvas")

    assert(#marks == 1, "only the chip with somewhere to report it carries a mark, found " .. #marks)

    local remove = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" and node.props.accessibilityLabel == "Remove Tag" then
            remove = node
        end
    end

    assert(remove ~= nil, "the mark is something a finger can land on, and it is named")

    remove.props.onPress()
    assert(removed == "Tag", "pressing it must report the chip it takes away")

    local labels = renderer:findAll("text")
    local shown = {}

    for index = 1, #labels do
        shown[labels[index].props.text] = true
    end

    assert(shown["Tag"] and shown["Plain"], "both chips show what they are labelled")
end

-- A control the platform decorates carries no look of its own, or there are two backgrounds.
--
-- A compact date picker draws its own rounded pill. A box painted behind it is a second background
-- around the first, wider than it and out of line with it, which is what a reader sees as a dark
-- rectangle behind a control that already looked finished. The two go together: a control the platform
-- answers a size for is a control the platform has drawn, and one the engine gives a bare height to is
-- one the style paints.
do
    local renderer = gui.headless()

    local function painted(node)
        local runtime = gui.start(gui.View { style = { grow = 1 }, node }, renderer,
            { size = { width = 390, height = 844 }, platform = "ios" })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        for _, found in pairs(renderer.nodes) do
            if found.frame ~= nil and found.type ~= "view" then
                local style = found.props.style or {}
                runtime:stop()
                return found.type, style.background
            end
        end
    end

    for _, decorated in ipairs({
        gui.DatePicker { value = "2026-09-17" },
        gui.TimePicker { value = "09:30" },
        gui.Switch { value = true },
        gui.Slider { value = 0.5 },
        gui.ColorPicker { value = "#3b82f6" },
    }) do
        local kind, background = painted(decorated)
        local platform = renderer:measureControl(kind)

        assert(platform.height > 0, "the platform must answer for a " .. kind .. ", which is what makes it one")
        assert(background == nil,
            "a " .. kind .. " is drawn by the platform, so nothing is painted behind it, painted "
                .. tostring(background))
    end

    -- And a control the engine gives a bare height to is bare without one, so it keeps its look.
    for _, plain in ipairs({
        gui.TextInput { value = "" },
        gui.Picker { options = { { value = "a", label = "A" } }, value = "a" },
    }) do
        local kind, background = painted(plain)

        assert(background ~= nil, "a " .. kind .. " is drawn plain, so the style is what paints it")
    end
end

