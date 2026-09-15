local gui = require("gui")
local async = require("async")

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 320, height = 480 }

    local runtime = gui.start(description, renderer, options)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function labels(renderer)
    local found = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" then
            found[#found + 1] = node.props.text
        end
    end

    table.sort(found)
    return table.concat(found, ",")
end

async.run(function()
    -- A value is read and written from anywhere, and reading it from a render binds the two.
    do
        local count = gui.observable(0)

        assert(count:get() == 0, "an observable holds what it was made with")
        assert(count:set(2) == 2, "and answers what it was written")
        assert(count:get() == 2, "and holds it")
        assert(count:update(function(was) return was + 3 end) == 5, "an update reads what is there")
    end

    -- Only what read it is drawn again, which is the whole point of binding to a value rather than
    -- holding it in the component that happens to own the screen.
    do
        local score = gui.observable(1)
        local drew = { top = 0, leaf = 0 }

        local Leaf = gui.component({
            name = "Leaf",
            render = function(self)
                drew.leaf = drew.leaf + 1
                return gui.Text { text = "score " .. score:read(self) }
            end,
        })

        local Top = gui.component({
            name = "Top",
            render = function()
                drew.top = drew.top + 1
                return gui.View { gui.Text { text = "top" }, Leaf {} }
            end,
        })

        local runtime, renderer = start(Top {})

        assert(labels(renderer) == "score 1,top", "the screen draws what the value holds, got " .. labels(renderer))
        assert(drew.top == 1 and drew.leaf == 1, "each component drew once")

        score:set(7)
        runtime:commit()

        assert(labels(renderer) == "score 7,top", "a change reaches the screen, got " .. labels(renderer))
        assert(drew.leaf == 2, "the component that read it drew again, it drew " .. drew.leaf .. " times")
        assert(drew.top == 1, "and the one that did not read it did not, it drew " .. drew.top .. " times")

        -- Writing what is already there is not a change, so it costs nothing rather than a commit.
        score:set(7)
        runtime:commit()

        assert(drew.leaf == 2, "writing the same value draws nothing again, it drew " .. drew.leaf .. " times")
    end

    -- What is gone stops being told, or a value written from a timer marks a node in a tree that left.
    do
        local shown = gui.observable("here")
        local drew = 0

        local Leaf = gui.component({
            name = "Bound",
            render = function(self)
                drew = drew + 1
                return gui.Text { text = shown:read(self) }
            end,
        })

        local Top = gui.component({
            name = "Holder",
            state = { keep = true },
            render = function(self)
                return gui.View { self.state.keep and Leaf {} or gui.Text { text = "gone" } }
            end,
        })

        local runtime = start(Top {})
        local top = nil

        for instance in pairs(shown.readers) do
            top = instance
        end

        assert(top ~= nil, "the component that read it is remembered")

        runtime.root.instance:setState({ keep = false })
        runtime:commit()

        local before = drew
        shown:set("elsewhere")
        runtime:commit()

        assert(drew == before, "a component that has gone is not drawn again, it drew " .. drew .. " times")
        assert(next(shown.readers) == nil, "and it is no longer remembered")
    end

    -- Anything that is not a component listens by subscribing, and stops when it lets go.
    do
        local level = gui.observable(0)
        local heard = {}

        local stop = level:subscribe(function(value, was) heard[#heard + 1] = was .. "->" .. value end)

        level:set(3)
        level:set(3)
        level:set(5)

        assert(table.concat(heard, ",") == "0->3,3->5", "a listener hears every change, heard " .. table.concat(heard, ","))

        stop()
        level:set(9)

        assert(#heard == 2, "and hears nothing once it has let go, heard " .. #heard)
    end

    print("gui.observable ok")
end)
