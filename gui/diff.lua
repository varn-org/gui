local element = require("gui.element")
local protocol = require("gui.bridge.protocol")

local M = {}

local nextId = 0

local function claimId()
    nextId = nextId + 1
    return nextId
end

--- Resets the id counter, which only a test that asserts on concrete ids needs.
function M.resetIds()
    nextId = 0
end

M.removed = protocol.removed

--- The props written as a literal at the point of use, which is a fresh table on every render.
---
--- A style is data rather than an object, so the same style written again is the same style. Comparing
--- those by identity would mark every node in the tree as changed on every commit, which is an update
--- for each of them over the bridge and a layout pass that can keep nothing.
local LITERAL = {
    style = true, contentStyle = true, edges = true, transition = true, enter = true,
    commands = true, spans = true, options = true, segments = true, pinned = true,
}

local sameValue

sameValue = function(before, after)
    if before == after then
        return true
    end

    if type(before) ~= "table" or type(after) ~= "table" then
        return false
    end

    for key, value in pairs(after) do
        if not sameValue(before[key], value) then
            return false
        end
    end

    for key in pairs(before) do
        if after[key] == nil then
            return false
        end
    end

    return true
end

local function samePropValue(key, before, after)
    if LITERAL[key] then
        return sameValue(before, after)
    end

    return before == after
end

local function propsDiffer(before, after)
    for key, value in pairs(after) do
        if not samePropValue(key, before[key], value) then
            return true
        end
    end

    for key in pairs(before) do
        if after[key] == nil then
            return true
        end
    end

    return false
end

--- Answers whether a change to a prop is one a renderer would see.
---
--- A handler travels as a marker rather than as itself, so a fresh closure over the same event leaves a
--- renderer with exactly what it already holds. The tree still takes the new closure, since that is the
--- one that reads the state the render was made from.
local function visibleChange(key, before, after)
    if type(before) == "function" and type(after) == "function" then
        return false
    end

    return not samePropValue(key, before, after)
end

local function changedProps(before, after)
    local changed = nil

    for key, value in pairs(after) do
        if visibleChange(key, before[key], value) then
            changed = changed or {}
            changed[key] = value
        end
    end

    for key in pairs(before) do
        if after[key] == nil then
            changed = changed or {}
            changed[key] = M.removed
        end
    end

    return changed
end

--- Answers the props to retain, keeping the table a literal prop already had when it says the same thing.
---
--- Identity is what the layout and the style cache are keyed on, so a style that did not change has to
--- stay the table it was or nothing downstream can tell that it did not.
local function carried(before, after)
    local props = {}

    for key, value in pairs(after) do
        if LITERAL[key] and sameValue(before[key], value) then
            props[key] = before[key]
        else
            props[key] = value
        end
    end

    return props
end

local function isComponent(source)
    return type(source.type) == "table"
end

--- Answers the host node a subtree contributes, descending through components that render one.
local function hostOf(node)
    while node.kind == "component" do
        node = node.child
    end

    return node
end

local mount
local patch
local unmount

local function renderInstance(node)
    local rendered = node.instance:render()

    if not element.isElement(rendered) then
        error("the render of " .. (node.type.name or "a component") .. " must answer one element", 0)
    end

    return rendered
end

--- Tells a component a moment has come, without letting what it does then take the commit with it.
---
--- The half of the lifecycle that runs before the batch runs inside the diff, so a component whose
--- handler fails would stop the whole tree being built rather than only itself.
local function tell(instance, name)
    local handler = instance[name]

    if handler == nil then
        return
    end

    local ok, problem = pcall(handler, instance)

    if not ok and instance.scheduler ~= nil then
        instance.scheduler.report("a component's " .. name .. " failed: " .. tostring(problem))
    end
end

