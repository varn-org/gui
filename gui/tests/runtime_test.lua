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

-- A component whose root child changes type is put back where it was.
do
    local renderer = headless.create()

    local Swapper = component.define({
        state = { loaded = false },
        render = function(self)
            if self.state.loaded then
                return Text { text = "done" }
            end

            return View { style = { height = 10 } }
        end,
    })

    local app = runtime.start(View { Text { text = "before" }, Swapper {} }, renderer, {
        size = { width = 100, height = 100 },
    })

    local swapper = app.root.children[2]
    swapper.instance:setState({ loaded = true })
    app:commit()

    local children = renderer:tree()[1].children
    assert(#children == 2, "the replacement must be attached, got " .. #children .. " children")
    assert(children[2].type == "text", "the replacement must sit where the old node sat")
    assert(children[2].props.text == "done", "the replacement must carry the new description")
end

-- Every node keeps a frame, not only the ones the last layout moved.
do
    local renderer = headless.create()

    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return View {
                style = { padding = 4 },
                Text { text = "steady" },
                Text { text = "count " .. self.state.count },
            }
        end,
    })

    local app = runtime.start(View { Counter {} }, renderer, { size = { width = 200, height = 100 } })
    local steady = nil

    for id, node in pairs(app.byId) do
        if node.props.text == "steady" then
            steady = id
        end
    end

    assert(steady ~= nil, "the fixed text must be in the tree")
    assert(app.frames[steady] ~= nil, "a frame must be known after the mount")

    app.root.children[1].instance:setState({ count = 1 })
    app:commit()

    assert(app.frames[steady] ~= nil,
        "a node that did not move must still have a frame after a commit")
end

-- A state change made while a commit runs is not lost.
do
    local renderer = headless.create()
    local other = nil

    local Watcher = component.define({
        state = { seen = 0 },
        render = function(self)
            other = self
            return Text { text = "seen " .. self.state.seen }
        end,
    })

    local Trigger = component.define({
        state = { count = 0 },
        render = function(self)
            if self.state.count > 0 and other ~= nil then
                other:setState({ seen = self.state.count })
            end

            return Text { text = "trigger " .. self.state.count }
        end,
    })

    local app = runtime.start(View { Watcher {}, Trigger {} }, renderer, {
        size = { width = 200, height = 100 },
    })

    app.root.children[2].instance:setState({ count = 1 })
    app:commit()

    assert(app:needsCommit(), "a change made during a commit must ask for another one")

    app:commit()
    assert(renderer:tree()[1].children[1].props.text == "seen 1",
        "the change made during the commit must reach the renderer")
end

