local gui = require("gui")
local element = require("gui.element")
local diff = require("gui.diff")
local component = require("gui.component")

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

local function run(pending)
    for index = 1, #pending do
        pending[index]()
    end
end

-- A component contributes no node of its own, only what it renders.
do
    local Label = component.define(function(self)
        return Text { text = self.props.text }
    end)

    local node, ops = diff.mount(View { Label { text = "hello" } })

    assert(count(ops, "create") == 2, "only the view and the rendered text are created, got " .. count(ops, "create"))
    assert(node.children[1].kind == "component", "the component stays in the retained tree")
    assert(diff.hostOf(node.children[1]).type == "text", "a component resolves to the host node it rendered")
end

-- A component holds state, and its own render sees it.
do
    local Counter = component.define({
        state = { count = 7 },
        render = function(self)
            return Text { text = "count " .. self.state.count }
        end,
    })

    local node = diff.mount(Counter {})
    assert(diff.hostOf(node).props.text == "count 7", "the initial state must reach the render")
end

-- Two instances of one component do not share state.
do
    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return Text { text = tostring(self.state.count) }
        end,
    })

    local node = diff.mount(View { Counter { key = "a" }, Counter { key = "b" } })
    node.children[1].instance.state.count = 5

    assert(node.children[2].instance.state.count == 0, "one instance must not see another's state")
end

-- New props reach the render, and the operation carries only the leaf that changed.
do
    local Label = component.define(function(self)
        return Text { text = self.props.text }
    end)

    local node = diff.mount(View { Label { text = "before" } })
    local ops = diff.reconcile(node, View { Label { text = "after" } })

    assert(#ops == 1, "one changed prop must produce one operation, got " .. #ops)
    assert(ops[1].op == "update" and ops[1].props.text == "after", "the update must carry the new text")
end

-- Re-rendering with the same props produces nothing.
do
    local Label = component.define(function(self)
        return Text { text = self.props.text }
    end)

    local node = diff.mount(View { Label { text = "same" } })
    local ops = diff.reconcile(node, View { Label { text = "same" } })

    assert(#ops == 0, "an unchanged component must produce no operations, got " .. #ops)
end

-- A state change re-renders only what that component owns.
do
    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return Text { text = "count " .. self.state.count }
        end,
    })

    local node = diff.mount(View { Text { text = "sibling" }, Counter {} })
    local instance = node.children[2].instance

    instance.state.count = 1
    local ops = diff.reconcileComponent(node.children[2])

    assert(#ops == 1, "a state change must touch only the subtree it owns, got " .. #ops)
    assert(ops[1].props.text == "count 1", "the update must carry the new render")
end

-- The lifecycle callbacks fire, and in the order a caller expects.
do
    local seen = {}
    local Tracked = component.define({
        render = function(self)
            return Text { text = self.props.text }
        end,
        onMount = function() seen[#seen + 1] = "mount" end,
        onUpdate = function() seen[#seen + 1] = "update" end,
        onUnmount = function() seen[#seen + 1] = "unmount" end,
    })

    local node, _, mounted = diff.mount(View { Tracked { key = "a", text = "one" } })
    run(mounted)

    local _, updated = diff.reconcile(node, View { Tracked { key = "a", text = "two" } })
    run(updated)

    local _, removed = diff.reconcile(node, View {})
    run(removed)

    assert(table.concat(seen, ",") == "mount,update,unmount", "got " .. table.concat(seen, ","))
end

-- A keyed component survives a reorder with the state it accumulated.
do
    local Counter = component.define({
        state = { count = 0 },
        render = function(self)
            return Text { text = self.props.name }
        end,
    })

    local node = diff.mount(View {
        Counter { key = "a", name = "a" },
        Counter { key = "b", name = "b" },
    })

    node.children[1].instance.state.count = 42

    local ops = diff.reconcile(node, View {
        Counter { key = "b", name = "b" },
        Counter { key = "a", name = "a" },
    })

    assert(count(ops, "create") == 0, "a reorder must not rebuild a keyed component")

    local moved = node.children[2]
    assert(moved.props.name == "a", "the keyed component must land in its new position")
    assert(moved.instance.state.count == 42, "a keyed component must keep its state across a reorder")
end

-- Calling setState from inside render is refused rather than starting a commit inside a commit.
do
    local Bad = component.define({
        state = { value = 0 },
        render = function(self)
            self:setState({ value = 1 })
            return Text { text = "never" }
        end,
    })

    local ok, message = pcall(diff.mount, Bad {})
    assert(not ok, "setState from render must be refused")
    assert(tostring(message):find("render"), "the message must say where the call came from")
end

-- A render that answers something other than an element is refused with a message naming the component.
do
    local Bad = component.define({ name = "Broken", render = function() return 42 end })

    local ok, message = pcall(diff.mount, Bad {})
    assert(not ok, "a render that answers a non-element must be refused")
    assert(tostring(message):find("Broken"), "the message must name the component, got " .. tostring(message))
end

-- A state field is cleared by setting it to none, since a nil is invisible to the change itself.
do
    local seen = nil

    local Holder = gui.component({
        name = "Holder",
        state = { open = "something" },
        render = function(self)
            seen = self.state.open
            return gui.Text { text = tostring(self.state.open) }
        end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(Holder {}, renderer, { size = { width = 100, height = 100 } })

    assert(seen == "something", "the field starts with what it was given")

    runtime.root.instance:setState({ open = nil })
    runtime:commit()
    assert(seen == "something", "a nil says nothing, so nothing changes")

    runtime.root.instance:setState({ open = gui.none })
    runtime:commit()
    assert(seen == nil, "none clears the field")
end

print("gui.component ok")
