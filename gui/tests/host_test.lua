local async = require("async")
local fs = require("fs")
local zip = require("zip")
local gui = require("gui")
local bridge = require("gui.host.bridge")
local launch = require("gui.host.launch")

local scratch = assert(os.getenv("VARN_TEST_DIR"), "VARN_TEST_DIR is not set")

--- Stands in for a platform, recording what crossed the bridge and reporting what a device would.
local function platform(options)
    options = options or {}

    local recorder = {
        batches = {},
        fonts = {},
        calls = {},
        handlers = {},
        surface = options.surface or {
            width = 390,
            height = 844,
            scale = 3,
            safeArea = { top = 47, right = 0, bottom = 34, left = 0 },
        },
    }

    host = {
        gui_apply = function(ops)
            recorder.batches[#recorder.batches + 1] = ops
        end,

        gui_measure = function(request)
            local size = request.style.fontSize or 15
            return { width = #request.text * size * 0.5, height = size * 1.35 }
        end,

        gui_invoke = function(request)
            recorder.calls[#recorder.calls + 1] = request
            return true
        end,

        gui_capabilities = function()
            return options.capabilities or { text = true, image = true, list = true, video = false }
        end,

        gui_surface = function()
            return recorder.surface
        end,

        gui_register_font = function(font)
            recorder.fonts[#recorder.fonts + 1] = font
        end,

        on = function(name, handler)
            recorder.handlers[name] = handler
        end,
    }

    return recorder
end

--- Answers every operation of a kind that crossed the bridge, which is what a test reads back.
local function operations(recorder, kind)
    local found = {}

    for index = 1, #recorder.batches do
        local batch = recorder.batches[index]

        for position = 1, #batch do
            if batch[position].op == kind then
                found[#found + 1] = batch[position]
            end
        end
    end

    return found
end

--- Builds a project on disk, answering the archive it packed into.
local function pack(name, files)
    local root = scratch .. "/" .. name
    local entries = {}

    for path, content in pairs(files) do
        local directory = path:match("^(.*)/[^/]+$")
        fs.mkdir(directory ~= nil and root .. "/" .. directory or root):await()
        fs.writeFile(root .. "/" .. path, content):await()
        entries[#entries + 1] = { file = root .. "/" .. path, entry = path }
    end

    local archive = scratch .. "/" .. name .. ".vap"
    zip.create(archive, entries):await()
    return archive
end

async.run(function()
    -- A batch crosses as json, so a handler never travels and the sentinel travels as text.
    do
        local recorder = platform()

        local app = bridge.run(gui.View {
            style = { background = "#101010" },
            gui.Button { title = "Go", onPress = function() end },
        })

        local created = operations(recorder, "create")
        local button = nil

        for index = 1, #created do
            if created[index].type == "button" then
                button = created[index]
            end
        end

        assert(button ~= nil, "the button must have crossed the bridge")
        assert(button.props.onPress == true, "a handler crosses as a marker rather than a function")
        assert(button.props.title == "Go", "a plain prop crosses unchanged")
        assert(app ~= nil)
    end

    -- The insets the host reports on the surface reach the tree before the first layout.
    do
        local recorder = platform()

        local app = bridge.run(gui.SafeArea {
            style = { grow = 1 },
            gui.Text { text = "content" },
        })

        local frames = operations(recorder, "frame")
        local label = nil

        for index = 1, #frames do
            label = frames[index]
        end

        assert(label.y == 47, "the safe area the host reported must already be avoided, got " .. label.y)
        assert(app ~= nil)
    end

    -- The host reports the keyboard, and the tree leaves room for it without asking what platform it is.
    do
        local recorder = platform()

        local app = bridge.run(gui.KeyboardAvoiding {
            style = { grow = 1, justify = "end" },
            gui.TextInput { value = "", style = { height = 44 } },
        })

        local before = #recorder.batches
        recorder.handlers["gui.keyboard"]({ height = 300 })

        assert(#recorder.batches > before, "the keyboard must reach the tree")

        local frames = operations(recorder, "frame")
        local field = frames[#frames]

        assert(field.y == 844 - 300 - 44, "the field must rise clear of the keyboard, got " .. field.y)
        assert(app ~= nil)
    end

    -- An event the host reports reaches the handler the tree declared for that node.
    do
        local recorder = platform()
        local pressed = 0

        bridge.run(gui.Button { title = "Go", onPress = function() pressed = pressed + 1 end })

        local created = operations(recorder, "create")
        local button = created[#created]

        recorder.handlers["gui.event"]({ id = button.id, name = "onPress", payload = {} })
        assert(pressed == 1, "the event must reach the handler on that node")
    end

    -- A resize reaches the layout, which is what a rotation is.
    do
        local recorder = platform()

        bridge.run(gui.View { style = { grow = 1 } })
        recorder.handlers["gui.resize"]({ width = 844, height = 390 })

        local frames = operations(recorder, "frame")
        local last = frames[#frames]

        assert(last.width == 844, "the tree must lay out against the new size")
    end

    -- Registering a font drops the measurements taken before it arrived.
    do
        local recorder = platform()

        local app = bridge.run(gui.Text { text = "measured" })
        local before = #recorder.batches

        recorder.handlers["gui.fontsRegistered"]()
        assert(#recorder.batches > before, "a registered font must relay out what was measured without it")
        assert(app ~= nil)
    end

    -- A project launches from its archive, with its fonts registered before anything is measured.
    do
        local archive = pack("launched", {
            ["manifest.lua"] = [[
return {
    identifier = "dev.varn.gui.launched",
    version = "1.0.0",
    entry = "app.lua",
    fonts = { { family = "Gallery", file = "gallery.ttf", weight = "400" } },
}
]],
            ["app.lua"] = [[
local gui = require("gui")

return function()
    return gui.View {
        style = { grow = 1, background = "#ffffff" },
        gui.Text { text = "packed", style = { fontFamily = "Gallery" } },
    }
end
]],
            ["assets/fonts/gallery.ttf"] = "font bytes",
        })

        local recorder = platform()
        local app = launch.run(archive, { cache = scratch .. "/cache" })

        assert(#recorder.fonts == 1, "the fonts the manifest declares must be registered")
        assert(recorder.fonts[1].family == "Gallery", "a font is registered under the family a style names")
        assert(recorder.fonts[1].path:find("gallery.ttf", 1, true), "the font is registered from the expanded bundle")

        local created = operations(recorder, "create")
        local label = nil

        for index = 1, #created do
            if created[index].type == "text" then
                label = created[index]
            end
        end

        assert(label ~= nil and label.props.text == "packed", "the entry point the manifest names is what ran")
        assert(app.bundle.manifest.identifier == "dev.varn.gui.launched", "the runtime carries the project it ran")
    end

    -- A component asking for something the renderer has no answer for is refused rather than ignored.
    do
        platform({ capabilities = { text = true, video = false } })
        local app = bridge.run(gui.View {})
        local renderer = app.renderer

        assert(renderer:can("text"), "a declared capability is available")
        assert(not renderer:can("video"), "an undeclared capability is not")

        local ok, message = pcall(renderer.require, renderer, "video", "the player screen")
        assert(not ok, "asking for a missing capability must be refused")
        assert(tostring(message):find("video"), "the refusal names what was missing")
    end

    -- Without a host there is nothing to draw on, which is said rather than discovered later.
    do
        host = nil
        local ok, message = pcall(bridge.run, gui.View {})

        assert(not ok, "running with no host must be refused")
        assert(tostring(message):find("no gui host"), "the refusal says what is missing")
    end

    print("gui.host ok")
end)
