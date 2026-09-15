local context = require("gui.context")

--- The look the application is drawn in, and the way to put it in another one.
---
--- A theme reaches a tree through the styles it resolves rather than through anything a component reads,
--- which is what keeps a screen free of it. Choosing one is the other half: a settings screen offering a
--- reader a look, an application drawn in a customer's colours, a page told which of two brands it is
--- serving. Each of those is a component deep in a tree that has to reach the runtime holding it, and a
--- runtime is not something a screen is handed.
---
--- What it carries is the name of the look in use and the way to wear another. Reading it draws the
--- component again when the look changes, so a chooser shows which one is on without holding a copy of
--- the answer.
return context.create({
    name = "varn",
    use = function()
        error("nothing is holding this tree, so it cannot be put in another look", 2)
    end,
})
