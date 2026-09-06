local async = require("async")
local bundle = require("gui.assets.bundle")
local bridge = require("gui.host.bridge")
local crypto = require("crypto")
local element = require("gui.element")
local fs = require("fs")

local M = {}

--- Answers the description an application answers, refusing anything that is not one.
---
--- An entry point answers an element, a function that builds one, or a table carrying it as `root`.
--- Anything else is refused here rather than mounted as a node with no children.
local function describe(entry, application)
    if type(application) == "function" then
        application = application()
    end

    if type(application) == "table" and not element.isElement(application) and application.root ~= nil then
        application = application.root
    end

    if not element.isElement(application) then
        error(entry .. " must answer an element, a function that builds one, or a table carrying it as root", 0)
    end

    return application
end

--- Loads a project and runs it against the host, which is what a sample application launches through.
---
--- The archive is expanded once into the cache, its fonts are registered before the first layout so
--- nothing is measured in a font it is not drawn in, and the entry point the manifest names is the
--- only Lua the host has to know about.
function M.run(path, options)
    options = options or {}

    local project = options.directory and bundle.openDirectory(path) or bundle.open(path, options.cache)
    local entry = project:entry()

    package.path = project.root .. "/?.lua;" .. project.root .. "/?/init.lua;" .. package.path

    local chunk, problem = loadfile(entry, "t")
    if chunk == nil then
        error("the entry point could not be read: " .. tostring(problem), 0)
    end

    local application = describe(entry, chunk())

    local runtime = bridge.run(application, {
        fonts = project:fonts(),
        theme = options.theme,
        assets = project,
        onProblem = options.onProblem,
    })

    runtime.bundle = project
    return runtime
end

--- Takes the archive from the host rather than from a path, and runs it.
---
--- A host that shares no filesystem with the engine hands the bytes over instead, which is what the
--- browser does. The archive is written into the engine's own filesystem once and opened from there,
--- so everything after this point is the same as launching from a path.
function M.receive(options)
    options = options or {}

    if host == nil or host.gui_archive == nil then
        error("the host registered no gui_archive, so there is no application to run", 0)
    end

    local handed = host.gui_archive()

    if type(handed) ~= "table" or type(handed.bytes) ~= "string" then
        error("gui_archive must answer a table carrying the archive as base64 bytes", 0)
    end

    local path = options.path or "/" .. (handed.name or "application.vap")
    fs.writeFile(path, crypto.base64Decode(handed.bytes)):await()

    return M.run(path, options)
end

--- Starts an application, which is the one call a host makes after it has registered its bridge.
---
--- Opening a project reads files, so the work runs on a coroutine the host's own loop drives rather
--- than blocking the thread that owns the interface. The archive comes from `path` when the host
--- shares a filesystem with the engine, and from `gui_archive` when it does not.
function M.start(options)
    options = options or {}

    -- Opening runs on a coroutine, so a failure there reaches the engine's log and nowhere a reader can
    -- see. The host is told instead, since it has a screen and the log does not.
    async.run(function()
        local ok, answer = pcall(function()
            if options.path ~= nil then
                return M.run(options.path, options)
            end

            return M.receive(options)
        end)

        if not ok then
            if options.onProblem == nil then
                error(answer, 0)
            end

            options.onProblem(tostring(answer))
            return
        end

        if options.onReady ~= nil then
            options.onReady(answer)
        end
    end)
end

return M