-- A commit never names a node it removed in the same batch.
do
    local renderer = headless.create()

    local Screen = component.define({
        name = "Screen",
        state = { showing = true },
        render = function(self)
            if not self.state.showing then
                return View { Text { text = "after" } }
            end

            return View {
                Text { text = "after" },
                Text { style = { color = "#112233ff" }, text = "before" },
            }
        end,
    })

    local app = runtime.start(View { Screen {} }, renderer, { size = { width = 200, height = 100 } })
    local screen = app.root.children[1]

    local removed = nil

    for id, node in pairs(app.byId) do
        if node.props.text == "before" then
            removed = id
        end
    end

    assert(removed ~= nil, "the node that goes away must be in the tree")

    -- A theme sends every node its style again, and it must send them to the tree the batch leaves
    -- behind rather than the one it started from.
    app:setTheme(app.theme)
    screen.instance:setState({ showing = false })
    app:commit()

    local batch = renderer.batches[#renderer.batches]
    local gone = false

    for index = 1, #batch do
        local op = batch[index]

        if op.id == removed then
            assert(not gone, "no operation may name a node the same batch removed")
            gone = op.op == "remove"
        end
    end
end

-- A component an ancestor has rendered away is not reconciled, however it was left dirty.
do
    local renderer = headless.create()

    local Leaf = component.define({
        name = "Leaf",
        state = { tick = 0 },
        render = function(self) return Text { text = "leaf " .. self.state.tick } end,
    })

    local Screen = component.define({
        name = "Screen",
        state = { showing = true },
        render = function(self)
            if not self.state.showing then
                return View { Text { text = "empty" } }
            end

            return View { Leaf {} }
        end,
    })

    local app = runtime.start(View { Screen {} }, renderer, { size = { width = 200, height = 100 } })
    local screen = app.root.children[1]
    local leaf = screen.child.children[1]

    screen.instance:setState({ showing = false })
    app:commit()

    -- A pass that marks the whole tree, which is what a rotation does, reaches a component its own
    -- ancestor rendered away earlier in the same pass. Reconciling it names ids that no longer exist.
    leaf.instance.state.tick = 1
    app.dirty[leaf] = true
    app:schedule()

    local ok, problem = pcall(app.commit, app)

    assert(ok, "the batch must stand however the dirty set was ordered, got " .. tostring(problem))
    assert(renderer:tree()[1].children[1].children[1].props.text == "empty",
        "the ancestor's own render must be what reaches the renderer")
end

-- A renderer that measures a string as something that is not a real number is named for it.
do
    local renderer = headless.create()

    renderer.measureText = function() return { width = 0 / 0, height = 12 } end

    local ok, problem = pcall(function()
        runtime.start(View { Text { text = "wide" } }, renderer, { size = { width = 100, height = 100 } })
    end)

    assert(not ok, "a measurement that is not a number must be refused")
    assert(tostring(problem):find("something other than a size", 1, true) ~= nil,
        "the renderer must be named for it, got " .. tostring(problem))
end

-- Measuring the same string over and over holds a bounded number of them.
do
    local renderer = headless.create()
    local app = runtime.start(View {}, renderer, { size = { width = 100, height = 100 } })

    for index = 1, 4000 do
        app:measureText("line " .. index, { fontSize = 12 }, nil)
    end

    assert(app.measurements.count <= 512,
        "the measurement cache must stay bounded, holds " .. app.measurements.count)
end

--- What a component asks to happen later, run inside the one body this file has.
local function laterIsReported()
    local renderer = headless.create()
    local told = nil

    local Later = component.define({
        name = "Later",
        onMount = function(self)
            self:after(1, function() error("what happened later failed", 0) end)
        end,
        render = function() return Text { text = "later" } end,
    })

    runtime.start(Later {}, renderer, {
        size = { width = 100, height = 100 },
        onProblem = function(problem) told = problem end,
    })

    async.sleep(40):await()

    assert(told ~= nil and told:find("what happened later failed", 1, true) ~= nil,
        "a deferred action that failed must be reported, got " .. tostring(told))

    -- A component that has gone is not asked to do what it asked for while it was there.
    local ran = 0
    local gone = nil

    local Leaving = component.define({
        name = "Leaving",
        onMount = function(self)
            gone = self
            self:after(20, function() ran = ran + 1 end)
        end,
        render = function() return Text { text = "leaving" } end,
    })

    runtime.start(Leaving {}, headless.create(), { size = { width = 100, height = 100 } })
    gone.mounted = false

    async.sleep(60):await()

    assert(ran == 0, "a component that has gone does not run what it asked for")
end

-- Something a component asks to happen later is reported when it fails, and never stops the loop.

-- A delay is milliseconds, and anything that is not a number of them is refused rather than passed on.
do
    local renderer = headless.create()
    local told = nil

    local Wrong = component.define({
        name = "Wrong",
        onMount = function(self)
            self:after("soon", function() end)
        end,
        render = function() return Text { text = "wrong" } end,
    })

    runtime.start(Wrong {}, renderer, {
        size = { width = 100, height = 100 },
        onProblem = function(problem) told = problem end,
    })

    assert(told ~= nil and told:find("a delay is a number of milliseconds", 1, true) ~= nil,
        "a delay that is not a number must be named, got " .. tostring(told))
end

-- Insets the platform reports again, saying the same thing, cost nothing.
--
-- A platform reports these on every layout it does, which during a rotation is every frame, and what
-- follows lays the whole tree out and renders it again.
do
    local renderer = headless.create()
    local rendered = 0

    local Screen = component.define({
        name = "Screen",
        render = function()
            rendered = rendered + 1
            return Text { text = "screen" }
        end,
    })

    local app = runtime.start(Screen {}, renderer, {
        size = { width = 320, height = 640 },
        insets = { top = 47, right = 0, bottom = 34, left = 0 },
    })

    local before = rendered

    for _ = 1, 20 do
        app:setInsets({ top = 47, right = 0, bottom = 34, left = 0 })
    end

    assert(rendered == before, "insets that say the same thing render nothing, rendered " ..
        (rendered - before) .. " times")
    assert(not app:needsCommit(), "and ask for no commit")

    app:setInsets({ top = 0, right = 0, bottom = 21, left = 0 })

    assert(app:needsCommit(), "insets that changed do ask for one")
end

-- One runtime never renders a component another runtime holds.
--
-- What reads the surface is remembered for the whole process, so a runtime handed another one's
-- component marks a node dirty in a tree that does not contain it, and the batch that follows names
-- ids the renderer it reaches never created.
do
    local environment = require("gui.environment")

    local Reader = component.define({
        name = "Reader",
        render = function(self)
            return Text { text = environment:read(self).platform }
        end,
    })

    local first = runtime.start(Reader {}, headless.create(), {
        size = { width = 320, height = 640 },
        platform = "ios",
    })

    local second = runtime.start(Reader {}, headless.create(), {
        size = { width = 320, height = 640 },
        platform = "android",
    })

    first:setInsets({ top = 20, right = 0, bottom = 0, left = 0 })

    for node in pairs(first.dirty) do
        assert(node.instance.scheduler == first.scheduler,
            "a runtime marks only the components it holds")
    end

    local ok, problem = pcall(first.commit, first)
    assert(ok, "and the batch that follows stands, got " .. tostring(problem))

    second:setInsets({ top = 20, right = 0, bottom = 0, left = 0 })
    assert(pcall(second.commit, second), "and so does the other one's")
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

-- Anything that lands after the tree has been taken down is ignored rather than half done.
--
-- A picture that arrives, a timer that fires and an event a host sends all come whenever they come. A
-- runtime with no tree left has nothing to commit, and building one from a root that is not there
-- reports a failure a reader can do nothing about, once for each thing that was still on its way.
do
    local said = {}
    local renderer = headless.create()
    local app = runtime.start(View { Text { text = "here" } }, renderer, {
        size = { width = 200, height = 100 },
        onProblem = function(problem) said[#said + 1] = problem end,
    })

    local pressed = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" then
            pressed = node.id
        end
    end

    app:stop()

    app:schedule()
    assert(not app:needsCommit(), "a runtime that has been taken down asks for no commit")
    assert(app:commit() == false, "and runs none if it is asked to")
    assert(app:dispatch(pressed, "onPress", nil) == false, "an event for a node that is gone is ignored")

    -- Everything else a host can call while it is taking a surface down.
    app:resize(300, 200)
    app:setInsets({ top = 20, right = 0, bottom = 10, left = 0 })
    app:setAppearance("dark")
    app:setKeyboard(320)
    app:invalidateMeasurements()
    app:invalidatePictures("https://example.test/one.png", true)

    assert(app:goBack() == false, "and there is nowhere left to go back to")
    assert(not app:needsCommit(), "none of it asks for a commit")
    assert(#said == 0, "and none of it is reported as a failure: " .. table.concat(said, " / "))
end

-- A screen that asks for a commit from inside one for ever is stopped and named.
--
-- A component that changes its own state from `onUpdate` is answered with another commit, which calls
-- `onUpdate` again. The loop never idles: the device runs at full tilt with nothing on screen moving
-- and nothing reported anywhere, which is a battery gone and no way of knowing why.
do
    local said = {}
    local Spinning = component.define({
        name = "Spinning",
        state = { at = 0 },
        onUpdate = function(self) self:setState({ at = self.state.at + 1 }) end,
        render = function(self) return Text { text = "at " .. self.state.at } end,
    })

    local renderer = headless.create()
    local app = runtime.start(Spinning {}, renderer, {
        size = { width = 390, height = 844 },
        onProblem = function(problem) said[#said + 1] = problem end,
    })

    app.root.instance:setState({ at = 1 })

    local commits = 0

    for _ = 1, 500 do
        if not app:needsCommit() then
            break
        end

        app:commit()
        commits = commits + 1
    end

    assert(commits < 100, "a screen that never settles is stopped rather than run for ever, ran " .. commits)
    assert(not app:needsCommit(), "and it stops asking")
    assert(#said == 1 and said[1]:find("Spinning", 1, true) ~= nil,
        "and the component that does it is named: " .. table.concat(said, " / "))

    app:stop()
end

-- A screen that settles after a few rounds is left alone, since that is what converging looks like.
do
    local said = {}
    local Settling = component.define({
        name = "Settling",
        state = { at = 0 },
        onUpdate = function(self)
            if self.state.at < 5 then
                self:setState({ at = self.state.at + 1 })
            end
        end,
        render = function(self) return Text { text = "at " .. self.state.at } end,
    })

    local renderer = headless.create()
    local app = runtime.start(Settling {}, renderer, {
        size = { width = 390, height = 844 },
        onProblem = function(problem) said[#said + 1] = problem end,
    })

    app.root.instance:setState({ at = 1 })

    for _ = 1, 20 do
        if not app:needsCommit() then
            break
        end

        app:commit()
    end

    assert(#said == 0, "a screen that settles is left alone: " .. table.concat(said, " / "))
    assert(renderer:find("text").props.text == "at 5", "and it settles where it meant to")

    app:stop()
end

-- Children keyed and shuffled are drawn in the order they were asked for, every time.
--
-- Reordering is where a reconciler goes wrong quietly: the tree is right, the renderer holds the same
-- nodes, and what a reader sees is in an order nobody asked for. Eighty random orders are enough to
-- catch an index that counts a sibling it should not.
do
    local Rows = component.define({
        name = "Rows",
        state = { order = { 1, 2, 3, 4, 5 } },
        render = function(self)
            local rows = {}

            for index, at in ipairs(self.state.order) do
                rows[index] = View { key = "row:" .. at, style = { height = 10 },
                    Text { key = "label", text = "Row " .. at } }
            end

            return View { style = { grow = 1 }, table.unpack(rows) }
        end,
    })

    local renderer = headless.create()
    local app = runtime.start(Rows {}, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not app:needsCommit() then
            break
        end

        app:commit()
    end

    --- Answers what a reader sees, top to bottom, since a frame is relative to the node it sits in.
    local function shown()
        local rows = {}

        for _, node in pairs(renderer.nodes) do
            if node.type == "view" and node.props.key ~= nil and tostring(node.props.key):find("^row:") then
                local label = nil

                for _, child in pairs(renderer.nodes) do
                    if child.parent == node.id and child.type == "text" then
                        label = child.props.text
                    end
                end

                rows[#rows + 1] = { y = node.frame.y, text = label or "" }
            end
        end

        table.sort(rows, function(first, second) return first.y < second.y end)

        local drawn = {}

        for index = 1, #rows do
            drawn[index] = rows[index].text:match("%d+")
        end

        return table.concat(drawn, ",")
    end

    math.randomseed(11)

    for round = 1, 80 do
        local order = {}

        for index = 1, 5 do
            order[index] = index
        end

        for index = 5, 2, -1 do
            local at = math.random(index)
            order[index], order[at] = order[at], order[index]
        end

        app.root.instance:setState({ order = order })
        app:commit()

        local wanted = {}

        for index = 1, #order do
            wanted[index] = tostring(order[index])
        end

        assert(shown() == table.concat(wanted, ","),
            "round " .. round .. " drew " .. shown() .. " where " .. table.concat(wanted, ",") .. " was asked for")
    end

    app:stop()
end

-- A frame that is not a number never crosses the bridge.
--
-- Json carries no NaN and no infinity: either one crosses as null, which a renderer reads as nothing
-- and lays the node out at nowhere. A screen that vanishes with no error anywhere is the worst kind of
-- failure there is, so the frame is refused, the node keeps the one it had, and the problem is said.
do
    local said = {}
    local renderer = headless.create()
    local app = runtime.start(
        View { style = { grow = 1 }, View { key = "broken", style = { width = 0 / 0, height = 20 } } },
        renderer,
        { size = { width = 200, height = 100 }, onProblem = function(problem) said[#said + 1] = problem end }
    )

    for _ = 1, 4 do
        if not app:needsCommit() then
            break
        end

        app:commit()
    end

    local broken = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.key == "broken" then
            broken = node
        end
    end

    assert(broken ~= nil, "the node is still built")
    assert(broken.frame == nil or broken.frame.width == broken.frame.width,
        "a frame that is not a number is never sent, it holds " .. tostring(broken.frame and broken.frame.width))
    assert(#said > 0, "and the problem is reported rather than swallowed")

    app:stop()
end

-- A callback a commit owes is the caller's own, so one that throws is reported rather than trusted.
--
-- These run after the batch has reached the renderer, outside what the commit guards, so an error in
-- one took the whole application with it and left every callback queued behind it unrun: a component
-- whose neighbour threw was never mounted at all.
do
    local told = nil
    local mounted = 0

    local Throws = component.define({
        name = "Throws",
        onMount = function() error("an onMount that failed", 0) end,
        render = function() return Text { text = "first" } end,
    })

    local Mounts = component.define({
        name = "Mounts",
        onMount = function() mounted = mounted + 1 end,
        render = function() return Text { text = "second" } end,
    })

    local renderer = headless.create()
    local ok = pcall(function()
        runtime.start(View { style = { grow = 1 }, Throws {}, Mounts {} }, renderer, {
            size = { width = 320, height = 640 },
            onProblem = function(problem) told = problem end,
        })
    end)

    assert(ok, "a callback that failed must not take the application with it")
    assert(told ~= nil and told:find("an onMount that failed", 1, true) ~= nil,
        "it must be reported, got " .. tostring(told))
    assert(mounted == 1, "and the one behind it must still be mounted")
end

-- A commit arranged by the host is on a coroutine of its own, so a render that fails there is reported.
--
-- Nothing caught it, so the error reached the engine's log and nowhere a reader could see, the
-- coroutine died, and the screen stopped moving with nothing said.
do
    local async = require("async")

    async.run(function()
        laterIsReported()

        local told = nil
        local failing = false

        local Screen = component.define({
            name = "Screen",
            state = { count = 0 },
            render = function(self)
                if failing then
                    error("a render that failed", 0)
                end

                return Text { text = tostring(self.state.count) }
            end,
        })

        local renderer = headless.create()
        local runtime = runtime.start(Screen {}, renderer, {
            size = { width = 320, height = 640 },
            onProblem = function(problem) told = problem end,
        })

        -- The host arranges a commit the way the bridge does, on a coroutine with nothing above it.
        runtime.arrange = function(pending)
            async.spawn(function()
                local ok, problem = pcall(pending.commit, pending)

                if not ok then
                    pending:report("the screen could not be drawn: " .. tostring(problem))
                end
            end)
        end

        failing = true
        runtime.root.instance:setState({ count = 1 })

        async.sleep(60):await()

        assert(told ~= nil and told:find("a render that failed", 1, true) ~= nil,
            "a render that failed after the first frame must be reported, got " .. tostring(told))

        print("gui.runtime ok")
    end)
end
