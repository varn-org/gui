local gui = require("gui")

local function start(description, size)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = size or { width = 390, height = 400 } })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function rows(count, watched, told)
    local built = {}

    for index = 1, count do
        built[index] = gui.View {
            key = "row:" .. index,
            style = { height = 100 },
            onEnterView = index == watched and function() told[#told + 1] = "in" end or nil,
            onExitView = index == watched and function() told[#told + 1] = "out" end or nil,
        }
    end

    return built
end

-- A box below the fold is out of view, and comes into it when the surface is scrolled to it.
do
    local told = {}
    local runtime, renderer = start(gui.ScrollView { style = { grow = 1 }, table.unpack(rows(20, 12, told)) })

    assert(#told == 0, "a box eleven hundred points down is not seen, heard " .. table.concat(told, ","))

    local surface = renderer:find("scroll")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 900 })
    assert(table.concat(told, ",") == "in", "and is seen once it is scrolled to, heard " .. table.concat(told, ","))

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 0 })
    assert(table.concat(told, ",") == "in,out", "and goes again, heard " .. table.concat(told, ","))
end

-- A box already on screen is told so on the first commit, without anything being scrolled.
do
    local told = {}

    start(gui.View {
        style = { grow = 1 },
        gui.View {
            style = { height = 100 },
            onEnterView = function() told[#told + 1] = "in" end,
        },
    })

    assert(table.concat(told, ",") == "in", "a box on screen is seen at once, heard " .. table.concat(told, ","))
end

-- A box that has not moved is told once, however many times the surface is scrolled around it.
do
    local told = {}
    local runtime, renderer = start(gui.ScrollView { style = { grow = 1 }, table.unpack(rows(20, 1, told)) })

    local surface = renderer:find("scroll")

    for offset = 0, 40, 10 do
        runtime:dispatch(surface.id, "onScroll", { x = 0, y = offset })
    end

    assert(table.concat(told, ",") == "in", "a box that stayed put is told once, heard " .. table.concat(told, ","))
end

-- A box is cut by every surface between it and the screen, not by the last one alone.
--
-- The box here sits below the fold of a small list that is itself sitting comfortably on screen, so
-- measuring the box against the screen answers that it is visible when it is not: what hides it is its
-- own list, which is three hundred points shorter than what it holds. That is the case the arithmetic
-- exists for, and nothing about the outer page moves in it at all.
do
    local told = {}

    local inner = gui.ScrollView {
        key = "inner",
        style = { height = 200 },
        gui.View { key = "above", style = { height = 300 } },
        gui.View {
            key = "watched",
            style = { height = 100 },
            onEnterView = function() told[#told + 1] = "in" end,
            onExitView = function() told[#told + 1] = "out" end,
        },
    }

    local runtime, renderer = start(gui.View { style = { grow = 1 }, inner }, { width = 390, height = 800 })

    assert(#told == 0,
        "a box below the fold of its own list is not seen, however well the list sits, heard "
            .. table.concat(told, ","))

    local surface = renderer:find("scroll")

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 300 })
    assert(table.concat(told, ",") == "in", "and is seen when its list is scrolled to it, heard " .. table.concat(told, ","))

    runtime:dispatch(surface.id, "onScroll", { x = 0, y = 0 })
    assert(table.concat(told, ",") == "in,out", "and goes when the list is scrolled back, heard " .. table.concat(told, ","))
end

-- A box inside a surface that is itself scrolled out of sight goes with it.
do
    local told = {}

    local inner = gui.ScrollView {
        key = "inner",
        style = { height = 200 },
        gui.View {
            key = "watched",
            style = { height = 100 },
            onEnterView = function() told[#told + 1] = "in" end,
            onExitView = function() told[#told + 1] = "out" end,
        },
    }

    local runtime, renderer = start(gui.ScrollView {
        key = "outer",
        style = { grow = 1 },
        gui.View { key = "spacer", style = { height = 100 } },
        inner,
        gui.View { key = "tail", style = { height = 2000 } },
    }, { width = 390, height = 400 })

    assert(table.concat(told, ",") == "in", "the box starts in sight, heard " .. table.concat(told, ","))

    runtime:dispatch(renderer:findAll("scroll")[1].id, "onScroll", { x = 0, y = 800 })

    assert(table.concat(told, ",") == "in,out",
        "scrolling the page past the list takes the box with it, heard " .. table.concat(told, ","))
end

-- A handler is free to change state, which means it runs after the commit rather than inside one.
do
    local drawn = 0

    local Screen = gui.component({
        name = "Screen",
        state = { seen = false },
        render = function(self)
            drawn = drawn + 1

            return gui.View {
                style = { grow = 1 },
                gui.View {
                    style = { height = 50 },
                    onEnterView = function() self:setState({ seen = true }) end,
                },
                gui.Text { text = self.state.seen and "seen" or "not yet" },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local said = renderer:find("text")

    assert(said.props.text == "seen", "a handler may change state from inside the report, said " .. said.props.text)
    assert(drawn < 10, "and that settles rather than looping, drew " .. drawn .. " times")
end

-- A surface is asked for its offset only while something under it is watching.
--
-- A scroll is reported by the pixel, so binding one on every surface of every screen is a crossing of
-- the bridge for every frame of every drag, on a screen that has no use for any of them.
do
    local _, quiet = start(gui.ScrollView { style = { grow = 1 },
        gui.View { style = { height = 900 } },
    })

    assert(quiet:find("scroll").props.onScroll == nil,
        "a surface with nothing watching under it is not asked for its offset")

    local _, watched = start(gui.ScrollView { style = { grow = 1 },
        gui.View { style = { height = 900 }, onEnterView = function() end },
    })

    assert(watched:find("scroll").props.onScroll == true,
        "and is asked as soon as something under it is")
end

print("gui.seeing ok")
