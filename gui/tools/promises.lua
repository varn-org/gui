local fs = require("fs")
local support = require("gui.components.support")

local M = {}

--- The families every component is declared in, which is what the reference is built from as well.
local FAMILIES = {
    "gui.components.structure",
    "gui.components.content",
    "gui.components.input",
    "gui.components.collections",
    "gui.components.containers",
    "gui.components.presentation",
    "gui.components.feedback",
}

--- Where a prop can be answered: by a renderer that applies it, or by the component that builds on it.
local SOURCES = {
    "renderers/ios",
    "renderers/web",
    "renderers/android/src/main",
    "gui",
}

--- The props every node carries, which are answered in one place rather than declared by each component.
local UNIVERSAL = {
    key = true,
    style = true,
    ref = true,
    testID = true,
    accessibilityLabel = true,
}

--- Answers what a file says about a prop, which is not the list of props it declares taking.
---
--- A declaration writes every prop it takes by name, so counting that as evidence would mean every
--- declaration proves itself and the check answers nothing.
function M.evidence(source)
    return (source:gsub("props = {[^}]*}", ""):gsub("events = {[^}]*}", ""))
end

--- The names a prop is read under: a renderer names it, and a component reads it off what it was given.
local HOLDERS = { "props", "spec", "options", "entry", "declaration" }

local function reads(source, name)
    if source:find('"' .. name .. '"', 1, true) ~= nil then
        return true
    end

    for index = 1, #HOLDERS do
        if source:find(HOLDERS[index] .. "%." .. name .. "%f[%W]") ~= nil then
            return true
        end
    end

    return false
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
            if not path:match("gui/tools/") then
                into[#into + 1] = M.evidence(fs.readFile(path):await())
            end
        end
    end

    return into
end

--- Answers every prop and event a component declares that nothing anywhere reads.
---
--- A declaration is a promise: `docs/components.md` is generated from it, so a prop listed there is one
--- a caller writes and believes. One nothing reads is worse than one that does not exist.
function M.unkept()
    local sources = {}

    for index = 1, #SOURCES do
        gather(SOURCES[index], sources)
    end

    local corpus = table.concat(sources, "\n")
    local broken = {}

    for index = 1, #FAMILIES do
        for name, constructor in pairs(require(FAMILIES[index])) do
            local declaration = support.declarations[constructor]

            if declaration ~= nil then
                local named = {}

                for position = 1, #declaration.props do
                    named[#named + 1] = declaration.props[position]
                end

                for position = 1, #declaration.events do
                    named[#named + 1] = declaration.events[position]
                end

                for position = 1, #named do
                    local prop = named[position]

                    if not UNIVERSAL[prop] and not reads(corpus, prop) then
                        broken[#broken + 1] = name .. "." .. prop
                    end
                end
            end
        end
    end

    table.sort(broken)
    return broken
end

return M
