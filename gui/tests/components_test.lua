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
-- The padding was declared twice for the ones that draw their own — once as what the type is naturally worth and again
-- in the style the renderer draws it with — and the engine added both. A badge showing a single digit
-- came out 32 across and 24 tall for a pill that is 20 by 20, so it hung off whatever it was counting
-- and covered the thing beside it.
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

