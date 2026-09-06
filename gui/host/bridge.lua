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

--- Reaches a node imperatively, which is what a ref calls through.
function Bridge:invoke(id, method, arguments)
    return host.gui_invoke({ id = id, method = method, arguments = arguments })
end

--- Answers whether the host can do the named thing, which a component checks before asking for it.
function Bridge:can(capability)
    return self.capabilities[capability] == true
end

--- Refuses loudly when a component needs something this host has no answer for.
function Bridge:require(capability, who)
    if self:can(capability) then
        return
    end

    error(who .. " needs " .. capability .. ", which this renderer does not provide", 0)
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
        theme = options.theme,
        assets = options.assets,
        onProblem = options.onProblem,

        -- A commit is posted to the loop the host already polls, so nothing has to tick across the bridge.
        arrange = function(runtimeToCommit)
            async.spawn(function() runtimeToCommit:commit() end)
        end,
    })

    host.on("gui.event", function(event)
        app:dispatch(event.id, event.name, event.payload)
        app:commit()
    end)

    host.on("gui.resize", function(size)
        app:resize(size.width, size.height)

        if size.safeArea ~= nil then
            app:setInsets(size.safeArea)
        end

        if size.appearance ~= nil then
            app:setAppearance(size.appearance)
        end

        app:commit()
    end)

    host.on("gui.appearance", function(event)
        app:setAppearance(event.appearance)
        app:commit()
    end)

    host.on("gui.insets", function(insets)
        app:setInsets(insets)
        app:commit()
    end)

    host.on("gui.keyboard", function(event)
        app:setKeyboard(event.height or 0)
        app:commit()
    end)

    host.on("gui.fontsRegistered", function()
        app:invalidateMeasurements()
        app:commit()
    end)

    return app
end

return M
