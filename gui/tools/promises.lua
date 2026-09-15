local fs = require("fs")
local support = require("gui.components.support")

local M = {}

--- The families every component is declared in, which is what the reference is built from as well.
local FAMILIES = require("gui.components.families")

--- The three that each have to honour a prop, since one honouring it is not the same as all of them.
local RENDERERS = {
    ios = "renderers/ios",
    android = "renderers/android/src/main",
    web = "renderers/web",
}

--- Where a prop may be answered before it ever reaches a renderer.
---
--- A component that builds on other components answers its own props itself, and a prop the engine
--- turns into something else is answered in the runtime, so neither has to reach a platform at all.
local ENGINE = "gui"

--- The props every node carries, which are answered in one place rather than declared by each component.
local UNIVERSAL = {
    key = true,
    style = true,
    ref = true,
    testID = true,
    accessibilityLabel = true,

    -- Where a node ended up is answered by the engine's own layout, on every node that asks.
    onLayout = true,
}

--- The props of a host node that the engine answers, so no renderer ever has to.
---
--- Each of these is written out by name rather than inferred, because the engine *reading* a prop is
--- not the same as the engine *answering* it: the layout reads how many lines a paragraph may run to in
--- order to size its box, and a renderer still has to cut it off at the last one. Taking a mention in
--- the engine as proof was how a paragraph that never truncated on the web, a radio that reported
--- nothing there and a surface that would not page all passed this suite.
local ANSWERED = {
    -- Turned into a style by the component that declares it.
    ["Badge.dot"] = true,
    ["Badge.max"] = true,
    ["Badge.textColor"] = true,
    ["Button.variant"] = true,
    ["Card.elevation"] = true,
    ["Card.outlined"] = true,
    ["Card.padded"] = true,
    ["Divider.inset"] = true,
    ["Divider.orientation"] = true,
    ["Skeleton.shape"] = true,

    -- Turned into the size of the frame by the component's own natural size.
    ["ActivityIndicator.size"] = true,
    ["Button.size"] = true,
    ["Rating.size"] = true,
    ["Spacer.size"] = true,
    ["Skeleton.lines"] = true,
    ["TextArea.rows"] = true,

    -- Turned into a measurement of the text rather than a number, which is the engine's own measuring.
    ["TextArea.grows"] = true,

    -- Turned into padding or into an arrangement by the runtime.
    ["SafeArea.edges"] = true,
    ["KeyboardAvoiding.behavior"] = true,
    ["KeyboardAvoiding.offset"] = true,
    ["ScrollView.contentStyle"] = true,

    -- Answered by the engine, which is what knows: it is the engine that fetches a picture.
    ["Image.onLoad"] = true,
    ["Image.onError"] = true,

    -- Worked out by the engine from the frames it laid out and the offsets a surface reports, so no
    -- renderer sees these at all. A browser has an observer for it and the phones have nothing, and
    -- three implementations of it would agree by luck rather than by arithmetic.
    ["View.onEnterView"] = true,
    ["View.onExitView"] = true,
}

--- The tables a renderer keys by the type of a node rather than by the name of a prop.
---
--- A prop named after a node type would otherwise prove itself against the row that builds a view for
--- that type: an `icon` on a button is answered by nobody, and the row that makes an icon view says so.
local TYPED = { "TAGS", "INPUT_TYPES", "PADDED", "PARTED", "SCROLLING" }

--- The source that chooses a view for a type, which reads no props at all.
local FACTORIES = "VarnViewFactory"

--- Answers what a file says about a prop, which is not the list of props it declares taking.
---
--- A declaration writes every prop it takes by name, so counting that as evidence would mean every
--- declaration proves itself and the check answers nothing.
local function evidence(source)
    local left = (source:gsub("props = {[^}]*}", ""):gsub("events = {[^}]*}", ""))

    -- A component names the node type it is built on, which is a type and never a prop.
    left = (left:gsub("support%.host%(\"[%w_]+\"", "support.host("))
    left = (left:gsub("support%.component%(\"[%w_]+\"", "support.component("))

    for index = 1, #TYPED do
        left = (left:gsub("const " .. TYPED[index] .. " = [^;]*;", ""))
    end

    return left
end

--- The names a prop is read under: a renderer names it, and a component reads it off what it was given.
local HOLDERS = { "props", "spec", "options", "entry", "declaration", "style", "look" }

