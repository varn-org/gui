local async = require("async")
local fs = require("fs")
local bundle = require("gui.assets.bundle")

local M = {}

local Report = {}
Report.__index = Report

--- Records something wrong with the project, which is what makes the check fail.
function Report:problem(message)
    self.problems[#self.problems + 1] = message
end

--- Records something worth knowing that is not wrong, which is what an unused asset is.
function Report:note(message)
    self.notes[#self.notes + 1] = message
end

local IMAGE_KINDS = { png = true, jpg = true, jpeg = true, gif = true, webp = true, svg = true }
local FONT_KINDS = { ttf = true, otf = true, ttc = true, woff = true, woff2 = true }

local function extension(name)
    return (name:match("%.(%w+)$") or ""):lower()
end

--- Answers every file under a directory, as paths relative to it.
local function walk(root, prefix, found)
    if not fs.exists(root) then
        return found
    end

    local names = fs.readdir(root):await()

    for index = 1, #names do
        local name = names[index]
        local path = root .. "/" .. name

        if fs.stat(path):await().isDir then
            walk(path, prefix .. name .. "/", found)
        else
            found[#found + 1] = prefix .. name
        end
    end

    return found
end

--- Answers the text of every Lua source the project carries, which is where a name is referenced.
---
--- The manifest is left out, since it declares an asset rather than referencing one and reading it as
--- a reference would make every declaration prove itself.
local function sources(root)
    local text = {}
    local files = walk(root, "", {})

    for index = 1, #files do
        local name = files[index]

        if extension(name) == "lua" and name ~= "manifest.lua" then
            text[#text + 1] = fs.readFile(root .. "/" .. name):await()
        end
    end

    return table.concat(text, "\n")
end

--- Checks that every font the manifest declares is present and named where a style can reach it.
local function checkFonts(project, report, text)
    local declared = project.manifest.fonts or {}
    local families = {}

    for index = 1, #declared do
        local entry = declared[index]

        if entry.family == nil then
            report:problem("a font entry has no family, so no style can name it")
        end

        if entry.file == nil then
            report:problem("the font " .. tostring(entry.family) .. " names no file")
        elseif not fs.exists(project.root .. "/assets/fonts/" .. entry.file) then
            report:problem("the manifest declares assets/fonts/" .. entry.file .. ", which the project does not carry")
        elseif not FONT_KINDS[extension(entry.file)] then
            report:problem(entry.file .. " is declared as a font but is not one")
        end

        families[entry.family] = true
    end

    for family in pairs(families) do
        if family ~= nil and not text:find(family, 1, true) then
            report:note("the font family " .. family .. " is registered but no style names it")
        end
    end

    local carried = walk(project.root .. "/assets/fonts", "", {})
    for index = 1, #carried do
        local name = carried[index]
        local found = false

        for position = 1, #declared do
            if declared[position].file == name then
                found = true
            end
        end

        if not found then
            report:note("assets/fonts/" .. name .. " is in the project but the manifest does not declare it")
        end
    end
end

--- Checks that every image a source names is present, and reports the ones nothing names.
local function checkImages(project, report, text)
    local carried = walk(project.root .. "/assets/images", "", {})
    local preloaded = table.concat(project.manifest.preload or {}, "\n")
    local base = {}

    for index = 1, #carried do
        local name = carried[index]

        if not IMAGE_KINDS[extension(name)] then
            report:problem("assets/images/" .. name .. " is not an image")
        end

        -- A density variant belongs to the plain name, so it is not an asset of its own.
        local plain = name:gsub("@[23]x(%.%w+)$", "%1")
        base[plain] = true

        if not text:find(plain, 1, true) and not preloaded:find(plain, 1, true) then
            report:note("assets/images/" .. plain .. " is in the project but nothing references it")
        end
    end

    for reference in text:gmatch('["\']([%w%-_/]+%.[%w]+)["\']') do
        if IMAGE_KINDS[extension(reference)] then
            local name = reference:gsub("^images/", "")

            if not base[name] then
                report:problem("a source references the image " .. reference .. ", which the project does not carry")
            end
        end
    end
end

--- Checks the manifest itself, which is what names the entry point and the identifier.
local function checkManifest(project, report)
    local manifest = project.manifest

    if type(manifest.identifier) ~= "string" or manifest.identifier == "" then
        report:problem("the manifest needs an identifier")
    end

    if type(manifest.version) ~= "string" then
        report:problem("the manifest needs a version")
    end

    local entry = manifest.entry or "app.lua"
    if not fs.exists(project.root .. "/" .. entry) then
        report:problem("the manifest names the entry point " .. entry .. ", which the project does not carry")
    end

    for index = 1, #(manifest.preload or {}) do
        local name = manifest.preload[index]
        if not fs.exists(project.root .. "/assets/" .. name) then
            report:problem("the manifest preloads assets/" .. name .. ", which the project does not carry")
        end
    end
end

--- Checks a project directory or an archive, answering what is wrong and what is worth knowing.
function M.check(path, cacheRoot)
    local directory = fs.exists(path) and fs.stat(path):await().isDir
    local project = directory and bundle.openDirectory(path) or bundle.open(path, cacheRoot)
    local report = setmetatable({ problems = {}, notes = {}, project = project }, Report)
    local text = sources(project.root)

    checkManifest(project, report)
    checkFonts(project, report, text)
    checkImages(project, report, text)

    return report
end

--- Runs the check from the command line, reporting what it found and failing when something is wrong.
function M.main(arguments)
    local path = arguments[1]

    if path == nil then
        print("usage: doctor <project directory or .vap>")
        return 1
    end

    local report = M.check(path, os.getenv("VARN_TEST_DIR") or ".varn/cache")

    for index = 1, #report.notes do
        print("note: " .. report.notes[index])
    end

    for index = 1, #report.problems do
        print("problem: " .. report.problems[index])
    end

    if #report.problems > 0 then
        print(#report.problems .. " problems, " .. #report.notes .. " notes")
        return 1
    end

    print(report.project.manifest.identifier .. " is sound, " .. #report.notes .. " notes")
    return 0
end

if arg ~= nil and arg[0] ~= nil and arg[0]:find("doctor.lua", 1, true) then
    -- Reading a project is io, so the check runs on a coroutine the loop drives and exits from there.
    async.run(function() os.exit(M.main(arg)) end)
end

return M
