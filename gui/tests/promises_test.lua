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

    -- Every field a style may carry is one all three renderers name.
    --
    -- A style crosses to all of them, so one honoured by two is a caller who writes it, sees it work on
    -- the phone in their hand, and hears from somebody else that it does nothing on the other.
    local unpainted = promises.unpainted()

    assert(#unpainted == 0, "a renderer does not honour " .. #unpainted .. " of the style fields declared:\n  "
        .. table.concat(unpainted, "\n  "))

    -- Every prop that carries a colour is one the engine turns into a colour.
    --
    -- A renderer reads a colour and parses nothing, so a theme name that reaches one is a control
    -- painted in nothing at all.
    local unresolved = promises.unresolved()

    assert(#unresolved == 0, "the engine never paints " .. #unresolved .. " of the colour props declared:\n  "
        .. table.concat(unresolved, "\n  "))

    -- Every setter a renderer's own view carries is one something in that renderer calls.
    --
    -- The props of a node are applied by a switch on the name of the prop, somewhere other than the view
    -- they are applied to, and nothing joins the two. A branch that forgets a type leaves a setter that
    -- is never called and a prop that is dropped without a word: a sound was never given its source on
    -- iOS at all, so pressing play played nothing and nothing reported a failure, there being nothing to
    -- fail. Asking whether the name is read anywhere in the renderer does not see it, since the word is
    -- read for a picture and for a film in the same file.
    local dangling = promises.unwired()

    assert(#dangling == 0, "a renderer carries " .. #dangling .. " setters nothing in it ever calls:\n  "
        .. table.concat(dangling, "\n  "))

    -- No name is answered twice in one switch, since the second branch is one nothing ever reaches.
    --
    -- A renderer routes props by their name and events by theirs. A camera's zoom was read as a map's
    -- and dropped, and a sound, a film and a page were each left unable to report a failure at all. The
    -- compiler says so, and a warning is not a failure.
    local twice = promises.unreachable()

    assert(#twice == 0, "a renderer answers " .. #twice .. " names twice in one switch:\n  "
        .. table.concat(twice, "\n  "))

    -- Nothing declares a method twice, since the second silently replaces the first.
    --
    -- Nothing says so either: a method added for an editor took the name the whole browser renderer
    -- reported its events through, and every control on the page quietly stopped reporting. The runtime
    -- is one object spread over the files its contexts live in, which is the same shape seen from the
    -- other side. The compiler says it on the two phones, and neither Lua nor a browser says anything.
    local redefined = promises.redefined()

    assert(#redefined == 0, #redefined .. " methods are declared twice:\n  "
        .. table.concat(redefined, "\n  "))

    -- Nothing declares a name for its own file that its own file never reads.
    --
    -- A local reaches nowhere but the file it is written in, so one nothing there names is dead wherever
    -- it came from: an import left behind when a split moved the code away, a constant a component now
    -- works out for itself. Lua says nothing about either, so they gather where nobody looks.
    local unread = promises.unread()

    assert(#unread == 0, #unread .. " names are declared and never read:\n  "
        .. table.concat(unread, "\n  "))

    -- No prop is answered twice with nothing telling the two answers apart.
    --
    -- A browser renderer routes props through a run of checks and Android through a `when`, and either
    -- way the first answer for a name wins. In a browser a second is correct when the first is held to a
    -- node type, since two types may read one name. In a `when` there is no holding it to anything: a
    -- field and an editor both saying where the caret is were two arms, and the editor's never ran.
    local shadowed = promises.shadowed()

    assert(#shadowed == 0, #shadowed .. " props are answered twice where only the first answer runs:\n  "
        .. table.concat(shadowed, "\n  "))

    -- Every action a component declares is one all three renderers perform.
    --
    -- An action is a promise the way a prop is, and a caller reaches it through a ref after reading the
    -- reference. One answered by two renderers out of three throws on the third, which is a screen that
    -- works on the phone in the writer's hand and fails on somebody else's.
    local unanswered = promises.unanswered()

    assert(#unanswered == 0, "nothing performs " .. #unanswered .. " of the actions declared:\n  "
        .. table.concat(unanswered, "\n  "))

    -- The capability names agree wherever they are written down.
    --
    -- They live in the contract and each native suite carries a copy to hold its own renderer against,
    -- so a name added to the contract and to the three renderers still leaves two lists behind — and
    -- what that looks like is a suite failing on a capability that is perfectly correct.
    local adrift = promises.uncontracted()

    assert(#adrift == 0, "the capability names disagree in " .. #adrift .. " places:\n  "
        .. table.concat(adrift, "\n  "))

    -- No list of children is spread anywhere but last.
    --
    -- `table.unpack` in the middle of a table constructor yields one value rather than all of them, so
    -- the rest of the list is dropped without a nil, without an error and without anything on screen
    -- looking wrong enough to notice. Four screens have shipped short this way.
    local dropped = promises.unspread()

    assert(#dropped == 0, #dropped .. " lists of children are spread before something else:\n  "
        .. table.concat(dropped, "\n  "))

    print("gui.promises ok")
end)
