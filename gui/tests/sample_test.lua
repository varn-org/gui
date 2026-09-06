local gui = require("gui")

-- The sample is loaded the way a host loads it, with its own root on the path.
package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local app = require("app")
local catalogue = require("catalogue")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
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
    assert(#renderer:findAll("sectionlist") == 0, "the index gives up the screen while a demo has it")

    instance:setState({ open = gui.none })
    runtime:commit()

    assert(#renderer:findAll("sectionlist") == 1, "going back brings the index with it")
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
    local painted = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "safearea" and node.props.style ~= nil then
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
            end)

            assert(ok, group.title .. " / " .. demo.title .. " failed against the bundle: " .. tostring(message))
        end
    end
end

-- Every demo renders on its own, so a failure names the one that broke.
do
    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local ok, message = pcall(start, gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) })

            assert(ok, group.title .. " / " .. demo.title .. " failed to render: " .. tostring(message))
        end
    end
end

-- Nothing on a demo is invisible for want of a size, which is what a component with no size would be.
do
    local ALLOWED = {
        spacer = true, view = true, scroll = true, safearea = true, keyboardavoiding = true,
        list = true, sectionlist = true, grid = true, carousel = true, pressable = true,
    }

    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local _, renderer = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) })

            for _, node in pairs(renderer.nodes) do
                local frame = node.frame
                local hidden = node.props.visible == false or node.props.open == false

                if frame ~= nil and not ALLOWED[node.type] and not hidden then
                    assert(frame.width > 0 and frame.height > 0,
                        demo.title .. ": a " .. node.type .. " measured " .. frame.width .. "x" .. frame.height
                            .. ", so nothing of it would be seen")
                end
            end
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

    local dark = gui.theme.dark():color("surface")
    local painted = false

    for _, node in pairs(renderer.nodes) do
        if node.type == "safearea" and node.props.style ~= nil and node.props.style.background == dark then
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

    local _, renderer = start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) })
    local lists = renderer:findAll("list")

    assert(#lists == 1, "the demo must carry one list")
    assert(lists[1].props.itemCount == 50000, "the list must know how long the data is")
    assert(lists[1].props.recycle == true, "the list must reuse its cells")
    assert(#lists[1].children < 60, "only what can be seen, plus a margin, may be realised")
end

-- Every component the library exposes appears somewhere in the gallery, so nothing ships without one.
do
    local fs = require("fs")
    local async = require("async")

    async.run(function()
        local sources = { fs.readFile("sample/app.lua"):await(), fs.readFile("sample/parts.lua"):await() }
        local names = fs.readdir("sample/demos"):await()

        for index = 1, #names do
            sources[#sources + 1] = fs.readFile("sample/demos/" .. names[index]):await()
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
        assert(#components == 55, "the library exposes " .. #components .. " components")

        print("gui.sample ok")
    end)
end
