local async = require("async")
local promises = require("gui.tools.promises")

-- A declaration is a promise, and every one of them is kept.
--
-- `support.host` says its props are the ones a renderer honours, and `docs/components.md` is generated
-- from those declarations, so a prop listed there is one a caller writes and believes. A sweep of the
-- three renderers and the components found two hundred and fifty-four that nothing anywhere read: a
-- field that ignored its own length, a video that ignored everything but its source, and six components
-- no renderer built at all. A prop that exists only in the documentation is worse than one that does
-- not exist, so a new one is either honoured somewhere or it is not declared.
async.run(function()
    local broken = promises.unkept()

    assert(#broken == 0, "nothing reads " .. #broken .. " of the props and events declared:\n  "
        .. table.concat(broken, "\n  "))

    -- Every node type a component is built on is one all three renderers can build.
    --
    -- A component wired into two of them is a screen that draws on two platforms and throws on the
    -- third, where a renderer refuses a type it has no view for rather than drawing nothing quietly.
    local missing = promises.unbuilt()

    assert(#missing == 0, "a renderer has no view for " .. #missing .. " of the types declared:\n  "
        .. table.concat(missing, "\n  "))

    print("gui.promises ok")
end)
