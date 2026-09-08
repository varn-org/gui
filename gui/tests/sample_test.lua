local gui = require("gui")

-- The sample is loaded the way a host loads it, with its own root on the path.
package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local support = require("gui.components.support")

local app = require("app")
local catalogue = require("catalogue")

--- What has to be run inside the one asynchronous body this file has, since a second one never resumes.
local M = {}

local function start(description, given, onProblem)
    local renderer = given or gui.headless()
    local runtime = gui.start(description, renderer,
        { size = { width = 390, height = 844 }, onProblem = onProblem })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

-- The gallery leaves the system's own bars to the system, so they read in both appearances.
--
-- It named `light`, which was right in the dark and put white glyphs on the white bar the light
-- appearance turned it into. A screen that names one is naming it for both.
do
    local _, renderer = start(app.root)

    for _, node in pairs(renderer.nodes) do
        assert(node.props.barContent == nil,
            "the gallery must not pin how the system draws its bars, pinned "
                .. tostring(node.props.barContent))
    end
end

-- The first screen is a list of what there is to see, grouped by the kind of thing it is.
do
    local _, renderer = start(app.root)

    assert(#renderer:findAll("sectionlist") == 1, "the index must be one sectioned list")
    assert(catalogue.count() >= 20, "the gallery must carry the demos, has " .. catalogue.count())

    local labels = renderer:findAll("text")
    local titled = false

    for index = 1, #labels do
        if labels[index].props.text == "Varn GUI" then
            titled = true
        end
    end

    assert(titled, "the bar must name the application while the index is showing")
end

-- Opening a demo replaces the body and offers the way back, and going back brings the index with it.
do
    local runtime, renderer = start(app.root)
    local instance = runtime.root.instance

    instance:setState({ open = { group = "inputs", item = "fields" } })
    runtime:commit()

    assert(#renderer:findAll("textinput") > 0, "the demo itself must be on screen")

    -- The index stays where it was under the demo rather than being taken down, so coming back is the
    -- list a reader left rather than a new one scrolled to the top.
    assert(#renderer:findAll("sectionlist") == 1, "the index stays behind the demo that covers it")

    instance:setState({ open = gui.none })
    runtime:commit()

    assert(#renderer:findAll("sectionlist") == 1, "going back brings the index with it")
    assert(#renderer:findAll("textinput") == 0, "and the demo it left is taken down")
end

-- The gallery is themed the way the platform is set, without a switch of its own.
do
    local renderer = gui.headless()
    local runtime = gui.start(app.root, renderer, { size = { width = 390, height = 844 }, appearance = "dark" })

    for _ = 1, 4 do
        if runtime:needsCommit() then
            runtime:commit()
        end
    end

    local light = gui.theme.create():color("surface")
    -- The safe area paints the whole screen and insets what is inside it, so the background is on the
    -- box that fills the surface rather than on the one that holds the padding.
    local painted = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.style ~= nil and node.props.style.background ~= nil and node.frame ~= nil
            and node.frame.width == 390 and node.frame.y == 0 then
            painted = node.props.style.background
        end
    end

    assert(painted ~= nil, "the gallery paints its background")
    assert(painted ~= light, "a dark platform is themed dark, got " .. tostring(painted))

    assert(#renderer:findAll("switch") == 0, "the gallery carries no appearance switch of its own")
end

-- Every screen renders with the bundle attached, which is the only way an application ever runs.
--
-- The runtime expands an asset name against the bundle, so a prop it reads as a file that is not one
-- fails there and nowhere else: every screen looked right from the source tree and the form was blank
-- on a device, because a placeholder is a picture on an image and the words in an empty field on a field.
do
    local project = require("gui.assets.bundle").openDirectory("sample")

    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local renderer = gui.headless()

            local ok, message = pcall(function()
                local runtime = gui.start(gui.View { style = { grow = 1 }, demo.render() }, renderer,
                    { size = { width = 390, height = 844 }, assets = project })

                for _ = 1, 4 do
                    if not runtime:needsCommit() then
                        break
                    end

                    runtime:commit()
                end

                runtime:stop()
            end)

            assert(ok, group.title .. " / " .. demo.title .. " failed against the bundle: " .. tostring(message))
        end
    end
end

--- Every node type the gallery draws, which is what proves a component is shown rather than mentioned.
local DRAWN = {}

--- What a control is changed to when a demo is driven, which is enough to reach the handler behind it.
local CHANGED = {
    switch = true,
    checkbox = true,
    radio = true,
    slider = 0.5,
    stepper = 2,
    segmented = 2,
    rating = 3,
    textinput = "typed",
    textarea = "typed",
    searchbar = "typed",
    colorpicker = "#336699",
    datepicker = "2026-01-02",
    timepicker = "09:30",
}

--- What a press carries for the types that report something with one, which is what the platform sends.
local PRESSED = {
    map = { latitude = 51.5074, longitude = -0.1278 },
}

--- Every other event a reader causes, with what the platform sends when they do.
---
--- A press and a change are what most controls report, and the rest are where the handlers nobody
--- drives live: what a list says when it is scrolled to its end, what a field says when the return key
--- is pressed, what a row says when it is swiped.
local CAUSED = {
    onLongPress = function() return nil end,
    onSubmit = function() return nil end,
    onFocus = function() return nil end,
    onBlur = function() return nil end,
    onRefresh = function() return nil end,
    onCommit = function(node) return CHANGED[node.type] end,
    onSelect = function(node) return { item = 1, index = 1 } end,
    onSwipe = function() return { direction = "left" } end,
    onScroll = function() return { x = 0, y = 400 } end,
    onScrollEnd = function() return { x = 0, y = 400 } end,
    onIndexChange = function() return 2 end,
    onRegionChange = function() return { center = { latitude = 51.5, longitude = -0.12 }, zoom = 11 } end,
    onMarkerPress = function() return { key = "home" } end,
    onProgress = function() return { position = 3, duration = 120 } end,
    onReady = function() return { duration = 120 } end,
    onEnd = function() return nil end,
    onLoad = function() return nil end,
    onError = function() return { message = "nothing came back" } end,
    onPick = function() return { name = "one.png", size = 8, type = "image/png", bytes = nil } end,
    onRemove = function() return nil end,
    onDismiss = function() return nil end,
    onAction = function() return "ok" end,
}


--- Presses and changes everything a demo carries, which is what a reader does to it.
---
--- Rendering a screen proves it draws. It proves nothing about what happens when it is used, and the
--- handler behind a control is where a screen actually fails: a picture handed a prop it does not take
--- threw on every commit after it was chosen, and every case that only rendered the screen passed.
local function drive(runtime, renderer, named)
    local reached = {}

    for _, node in pairs(renderer.nodes) do
        reached[#reached + 1] = node
    end

    table.sort(reached, function(first, second) return first.id < second.id end)

    for index = 1, #reached do
        local node = reached[index]

        if renderer.nodes[node.id] ~= nil then
            if node.props.onPress ~= nil then
                runtime:dispatch(node.id, "onPress", PRESSED[node.type])
                runtime:commit()
            end

            local changed = CHANGED[node.type]

            if changed ~= nil and node.props.onChange ~= nil then
                runtime:dispatch(node.id, "onChange", changed)
                runtime:commit()
            end

            for name, carried in pairs(CAUSED) do
                if node.props[name] ~= nil then
                    runtime:dispatch(node.id, name, carried(node))
                    runtime:commit()
                end
            end
        end
    end

    runtime:commit()
end

-- Every demo renders on its own, and then everything on it is used, so a failure names the one that
-- broke and the thing that broke it.
--
-- Every press and every change a reader can make is made here. What a screen does when it is used is
-- where one actually fails, and a case that only renders it sees none of that.
do
    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local renderer = gui.headless()
            local said = {}
            local ok, runtime = pcall(start, gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) },
                renderer, function(problem) said[#said + 1] = problem end)

            assert(ok, group.title .. " / " .. demo.title .. " failed to render: " .. tostring(runtime))

            drive(runtime, renderer, group.title .. " / " .. demo.title)

            assert(#said == 0, group.title .. " / " .. demo.title .. " reported "
                .. #said .. " problems while it was used:\n  " .. table.concat(said, "\n  "))

            for _, node in pairs(renderer.nodes) do
                DRAWN[node.type] = true
            end

            runtime:stop()
        end
    end
end

-- Nothing on a demo is invisible for want of a size, which is what a component with no size would be.
do
    -- A box may be empty, and a sound and a fix are never seen at all, since what a reader sees of
    -- either is drawn by the tree that asked for it.
    local ALLOWED = {
        spacer = true, view = true, scroll = true, safearea = true, keyboardavoiding = true,
        list = true, sectionlist = true, grid = true, carousel = true, pressable = true,
        audio = true, location = true,
    }

    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local runtime, renderer = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) })

            for _, node in pairs(renderer.nodes) do
                local frame = node.frame
                local hidden = node.props.visible == false or node.props.open == false

                if frame ~= nil and not ALLOWED[node.type] and not hidden then
                    assert(frame.width > 0 and frame.height > 0,
                        demo.title .. ": a " .. node.type .. " measured " .. frame.width .. "x" .. frame.height
                            .. ", so nothing of it would be seen")
                end
            end

            runtime:stop()
        end
    end
end

-- The platform changing its appearance repaints the tree, which is what following the system means.
do
    local runtime, renderer = start(app.root)
    local before = #renderer.batches

    runtime:setAppearance("dark")
    runtime:commit()

    assert(#renderer.batches > before, "the platform turning dark must reach the renderer")

    local dark = gui.color.toHex(gui.theme.dark():color("surface"))
    local painted = false

    for _, node in pairs(renderer.nodes) do
        if node.props.style ~= nil and node.props.style.background == dark then
            painted = true
        end
    end

    assert(painted, "the gallery must repaint against the dark theme")
end

-- A render that changed nothing sends nothing, which is what keeps a screen answering while it is used.
do
    local runtime, renderer = start(app.root)
    local before = #renderer.batches

    runtime:markDirty(runtime.root)
    runtime:commit()

    assert(#renderer.batches == before, "re-rendering the same tree must reach the renderer with nothing")
end

-- The long list realises a bounded number of cells however long the data is.
do
    local demo = catalogue.find("lists", "long")
    assert(demo ~= nil, "the long list must be in the gallery")

    local runtime, renderer = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) })
    local lists = renderer:findAll("list")

    assert(#lists == 1, "the demo must carry one list")
    assert(lists[1].props.itemCount == 50000, "the list must know how long the data is")
    assert(lists[1].props.recycle == true, "the list must reuse its cells")
    assert(#lists[1].children < 60, "only what can be seen, plus a margin, may be realised")

    runtime:stop()
end

-- Turning the phone keeps everything a reader had put into the screen.
--
-- The gallery rendered a split where there was room for both and a stack where there was not, which is
-- two different trees: a turn of the device crossed between them and every component under either was
-- taken down and built again. A reader lost what they had typed for having held the phone sideways.
do
    local runtime, renderer = start(app.root)

    runtime.root.instance:setState({ open = { group = "inputs", item = "fields" } })
    runtime:commit()

    local field = renderer:findAll("textinput")[1]

    assert(field ~= nil, "the demo must carry a field to type into")
    field.props.onChange("typed by a reader")

    for _ = 1, 4 do
        runtime:commit()
    end

    runtime:resize(844, 390)

    for _ = 1, 6 do
        runtime:commit()
    end

    local after = renderer:findAll("textinput")[1]

    assert(after ~= nil, "the demo must still be on screen after the phone was turned")
    assert(after.props.value == "typed by a reader",
        "and still hold what was typed into it, holds " .. tostring(after.props.value))

    runtime:stop()
end

-- What the picker demo does with a chosen file is run rather than read.
--
-- The demo wrote it with `fs.mkdtemp`, which makes a directory beside wherever the process was started.
-- That is writable on a desktop and is not on a phone, so it worked in this suite and failed on the
-- device: the screen showed `attempt to concatenate a nil value (local 'folder')` and nothing was kept.
-- Running the demo's own code is what tells the difference.
do
    local async = require("async")
    local crypto = require("crypto")
    local fs = require("fs")
    local storage = require("gui.host.storage")

    storage.use(os.getenv("VARN_TEST_DIR") .. "/demo-files")

    M.picking = function()
        local demo = catalogue.find("inputs", "pickers")
        local renderer = gui.headless()
        local runtime = gui.start(gui.View { style = { grow = 1 }, demo.render() }, renderer,
            { size = { width = 390, height = 844 } })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        local picker = nil

        for _, node in pairs(runtime.byId) do
            if node.type == "filepicker" and node.props.onPick ~= nil then
                picker = node
            end
        end

        assert(picker ~= nil, "the demo must carry a picker")

        local original = "the bytes of a picture"

        -- Each is reported on its own, as soon as it has been read.
        picker.props.onPick({ name = "one.png", size = #original, type = "image/png",
            bytes = crypto.base64Encode(original) })
        picker.props.onPick({ name = "huge.mov", size = 900000000, type = "video/quicktime" })

        -- What the demo does with it is asked for later, so the loop is given a turn to do it in.
        async.sleep(20):await()

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        local pictures = renderer:findAll("image")

        assert(#pictures == 1, "the picture among what was chosen is shown, found " .. #pictures)
        assert(pictures[1].props.source:sub(1, 1) == "/",
            "from the file it was written to, which is somewhere absolute, is " .. pictures[1].props.source)
        assert(fs.exists(pictures[1].props.source), "and the file is really there")
        assert(fs.readFile(pictures[1].props.source):await() == original,
            "holding what was chosen, byte for byte")

        local said = {}

        for _, node in pairs(renderer.nodes) do
            if node.type == "text" and node.props.text ~= nil then
                said[#said + 1] = node.props.text
            end
        end

        local shown = table.concat(said, "\n")

        assert(shown:find("one.png", 1, true) ~= nil, "the demo names what was chosen, showing\n" .. shown)
        assert(shown:find("too large to read", 1, true) ~= nil, "and says which of it was not read")

        runtime:stop()
    end
end

-- Every component the library exposes appears somewhere in the gallery, so nothing ships without one.
do
    local fs = require("fs")
    local async = require("async")

    async.run(function()
        M.picking()

        local sources = { fs.readFile("sample/app.lua"):await(), fs.readFile("sample/parts.lua"):await() }

        for _, folder in ipairs({ "sample/demos", "sample/apps" }) do
            local names = fs.readdir(folder):await()

            for index = 1, #names do
                sources[#sources + 1] = fs.readFile(folder .. "/" .. names[index]):await()
            end
        end

        local text = table.concat(sources, "\n")
        local missing = {}
        local components = gui.components()

        for index = 1, #components do
            if not text:find("gui." .. components[index] .. " ", 1, true)
                and not text:find("gui." .. components[index] .. "{", 1, true)
                and not text:find("gui." .. components[index] .. "(", 1, true) then
                missing[#missing + 1] = components[index]
            end
        end

        assert(#missing == 0, "the gallery shows no example of " .. table.concat(missing, ", "))

        -- Written into a demo is not the same as drawn by one: a player was declared in a file the
        -- gallery loads and put into no screen at all, and naming it in the source was enough to pass.
        local undrawn = {}

        for index = 1, #components do
            local declaration = support.declarations[gui[components[index]]]

            if declaration ~= nil and declaration.host and not DRAWN[declaration.kind] then
                undrawn[#undrawn + 1] = components[index]
            end
        end

        assert(#undrawn == 0, "the gallery draws no " .. table.concat(undrawn, ", "))
        assert(#components == 61, "the library exposes " .. #components .. " components")

        print("gui.sample ok")
    end)
end
