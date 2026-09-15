local context = require("gui.context")

--- What a screen reaches to go somewhere, provided by the router that is showing it.
---
--- A screen deep in a tree names an address rather than being handed a callback through every component
--- above it, and what answers it is whichever router is showing that screen.
return context.create({
    address = "/",
    path = "/",
    params = {},
    query = {},

    go = function()
        error("nothing is routing this screen, so there is nowhere to go", 2)
    end,

    replace = function()
        error("nothing is routing this screen, so there is nothing to replace", 2)
    end,

    back = function()
        error("nothing is routing this screen, so there is nothing to go back to", 2)
    end,
})
