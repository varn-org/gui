local support = require("gui.components.support")

local M = {}

--- Answers what a component is drawn by, which is a node, Lua, or either as the control theme says.
local function drawnAs(declaration)
    if declaration.host then
        return "`" .. declaration.kind .. "`"
    end

    if declaration.platform ~= nil then
        return "`" .. declaration.platform .. "` or Lua"
    end

    return "Lua"
end

local FAMILIES = require("gui.components.families")

local function sorted(values)
    local copy = {}

    for index = 1, #values do
        copy[index] = values[index]
    end

    table.sort(copy)
    return copy
end

local function names(values)
    if #values == 0 then
        return "—"
    end

    return "`" .. table.concat(sorted(values), "`, `") .. "`"
end

local function defaults(values)
    local written = {}

    for name, value in pairs(values) do
        written[#written + 1] = name .. " = " .. (type(value) == "table" and "{ … }" or tostring(value))
    end

    if #written == 0 then
        return "—"
    end

    table.sort(written)
    return "`" .. table.concat(written, "`, `") .. "`"
end

--- Answers every component of a family, as the name a caller writes and what it declares.
local function familyOf(module)
    local family = require(module)
    local found = {}

    for name, constructor in pairs(family) do
        local declaration = support.declarations[constructor]

        if declaration ~= nil then
            found[#found + 1] = { name = name, declaration = declaration }
        end
    end

    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

--- Answers the reference as markdown, which is the table every component appears in.
---
--- The page is built from the declarations themselves, so a component cannot document a prop it does
--- not accept and cannot accept one it does not document.
function M.render()
    local lines = {}

    for index = 1, #FAMILIES do
        local family = FAMILIES[index]

        lines[#lines + 1] = "### " .. family.title
        lines[#lines + 1] = ""
        lines[#lines + 1] = "| Component | Node | Props | Events | Actions | Defaults |"
        lines[#lines + 1] = "|---|---|---|---|---|---|"

        local entries = familyOf(family.module)
        for position = 1, #entries do
            local entry = entries[position]
            local declaration = entry.declaration

            lines[#lines + 1] = table.concat({
                "| `" .. entry.name .. "` ",
                "| " .. drawnAs(declaration) .. " ",
                "| " .. names(declaration.props) .. " ",
                "| " .. names(declaration.events) .. " ",
                "| " .. names(declaration.actions) .. " ",
                "| " .. defaults(declaration.defaults) .. " |",
            })
        end

        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

if arg ~= nil and arg[0] ~= nil and arg[0]:find("reference.lua", 1, true) then
    print(M.render())
end

return M
