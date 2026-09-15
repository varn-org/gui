local async = require("async")
local gui = require("gui")
local conformance = require("gui.bridge.conformance")
local waitFor = require("gui.tests.waiting")

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 390, height = 844 }

    local runtime = gui.start(description, renderer, options)

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

-- The three states are named once, since a host, a screen and the engine must mean the same by them.
do
    assert(#conformance.states == 3, "there are three states, the contract carries " .. #conformance.states)
    assert(table.concat(conformance.states, ",") == "active,inactive,background",
        "and they are active, inactive and background, in that order of going away")
end

-- A component is told the application went away and told which way, and told when it comes back.
do
    local told = {}

    local Screen = gui.component({
        name = "Screen",
        onPause = function(_, state) told[#told + 1] = "pause:" .. state end,
        onResume = function() told[#told + 1] = "resume" end,
        render = function() return gui.Text { text = "here" } end,
    })

    local runtime = start(Screen {})

    runtime:setLifecycle("background")
    runtime:setLifecycle("active")

    assert(table.concat(told, ",") == "pause:background,resume",
        "a screen hears the application go and come back, heard " .. table.concat(told, ","))
end

-- Going from one way of being away to another is not a return, and is not announced as one.
--
-- A call arriving over an application that was already in the background is still away, and a screen
-- that saved on the way out has no reason to save again or to think it is back.
do
    local told = {}

    local Screen = gui.component({
        name = "Screen",
        onPause = function(_, state) told[#told + 1] = "pause:" .. state end,
        onResume = function() told[#told + 1] = "resume" end,
        render = function() return gui.Text { text = "here" } end,
    })

    local runtime = start(Screen {})

    runtime:setLifecycle("inactive")
    runtime:setLifecycle("background")
    runtime:setLifecycle("inactive")
    runtime:setLifecycle("active")

    assert(table.concat(told, ",") == "pause:inactive,resume",
        "away is away however it is reached, heard " .. table.concat(told, ","))
end

-- Every component in the tree is told, not only the one at the top of it.
do
    local heard = 0

    local Deep = gui.component({
        name = "Deep",
        onPause = function() heard = heard + 1 end,
        render = function() return gui.Text { text = "deep" } end,
    })

    local Middle = gui.component({
        name = "Middle",
        render = function() return gui.View { Deep {}, Deep {} } end,
    })

    local runtime = start(gui.View { Middle {}, Deep {} })

    runtime:setLifecycle("background")
    assert(heard == 3, "every screen the tree holds is told, " .. heard .. " were")
end

-- A screen can read where the application is, the way it reads the appearance and the safe area.
do
    local seen = {}

    local Screen = gui.component({
        name = "Screen",
        reads = { "surface" },
        render = function(self)
            seen[#seen + 1] = gui.environment:read(self).state
            return gui.Text { text = "here" }
        end,
    })

    local runtime = start(Screen {})

    assert(seen[1] == "active", "an application starts in front, read " .. tostring(seen[1]))

    runtime:setLifecycle("background")
    runtime:commit()

    assert(seen[#seen] == "background", "and a screen sees it go, read " .. tostring(seen[#seen]))
end

-- An application launched into the background is not told it is in front.
do
    local runtime = start(gui.Text { text = "here" }, { state = "background" })

    assert(runtime.environment.state == "background",
        "a runtime starts where the host says it is, started " .. tostring(runtime.environment.state))
end

-- A handler that fails at one of these moments is reported rather than taking the loop with it.
do
    local told = nil

    local Screen = gui.component({
        name = "Screen",
        onPause = function() error("the screen could not save", 0) end,
        render = function() return gui.Text { text = "here" } end,
    })

    local runtime = start(Screen {}, { onProblem = function(problem) told = problem end })

    runtime:setLifecycle("background")

    assert(told ~= nil and told:find("the screen could not save", 1, true) ~= nil,
        "a failure at one of these moments is reported, got " .. tostring(told))
end

async.run(function()
    -- What a component asked to happen later waits for the application to come back.
    --
    -- A suspended application on one platform runs nothing at all, a paused one on another carries on,
    -- and a hidden tab on the third is throttled without being stopped, so the same timer fires three
    -- ways. It fires one way here: it waits.
    do
        local turns = 0

        local Screen = gui.component({
            name = "Screen",
            onMount = function(self)
                self:every(10, function() turns = turns + 1 end)
            end,
            render = function() return gui.Text { text = "here" } end,
        })

        local runtime = start(Screen {})

        waitFor(function() return turns > 0 end)
        assert(turns > 0, "a timer turns while the application is in front")

        runtime:setLifecycle("background")

        local taken = turns
        async.sleep(80):await()

        assert(turns == taken, "and stops while it is away, took " .. (turns - taken) .. " turns")

        runtime:setLifecycle("active")

        waitFor(function() return turns > taken end)
        assert(turns > taken, "and carries on when it comes back, took " .. (turns - taken) .. " turns")
    end

    print("gui.application ok")
end)
