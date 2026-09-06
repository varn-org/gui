local async = require("async")
local fs = require("fs")
local zip = require("zip")
local bundle = require("gui.assets.bundle")

local scratch = assert(os.getenv("VARN_TEST_DIR"), "VARN_TEST_DIR is not set")
local cache = scratch .. "/cache"

local function pack(into)
    local entries = {}
    local files = {
        "manifest.lua",
        "app.lua",
        "assets/images/logo.png",
        "assets/images/logo@2x.png",
    }

    for index = 1, #files do
        entries[index] = { file = "sample/" .. files[index], entry = files[index] }
    end

    zip.create(into, entries):await()
    return into
end


async.run(function()
    local archive = pack(scratch .. "/gallery.vap")

    -- A project directory opens without packing, which is what a development loop wants.
    do
        local opened = bundle.openDirectory("sample")

        assert(opened.manifest.identifier == "dev.varn.gui.gallery", "the manifest must be read")
        assert(opened.manifest.version == "1.0.0", "the manifest must carry its version")
        assert(opened:entry():find("app.lua"), "the entry point must resolve")
    end

    -- An archive expands into a cache and answers what it carries.
    do
        local opened = bundle.open(archive, cache)

        assert(opened.digest ~= nil and #opened.digest > 0, "the archive must be identified by its bytes")
        assert(opened.manifest.name == "Varn GUI Gallery", "the manifest must survive the round trip")
        assert(fs.exists(opened.root .. "/" .. bundle.marker), "a finished expansion must be marked")
    end

    -- Opening the same archive twice reuses the expansion rather than doing it again.
    do
        local first = bundle.open(archive, cache)
        local stamp = fs.stat(first.root .. "/manifest.lua"):await().mtime

        local second = bundle.open(archive, cache)
        assert(second.root == first.root, "the same bytes must land in the same cache")
        assert(fs.stat(second.root .. "/manifest.lua"):await().mtime == stamp, "a second open must not re-expand")
    end

    -- An expansion that was only written in part is discarded rather than trusted.
    do
        local opened = bundle.open(archive, cache)
        fs.removeRecursive(opened.root .. "/" .. bundle.marker):await()
        fs.removeRecursive(opened.root .. "/app.lua"):await()

        local reopened = bundle.open(archive, cache)
        assert(fs.exists(reopened.root .. "/app.lua"), "an unmarked cache must be rebuilt")
        assert(fs.exists(reopened.root .. "/" .. bundle.marker), "the rebuild must mark itself finished")
    end

    -- Every font the manifest declares resolves to a file the renderer can register.
    --
    -- The fixture is this test's own, since the sample ships no font: a font carries a licence, and one
    -- that is a placeholder rather than a font would be registered by nobody and drawn by nobody.
    do
        local project = scratch .. "/fonted"
        fs.mkdir(project .. "/assets/fonts"):await()

        fs.writeFile(project .. "/manifest.lua", table.concat({
            "return {",
            "    identifier = 'dev.varn.gui.fonted',",
            "    name = 'Fonted',",
            "    entry = 'app.lua',",
            "    fonts = {",
            "        { family = 'Gallery', file = 'gallery-regular.ttf', weight = '400' },",
            "        { family = 'Gallery', file = 'gallery-bold.ttf', weight = '700' },",
            "    },",
            "}",
        }, "\n")):await()

        fs.writeFile(project .. "/app.lua", "return nil"):await()
        fs.writeFile(project .. "/assets/fonts/gallery-regular.ttf", "regular"):await()
        fs.writeFile(project .. "/assets/fonts/gallery-bold.ttf", "bold"):await()

        local fonts = bundle.openDirectory(project):fonts()

        assert(#fonts == 2, "both fonts must resolve, got " .. #fonts)
        assert(fonts[1].family == "Gallery", "a font must carry the family the manifest named")
        assert(fonts[1].weight == "400", "a font must carry its weight")
        assert(fs.exists(fonts[1].path), "a font must resolve to a file that exists")
    end

    -- An image resolves by name, and a density variant wins when the scale asks for one.
    do
        local opened = bundle.open(archive, cache)

        assert(opened:image("logo.png", 1):find("logo%.png$"), "scale one takes the plain name")
        assert(opened:image("logo.png", 2):find("logo@2x%.png$"), "scale two takes the variant")
        assert(opened:image("logo.png", 3):find("logo@2x%.png$"), "scale three falls back to the largest there is")
    end

    -- Asking for something the bundle does not carry says what was missing.
    do
        local opened = bundle.open(archive, cache)

        local ok, message = pcall(opened.path, opened, "images", "absent.png")
        assert(not ok, "a missing asset must be refused")
        assert(tostring(message):find("absent.png"), "the message must name what was missing")
    end

    -- An archive with no manifest is refused rather than opened half way.
    do
        local empty = scratch .. "/empty.vap"
        zip.create(empty, { { file = "sample/app.lua", entry = "app.lua" } }):await()

        local ok, message = pcall(bundle.open, empty, cache)
        assert(not ok, "an archive with no manifest must be refused")
        assert(tostring(message):find("manifest"), "the message must say what was missing")
    end

    -- A manifest with no identifier is refused, since a host has nothing to key its storage on.
    do
        local broken = scratch .. "/broken"
        fs.mkdir(broken):await()
        fs.writeFile(broken .. "/manifest.lua", "return { name = 'nameless' }"):await()

        local ok, message = pcall(bundle.openDirectory, broken)
        assert(not ok, "a manifest with no identifier must be refused")
        assert(tostring(message):find("identifier"), "the message must name what was missing")
    end

    -- A screen names the file it wants, and the runtime is what turns that into a path a renderer opens.
    --
    -- Nothing did, so a bundled image reached every renderer as the name it was written with and none of
    -- them found a file there: an application shipping its own pictures showed empty boxes.
    do
        local gui = require("gui")
        local project = bundle.openDirectory("sample")
        local renderer = gui.headless()

        local runtime = gui.start(gui.View { style = { grow = 1 },
            gui.Image { source = "logo.png", style = { height = 40 } },
            gui.Image { source = "https://varn.dev/remote.png", style = { height = 40 } },
        }, renderer, { size = { width = 390, height = 844 }, assets = project, scale = 2 })

        runtime:commit()

        local images = renderer:findAll("image")
        assert(#images == 2, "the screen carries two pictures, found " .. #images)

        assert(images[1].props.source:find("assets/images/logo", 1, true) ~= nil,
            "a bundled name must expand to the file in the bundle, got " .. images[1].props.source)
        assert(images[1].props.source:find("@2x", 1, true) ~= nil,
            "a screen drawn at twice the scale takes the variant for it, got " .. images[1].props.source)
        assert(images[2].props.source == "https://varn.dev/remote.png",
            "a source somewhere else entirely is left alone, got " .. images[2].props.source)
    end

    -- A name the bundle does not carry is refused loudly rather than drawn as an empty box.
    do
        local gui = require("gui")
        local project = bundle.openDirectory("sample")

        local ok, message = pcall(function()
            local runtime = gui.start(gui.Image { source = "missing.png", style = { height = 40 } },
                gui.headless(), { size = { width = 390, height = 844 }, assets = project })

            runtime:commit()
        end)

        assert(not ok, "an image the bundle does not carry must be refused")
        assert(tostring(message):find("missing.png", 1, true) ~= nil, "the message must name what was asked for")
    end

    print("gui.bundle ok")
end)
