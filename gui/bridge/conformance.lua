local protocol = require("gui.bridge.protocol")

local M = {}

--- The states an application is in, which every platform distinguishes and which mean different things.
---
--- Active is in front and taking input. Inactive is in front and not taking input — a call arriving, the
--- control centre pulled down, a window losing focus — which is where a game pauses and a video need
--- not. Background is out of sight and may be ended without another word, which is where everything a
--- reader would miss is saved.
M.states = { "active", "inactive", "background" }

--- The capabilities a renderer may declare, which a screen reads before it draws what needs one.
M.capabilities = {
    "text", "image", "list", "scroll", "input", "video", "webview", "canvas",
    "picker", "datepicker", "haptics", "safearea", "fontBytes", "imageBytes",
    "audio", "map", "location", "gradient", "nineSlice", "blur", "camera", "microphone",
    "systemBars",
}

local function tree(renderer)
    return renderer:tree()
end

local function only(list)
    assert(#list == 1, "expected one root, found " .. #list)
    return list[1]
end

--- The cases every renderer runs, each one a batch and what the tree must look like afterwards.
---
--- A renderer passes when it applies operations the same way the others do. This is what keeps three
--- implementations from drifting, since a screenshot cannot be compared across platforms but a tree can.
M.cases = {
    {
        name = "creates and attaches a root",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
            })

            local root = only(tree(renderer))
            assert(root.type == "view", "the root must be the node that was created")
            assert(#root.children == 0, "a fresh root has no children")
        end,
    },
    {
        name = "nests children in the order they were inserted",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "text", props = { text = "a" } },
                { op = "insert", id = 2, parent = 1, index = 1 },
                { op = "create", id = 3, type = "text", props = { text = "b" } },
                { op = "insert", id = 3, parent = 1, index = 2 },
            })

            local root = only(tree(renderer))
            assert(root.children[1].props.text == "a", "the first child must come first")
            assert(root.children[2].props.text == "b", "the second child must come second")
        end,
    },
    {
        name = "updates only the props it was given",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = { opacity = 1, testID = "root" } },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "update", id = 1, props = { opacity = 0.5 } },
            })

            local root = only(tree(renderer))
            assert(root.props.opacity == 0.5, "the changed prop must be applied")
            assert(root.props.testID == "root", "an untouched prop must survive")
        end,
    },
    {
        name = "drops a prop an update marked removed",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = { opacity = 0.5 } },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "update", id = 1, props = { opacity = protocol.removed } },
            })

            assert(only(tree(renderer)).props.opacity == nil, "a removed prop must be gone")
        end,
    },
    {
        name = "moves a child without rebuilding it",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "text", props = { text = "a" } },
                { op = "insert", id = 2, parent = 1, index = 1 },
                { op = "create", id = 3, type = "text", props = { text = "b" } },
                { op = "insert", id = 3, parent = 1, index = 2 },
                { op = "move", id = 3, parent = 1, index = 1 },
            })

            local root = only(tree(renderer))
            assert(root.children[1].props.text == "b", "the moved child must land where it was sent")
            assert(root.children[2].props.text == "a", "the other child must shift along")
            assert(#root.children == 2, "a move must not add a child")
        end,
    },
    {
        name = "removes a subtree whole",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "view", props = {} },
                { op = "insert", id = 2, parent = 1, index = 1 },
                { op = "create", id = 3, type = "text", props = { text = "deep" } },
                { op = "insert", id = 3, parent = 2, index = 1 },
                { op = "remove", id = 3 },
                { op = "remove", id = 2 },
            })

            assert(#only(tree(renderer)).children == 0, "the subtree must be gone")
        end,
    },
    {
        name = "places a node at the frame it was given",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "frame", id = 1, x = 10, y = 20, width = 100, height = 40 },
            })

            local frame = only(tree(renderer)).frame
            assert(frame.x == 10 and frame.y == 20, "the origin must be the one that was sent")
            assert(frame.width == 100 and frame.height == 40, "the size must be the one that was sent")
        end,
    },
    {
        name = "reparents a node rather than duplicating it",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "view", props = {} },
                { op = "insert", id = 2, parent = 1, index = 1 },
                { op = "create", id = 3, type = "view", props = {} },
                { op = "insert", id = 3, parent = 1, index = 2 },
                { op = "create", id = 4, type = "text", props = { text = "moved" } },
                { op = "insert", id = 4, parent = 2, index = 1 },
                { op = "move", id = 4, parent = 3, index = 1 },
            })

            local root = only(tree(renderer))
            assert(#root.children[1].children == 0, "the old parent must have let go")
            assert(#root.children[2].children == 1, "the new parent must have taken it")
        end,
    },
    {
        name = "hangs a layer from the surface rather than from where it was written",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "view", props = {} },
                { op = "insert", id = 2, parent = 1, index = 1 },
                { op = "create", id = 3, type = "layer", props = {} },
                { op = "insert", id = 3, parent = 2, index = 1 },
                { op = "create", id = 4, type = "text", props = { text = "over it" } },
                { op = "insert", id = 4, parent = 3, index = 1 },
            })

            local roots = tree(renderer)

            assert(#roots == 2, "a layer stands beside the application, found " .. #roots .. " roots")
            assert(roots[2].type == "layer", "and over it rather than under it")
            assert(#roots[1].children[1].children == 0, "nothing of it is left where it was written")
            assert(roots[2].children[1].props.text == "over it", "and what it holds came with it")
        end,
    },
    {
        name = "refuses a batch that breaks the contract",
        run = function(renderer)
            local ok = pcall(renderer.apply, renderer, { { op = "update", id = 1 } })
            assert(not ok, "an update with no props must be refused")

            ok = pcall(renderer.apply, renderer, { { op = "nonsense", id = 1 } })
            assert(not ok, "an unknown operation must be refused")
        end,
    },
    {
        name = "answers a measurement for a string",
        run = function(renderer)
            local size = renderer:measureText("hello", { fontSize = 16 }, nil)

            assert(type(size.width) == "number" and size.width > 0, "a measurement must carry a width")
            assert(type(size.height) == "number" and size.height > 0, "a measurement must carry a height")
        end,
    },
    {
        name = "answers a finite measurement however it is bounded",
        run = function(renderer)
            local bounds = { 0, 1, 40, nil }

            for index = 1, 4 do
                local size = renderer:measureText("a longer sentence", { fontSize = 16 }, bounds[index])
                local named = tostring(bounds[index])

                assert(type(size.width) == "number" and size.width == size.width,
                    "a width must be a number at bound " .. named)
                assert(type(size.height) == "number" and size.height == size.height,
                    "a height must be a number at bound " .. named)
                assert(size.height < math.huge and size.width < math.huge,
                    "a measurement must be finite at bound " .. named)
                assert(size.height > 0, "a line of text is never zero high, at bound " .. named)
            end
        end,
    },
    {
        name = "measures a string with what it will be drawn with",
        run = function(renderer)
            local plain = renderer:measureText("spacing", { fontSize = 16 }, nil)
            local spaced = renderer:measureText("spacing", { fontSize = 16, letterSpacing = 4 }, nil)

            assert(spaced.width > plain.width,
                "space asked for between letters is space the line needs, got "
                    .. spaced.width .. " against " .. plain.width)

            -- A line is a multiple of the size, and it means that on every platform: asked as a
            -- multiple of the face's own line instead, the same tree is a different height on each.
            local tall = renderer:measureText("spacing", { fontSize = 16, lineHeight = 3 }, nil)

            assert(math.abs(tall.height - 48) <= 1,
                "a line is a multiple of the size, so one string at three of them is 48, got " .. tall.height)
        end,
    },
    {
        name = "a string carries the lines it was written with",
        run = function(renderer)
            local one = renderer:measureText("one", { fontSize = 16 }, nil)
            local three = renderer:measureText("one\ntwo\nthree", { fontSize = 16 }, nil)

            -- A line inside a block is not quite a line on its own, since the leading around a single
            -- one is not repeated, so three lines are about three times one rather than exactly.
            assert(three.height > one.height * 2.5 and three.height < one.height * 3.5,
                "a label of three lines is about three lines tall, got "
                    .. three.height .. " against " .. one.height)
        end,
    },
    {
        name = "reports an event as what the event carries",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "textinput", props = { value = "", onChange = function() end } },
                { op = "insert", id = 1, parent = 0, index = 1 },
            })

            renderer:raise(1, "onChange", "typed")
            renderer:raise(1, "onPress", nil)
            renderer:raise(1, "onScroll", { x = 0, y = 40 })

            local events = renderer.events
            assert(#events >= 3, "every event must be reported")

            local changed = events[#events - 2]
            assert(changed.name == "onChange", "a change is reported by the name of the prop that declared it")
            assert(changed.payload == "typed",
                "a change carries the value itself, not a table holding it, got " .. tostring(changed.payload))

            assert(events[#events - 1].payload == nil, "a press carries nothing")
            assert(events[#events].payload.y == 40, "a scroll carries the offset it reached")
        end,
    },
    {
        name = "reads a radio value as its identity rather than its state",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "radio", props = { value = "monthly", selected = true } },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "radio", props = { value = "yearly", selected = false } },
                { op = "insert", id = 2, parent = 0, index = 2 },
            })

            local radios = tree(renderer)
            assert(radios[1].props.selected == true, "the chosen radio must be the one marked selected")
            assert(radios[2].props.selected == false, "the other radio must be left alone")
            assert(radios[1].props.value == "monthly", "a radio keeps the value it reports when chosen")
        end,
    },
    {
        name = "reports a chosen day as a day rather than an instant",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "datepicker", props = { value = "2026-09-05", onChange = function() end } },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "create", id = 2, type = "timepicker", props = { value = "09:30", onChange = function() end } },
                { op = "insert", id = 2, parent = 0, index = 2 },
            })

            local pickers = tree(renderer)
            assert(pickers[1].props.value == "2026-09-05", "a calendar takes the day it was given")
            assert(pickers[2].props.value == "09:30", "and a clock the time it was given")
        end,
    },
    {
        name = "leaves a field alone when its value has not changed",
        run = function(renderer)
            renderer:apply({
                { op = "create", id = 1, type = "textinput", props = { value = "Ada", onChange = function() end } },
                { op = "insert", id = 1, parent = 0, index = 1 },
                { op = "update", id = 1, props = { value = "Ada" } },
            })

            assert(only(tree(renderer)).props.value == "Ada", "the field must hold the value it was given")
        end,
    },
    {
        name = "paints its own ground from the theme",
        run = function(renderer)
            renderer:showTheme({ appearance = "dark", background = "#101014ff", text = "#e7e2eaff", primary = "#8c9effff", family = "Roboto" })

            renderer:apply({
                { op = "create", id = 1, type = "view", props = {} },
                { op = "insert", id = 1, parent = 0, index = 1 },
            })

            assert(renderer.ground.background == "#101014ff", "the ground it was given is what it paints")
            assert(renderer.ground.appearance == "dark", "and the scheme it was told to be in")
        end,
    },
    {
        name = "declares what it can do",
        run = function(renderer)
            assert(type(renderer.capabilities) == "table", "a renderer must declare its capabilities")

            for index = 1, #M.capabilities do
                local name = M.capabilities[index]
                local value = renderer.capabilities[name]
                assert(value == nil or type(value) == "boolean", name .. " must be declared as a boolean")
            end
        end,
    },
}

--- Runs every case against a freshly built renderer, answering the failures.
function M.run(build)
    local failures = {}

    for index = 1, #M.cases do
        local case = M.cases[index]
        local ok, message = pcall(case.run, build())

        if not ok then
            failures[#failures + 1] = case.name .. ": " .. tostring(message)
        end
    end

    return failures
end

return M
