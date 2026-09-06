local async = require("async")
local fs = require("fs")
local doctor = require("gui.tools.doctor")

local scratch = assert(os.getenv("VARN_TEST_DIR"), "VARN_TEST_DIR is not set")

--- Builds a project on disk from the files a case names, answering the directory it went into.
local function project(name, files)
    local root = scratch .. "/" .. name

    for path, content in pairs(files) do
        local directory = path:match("^(.*)/[^/]+$")
        fs.mkdir(directory ~= nil and root .. "/" .. directory or root):await()
        fs.writeFile(root .. "/" .. path, content):await()
    end

    return root
end

local MANIFEST = [[
return {
    identifier = "dev.varn.gui.case",
    name = "Case",
    version = "1.0.0",
    entry = "app.lua",
    fonts = { { family = "Gallery", file = "gallery.ttf", weight = "400" } },
}
]]

--- Answers whether any message carries the text a case is looking for.
local function mentions(messages, text)
    for index = 1, #messages do
        if messages[index]:find(text, 1, true) then
            return true
        end
    end

    return false
end

async.run(function()
    -- A sound project passes with nothing to report.
    do
        local root = project("sound", {
            ["manifest.lua"] = MANIFEST,
            ["app.lua"] = [[local logo = "images/logo.png" return { font = "Gallery", logo = logo }]],
            ["assets/fonts/gallery.ttf"] = "font bytes",
            ["assets/images/logo.png"] = "image bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(#report.problems == 0, "a sound project must report nothing: " .. table.concat(report.problems, ", "))
        assert(#report.notes == 0, "a sound project must have nothing worth noting: " .. table.concat(report.notes, ", "))
    end

    -- A font the manifest declares but the project does not carry is a problem.
    do
        local root = project("missing-font", {
            ["manifest.lua"] = MANIFEST,
            ["app.lua"] = [[return { font = "Gallery" }]],
            ["assets/images/keep.png"] = "image bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(mentions(report.problems, "gallery.ttf"), "a missing font must be reported")
    end

    -- An image a source names but the project does not carry is a problem.
    do
        local root = project("missing-image", {
            ["manifest.lua"] = MANIFEST,
            ["app.lua"] = [[return { logo = "images/logo.png", font = "Gallery" }]],
            ["assets/fonts/gallery.ttf"] = "font bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(mentions(report.problems, "images/logo.png"), "an image nothing carries must be reported")
    end

    -- An asset that is present but nothing references is worth knowing rather than wrong.
    do
        local root = project("unused", {
            ["manifest.lua"] = MANIFEST,
            ["app.lua"] = [[return { font = "Gallery" }]],
            ["assets/fonts/gallery.ttf"] = "font bytes",
            ["assets/images/unused.png"] = "image bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(#report.problems == 0, "an unused asset is not a problem")
        assert(mentions(report.notes, "unused.png"), "an unused asset must be noted")
    end

    -- A font family no style names is worth knowing, since registering it costs something.
    do
        local root = project("unnamed-family", {
            ["manifest.lua"] = MANIFEST,
            ["app.lua"] = [[return { text = "plain" }]],
            ["assets/fonts/gallery.ttf"] = "font bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(mentions(report.notes, "Gallery"), "a family nothing names must be noted")
    end

    -- A manifest naming an entry point the project does not carry is a problem.
    do
        local root = project("no-entry", {
            ["manifest.lua"] = MANIFEST,
            ["assets/fonts/gallery.ttf"] = "font bytes",
        })

        local report = doctor.check(root, scratch .. "/cache")

        assert(mentions(report.problems, "app.lua"), "a missing entry point must be reported")
    end

    -- The sample application is what the tool is measured against.
    do
        local report = doctor.check("sample", scratch .. "/cache")

        assert(#report.problems == 0, "the sample must be sound: " .. table.concat(report.problems, ", "))
    end

    print("gui.doctor ok")
end)
