local context = require("gui.context")

local M = {}

--- Whether what is under this is on screen, which only the thing showing it can say.
---
--- A stack keeps every screen it holds and shows the top one, a tab bar keeps every tab and shows the
--- chosen one, and a pager keeps its pages and shows the one it is on. Nothing under any of them can
--- work that out for itself, so each says it, and a component with a visibility callback is told.
M.context = context.create(true)

--- Marks everything under it as on screen or not.
M.Showing = M.context.Provider

--- Answers whether a component is on screen, which is what its callbacks are fired from.
function M.of(instance)
    return M.context:read(instance) ~= false
end

return M