--- Fires the moments a component is told about as it is built, shown, hidden and taken down.
---
--- The `will` half runs against the tree as it stands, before the batch reaches the platform, and the
--- other half is held until the batch has been applied, which is what makes "before" and "after" mean
--- what they say rather than both meaning the same instant.
local function showing(node, pending)
    local instance = node.instance

    if not instance.watchesVisibility then
        return
    end

    local visible = instance:visible()

    if visible == instance.shown then
        return
    end

    -- What was built out of sight has not gone from the screen, since it was never on it.
    local first = instance.shown == nil

    instance.shown = visible

    if not visible and first then
        return
    end

    if visible then
        tell(instance, "onWillAppear")

        if instance.onAppear then
            pending[#pending + 1] = function() instance:onAppear() end
        end

        return
    end

    tell(instance, "onWillDisappear")

    if instance.onDisappear then
        pending[#pending + 1] = function() instance:onDisappear() end
    end
end

--- Answers the props of a node that is arriving inside something already arriving, which is its own
--- arrival taken off it.
---
--- A screen pushed onto a stack travels in from the side, and everything mounted with it is mounted in
--- the same commit: a block that also arrives from below adds its own travel to the screen's and the
--- whole thing comes in diagonally. One arrival at a time, which is what a platform does with a pushed
--- screen — the screen moves and what is inside it moves with it.
local function settled(props)
    local copy = {}

    for key, value in pairs(props) do
        if key ~= "enter" then
            copy[key] = value
        end
    end

    return copy
end

local function mountComponent(source, ops, pending, parent, arriving)
    local node = {
        kind = "component",
        type = source.type,
        key = source.key,
        props = source.props,
        parentNode = parent,
    }

    node.instance = source.type.instantiate(source.props, source.children, node)

    tell(node.instance, "onWillMount")

    node.child = mount(renderInstance(node), ops, pending, node, arriving)

    -- Built before shown, which is the order the moments mean: a screen is loaded and then it appears.
    if node.instance.onMount then
        pending[#pending + 1] = function() node.instance:onMount() end
    end

    showing(node, pending)

    return node
end

local function mountHost(source, ops, pending, parent, arriving)
    local node = {
        id = claimId(),
        kind = "host",
        type = source.type,
        key = source.key,
        props = source.props,
        parentNode = parent,
        children = {},
    }

    -- The node keeps what it was given, so what it is compared against next time is unchanged: only the
    -- batch that builds it leaves the arrival out.
    local sent = node.props

    if arriving and sent.enter ~= nil then
        sent = settled(sent)
    end

    ops[#ops + 1] = { op = "create", id = node.id, type = node.type, props = sent }

    local inside = arriving or source.props.enter ~= nil

    for index = 1, #source.children do
        local child = mount(source.children[index], ops, pending, node, inside)
        node.children[index] = child
        ops[#ops + 1] = { op = "insert", id = hostOf(child).id, parent = node.id, index = index }
    end

    return node
end

mount = function(source, ops, pending, parent, arriving)
    if isComponent(source) then
        return mountComponent(source, ops, pending, parent, arriving)
    end

    return mountHost(source, ops, pending, parent, arriving)
end

unmount = function(node, ops, pending)
    if node.kind == "component" then
        -- A screen taken down while it was on screen goes from the screen first, which is the order the
        -- platforms tell one about it in: it disappears, and then it is taken down.
        if node.instance.watchesVisibility and node.instance.shown then
            node.instance.shown = false

            tell(node.instance, "onWillDisappear")

            if node.instance.onDisappear then
                pending[#pending + 1] = function() node.instance:onDisappear() end
            end
        end

        tell(node.instance, "onWillUnmount")

        if node.instance.onUnmount then
            pending[#pending + 1] = function() node.instance:onUnmount() end
        end

        node.instance.mounted = false
        unmount(node.child, ops, pending)
        return
    end

    for index = 1, #node.children do
        unmount(node.children[index], ops, pending)
    end

    -- A ref points at nothing once what it pointed at has gone, or it reaches a node the renderer has
    -- already forgotten and answers with a failure from inside the bridge.
    local holder = node.props.ref

    if type(holder) == "table" and holder.current ~= nil and holder.current.id == node.id then
        holder.current = nil
    end

    ops[#ops + 1] = { op = "remove", id = node.id }
end

local function keyOf(source, index)
    if source.key ~= nil then
        return source.key
    end

    return index
end

--- Answers whether a node already on screen is the one a description names, rather than a new one.
---
--- A key is what says two nodes of the same type are different things. Comparing only the type made a
--- component's own root immune to its key, so a component that says it is showing something else by
--- changing the key was patched in place instead: it never arrived, so nothing it declared to arrive
--- from was ever applied and every overlay appeared in one frame.
local function reusable(previous, source)
    return previous ~= nil and previous.type == source.type and previous.key == source.key
end

local function patchChildren(node, sources, ops, pending)
    local existing = {}
    for index = 1, #node.children do
        local child = node.children[index]
        existing[child.key ~= nil and child.key or index] = child
    end

    local matched = {}
    local result = {}

    for index = 1, #sources do
        local source = sources[index]
        local previous = existing[keyOf(source, index)]

        if reusable(previous, source) then
            matched[previous] = true
            patch(previous, source, ops, pending)
            result[index] = previous
        else
            result[index] = mount(source, ops, pending, node)
        end

        result[index].parentNode = node
    end

    local surviving = {}

    for index = 1, #node.children do
        local child = node.children[index]

        if matched[child] then
            surviving[#surviving + 1] = child
        else
            unmount(child, ops, pending)
        end
    end

    -- The order is worked out against what the renderer is left holding once the removals have landed,
    -- and each operation is applied here as it is emitted. Removing a child renumbers every child after
    -- it, so comparing against the order from before would move the whole rest of the list every time.
    for index = 1, #result do
        local child = result[index]

        if surviving[index] ~= child then
            for position = index + 1, #surviving do
                if surviving[position] == child then
                    table.remove(surviving, position)
                    break
                end
            end

            table.insert(surviving, index, child)

            local op = matched[child] and "move" or "insert"
            ops[#ops + 1] = { op = op, id = hostOf(child).id, parent = node.id, index = index }
        end
    end

    node.children = result
end

patch = function(node, source, ops, pending)
    node.key = source.key

    if node.kind == "component" then
        local before = node.props
        node.props = source.props
        node.instance.props = source.props
        node.instance.children = source.children

        local rendered = renderInstance(node)
        if reusable(node.child, rendered) then
            patch(node.child, rendered, ops, pending)
        else
            unmount(node.child, ops, pending)
            node.child = mount(rendered, ops, pending, node)
        end

        showing(node, pending)

        if node.instance.onUpdate then
            pending[#pending + 1] = function() node.instance:onUpdate(before) end
        end

        return
    end

    if propsDiffer(node.props, source.props) then
        local changed = changedProps(node.props, source.props)

        if changed ~= nil then
            ops[#ops + 1] = { op = "update", id = node.id, props = changed }
        end

        node.props = carried(node.props, source.props)
    end

    patchChildren(node, source.children, ops, pending)
end

--- Builds the retained tree for a fresh mount, the operations that create it, and the callbacks it owes.
function M.mount(source)
    local ops = {}
    local pending = {}
    local node = mount(source, ops, pending)

    ops[#ops + 1] = { op = "insert", id = hostOf(node).id, parent = 0, index = 1 }
    return node, ops, pending
end

--- Takes a retained tree down, answering the operations that remove it and the callbacks it owes.
function M.unmount(node)
    local ops = {}
    local pending = {}

    unmount(node, ops, pending)
    return ops, pending
end

--- Reconciles a retained tree against a new description, answering only what changed.
function M.reconcile(node, source)
    if node.type ~= source.type then
        error("the root of a tree cannot change type between commits", 2)
    end

    local ops = {}
    local pending = {}
    patch(node, source, ops, pending)
    return ops, pending
end

--- Answers the host a node hangs from and the position it hangs at, which is where a replacement goes.
---
--- A component holds no view of its own, so the node a renderer knows about is the nearest host above
--- it, and the position is where the branch this node stands in sits among that host's children.
local function attachment(node)
    local child = node
    local parent = node.parentNode

    while parent ~= nil and parent.kind ~= "host" do
        child = parent
        parent = parent.parentNode
    end

    if parent == nil then
        return 0, 1
    end

    for index = 1, #parent.children do
        if parent.children[index] == child then
            return parent.id, index
        end
    end

    error("a component was reconciled outside the tree it belongs to", 0)
end

--- Reconciles the subtree one component owns, which is what a state change needs.
function M.reconcileComponent(node)
    local ops = {}
    local pending = {}

    local rendered = renderInstance(node)
    if reusable(node.child, rendered) then
        patch(node.child, rendered, ops, pending)
    else
        local parent, index = attachment(node)

        unmount(node.child, ops, pending)
        node.child = mount(rendered, ops, pending, node)
        ops[#ops + 1] = { op = "insert", id = hostOf(node.child).id, parent = parent, index = index }
    end

    showing(node, pending)

    if node.instance.onUpdate then
        pending[#pending + 1] = function() node.instance:onUpdate(node.props) end
    end

    return ops, pending
end

M.hostOf = hostOf

--- Answers whether two values say the same thing, which is what a style is compared by.
M.sameValue = sameValue

return M
