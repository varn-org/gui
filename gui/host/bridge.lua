local async = require("async")
local crypto = require("crypto")
local fs = require("fs")
local runtime = require("gui.runtime")
local wire = require("gui.bridge.wire")

local M = {}

local Bridge = {}
Bridge.__index = Bridge

--- Applies a batch by handing it to the host, which is the one call a commit makes.
function Bridge:apply(ops)
    host.gui_apply(wire.encode(ops))
end

--- Asks the host what a string measures, since only the platform knows its own font engine.
function Bridge:measureText(text, style, bound)
    return host.gui_measure({ text = text, style = style, bound = bound })
end

--- Asks the host what it draws a control at, since a control has a size of its own the way a string has.
function Bridge:measureControl(kind)
    return host.gui_measure_control({ type = kind })
end

--- Tells the host what the application is drawn in, which is what it paints its own ground from.
---
--- A page, a window and an activity each draw something around what the tree draws, and none of it is a
--- node: the ground behind the surface, what a selection is drawn in, and the face a control the platform
--- owns writes its own captions in. A dark application on a white page is what leaving it out looks like.
function Bridge:showTheme(ground)
    host.gui_theme(ground)
end

--- Reaches a node imperatively, which is what a ref calls through.
function Bridge:invoke(id, method, arguments)
    return host.gui_invoke({ id = id, method = method, arguments = arguments })
end

--- Tells the host where the application went, which is what keeps a browser's own history in step.
---
--- A phone has nowhere to show an address, so a host that has says so and the rest are never asked.
function Bridge:address(where, mode)
    host.gui_address({ address = where, mode = mode })
end

--- Answers whether the host can do the named thing, which a component checks before asking for it.
function Bridge:can(capability)
    return self.capabilities[capability] == true
end

local function readCapabilities()
    local declared = host.gui_capabilities()
    if type(declared) ~= "table" then
        error("the host declared no capabilities, so a component cannot know what it may ask for", 0)
    end

    return declared
end

--- Registers every font a project carries, so a style may name a family before anything is measured.
---
--- A renderer that shares the engine's filesystem reads the path. One that does not, which is what a
--- browser is, declares `fontBytes` and is handed the file itself.
local function registerFonts(fonts, capabilities)
    for index = 1, #(fonts or {}) do
        local font = fonts[index]

        if capabilities.fontBytes == true then
            font = {
                family = font.family,
                path = font.path,
                weight = font.weight,
                style = font.style,
                bytes = crypto.base64Encode(fs.readFile(font.path):await()),
            }
        end

        local answer = host.gui_register_font(font)

        if type(answer) == "table" and answer.error ~= nil then
            error("the font " .. tostring(font.family) .. " could not be registered: " .. tostring(answer.error), 0)
        end
    end
end

--- Runs work against the tree and reports what fails, which is what an event from the host is given.
---
--- The engine calls a subscription from its own delivery, where an error is written to the engine's log
--- and to nowhere a reader can see. The screen would stop answering with nothing said, so every event
--- that reaches the tree comes back through here.
local function safely(app, what, work)
    local ok, problem = pcall(work)

    if not ok then
        app:report(what .. " failed: " .. tostring(problem))
    end
end

--- Starts a description against the host, wiring the events it reports back into the tree.
---
--- The host owns the run loop and calls poll, so everything a script does lands on the thread that
--- owns the interface. Nothing here dispatches, locks or waits.
function M.run(description, options)
    options = options or {}

    if host == nil or host.gui_apply == nil then
        error("no gui host is registered, so there is nothing to draw on", 0)
    end

    local bridge = setmetatable({ capabilities = readCapabilities() }, Bridge)
    local surface = host.gui_surface()

    registerFonts(options.fonts, bridge.capabilities)

    local app = runtime.start(description, bridge, {
        size = { width = surface.width, height = surface.height },
        insets = surface.safeArea,
        scale = surface.scale,
        appearance = surface.appearance,
        state = surface.state,
        platform = surface.platform,
        address = surface.address,
        theme = options.theme,
        assets = options.assets,
        pictures = options.pictures,
        imageBytes = bridge.capabilities.imageBytes == true,
        onProblem = options.onProblem,

        -- A commit is posted to the loop the host already polls, so nothing has to tick across the bridge.
        --
        -- A render that fails there is on a coroutine of its own, so an error escaping it reaches the
        -- engine's log and nowhere a reader can see, and the screen stops moving with nothing said.
        arrange = function(runtimeToCommit)
            async.spawn(function()
                local ok, problem = pcall(runtimeToCommit.commit, runtimeToCommit)

                if not ok then
                    runtimeToCommit:report("the screen could not be drawn: " .. tostring(problem))
                end
            end)
        end,
    })

    host.on("gui.event", function(event)
        safely(app, "an event from the host", function()
            app:dispatch(event.id, event.name, event.payload)
            app:commit()
        end)
    end)

    host.on("gui.files", function(reply)
        safely(app, "a file the platform answered for", function()
            require("gui.files").answered(reply)
        end)
    end)

    host.on("gui.preferences", function(reply)
        safely(app, "a preference the platform answered for", function()
            require("gui.preferences").answered(reply)
        end)
    end)

    host.on("gui.resize", function(size)
        safely(app, "a resize", function()
            app:resize(size.width, size.height)

            if size.safeArea ~= nil then
                app:setInsets(size.safeArea)
            end

            if size.appearance ~= nil then
                app:setAppearance(size.appearance)
            end

            app:commit()
        end)
    end)

    host.on("gui.address", function(event)
        safely(app, "an address", function()
            app:setAddress(event.address or "/")
            app:commit()
        end)
    end)

    host.on("gui.appearance", function(event)
        safely(app, "an appearance change", function()
            app:setAppearance(event.appearance)
            app:commit()
        end)
    end)

    host.on("gui.lifecycle", function(event)
        safely(app, "a change of state", function()
            app:setLifecycle(event.state)
            app:commit()
        end)
    end)

    host.on("gui.memory", function()
        safely(app, "a warning about memory", function()
            app:giveBack()
        end)
    end)

    host.on("gui.insets", function(insets)
        safely(app, "a safe area change", function()
            app:setInsets(insets)
            app:commit()
        end)
    end)

    host.on("gui.back", function()
        safely(app, "a back press", function() app:goBack() end)
    end)

    host.on("gui.keyboard", function(event)
        safely(app, "a keyboard change", function()
            app:setKeyboard(event.height or 0)
            app:commit()
        end)
    end)

    host.on("gui.fontsRegistered", function()
        safely(app, "a font registration", function()
            app:invalidateMeasurements()
            app:commit()
        end)
    end)

    -- A host that is finished with a surface says so, and the tree comes down: every screen hears it is
    -- going, every timer a screen asked for ends, and everything a node opened is given back.
    host.on("gui.stop", function()
        safely(app, "taking the tree down", function() app:stop() end)
    end)

    return app
end

return M
