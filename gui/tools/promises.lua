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

    -- Turned into padding or into an arrangement by the runtime.
    ["SafeArea.edges"] = true,
    ["KeyboardAvoiding.behavior"] = true,
    ["KeyboardAvoiding.offset"] = true,
    ["ScrollView.contentStyle"] = true,

    -- Answered by the engine, which is what knows: it is the engine that fetches a picture.
    ["Image.onLoad"] = true,
    ["Image.onError"] = true,
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
function M.evidence(source)
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
                into[#into + 1] = M.evidence(fs.readFile(path):await())
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

--- Answers every prop and event a component declares that nothing anywhere reads.
---
--- A declaration is a promise: `docs/components.md` is generated from it, so a prop listed there is one
--- a caller writes and believes. One nothing reads is worse than one that does not exist.
--- Answers every prop and event, with the name of each thing that has to honour it and does not.
---
--- A declaration is a promise: `docs/components.md` is generated from it, so a prop listed there is one
--- a caller writes and believes. Asking whether *anything anywhere* reads it is not enough, because a
--- prop honoured on one platform out of three is a promise kept for a third of the people who believe
--- it, and a whole sweep of those was invisible while the check ran over one corpus.
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

        local excused = UNIVERSAL[prop] or (declaration.host and ANSWERED[name .. "." .. prop])

        if not excused and not (not declaration.host and reads(engine, prop)) then
            if not declaration.host then
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

return M
