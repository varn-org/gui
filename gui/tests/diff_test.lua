local element = require("gui.element")
local diff = require("gui.diff")

local View = element.define("view")
local Text = element.define("text")

local function count(ops, kind)
    local total = 0
    for index = 1, #ops do
        if ops[index].op == kind then
            total = total + 1
        end
    end

    return total
end

local function find(ops, kind)
    for index = 1, #ops do
        if ops[index].op == kind then
            return ops[index]
        end
    end
end

-- The array part of a spec becomes the children and everything else becomes the props.
do
    local node = View { padding = 8, Text { text = "a" }, Text { text = "b" } }

    assert(element.isElement(node), "a constructor must answer an element")
    assert(node.type == "view", "the type must be the one the constructor was defined with")
    assert(node.props.padding == 8, "a named field must land in the props")
    assert(#node.children == 2, "the array part must become the children")
    assert(node.children[1].props.text == "a", "children must keep their order")
end

-- A bare string is a text node, so a label does not need a wrapper to say something.
do
    local node = View { "hello" }

    assert(#node.children == 1, "a string must become one child")
    assert(node.children[1].type == "text", "a string child must become a text node")
    assert(node.children[1].props.text == "hello", "the string must become the text prop")
end

-- A nested list is flattened, which is what a map over data produces.
do
    local rows = {}
    for index = 1, 3 do
        rows[index] = Text { text = "row " .. index }
    end

    local node = View { rows }
    assert(#node.children == 3, "a list of elements must flatten into the children")
end

-- A fresh mount creates every node once and inserts it under its parent.
do
    diff.resetIds()
    local _, ops = diff.mount(View { Text { text = "a" } })

    assert(count(ops, "create") == 2, "a mount must create the root and its child")
    assert(count(ops, "insert") == 2, "a mount must insert the child and the root")
    assert(count(ops, "update") == 0, "a mount has nothing to update")
end

-- A re-render that changes one leaf must not touch anything else.
do
    local node = diff.mount(View { Text { text = "a" }, Text { text = "b" } })
    local ops = diff.reconcile(node, View { Text { text = "a" }, Text { text = "changed" } })

    assert(#ops == 1, "one changed leaf must produce one operation, got " .. #ops)
    assert(ops[1].op == "update", "the operation must be an update")
    assert(ops[1].props.text == "changed", "the update must carry the new value")
end

-- An update carries only what changed, never the whole prop table.
do
    local node = diff.mount(View { padding = 8, margin = 4 })
    local ops = diff.reconcile(node, View { padding = 12, margin = 4 })

    local update = find(ops, "update")
    assert(update ~= nil, "a changed prop must produce an update")
    assert(update.props.padding == 12, "the changed prop must be carried")
    assert(update.props.margin == nil, "an unchanged prop must not be carried")
end

-- A prop the new tree dropped is reported as removed rather than left in place.
do
    local node = diff.mount(View { padding = 8 })
    local ops = diff.reconcile(node, View {})

    local update = find(ops, "update")
    assert(update ~= nil, "dropping a prop must produce an update")
    assert(update.props.padding == diff.removed, "a dropped prop must be marked removed")
end

-- An identical re-render produces nothing at all.
do
    local node = diff.mount(View { padding = 8, Text { text = "a" } })
    local ops = diff.reconcile(node, View { padding = 8, Text { text = "a" } })

    assert(#ops == 0, "an unchanged tree must produce no operations, got " .. #ops)
end

-- A keyed child survives a reorder, keeping the identity the renderer already has.
do
    local node = diff.mount(View {
        Text { key = "a", text = "a" },
        Text { key = "b", text = "b" },
        Text { key = "c", text = "c" },
    })

    local ids = {}
    for index = 1, #node.children do
        ids[node.children[index].props.text] = node.children[index].id
    end

    local ops = diff.reconcile(node, View {
        Text { key = "c", text = "c" },
        Text { key = "a", text = "a" },
        Text { key = "b", text = "b" },
    })

    assert(count(ops, "create") == 0, "a reorder must not rebuild a keyed child")
    assert(count(ops, "remove") == 0, "a reorder must not destroy a keyed child")
    assert(count(ops, "move") > 0, "a reorder must move the children that landed elsewhere")

    for index = 1, #node.children do
        local child = node.children[index]
        assert(child.id == ids[child.props.text], "a keyed child must keep its id across a reorder")
    end
end

-- Two children of one node under one key are refused, since a key names one child.
--
-- Written that way the second takes the first's place in the index the diff matches against, the first
-- matches nothing on the commit after and is taken down, and a row a screen drew disappears with nothing
-- anywhere saying why. Both are drawn on the first commit, so it never surfaces where it was written.
do
    local twice = function()
        return diff.mount(View {
            Text { key = "same", text = "first" },
            Text { key = "same", text = "second" },
        })
    end

    local ok, problem = pcall(twice)

    assert(not ok, "two children under one key must be refused")
    assert(tostring(problem):find("carry the key same", 1, true) ~= nil,
        "and the refusal must name the key, it said " .. tostring(problem))

    -- One key per node, so the same key under two different parents is two different children.
    local fine = diff.mount(View {
        View { key = "left", Text { key = "label", text = "one" } },
        View { key = "right", Text { key = "label", text = "two" } },
    })

    assert(#fine.children == 2, "a key is only ever compared against its own siblings")

    local after = pcall(diff.reconcile, fine, View {
        View { key = "left", Text { key = "label", text = "one" } },
        View { key = "left", Text { key = "label", text = "two" } },
    })

    assert(not after, "and a commit that introduces one is refused as well")
end

-- A child that is genuinely gone is removed, and a new one is created.
do
    local node = diff.mount(View { Text { key = "a", text = "a" }, Text { key = "b", text = "b" } })
    local ops = diff.reconcile(node, View { Text { key = "a", text = "a" }, Text { key = "c", text = "c" } })

    assert(count(ops, "remove") == 1, "the child that left must be removed")
    assert(count(ops, "create") == 1, "the child that arrived must be created")
    assert(#node.children == 2, "the tree must hold what the new description asked for")
end

-- Without a key, position decides identity, so a node is reused in place.
do
    local node = diff.mount(View { Text { text = "a" }, Text { text = "b" } })
    local firstId = node.children[1].id

    local ops = diff.reconcile(node, View { Text { text = "b" }, Text { text = "a" } })

    assert(count(ops, "create") == 0, "an unkeyed swap must reuse the nodes in place")
    assert(node.children[1].id == firstId, "position identity keeps the node where it was")
    assert(count(ops, "update") == 2, "both positions changed their text")
end

-- A child whose type changed is a different thing, so it is rebuilt rather than updated.
do
    local node = diff.mount(View { Text { key = "a", text = "a" } })
    local ops = diff.reconcile(node, View { View { key = "a" } })

    assert(count(ops, "create") == 1, "a changed type must create the replacement")
    assert(count(ops, "remove") == 1, "a changed type must remove what it replaced")
end

-- A key is what says two nodes of the same type are different things, wherever the node sits.
--
-- A component's own root compared on its type alone is patched in place when the key says it is
-- something else. Nothing about it is then new, so nothing it declared to arrive from is applied and
-- every overlay, drawer and pushed screen reaches the screen in a single frame while the way out of
-- them animates correctly.
do
    local gui = require("gui")

    local Switching = gui.component({
        name = "Switching",
        state = { shown = false },
        render = function(self)
            if not self.state.shown then
                return gui.View { key = "absent", style = { width = 0, height = 0 } }
            end

            return gui.View {
                key = "present",
                style = { width = 100, height = 100 },
                enter = { opacity = 0 },
                transition = { duration = 250, delay = 0, easing = { 0.4, 0, 0.2, 1 } },
            }
        end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(Switching {}, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local before = #renderer.batches

    runtime.root.instance:setState({ shown = true })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local arrived = nil

    for index = before + 1, #renderer.batches do
        for _, op in ipairs(renderer.batches[index]) do
            if op.op == "create" and op.props ~= nil and op.props.enter ~= nil then
                arrived = op
            end
        end
    end

    assert(arrived ~= nil, "a root under a new key must be created, not patched into the old one")
    assert(arrived.props.enter.opacity == 0, "and it must carry what it arrives from")
    assert(arrived.props.transition ~= nil, "and how long the arrival takes")
end

-- A tree mutated at random reaches the renderer as exactly the tree the description says.
--
-- Reordering, replacing and removing are where a reconciler goes wrong quietly: the ops apply, the
-- renderer holds a tree, and it is not the one the description named. Eighty rounds of insert, remove,
-- move, replace and re-key at random depths are compared node for node, and every batch is checked for
-- an op that names something the same batch removed.
do
    local gui = require("gui")

    math.randomseed(11)

    --- Answers a description built from a shape, which is what both sides are compared against.
    local function describe(shape)
        local children = {}

        for index = 1, #shape do
            local entry = shape[index]

            if entry.kind == "text" then
                children[index] = gui.Text { key = entry.key, text = entry.label }
            else
                children[index] = gui.View { key = entry.key, style = { height = entry.height },
                    table.unpack(describe(entry.children)) }
            end
        end

        return children
    end

    --- Answers what the renderer holds, as the shape a description would have built.
    local function held(node)
        local shape = {}

        for index = 1, #node.children do
            local child = node.children[index]

            if child.type == "text" then
                shape[index] = { kind = "text", label = child.props.text }
            else
                shape[index] = { kind = "view", height = child.props.style.height, children = held(child) }
            end
        end

        return shape
    end

    --- Answers whether what was asked for and what is drawn are the same tree.
    local function same(wanted, drawn, path)
        if #wanted ~= #drawn then
            return path .. ": " .. #wanted .. " children asked for, " .. #drawn .. " drawn"
        end

        for index = 1, #wanted do
            local one, other = wanted[index], drawn[index]
            local at = path .. "/" .. index

            if one.kind ~= other.kind then
                return at .. ": a " .. one.kind .. " asked for, a " .. other.kind .. " drawn"
            end

            if one.kind == "text" and one.label ~= other.label then
                return at .. ": " .. one.label .. " asked for, " .. tostring(other.label) .. " drawn"
            end

            if one.kind == "view" then
                if one.height ~= other.height then
                    return at .. ": " .. one.height .. " tall asked for, " .. tostring(other.height) .. " drawn"
                end

                local wrong = same(one.children, other.children, at)
                if wrong ~= nil then
                    return wrong
                end
            end
        end

        return nil
    end

    local next = 0

    local function entry(depth)
        next = next + 1

        if depth <= 0 or math.random() < 0.55 then
            return { kind = "text", key = "k" .. next, label = "label " .. next }
        end

        local children = {}

        for index = 1, math.random(0, 3) do
            children[index] = entry(depth - 1)
        end

        return { kind = "view", key = "k" .. next, height = math.random(10, 60), children = children }
    end

    --- Changes a shape the way a screen changes: something arrives, leaves, moves or becomes another thing.
    local function mutate(shape, depth)
        local roll = math.random()

        if #shape > 0 and roll < 0.2 then
            table.remove(shape, math.random(#shape))
        elseif #shape > 1 and roll < 0.4 then
            local from = math.random(#shape)
            table.insert(shape, math.random(#shape), table.remove(shape, from))
        elseif #shape > 0 and roll < 0.55 then
            shape[math.random(#shape)] = entry(depth - 1)
        elseif #shape > 0 and roll < 0.7 then
            local at = math.random(#shape)

            if shape[at].kind == "text" then
                shape[at].label = "label " .. math.random(1000)
            else
                shape[at].height = math.random(10, 60)
            end
        else
            table.insert(shape, math.random(#shape + 1), entry(depth - 1))
        end

        for index = 1, #shape do
            if shape[index].kind == "view" and math.random() < 0.4 then
                mutate(shape[index].children, depth - 1)
            end
        end

        return shape
    end

    local shape = {}

    for index = 1, 4 do
        shape[index] = entry(2)
    end

    local Screen = gui.component({
        name = "Fuzzed",
        state = { round = 0 },
        render = function() return gui.View { style = { grow = 1 }, table.unpack(describe(shape)) } end,
    })

    local renderer = gui.headless()
    local app = gui.start(Screen {}, renderer, { size = { width = 390, height = 844 } })

    for round = 1, 80 do
        mutate(shape, 3)

        local before = #renderer.batches
        app.root.instance:setState({ round = round })
        app:commit()

        for index = before + 1, #renderer.batches do
            local batch = renderer.batches[index]
            local gone = {}

            for position = 1, #batch do
                local op = batch[position]

                assert(op.id == nil or gone[op.id] == nil,
                    "round " .. round .. ": " .. op.op .. " names node " .. tostring(op.id)
                        .. ", which the same batch removed")

                if op.op == "remove" then
                    gone[op.id] = true
                end
            end
        end

        local wrong = same(shape, held(renderer:tree()[1]), "round " .. round)
        assert(wrong == nil, "the tree drawn is not the tree asked for, " .. tostring(wrong))
    end
end

print("gui.diff ok")
