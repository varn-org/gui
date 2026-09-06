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
local LITERAL = { style = true, contentStyle = true, edges = true }

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

local function mountComponent(source, ops, pending, parent)
    local node = {
        kind = "component",
        type = source.type,
        key = source.key,
        props = source.props,
        parentNode = parent,
    }

    node.instance = source.type.instantiate(source.props, source.children, node)
    node.child = mount(renderInstance(node), ops, pending, node)

    if node.instance.onMount then
        pending[#pending + 1] = function() node.instance:onMount() end
    end

    return node
end

local function mountHost(source, ops, pending, parent)
    local node = {
        id = claimId(),
        kind = "host",
        type = source.type,
        key = source.key,
        props = source.props,
        parentNode = parent,
        children = {},
    }

    ops[#ops + 1] = { op = "create", id = node.id, type = node.type, props = node.props }

    for index = 1, #source.children do
        local child = mount(source.children[index], ops, pending, node)
        node.children[index] = child
        ops[#ops + 1] = { op = "insert", id = hostOf(child).id, parent = node.id, index = index }
    end

    return node
end

mount = function(source, ops, pending, parent)
    if isComponent(source) then
        return mountComponent(source, ops, pending, parent)
    end

    return mountHost(source, ops, pending, parent)
end

unmount = function(node, ops, pending)
    if node.kind == "component" then
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

    ops[#ops + 1] = { op = "remove", id = node.id }
end

local function keyOf(source, index)
    if source.key ~= nil then
        return source.key
    end

    return index
end

local function reusable(previous, source)
    return previous ~= nil and previous.type == source.type
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

--- Reconciles the subtree one component owns, which is what a state change needs.
function M.reconcileComponent(node)
    local ops = {}
    local pending = {}

    local rendered = renderInstance(node)
    if reusable(node.child, rendered) then
        patch(node.child, rendered, ops, pending)
    else
        local parent = node.parent
        unmount(node.child, ops, pending)
        node.child = mount(rendered, ops, pending, node)

        if parent ~= nil then
            ops[#ops + 1] = { op = "insert", id = hostOf(node.child).id, parent = parent, index = node.index or 1 }
        end
    end

    if node.instance.onUpdate then
        pending[#pending + 1] = function() node.instance:onUpdate(node.props) end
    end

    return ops, pending
end

M.hostOf = hostOf

return M
