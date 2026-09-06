local element = require("gui.element")
local componentLayer = require("gui.component")

local M = {}

local Context = {}
Context.__index = Context

--- Answers the value the nearest provider above this component supplied, or the default when there is none.
function Context:read(instance)
    local node = instance.node

    while node ~= nil do
        if node.kind == "component" and node.type == self.provider and node.props.value ~= nil then
            return node.props.value
        end

        node = node.parentNode
    end

    return self.default
end

--- Declares a value that flows down a tree without being threaded through every component between.
function M.create(default)
    local context = setmetatable({ default = default }, Context)

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
