local async = require("async")
local fs = require("fs")
local gui = require("gui")
local bundle = require("gui.assets.bundle")
local natural = require("gui.layout.natural")

local ROOT = assert(os.getenv("VARN_TEST_DIR"), "VARN_TEST_DIR is not set")

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

local function refused(build, says)
    local ok, problem = pcall(build)

    assert(not ok, "must be refused: " .. says)
    assert(tostring(problem):find(says, 1, true) ~= nil,
        "the refusal must say " .. says .. ", said " .. tostring(problem))
end

async.run(function()
    -- One number cuts all four edges, and the renderer is never handed the shorthand.
    --
    -- A shorthand each renderer reads for itself is three chances to read it differently, so it is written
    -- the one way here and crosses as four numbers whichever way it was asked for.
    do
        local _, renderer = start(gui.NineSlice { source = "panel.png", slice = 12 })
        local slice = renderer:find("nineslice").props.slice

        assert(type(slice) == "table", "a slice crosses as four numbers, got a " .. type(slice))
        assert(slice.top == 12 and slice.right == 12 and slice.bottom == 12 and slice.left == 12,
            "one number cuts every edge")
    end

    -- Each edge may be cut on its own, which is what a window with a bar across its top needs.
    do
        local _, renderer = start(gui.NineSlice {
            source = "panel.png",
            slice = { top = 40, right = 20, bottom = 16, left = 20 },
        })

        local slice = renderer:find("nineslice").props.slice

        assert(slice.top == 40 and slice.right == 20 and slice.bottom == 16 and slice.left == 20,
            "the four edges cross as they were written")
    end

    -- What cannot be drawn is refused where it was written rather than drawn as nothing.
    do
        refused(function() return gui.NineSlice { slice = 8 } end, "needs a source")
        refused(function() return gui.NineSlice { source = "panel.png" } end, "needs a slice")

        refused(function() return gui.NineSlice { source = "panel.png", slice = { top = 8, right = 8 } } end,
            "needs a slice")

        refused(function() return gui.NineSlice { source = "panel.png", slice = -4 } end,
            "whole number of pixels")

        refused(function() return gui.NineSlice { source = "panel.png", slice = 2.5 } end,
            "whole number of pixels")

        refused(function() return gui.NineSlice { source = "panel.png", slice = 8, sliceScale = 0 } end,
            "above nothing")
    end

    -- A frame is worth at least the two corners it is cut at, since narrower than that it cannot be drawn.
    --
    -- The corners would overlap and what comes out is not the picture, so the minimum is not a number fixed
    -- for the type but one worked out from the cuts the node was given.
    do
        local least = natural.sizeOf("nineslice", { slice = { top = 10, right = 6, bottom = 14, left = 6 }, sliceScale = 1 })

        assert(least.minWidth == 12, "a frame is at least its two side cuts wide, got " .. tostring(least.minWidth))
        assert(least.minHeight == 24, "and its two end cuts tall, got " .. tostring(least.minHeight))

        local drawn = natural.sizeOf("nineslice", { slice = { top = 10, right = 6, bottom = 14, left = 6 }, sliceScale = 3 })

        assert(drawn.minWidth == 36, "drawn larger, the minimum grows with it, got " .. tostring(drawn.minWidth))
    end

    -- A frame narrower than its corners is laid out at the width it needs rather than at the one it was told.
    do
        local _, renderer = start(gui.View {
            style = { width = 200, height = 200 },
            gui.NineSlice { source = "panel.png", slice = 30, sliceScale = 2, style = { width = 20, height = 20 } },
        })

        local frame = renderer:find("nineslice")

        assert(frame.frame.width == 120, "the frame is as wide as its corners, got " .. tostring(frame.frame.width))
        assert(frame.frame.height == 120, "and as tall, got " .. tostring(frame.frame.height))
    end

    -- The picture a frame is cut from is the one that was named, never a denser variant of it.
    --
    -- The cuts point at that file's own pixels, so handing over an `@2x` twice the size would cut it at the
    -- same four numbers and every corner would come out half the width it was drawn at.
    do
        local project = ROOT .. "/framed"

        fs.mkdir(project .. "/assets/images"):await()
        fs.writeFile(project .. "/manifest.lua", "return { identifier = 'd.v.framed', version = '1.0.0' }"):await()
        fs.writeFile(project .. "/assets/images/panel.png", "the picture itself"):await()
        fs.writeFile(project .. "/assets/images/panel@2x.png", "twice the size"):await()
        fs.writeFile(project .. "/assets/images/badge.png", "a picture"):await()
        fs.writeFile(project .. "/assets/images/badge@2x.png", "twice the size"):await()

        local opened = bundle.openDirectory(project)

        local _, renderer = start(gui.View {
            gui.NineSlice { source = "panel.png", slice = 8 },
            gui.Image { source = "badge.png", style = { width = 40, height = 40 } },
        }, { assets = opened, scale = 2 })

        local frame = renderer:find("nineslice").props.source
        local picture = renderer:find("image").props.source

        assert(frame:find("panel.png", 1, true) ~= nil and frame:find("@2x", 1, true) == nil,
            "a frame is cut from the picture it named, got " .. frame)
        assert(picture:find("badge@2x.png", 1, true) ~= nil,
            "while a picture still takes the variant the surface is worth, got " .. picture)
    end

    -- A frame carries artwork per state, and each of those is cut from its own picture rather than a variant.
    --
    -- A frame is how a button is drawn from artwork, and a button is a different picture while a finger
    -- is on it, so the picture for each state is named the way the plain one is and resolved the same
    -- way — a denser variant would be cut at the same four numbers and come out half the width.
    do
        local project = ROOT .. "/stated"

        fs.mkdir(project .. "/assets/images"):await()
        fs.writeFile(project .. "/manifest.lua", "return { identifier = 'd.v.stated', version = '1.0.0' }"):await()

        for _, name in ipairs({ "plate", "plate-down", "plate-off" }) do
            fs.writeFile(project .. "/assets/images/" .. name .. ".png", "the picture itself"):await()
            fs.writeFile(project .. "/assets/images/" .. name .. "@2x.png", "twice the size"):await()
        end

        local _, renderer = start(gui.NineSlice {
            source = "plate.png",
            sources = { pressed = "plate-down.png", disabled = "plate-off.png" },
            slice = 8,
        }, { assets = bundle.openDirectory(project), scale = 2 })

        local held = renderer:find("nineslice").props.sources

        assert(type(held) == "table", "the artwork per state crosses as a table, got a " .. type(held))
        assert(held.pressed:find("plate-down.png", 1, true) ~= nil and held.pressed:find("@2x", 1, true) == nil,
            "a state is cut from the picture it named, got " .. tostring(held.pressed))
        assert(held.disabled:find("plate-off.png", 1, true) ~= nil,
            "and every state named is resolved, got " .. tostring(held.disabled))
        assert(held.hovered == nil, "a state with no artwork of its own is not invented")
    end

    -- A frame that names artwork for a state nobody has is refused where it was written.
    do
        refused(function()
            return gui.NineSlice { source = "panel.png", slice = 8, sources = { sideways = "no.png" } }
        end, "sideways")

        refused(function()
            return gui.NineSlice { source = "panel.png", slice = 8, sources = { pressed = 12 } }
        end, "sources.pressed")

        refused(function()
            return gui.NineSlice { source = "panel.png", slice = 8, sources = "one.png" }
        end, "sources names a picture per state")
    end

    -- A frame reports both edges of a press, which is what lets a button look pressed while it is.
    --
    -- A press is reported when the finger lifts, so a frame that only had that went down as it was let
    -- go: the whole of the animation happened after the press was over. A button drawn from artwork is
    -- the reason this component exists, and one that cannot show it is being held is not a button.
    do
        local told = {}
        local runtime, renderer = start(gui.NineSlice {
            source = "panel.png",
            slice = 8,
            onPressIn = function() told[#told + 1] = "in" end,
            onPressOut = function() told[#told + 1] = "out" end,
            onPress = function() told[#told + 1] = "press" end,
        })

        local frame = renderer:find("nineslice")

        runtime:dispatch(frame.id, "onPressIn", nil)
        runtime:dispatch(frame.id, "onPressOut", nil)
        runtime:dispatch(frame.id, "onPress", nil)

        assert(table.concat(told, ",") == "in,out,press",
            "a frame hears the finger land, lift and count, heard " .. table.concat(told, ","))
    end

    -- The cuts the sample writes are the cuts the artwork was drawn for.
    --
    -- A picture and the four numbers it is cut at belong together and live apart: the numbers are in the
    -- screen that draws the frame and the picture is drawn by a script that has to know them to check
    -- its own work. Two places holding the same four numbers agree with nothing unless something says
    -- so, and what a disagreement looks like is ornament pulled out of shape on a device.
    do
        local demo = fs.readFile("sample/demos/frames.lua"):await()
        local script = fs.readFile("tools/draw-frames.py"):await()

        local written = {}

        for source, slice in demo:gmatch('source = "([%w%-%.]+)", slice = ([^\n]-),?\n') do
            written[source] = slice:gsub("%s+", ""):gsub("[,}]+$", "}"):gsub("^([^{])[,}]*$", "%1")
        end

        assert(next(written) ~= nil, "the demo must name the pictures it cuts")

        for source in pairs(written) do
            assert(script:find('"' .. source .. '"', 1, true) ~= nil,
                "the sample cuts " .. source .. " and tools/draw-frames.py never draws it")
        end

        -- The one cut unevenly is the one worth naming, since it is the one a reader would get wrong.
        assert(written["window-titled.png"] == "{top=46,right=28,bottom=28,left=28}",
            "the titled window is cut deeper along its top, the demo says " .. tostring(written["window-titled.png"]))
        assert(script:find("(46, 28, 28, 28)", 1, true) ~= nil,
            "and the script that draws it must check itself against those same four numbers")
    end

    print("gui.nineslice ok")
end)
