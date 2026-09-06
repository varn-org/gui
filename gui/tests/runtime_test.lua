local element = require("gui.element")
local component = require("gui.component")
local runtime = require("gui.runtime")
local headless = require("gui.bridge.headless")

local View = element.define("view")
local Text = element.define("text")

-- A mount reaches the renderer as one batch that builds the whole tree.
do
    local renderer = headless.create()
    local app = runtime.start(View { Text { text = "hello" } }, renderer, { size = { width = 200, height = 100 } })

    local tree = renderer:tree()
    assert(#tree == 1, "the root must be attached once")
    assert(tree[1].type == "view", "the root must be the view")
    assert(tree[1].children[1].type == "text", "the child must be the text")
    assert(app ~= nil)
end

-- Every node receives a frame, relative to the node it sits inside.
do
    local renderer = headless.create()
    runtime.start(
        View { style = { padding = 10 }, View { style = { height = 20 } } },
        renderer,
        { size = { width = 100, height = 100 } }
    )

    local root = renderer:tree()[1]
    assert(root.frame.width == 100, "the root fills the surface")

    local child = root.children[1]
    assert(child.frame.x == 10 and child.frame.y == 10, "the child sits inside the padding")
    assert(child.frame.width == 80, "the child stretches across the content box")
end

-- A state change reaches the renderer as an update, and only for what changed.
do
    local renderer = headless.create()

    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return View { Text { text = "count " .. self.state.count } }
        end,
    })

    local app = runtime.start(Counter {}, renderer, { size = { width = 100, height = 100 } })
    local instance = app.root.instance

    instance:setState({ count = 1 })
    assert(app:needsCommit(), "a state change must schedule a commit")

    app:commit()
    assert(renderer:find("text").props.text == "count 1", "the renderer must see the new text")
    assert(renderer:counted("create") == 0, "an update must not rebuild anything")
end