--- Answers whether a source reads a prop by that name, rather than by a name that ends with it.
---
--- A plain substring makes `font.family` prove that an icon's `family` is honoured, so a prop nobody
--- reads passes because something unrelated happens to end in the same word.
local function reads(source, name)
    if source:find('"' .. name .. '"', 1, true) ~= nil then
        return true
    end

    for index = 1, #HOLDERS do
        if source:find("%f[%w_]" .. HOLDERS[index] .. "%." .. name .. "%f[%W]") ~= nil then
            return true
        end
    end

    -- A renderer that maps an event to a platform one writes the name as the key of a table. Only an
    -- event is looked for that way, since a renderer also keeps a table of node types and a prop named
    -- after one of them would prove itself against a row that has nothing to do with it.
    if name:find("^on%u") == nil then
        return false
    end

    return source:find("%f[%w_]" .. name .. "%s*:") ~= nil
end

--- Answers everything under a directory, skipping what only ever describes rather than does.
local function gather(root, into)
    local names = fs.readdir(root):await()

    for index = 1, #names do
        local path = root .. "/" .. names[index]

        if fs.stat(path):await().isDir then
            if names[index] ~= "tests" then
                gather(path, into)
            end
        elseif path:match("%.swift$") or path:match("%.js$") or path:match("%.kt$") or path:match("%.lua$") then
            if not path:match("gui/tools/") and not path:find(FACTORIES, 1, true) then
                into[#into + 1] = evidence(fs.readFile(path):await())
            end
        end
    end

    return into
end

--- Answers every node type a component is built on that some renderer cannot build.
---
--- A browser refuses a type it has no element for, so a component wired into two of the three is a
--- screen that draws on two platforms and throws on the third. Anything the browser draws as a plain
--- box is a plain box on the other two as well, and anything else is a control each of them has to name.
function M.unbuilt()
    local tags = {}

    for kind, tag in fs.readFile("renderers/web/renderer.js"):await():gmatch("\n    (%a+): \"(%a+)\",") do
        tags[kind] = tag
    end

    local native = {
        ios = fs.readFile("renderers/ios/VarnViewFactory.swift"):await(),
        android = fs.readFile("renderers/android/src/main/kotlin/dev/varn/gui/VarnViewFactory.kt"):await(),
    }

    local missing = {}

    for index = 1, #FAMILIES do
        for name, constructor in pairs(require(FAMILIES[index].module)) do
            local declaration = support.declarations[constructor]

            if declaration ~= nil and declaration.host then
                local tag = tags[declaration.kind]

                if tag == nil then
                    missing[#missing + 1] = name .. " (" .. declaration.kind .. ") on web"
                elseif tag ~= "div" then
                    for platform, source in pairs(native) do
                        if source:find('"' .. declaration.kind .. '"', 1, true) == nil then
                            missing[#missing + 1] = name .. " (" .. declaration.kind .. ") on " .. platform
                        end
                    end
                end
            end
        end
    end

    table.sort(missing)
    return missing
end

--- Answers every style field a renderer does not name, with the platform that does not name it.
---
--- A style field crosses to all three, so one honoured by two of them is a caller who writes it, sees it
--- work on the phone in their hand and hears from somebody else that it does nothing on the other.
function M.unpainted()
    local resolve = require("gui.style.resolve")

    -- Each renderer reads a style the way its own language does, so what counts as evidence differs:
    -- a subscript on iOS, the name of a json field on Android, and a field of an object on the web.
    local platforms = {
        {
            name = "ios",
            source = fs.readFile("renderers/ios/VarnStyle.swift"):await(),
            reads = function(source, field) return source:find('style["' .. field .. '"]', 1, true) ~= nil end,
        },
        {
            name = "android",
            source = fs.readFile("renderers/android/src/main/kotlin/dev/varn/gui/VarnStyle.kt"):await(),
            reads = function(source, field) return source:find('"' .. field .. '"', 1, true) ~= nil end,
        },
        {
            name = "web",
            source = fs.readFile("renderers/web/renderer.js"):await(),
            reads = function(source, field) return source:find("style." .. field, 1, true) ~= nil end,
        },
    }

    local missing = {}

    for field in pairs(resolve.drawn()) do
        for index = 1, #platforms do
            local platform = platforms[index]

            if not platform.reads(platform.source, field) then
                missing[#missing + 1] = field .. " on " .. platform.name
            end
        end
    end

    table.sort(missing)
    return missing
end

--- Answers every prop that carries a colour and is never turned into one.
---
--- A renderer reads a colour and parses nothing, so a theme name that reaches one is a control painted
--- in nothing at all: a placeholder colour written as `textMuted` was sent as the word itself, and three
--- renderers each drew a placeholder in whatever they draw when they are handed a colour they cannot
--- read. What the engine paints is what a caller may name.
function M.unresolved()
    local named = fs.readFile("gui/runtime/reads.lua"):await()
    local painted = {}

    for block in named:gmatch("M%.tints = {(.-)}") do
        for name in block:gmatch("(%w+) = true") do
            painted[name] = true
        end
    end

    for block in named:gmatch("M%.palettes = {(.-)}") do
        for name in block:gmatch("(%w+) = true") do
            painted[name] = true
        end
    end

    local missing = {}

    for index = 1, #FAMILIES do
        for name, constructor in pairs(require(FAMILIES[index].module)) do
            local declaration = support.declarations[constructor]

            for _, prop in ipairs(declaration ~= nil and declaration.props or {}) do
                local carries = prop:find("[Cc]olor") ~= nil or prop == "tint"

                if carries and not painted[prop] then
                    missing[#missing + 1] = name .. "." .. prop
                end
            end
        end
    end

    table.sort(missing)
    return missing
end

--- Answers every setter a renderer's own view declares that nothing in that renderer ever calls.
---
--- A view built for one node type carries the setters that node's props are applied through, and the
--- props are applied by a switch on the name of the prop somewhere else entirely. Nothing joins the two,
--- so a branch that forgets a type is a setter that is never called and a prop that is silently dropped:
--- a sound was never given its source on iOS at all, so pressing play played nothing and nothing went
--- wrong, since there was nothing for it to go wrong with.
function M.unwired()
    local sources = {
        ios = { root = "renderers/ios", declares = "func (set%u[%w]*)%s*%(" },
        android = {
            root = "renderers/android/src/main",
            declares = "fun (set%u[%w]*)%s*%(",
        },
    }

    local dangling = {}

    for platform, about in pairs(sources) do
        local corpus = {}

        gather(about.root, corpus)

        local whole = table.concat(corpus, "\n")
        local declared = {}

        for name in whole:gmatch(about.declares) do
            declared[name] = true
        end

        for name in pairs(declared) do
            if whole:find("%." .. name .. "%s*%(") == nil then
                dangling[#dangling + 1] = name .. " on " .. platform
            end
        end
    end

    table.sort(dangling)
    return dangling
end

--- Answers every name a renderer answers twice in one switch, which is a branch nothing ever reaches.
---
--- A renderer routes props by their name and events by theirs, each through one switch, so a second
--- branch for a name already answered is dead code the compiler mentions and nobody reads: a camera's
--- zoom was read as a map's, and a sound, a film and a page were each left unable to report a failure.
function M.unreachable()
    local switches = {
        ios = {
            path = "renderers/ios/VarnProps.swift",
            opens = "^(%s*)switch%s",
            branch = '^%s*case "([%a]+)":',
            closes = "^(%s*)}",
        },
        android = {
            path = "renderers/android/src/main/kotlin/dev/varn/gui/VarnProps.kt",
            opens = "^(%s*).*when%s*%(",
            branch = '^%s*"([%a]+)"%s*%->',
            closes = "^(%s*)}",
        },
    }

    local twice = {}

    for platform, about in pairs(switches) do
        local source = fs.readFile(about.path):await()
        local open = nil
        local seen = {}

        for line in (source .. "\n"):gmatch("([^\n]*)\n") do
            local closing = line:match(about.closes)

            if open ~= nil and closing ~= nil and #closing <= #open then
                open = nil
                seen = {}
            end

            if open ~= nil then
                local name = line:match(about.branch)

                if name ~= nil then
                    seen[name] = (seen[name] or 0) + 1

                    if seen[name] == 2 then
                        twice[#twice + 1] = name .. " on " .. platform
                    end
                end
            end

            local opening = line:match(about.opens)

            if opening ~= nil then
                open = opening
                seen = {}
            end
        end
    end

    table.sort(twice)
    return twice
end

--- Answers every prop and event, with the name of each thing that has to honour it and does not.
---
--- A declaration is a promise: `docs/components.md` is generated from it, so a prop listed there is one
--- a caller writes and believes. Asking whether anything anywhere reads it is not enough, since a prop
--- honoured on one platform out of three is a promise kept for a third of the people who believe it, so
--- each corpus is asked on its own.
function M.unkept()
    local engine = table.concat(gather(ENGINE, {}), "\n")
    local platforms = {}

    for platform, root in pairs(RENDERERS) do
        platforms[platform] = table.concat(gather(root, {}), "\n")
    end

    local broken = {}

    for index = 1, #FAMILIES do
        for name, constructor in pairs(require(FAMILIES[index].module)) do
            local declaration = support.declarations[constructor]

            if declaration ~= nil then
                M.check(name, declaration, engine, platforms, broken)
            end
        end
    end

    table.sort(broken)
    return broken
end

--- Records what a component promises and nobody keeps, naming the platforms that do not keep it.
---
--- A prop the engine answers never has to reach a platform: a component that computes its own look
--- from it has already turned it into a style, and one the runtime resolves has already become
--- something else. Anything left is a promise every renderer has to keep, not just one of them.
function M.check(name, declaration, engine, platforms, broken)
    local named = {}

    for position = 1, #declaration.props do
        named[#named + 1] = declaration.props[position]
    end

    for position = 1, #declaration.events do
        named[#named + 1] = declaration.events[position]
    end

    for position = 1, #named do
        local prop = named[position]

        -- A component the control theme may hand to the platform is drawn by a host node whenever it
        -- does, so its props are a renderer's promise as much as a host node's own are.
        local platform = declaration.host or declaration.platform ~= nil
        local excused = UNIVERSAL[prop] or (platform and ANSWERED[name .. "." .. prop])

        if not excused and not (not platform and reads(engine, prop)) then
            if not platform then
                broken[#broken + 1] = name .. "." .. prop .. " (nothing reads it)"
            else
                local missing = {}

                for platform, corpus in pairs(platforms) do
                    if not reads(corpus, prop) then
                        missing[#missing + 1] = platform
                    end
                end

                table.sort(missing)

                if #missing == 3 then
                    broken[#broken + 1] = name .. "." .. prop .. " (nothing reads it)"
                elseif #missing > 0 then
                    broken[#broken + 1] = name .. "." .. prop .. " (not on " .. table.concat(missing, ", ") .. ")"
                end
            end
        end
    end
end

--- Answers every name a Lua file declares for itself that nothing in that file ever reads.
---
--- A local is only ever reachable from the file it is written in, so one nothing in that file names is
--- dead wherever it came from — an import from a split that moved the code away and left the line, or a
--- constant a component worked out for itself. Lua reports neither, so it accumulates silently.
function M.unread()
    local dead = {}

    local function walk(root)
        local names = fs.readdir(root):await()

        for index = 1, #names do
            local path = root .. "/" .. names[index]

            if fs.stat(path):await().isDir then
                walk(path)
            elseif path:match("%.lua$") then
                local lines = {}

                for line in (fs.readFile(path):await() .. "\n"):gmatch("([^\n]*)\n") do
                    lines[#lines + 1] = line
                end

                for at = 1, #lines do
                    local name = lines[at]:match("^local%s+function%s+([%a_][%w_]*)")
                        or lines[at]:match("^local%s+([%a_][%w_]*)%s*=")

                    if name ~= nil and name ~= "_" then
                        local read = false

                        for other = 1, #lines do
                            if other ~= at and lines[other]:find("%f[%w_]" .. name .. "%f[^%w_]") ~= nil then
                                read = true
                                break
                            end
                        end

                        if not read then
                            dead[#dead + 1] = name .. " in " .. path
                        end
                    end
                end
            end
        end
    end

    walk("gui")
    walk("sample")

    table.sort(dead)
    return dead
end

--- Answers every method a class in the browser renderer declares twice, which is one nothing reaches.
---
--- A second declaration of a name silently replaces the first, and nothing says so: a method added for
--- an editor took the name the whole renderer reported its events through, and every control on the page
--- stopped reporting. The compiler catches this shape on the two phones, and a browser has none.
function M.redefined()
    local paths = { "renderers/web/renderer.js", "renderers/web/host.js", "renderers/web/place.js" }
    local twice = {}

    -- The runtime is one object spread over the files its contexts live in, so a method written twice
    -- is the second quietly replacing the first — which is what a split of one file into four is most
    -- likely to leave behind.
    local seen = {}

    for _, path in ipairs({ "gui/runtime/init.lua", "gui/runtime/sources.lua",
        "gui/runtime/styles.lua", "gui/runtime/keyboard.lua" }) do
        for name in fs.readFile(path):await():gmatch("function Runtime:([%a_][%w_]*)%s*%(") do
            if seen[name] ~= nil then
                twice[#twice + 1] = name .. " in " .. path .. " and in " .. seen[name]
            end

            seen[name] = path
        end
    end

    for index = 1, #paths do
        local source = fs.readFile(paths[index]):await()
        local seen = {}

        for line in (source .. "\n"):gmatch("([^\n]*)\n") do
            -- A file may hold several classes, and two of them answering the same name is two classes
            -- rather than one class answering it twice.
            if line:match("^%s*class%s") ~= nil or line:match("^export%s+class%s") ~= nil then
                seen = {}
            end

            local name = line:match("^    ([%a_][%w_]*)%s*%(")

            if name ~= nil and name ~= "constructor" and line:find("=", 1, true) == nil then
                seen[name] = (seen[name] or 0) + 1

                if seen[name] == 2 then
                    twice[#twice + 1] = name .. " in " .. paths[index]
                end
            end
        end
    end

    table.sort(twice)
    return twice
end

--- Answers every prop a renderer answers twice, where the second answer is one nothing ever reaches.
---
--- A renderer routes props by name, the browser through a run of checks and Android through a `when`, and
--- either way a second answer for a name the first already gave is a branch nothing reaches. In a browser
--- it is correct when the one before it is held to a node type, since two types may read one name. In a
--- `when` it is never correct, since the first arm that matches is the only arm that runs: a field and an
--- editor both saying where the caret is were two arms, and the editor's never reported at all.
function M.shadowed()
    local twice = {}

    local source = fs.readFile("renderers/web/renderer.js"):await()
    local seen = {}

    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        -- A method of its own is a run of checks of its own, and one nested inside a check is part of
        -- the answer above it rather than a second answer to the same name.
        if line:match("^    [%a_][%w_]*%s*%(") ~= nil then
            seen = {}
        end

        local name = line:match('^        if %(key === "([%w]+)"')

        if name ~= nil then
            local guarded = line:find("type ===", 1, true) ~= nil

            if seen[name] == "open" then
                twice[#twice + 1] = name .. " in renderers/web/renderer.js"
                seen[name] = "said"
            elseif seen[name] == nil then
                seen[name] = guarded and "guarded" or "open"
            end
        end
    end

    local kotlin = fs.readFile("renderers/android/src/main/kotlin/dev/varn/gui/VarnProps.kt"):await()
    local arms = {}

    for line in (kotlin .. "\n"):gmatch("([^\n]*)\n") do
        -- A method of its own holds a `when` of its own. Only the arms of the outermost one are read,
        -- since a `when` nested inside an arm answers a different question at a deeper indentation.
        if line:match("^    [%w ]*fun [%w]+") ~= nil then
            arms = {}
        end

        local names = line:match('^            ("[%w"%s,]+)%s*%->')

        if names ~= nil then
            for name in names:gmatch('"([%w]+)"') do
                if arms[name] then
                    twice[#twice + 1] = name .. " in VarnProps.kt"
                end

                arms[name] = true
            end
        end
    end

    local swift = fs.readFile("renderers/ios/VarnProps.swift"):await()
    local cases = {}

    for line in (swift .. "\n"):gmatch("([^\n]*)\n") do
        -- A function of its own holds a switch of its own, and only the arms of the outermost one are
        -- read, since a switch nested inside an arm answers a different question at a deeper indentation.
        if line:match("^    [%a ]*func [%w]+") ~= nil then
            cases = {}
        end

        local named = line:match('^        case ("[%w"%s,]+):')

        if named ~= nil then
            for name in named:gmatch('"([%w]+)"') do
                if cases[name] then
                    twice[#twice + 1] = name .. " in VarnProps.swift"
                end

                cases[name] = true
            end
        end
    end

    table.sort(twice)
    return twice
end

--- Answers every action a component declares that something has to answer and does not.
---
--- An action is a promise the way a prop is: a caller reads it in the reference and calls it through a
--- ref. A host node's actions are performed by each renderer's own action table, so one answered by two
--- of the three throws on the third, and a component's own are answered in Lua by the handle it hands
--- out. Asking whether anything anywhere answers the name is not enough, so each is asked on its own.
function M.unanswered()
    local performers = {
        ios = fs.readFile("renderers/ios/VarnActions.swift"):await(),
        android = fs.readFile("renderers/android/src/main/kotlin/dev/varn/gui/VarnActions.kt"):await(),
        web = fs.readFile("renderers/web/renderer.js"):await(),
    }

    local engine = table.concat(gather(ENGINE, {}), "\n")
    local broken = {}

    for index = 1, #FAMILIES do
        for name, constructor in pairs(require(FAMILIES[index].module)) do
            local declaration = support.declarations[constructor]

            for _, action in ipairs(declaration ~= nil and declaration.actions or {}) do
                if not declaration.host then
                    if engine:find("%f[%w_]" .. action .. "%s*=%s*function") == nil then
                        broken[#broken + 1] = name .. "." .. action .. " (nothing answers it)"
                    end
                else
                    local missing = {}

                    for platform, source in pairs(performers) do
                        if source:find('"' .. action .. '"', 1, true) == nil then
                            missing[#missing + 1] = platform
                        end
                    end

                    table.sort(missing)

                    if #missing > 0 then
                        broken[#broken + 1] = name .. "." .. action .. " (not on " .. table.concat(missing, ", ") .. ")"
                    end
                end
            end
        end
    end

    table.sort(broken)
    return broken
end

--- Answers every place the list of capabilities is written down and disagrees with the contract.
---
--- The names live in `gui/bridge/conformance.lua` and each native suite carries a copy to hold its own
--- renderer against, so adding one to the contract and to the three renderers still leaves two lists
--- behind — which is a suite failing on a capability that is correct. A list that has to agree with
--- another in three files agrees with nothing unless something says so.
function M.uncontracted()
    local contract = fs.readFile("gui/bridge/conformance.lua"):await()
    local named = {}

    for block in contract:gmatch("M%.capabilities = {(.-)}") do
        for name in block:gmatch('"([%w]+)"') do
            named[name] = true
        end
    end

    local copies = {
        ["renderers/ios/tests/ConformanceTests.swift"] = "let known = %[(.-)%]",
        ["renderers/android/src/test/kotlin/dev/varn/gui/ConformanceTest.kt"] = "val known = listOf%((.-)%)",
    }

    local adrift = {}

    for path, pattern in pairs(copies) do
        local source = fs.readFile(path):await()
        local carried = {}

        for block in source:gmatch(pattern) do
            for name in block:gmatch('"([%w]+)"') do
                carried[name] = true
            end
        end

        for name in pairs(named) do
            if not carried[name] then
                adrift[#adrift + 1] = name .. " is in the contract and not in " .. path
            end
        end

        for name in pairs(carried) do
            if not named[name] then
                adrift[#adrift + 1] = name .. " is in " .. path .. " and not in the contract"
            end
        end
    end

    table.sort(adrift)
    return adrift
end

--- Answers every spread of children that is not the last thing written in its element.
---
--- `table.unpack` in the middle of a table constructor yields exactly one value, so a row of six
--- pressables written before a button is one pressable and a button, silently. Nothing about it is a
--- Lua error, nothing is nil, and the screen draws: what comes out is a shorter list than the one that
--- was written. It has cost a stepper its keys, a checkbox and a radio their focus rings and a ride
--- screen four of its five rows, each found by looking at a screen rather than by anything failing.
function M.unspread()
    local roots = { "gui", "sample" }
    local dropped = {}

    for _, root in ipairs(roots) do
        local paths = {}

        local function walk(where)
            for _, name in ipairs(fs.readdir(where):await()) do
                local path = where .. "/" .. name

                if fs.stat(path):await().isDir then
                    if name ~= "tests" then
                        walk(path)
                    end
                elseif path:match("%.lua$") then
                    paths[#paths + 1] = path
                end
            end
        end

        walk(root)

        for _, path in ipairs(paths) do
            local lines = {}

            for line in (fs.readFile(path):await() .. "\n"):gmatch("(.-)\n") do
                lines[#lines + 1] = line
            end

            for index = 1, #lines do
                local spread = lines[index]:match("^%s*table%.unpack%b()%s*,%s*$")

                if spread ~= nil then
                    -- What may follow a spread is the end of the element it is in, which is a closing
                    -- brace, and nothing else. Anything that opens a child after it is a child that was
                    -- written and never reaches the tree.
                    local after = index + 1

                    while lines[after] ~= nil and lines[after]:match("^%s*$") do
                        after = after + 1
                    end

                    local next = lines[after]

                    if next ~= nil and next:match("^%s*[%}%)]") == nil then
                        dropped[#dropped + 1] = path .. ":" .. index
                            .. " spreads children and then writes more, which drops all but the first"
                    end
                end
            end
        end
    end

    table.sort(dropped)
    return dropped
end

return M
