local async = require("async")
local gui = require("gui")

--- Answers a runtime drawing into a headless renderer, which is what the operations are read back from.
local function start(description, options)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, options or { size = { width = 320, height = 640 } })

    runtime:commit()
    return runtime, renderer
end

local function drain(runtime)
    for _ = 1, 8 do
        runtime:commit()
    end
end

--- Answers every node of a type the renderer holds, which is what an overlay is looked for among.
local function found(renderer, type)
    local nodes = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == type then
            nodes[#nodes + 1] = node
        end
    end

    return nodes
end

-- A transition reaches a renderer as a duration in milliseconds and four control points.
--
-- Every platform takes a cubic bezier, and each takes it by its numbers rather than by a name only one
-- of them knows, so naming a curve in Lua is what stops three renderers disagreeing about `easeOut`.
do
    local _, renderer = start(gui.View {
        style = { opacity = 1 },
        transition = { duration = "fast", easing = "easeInOut" },
    })

    local node = renderer:find("view")
    local timing = node.props.transition

    assert(timing ~= nil, "a transition must reach the renderer")
    assert(timing.duration == 150, "a named duration must reach it as milliseconds, got " .. tostring(timing.duration))
    assert(timing.delay == 0, "a transition with no delay must carry nought")
    assert(#timing.easing == 4, "an easing must reach the renderer as four control points")
    assert(timing.easing[1] == 0.42 and timing.easing[3] == 0.58, "easeInOut must carry its own curve")
end

-- The state a node arrives from is resolved the way any other style is.
do
    local theme = gui.theme.create()
    local _, renderer = start(
        gui.View { style = { opacity = 1 }, enter = { opacity = 0, background = "primary" } },
        { size = { width = 320, height = 640 }, theme = theme }
    )

    local entering = renderer:find("view").props.enter

    assert(entering ~= nil, "the state a node arrives from must reach the renderer")
    assert(entering.opacity == 0, "an arriving node must carry the opacity it starts at")
    assert(entering.background == gui.color.toHex(theme.colors.primary),
        "the state a node arrives from is resolved like any other style")
end

-- A transition written the same way twice is the same transition, so a node is not marked as changed.
do
    local Screen = gui.component({
        name = "Screen",
        state = { count = 0 },
        render = function(self)
            return gui.View {
                style = { width = 100, height = 100 },
                transition = { duration = "fast" },
                gui.Text { text = tostring(self.state.count) },
            }
        end,
    })

    local runtime, renderer = start(Screen {})
    local before = #renderer.batches

    runtime.root.instance:setState({ count = 1 })
    drain(runtime)

    local touched = 0

    for index = before + 1, #renderer.batches do
        local batch = renderer.batches[index]

        for position = 1, #batch do
            if batch[position].op == "update" and batch[position].props.transition ~= nil then
                touched = touched + 1
            end
        end
    end

    assert(touched == 0, "a transition written again is the same transition, sent " .. touched .. " times")
end

-- One arrival at a time: what is inside something that is arriving arrives with it.
--
-- A screen pushed onto a stack travels in from the side, and everything mounted with it is mounted in
-- the same commit. A block that also arrives from below adds its own travel to the screen's and the
-- whole thing comes in diagonally, which is what a reader sees as a bug rather than as motion.
do
    local renderer = gui.headless()
    local runtime = gui.start(gui.View {
        style = { grow = 1 },
        enter = { opacity = 0, transform = { translateX = 40 } },
        transition = { duration = 200 },

        gui.View {
            key = "block",
            style = { height = 80 },
            enter = { opacity = 0, transform = { translateY = 16 } },
            transition = { duration = 200 },
            gui.Text { text = "Inside" },
        },
    }, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local screen = nil
    local block = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.key == "block" then
            block = node
        elseif node.type == "view" and node.props.enter ~= nil then
            screen = node
        end
    end

    assert(screen ~= nil, "the screen keeps the arrival it was given")
    assert(block ~= nil, "and what is inside it is built")
    assert(block.props.enter == nil,
        "what is inside something that is arriving does not arrive separately, it carries "
            .. tostring(block.props.enter))

    runtime:stop()
end

-- A node that arrives on its own, with nothing arriving above it, keeps its arrival.
do
    local Screen = gui.component({
        name = "Screen",
        state = { shown = false },
        render = function(self)
            return gui.View { style = { grow = 1 },
                self.state.shown and gui.View {
                    key = "later",
                    style = { height = 40 },
                    enter = { opacity = 0, transform = { translateY = 16 } },
                    transition = { duration = 200 },
                } or false,
            }
        end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(Screen {}, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    runtime.root.instance:setState({ shown = true })
    runtime:commit()

    local later = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.key == "later" then
            later = node
        end
    end

    assert(later ~= nil, "the node that was added is built")
    assert(later.props.enter ~= nil, "and it arrives, since nothing above it was arriving")

    runtime:stop()
end


-- An overlay dismissed stays on screen for as long as its exit takes.
--
-- A node removed from the tree is gone the moment the commit lands, so an overlay that vanished between
-- two frames is one nobody saw leave. Presence holds it, hands the renderer the state to animate
-- towards, and only then lets it go.
async.run(function()
    local Screen = gui.component({
        name = "Screen",
        state = { open = true },
        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Presence {
                    visible = self.state.open,
                    transition = "slideUp",
                    duration = 60,
                    gui.Text { key = "card", text = "Inside" },
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    assert(#found(renderer, "text") == 1, "what a presence holds must be on screen while it is visible")

    runtime.root.instance:setState({ open = false })
    drain(runtime)

    local leaving = found(renderer, "text")
    assert(#leaving == 1, "what a presence holds must stay on screen while it leaves")

    local leavingStates = 0

    for _, node in ipairs(found(renderer, "view")) do
        if node.props.style ~= nil and node.props.style.opacity == 0 then
            leavingStates = leavingStates + 1
        end
    end

    assert(leavingStates == 1, "a leaving node must be given the state to animate towards")

    async.sleep(180):await()
    drain(runtime)

    assert(#found(renderer, "text") == 0, "what a presence holds must go once its exit has had its time")

    print("gui.animation ok")
end)
