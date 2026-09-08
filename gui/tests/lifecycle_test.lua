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

--- A screen that says every moment it is told about, in the order it is told.
local function Screen(said, name)
    return gui.component({
        name = "Screen:" .. name,

        onWillMount = function() said[#said + 1] = name .. ":willMount" end,
        onMount = function() said[#said + 1] = name .. ":mount" end,
        onWillAppear = function() said[#said + 1] = name .. ":willAppear" end,
        onAppear = function() said[#said + 1] = name .. ":appear" end,
        onWillDisappear = function() said[#said + 1] = name .. ":willDisappear" end,
        onDisappear = function() said[#said + 1] = name .. ":disappear" end,
        onWillUnmount = function() said[#said + 1] = name .. ":willUnmount" end,
        onUnmount = function() said[#said + 1] = name .. ":unmount" end,

        render = function() return gui.Text { text = name } end,
    })
end

--- Answers what was said and empties the list, so what follows stands on its own.
---
--- The list is emptied rather than replaced, since what says it holds the one it was given.
local function drain(said, moments)
    local kept = {}

    for index = 1, #said do
        if moments == nil then
            kept[#kept + 1] = said[index]
        else
            for at = 1, #moments do
                if said[index]:find(moments[at], 1, true) then
                    kept[#kept + 1] = said[index]
                end
            end
        end
    end

    for index = #said, 1, -1 do
        said[index] = nil
    end

    return table.concat(kept, " ")
end

--- Answers what was said with everything but the named moments taken out.
local function only(said, moments)
    local kept = {}

    for index = 1, #said do
        for at = 1, #moments do
            if said[index]:find(moments[at], 1, true) then
                kept[#kept + 1] = said[index]
            end
        end
    end

    return table.concat(kept, " ")
end

-- Building a screen and showing it are two different things, and each is a pair.
do
    local said = {}
    local One = Screen(said, "one")

    local runtime = select(1, start(gui.View { style = { grow = 1 }, One {} }))

    assert(drain(said) == "one:willMount one:willAppear one:mount one:appear",
        "a screen is built, then shown, and each half is told before and after")

    runtime:stop()

    assert(drain(said) == "one:willDisappear one:willUnmount one:disappear one:unmount",
        "and it goes from the screen before it is taken down, each half told before and after")
end

-- A screen a stack keeps under the one on top is built and never shown.
do
    local said = {}
    local First = Screen(said, "first")
    local Second = Screen(said, "second")

    local Stack = gui.component({
        name = "Stack",
        state = { deep = false },
        render = function(self)
            local screens = { { key = "first", title = "First", content = First {} } }

            if self.state.deep then
                screens[2] = { key = "second", title = "Second", content = Second {} }
            end

            return gui.NavigationStack { index = #screens, screens = screens }
        end,
    })

    local runtime = select(1, start(Stack {}))

    assert(only(said, { "first:" }) == "first:willMount first:willAppear first:mount first:appear",
        "the screen a stack opens on is shown: " .. only(said, { "first:" }))

    drain(said)
    runtime.root.instance:setState({ deep = true })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(only(said, { "first:" }) == "first:willDisappear first:disappear",
        "a screen the stack covered has gone from the screen without being taken down: "
            .. only(said, { "first:" }))
    assert(only(said, { "second:" }) == "second:willMount second:willAppear second:mount second:appear",
        "and the one pushed over it is built and shown: " .. only(said, { "second:" }))

    drain(said)
    runtime.root.instance:setState({ deep = false })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(only(said, { "first:" }) == "first:willAppear first:appear",
        "coming back shows the screen again rather than building it: " .. only(said, { "first:" }))
end

-- A screen held out of sight by whatever is showing it is never told it appeared.
do
    local said = {}
    local Hidden = Screen(said, "hidden")

    start(gui.View { style = { grow = 1 },
        gui.Showing { value = false, Hidden {} },
    })

    assert(only(said, { "hidden:" }) == "hidden:willMount hidden:mount",
        "a screen that was built but never shown hears nothing about appearing: " .. only(said, { "hidden:" }))
end

-- What is showing decides, however deep the component sits under it.
do
    local said = {}
    local Deep = Screen(said, "deep")

    local Tabs = gui.component({
        name = "Tabs",
        state = { tab = 1 },
        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Showing { value = self.state.tab == 1,
                    gui.View { style = { grow = 1 }, gui.View { style = { grow = 1 }, Deep {} } },
                },
            }
        end,
    })

    local runtime = select(1, start(Tabs {}))

    assert(only(said, { "deep:" }):find("deep:appear", 1, true) ~= nil, "the chosen tab is shown")

    drain(said)
    runtime.root.instance:setState({ tab = 2 })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(only(said, { "deep:" }) == "deep:willDisappear deep:disappear",
        "and leaving it takes the tab off the screen without taking it down: " .. only(said, { "deep:" }))

    drain(said)
    runtime.root.instance:setState({ tab = 1 })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(only(said, { "deep:" }) == "deep:willAppear deep:appear",
        "coming back to it shows it again: " .. only(said, { "deep:" }))
end

-- A component whose moment fails takes itself down and not the screen.
--
-- The half of the lifecycle that runs before the batch runs inside the diff, so a handler that throws
-- would stop the whole tree being built rather than only the component that wrote it.
do
    local said = {}
    local Broken = gui.component({
        name = "Broken",
        onWillMount = function() error("this one is broken") end,
        onWillAppear = function() error("and so is this") end,
        render = function() return gui.Text { text = "Broken" } end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(gui.View { style = { grow = 1 },
        Broken {},
        gui.Text { text = "Beside it" },
    }, renderer, {
        size = { width = 390, height = 844 },
        onProblem = function(problem) said[#said + 1] = problem end,
    })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local shown = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" then
            shown[#shown + 1] = node.props.text
        end
    end

    table.sort(shown)

    assert(#said >= 2, "each failing moment is reported: " .. table.concat(said, " / "))
    assert(table.concat(shown, "|") == "Beside it|Broken",
        "and the screen is still built, showing " .. table.concat(shown, "|"))

    runtime:stop()
end

print("gui.lifecycle ok")