-- Many state changes in one turn produce one commit.
do
    local renderer = headless.create()

    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return Text { text = tostring(self.state.count) }
        end,
    })

    local app = runtime.start(Counter {}, renderer, { size = { width = 100, height = 100 } })
    local before = #renderer.batches

    app.root.instance:setState({ count = 1 })
    app.root.instance:setState({ count = 2 })
    app.root.instance:setState({ count = 3 })
    app:commit()

    assert(#renderer.batches == before + 1, "three changes must produce one batch")
    assert(renderer:find("text").props.text == "3", "the commit must carry the last state")
end

-- A commit with nothing to do sends nothing at all.
do
    local renderer = headless.create()
    local app = runtime.start(View {}, renderer, { size = { width = 100, height = 100 } })

    local before = #renderer.batches
    app:commit()

    assert(#renderer.batches == before, "an idle commit must not reach the renderer")
end

-- Resizing recomputes the frames and leaves the tree alone.
do
    local renderer = headless.create()
    local app = runtime.start(View { style = { padding = 10 } }, renderer, { size = { width = 100, height = 100 } })

    app:resize(300, 200)
    app:commit()

    local root = renderer:tree()[1]
    assert(root.frame.width == 300 and root.frame.height == 200, "the root must take the new size")
    assert(renderer:counted("create") == 0, "a resize must not rebuild the tree")
end

-- A frame that did not move is not sent again.
do
    local renderer = headless.create()
    local app = runtime.start(View { style = { padding = 10 }, View { style = { height = 20 } } }, renderer, {
        size = { width = 100, height = 100 },
    })

    local before = #renderer.batches
    app:resize(100, 100)
    app:schedule()
    app:commit()

    assert(#renderer.batches == before, "an unchanged frame must not reach the renderer at all")
end

-- An event reaches the handler the node carries.
do
    local renderer = headless.create()
    local pressed = 0

    local app = runtime.start(
        View { onPress = function() pressed = pressed + 1 end },
        renderer,
        { size = { width = 100, height = 100 } }
    )

    local id = renderer:find("view").id
    assert(app:dispatch(id, "onPress", {}), "the dispatch must find the handler")
    assert(pressed == 1, "the handler must have run")
end

-- An event for a node with no handler is reported as unhandled rather than raising.
do
    local renderer = headless.create()
    local app = runtime.start(View {}, renderer, { size = { width = 100, height = 100 } })

    local id = renderer:find("view").id
    assert(not app:dispatch(id, "onPress", {}), "a node with no handler answers false")
    assert(not app:dispatch(9999, "onPress", {}), "an unknown node answers false")
end

-- Text is measured through the renderer, and the same question is only asked once.
do
    local renderer = headless.create()
    local asked = 0

    local original = renderer.measureText
    renderer.measureText = function(self, text, style, bound)
        asked = asked + 1
        return original(self, text, style, bound)
    end

    local app = runtime.start(
        View { style = { direction = "row" }, Text { text = "hello", style = { fontSize = 10 } } },
        renderer,
        { size = { width = 200, height = 100 } }
    )

    local first = asked
    assert(first > 0, "the mount must have measured the label")

    -- Laying the same tree out at the same size asks the same question, which the cache already answers.
    app:schedule()
    app:commit()
    assert(asked == first, "a repeated question must come from the cache, asked " .. asked .. " times")

    -- A different width bound is a different question, so the renderer is asked again.
    app:resize(80, 100)
    app:commit()
    assert(asked > first, "a new width bound must reach the renderer")

    local bounded = asked
    app:invalidateMeasurements()
    app:commit()
    assert(asked > bounded, "invalidating must ask the renderer again")
end

-- A batch that broke the contract is refused before it reaches a renderer.
do
    local renderer = headless.create()
    local ok = pcall(renderer.apply, renderer, { { op = "update", id = 1 } })
    assert(not ok, "an update with no props must be refused")

    ok = pcall(renderer.apply, renderer, { { op = "fly", id = 1 } })
    assert(not ok, "an unknown operation must be refused")
end

-- A node is created with a style even when it was written with none of its own.
--
-- A renderer told nothing leaves its widget at the platform's own defaults, and a label drawn at a size
-- the engine never measured is given a frame a few points short of the text it holds.
do
    local gui = require("gui")
    local renderer = gui.headless()
    local app = gui.start(gui.View { style = { grow = 1 }, gui.Text { text = "Left" } }, renderer,
        { size = { width = 390, height = 844 } })

    app:commit()

    for _, node in pairs(renderer.nodes) do
        assert(type(node.props.style) == "table",
            "a " .. node.type .. " was created with no style at all")
    end

    local label = renderer:find("text")
    assert(type(label.props.style.fontSize) == "number", "a string is drawn at a size the theme decided")
    assert(type(label.props.style.color) == "string", "a string is drawn in a colour the theme decided")
end

-- A commit that fails does not take the application with it.
--
-- The runtime marks itself as committing for the length of one, and a runtime in that state schedules
-- no further commits. An error anywhere in a commit left that mark set for good: the screen stopped
-- moving and the application went on running, answering nothing.
do
    local gui = require("gui")
    local broken = false

    local App = gui.component({
        name = "App",
        state = { count = 0 },
        render = function(self)
            if broken then
                error("a render that failed once")
            end

            return gui.Text { text = "count " .. self.state.count }
        end,
    })

    local renderer = gui.headless()
    local app = gui.start(App {}, renderer, { size = { width = 390, height = 844 } })
    app:commit()

    broken = true
    app.root.instance:setState({ count = 1 })
    assert(not pcall(app.commit, app), "a render that throws must reach the caller")

    broken = false
    app.root.instance:setState({ count = 2 })

    assert(app:needsCommit(), "a change after a failed commit must still ask for one")
    assert(app:commit(), "the runtime must commit again once the cause is gone")
    assert(renderer:find("text").props.text == "count 2", "and what it draws must be the state it holds")
end

-- What a handler does is reported rather than trusted, since it belongs to the application.
do
    local gui = require("gui")
    local told = nil

    local renderer = gui.headless()
    local app = gui.start(gui.Pressable { onPress = function() error("a handler that failed", 0) end },
        renderer, {
            size = { width = 390, height = 844 },
            onProblem = function(problem) told = problem end,
        })

    app:commit()

    local pressable = renderer:find("pressable")
    assert(app:dispatch(pressable.id, "onPress", nil), "the handler must be reached")
    assert(told ~= nil and told:find("a handler that failed", 1, true) ~= nil,
        "a handler that failed must be reported, got " .. tostring(told))

    app.root.props.onPress = function() end
    assert(app:dispatch(pressable.id, "onPress", nil), "the next press must still be delivered")
end

print("gui.runtime ok")
