local element = require("gui.element")
local componentLayer = require("gui.component")

local M = {}

local Context = {}
Context.__index = Context

--- Answers the value the nearest provider above this component supplied, or the default when there is none.
---
--- Who read it is remembered, so a change to the value renders those components again rather than the
--- whole tree. A rotation hands the engine a new size on every frame it animates, and rendering
--- everything for each of them costs more than a frame is worth.
function Context:read(instance)
    self.readers[instance] = true

    local node = instance.node

    while node ~= nil do
        if node.kind == "component" and node.type == self.provider and node.props.value ~= nil then
            return node.props.value
        end

        node = node.parentNode
    end

    return self.default
end

--- Answers every component of one runtime that has read this and is still on screen.
---
--- This is declared once for the whole process, so what read it may belong to any runtime that is
--- running. Handing one of them a component another one holds marks a node dirty in a tree that does
--- not contain it, and the batch that follows names ids the renderer it reaches never created.
function Context:read_by(scheduler)
    local found = {}

    for instance in pairs(self.readers) do
        if not instance.mounted then
            self.readers[instance] = nil
        elseif instance.scheduler == scheduler then
            found[#found + 1] = instance
        end
    end

    return found
end

--- Declares a value that flows down a tree without being threaded through every component between.
function M.create(default)
    local context = setmetatable({ default = default, readers = setmetatable({}, { __mode = "k" }) }, Context)

    local Provider, kind = componentLayer.define({
        name = "ContextProvider",
        render = function(self)
            if #self.children == 1 then
                return self.children[1]
            end

            return element.define("view")({ style = self.props.style, table.unpack(self.children) })
        end,
    })

    context.Provider = Provider
    context.provider = kind
    return context
end

return M
