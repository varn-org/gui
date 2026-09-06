local protocol = require("gui.bridge.protocol")

local M = {}

local Renderer = {}
Renderer.__index = Renderer

--- Applies a batch the way a real renderer would, keeping a tree a test can read back.
function Renderer:apply(ops)
    local problem = protocol.validate(ops)
    if problem ~= nil then
        error("the batch broke the protocol: " .. problem, 0)
    end

    self.batches[#self.batches + 1] = ops

    for index = 1, #ops do
        local op = ops[index]

        if op.op == "create" then
            self.nodes[op.id] = { id = op.id, type = op.type, props = op.props or {}, children = {} }
        elseif op.op == "update" then
            local node = self:expect(op.id)
            for key, value in pairs(op.props) do
                node.props[key] = value ~= protocol.removed and value or nil
            end
        elseif op.op == "insert" or op.op == "move" then
            self:place(op)
        elseif op.op == "remove" then
            self:detach(op.id)
            self.nodes[op.id] = nil
        elseif op.op == "frame" then
            local node = self:expect(op.id)
            node.frame = { x = op.x, y = op.y, width = op.width, height = op.height }
        end
    end
end

function Renderer:expect(id)
    local node = self.nodes[id]
    if node == nil then
        error("the batch touched node " .. tostring(id) .. ", which was never created", 0)
    end

    return node
end

function Renderer:detach(id)
    local node = self.nodes[id]
    if node == nil or node.parent == nil then
        return
    end

    local siblings = node.parent == 0 and self.roots or self:expect(node.parent).children
    for index = 1, #siblings do
        if siblings[index] == id then
            table.remove(siblings, index)
            break
        end
    end

    node.parent = nil
end

function Renderer:place(op)
    self:expect(op.id)
    self:detach(op.id)

    local siblings = op.parent == 0 and self.roots or self:expect(op.parent).children
    local index = math.min(op.index, #siblings + 1)

    table.insert(siblings, index, op.id)
    self.nodes[op.id].parent = op.parent
end

--- Answers the tree as nested tables, which is what an assertion reads.
function Renderer:tree(id)
    if id == nil then
        local roots = {}
        for index = 1, #self.roots do
            roots[index] = self:tree(self.roots[index])
        end

        return roots
    end

    local node = self:expect(id)
    local built = { type = node.type, props = node.props, frame = node.frame, children = {} }

    for index = 1, #node.children do
        built.children[index] = self:tree(node.children[index])
    end

    return built
end

--- Answers every node of the given type, which is how a test finds the label it cares about.
function Renderer:findAll(kind)
    local found = {}
    for _, node in pairs(self.nodes) do
        if node.type == kind then
            found[#found + 1] = node
        end
    end

    table.sort(found, function(a, b) return a.id < b.id end)
    return found
end

--- Answers the one node of the given type, refusing when there is not exactly one.
function Renderer:find(kind)
    local found = self:findAll(kind)
    if #found ~= 1 then
        error("expected one " .. kind .. ", found " .. #found, 2)
    end

    return found[1]
end

--- Answers how many operations of a kind the last batch carried.
function Renderer:counted(kind)
    local batch = self.batches[#self.batches] or {}
    local total = 0

    for index = 1, #batch do
        if batch[index].op == kind then
            total = total + 1
        end
    end

    return total
end

--- Reports an event the way a platform would, which is what a conformance case drives.
function Renderer:raise(id, name, payload)
    self.events[#self.events + 1] = { id = id, name = name, payload = payload }
end

--- Records an imperative call, which is what a ref reaches a node through.
function Renderer:invoke(id, method, arguments)
    self:expect(id)
    self.calls[#self.calls + 1] = { id = id, method = method, arguments = arguments }
    return true
end

--- The size this renderer draws each control at, which is what a test predicts against.
local CONTROLS = {
    switch = { width = 51, height = 31 },
    slider = { width = 0, height = 32 },
    stepper = { width = 94, height = 32 },
    segmented = { width = 0, height = 32 },
    progress = { width = 0, height = 4 },
    activity = { width = 24, height = 24 },
    datepicker = { width = 0, height = 44 },
    timepicker = { width = 0, height = 44 },
    colorpicker = { width = 44, height = 32 },
}

--- Answers the size a control is drawn at, which is the one thing about it Lua cannot work out.
function Renderer:measureControl(kind)
    return CONTROLS[kind] or { width = 0, height = 0 }
end

--- Measures text the way a platform would, at a size a test can predict.
function Renderer:measureText(text, style, bound)
    local size = style.fontSize or 15
    local width = #text * size * 0.5

    -- A bound of zero is a node that has not been measured yet, not a node with no room.
    if bound ~= nil and bound > 0 and width > bound then
        return { width = bound, height = math.ceil(width / bound) * size * 1.35 }
    end

    return { width = width, height = size * 1.35 }
end

--- Builds a renderer that records what it is told instead of drawing it.
function M.create()
    return setmetatable({
        nodes = {},
        roots = {},
        batches = {},
        calls = {},
        events = {},
        capabilities = { text = true, image = true, list = true, video = false, webview = false },
    }, Renderer)
end

return M
