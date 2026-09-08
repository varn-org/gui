local async = require("async")
local fs = require("fs")
local gui = require("gui")
local pictures = require("gui.assets.pictures")

local ROOT = os.getenv("VARN_TEST_DIR")

--- Answers a store that never reaches the network, so what a picture does while it waits is testable.
local function held(answers)
    local store = pictures.create(ROOT .. "/held", function() end)

    store.fetch = function(self, url)
        local landed = answers[url]

        if landed == "missing" then
            self.failed[url] = true
            return nil
        end

        return landed
    end

    return store
end

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 320, height = 480 }

    local runtime = gui.start(description, renderer, options)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

-- A picture from somewhere else is fetched by the engine and handed over as a file.
--
-- A phone hands an `https://` string straight to its image view and quietly draws nothing, so the one
-- fetch here is what makes a remote picture work on all three at once.
do
    local store = held({ ["https://example.test/one.jpg"] = "/cache/one.jpg" })
    local _, renderer = start(
        gui.Image { source = "https://example.test/one.jpg", style = { height = 80 } },
        { pictures = store }
    )

    assert(renderer:find("image").props.source == "/cache/one.jpg",
        "a fetched picture reaches the renderer as the file it landed as")
end

-- While it is still on its way, the placeholder is what is drawn.
do
    local store = held({})
    local _, renderer = start(
        gui.Image { source = "https://example.test/slow.jpg", placeholder = "logo.png", style = { height = 80 } },
        { pictures = store }
    )

    assert(renderer:find("image").props.source == "logo.png",
        "a picture that has not landed shows what stands in for it")
end

-- One that never arrives leaves the placeholder rather than an empty box.
do
    local store = held({ ["https://example.test/gone.jpg"] = "missing" })
    local _, renderer = start(
        gui.Image { source = "https://example.test/gone.jpg", placeholder = "logo.png", style = { height = 80 } },
        { pictures = store }
    )

    assert(renderer:find("image").props.source == "logo.png",
        "a picture that never came leaves what stands in for it")
end

-- A renderer that shares no filesystem with the engine is handed the bytes rather than a name.
async.run(function()
    local root = ROOT .. "/bytes"
    fs.mkdir(root)
    fs.writeFile(root .. "/one.png", "not really a png"):await()

    local app = nil
    local store = pictures.create(root, function(url, ok)
        if app ~= nil then
            app:invalidatePictures(url, ok)
        end
    end)
    store.fetch = function() return root .. "/one.png" end

    local renderer = nil
    app, renderer = start(
        gui.Image { source = "https://example.test/one.png", style = { height = 80 } },
        { pictures = store, imageBytes = true }
    )

    -- The bytes are asked for during a commit and read after it, since a commit cannot wait on a file.
    async.sleep(40):await()
    app:commit()

    local source = renderer:find("image").props.source

    assert(source ~= nil and source:find("^data:image/png;base64,") ~= nil,
        "a renderer that asked for bytes is handed a data uri, got " .. tostring(source))

    -- A picture that is already a data uri is left exactly as it is.
    local _, plain = start(
        gui.Image { source = "data:image/png;base64,AAAA", style = { height = 80 } },
        { pictures = store, imageBytes = true }
    )

    assert(plain:find("image").props.source == "data:image/png;base64,AAAA",
        "a picture handed over as bytes is not fetched again")

    -- A picture that lands tells whatever was waiting on it, which the engine is what knows.
    local landed = pictures.create(root, function() end)
    landed.fetch = function() return nil end

    local told = nil
    local runtime = select(1, start(
        gui.Image {
            source = "https://example.test/two.png",
            onLoad = function() told = "loaded" end,
            onError = function() told = "failed" end,
            style = { height = 80 },
        },
        { pictures = landed }
    ))

    assert(told == nil, "nothing is reported while a picture is still on its way")

    runtime:invalidatePictures("https://example.test/two.png", true)
    assert(told == "loaded", "a picture that arrived tells what was waiting on it")

    runtime:invalidatePictures("https://example.test/two.png", false)
    assert(told == "failed", "a picture that never came says so")

    -- A picture that lands reaches the screen in the run that fetched it.
    --
    -- A source that had not arrived was sent as its placeholder, and a restyle sends styles rather than
    -- props, so a fetched picture only ever appeared the next time the application was opened.
    local arriving = pictures.create(root, function() end)
    local landed = false

    arriving.fetch = function()
        if landed then
            return root .. "/one.png"
        end

        return nil
    end

    local runtime, renderer = start(
        gui.Image { source = "https://example.test/late.png", placeholder = "logo.png", style = { height = 80 } },
        { pictures = arriving }
    )

    assert(renderer:find("image").props.source == "logo.png", "what has not landed shows what stands in for it")

    landed = true
    runtime:invalidatePictures("https://example.test/late.png", true)

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(renderer:find("image").props.source == root .. "/one.png",
        "a picture that landed must reach the screen, got " .. tostring(renderer:find("image").props.source))

    -- A picture that cannot be had is asked for once, not once for every commit that follows.
    local missing = ROOT .. "/failing"
    fs.mkdir(missing)

    local asked = 0
    local answering = pictures.get
    pictures.get = function()
        asked = asked + 1
        return nil
    end

    local waiting = nil
    local giving = pictures.create(missing, function(url, ok)
        if waiting ~= nil then
            waiting:invalidatePictures(url, ok)
        end
    end)

    waiting = start(
        gui.Image { source = "https://example.test/gone.png", style = { height = 80 } },
        { pictures = giving }
    )

    async.sleep(40):await()

    for _ = 1, 5 do
        waiting.repainting = true
        waiting:schedule()
        waiting:commit()
        async.sleep(5):await()
    end

    pictures.get = answering

    assert(asked == 1, "a picture that could not be had is asked for once, got " .. asked)

    print("gui.pictures ok")
end)
