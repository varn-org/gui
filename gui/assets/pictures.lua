local async = require("async")
local cache = require("gui.tools.cache")
local crypto = require("crypto")
local fs = require("fs")
local http = require("http")

local M = {}

local Store = {}
Store.__index = Store

--- What each extension is written as when a picture is handed over as bytes rather than as a path.
local TYPES = {
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    webp = "image/webp",
    svg = "image/svg+xml",
}

--- How many redirects a picture is chased through before it is given up on.
local HOPS = 4

--- How many pictures a run remembers having fetched, which is what a feed keeps adding to.
---
--- Each entry is a url and the file it landed in, and the file is still there once one is dropped, so
--- a picture asked for again after that is found on disk rather than fetched a second time.
local KNOWN = 512

--- How many pictures are held as bytes at once, which is what a renderer with no filesystem is handed.
---
--- A data URI is larger than the file it carries, so a gallery of photographs would otherwise hold
--- every picture it has ever shown for as long as the application runs.
local HELD = 24

local function extensionOf(name)
    return (name:match("%.(%w+)$") or "png"):lower()
end

--- Fetches a picture from somewhere else and answers where it landed.
---
--- A phone hands an `https://` string straight to its image view, which quietly draws nothing, so the
--- engine fetches it once with the http client it already has and hands every renderer a local file.
--- One implementation serves all three, and each still only ever loads what it was given.
function Store:fetch(url)
    local held = self.byUrl:get(url)

    if held ~= nil then
        return held
    end

    -- A picture that could not be had stays that way for this run. Asking again would fetch again, and
    -- the answer schedules the repaint that asks again, which is a request and a full commit per round.
    if self.failed:get(url) ~= nil then
        return nil
    end

    local digest = crypto.digest("SHA256", url)
    local path = self.root .. "/" .. digest .. "." .. extensionOf(url)

    if fs.exists(path) then
        self.byUrl:set(url, path)
        return path
    end

    if self.pending[url] then
        return nil
    end

    self.pending[url] = true

    async.spawn(function()
        local ok, answer = pcall(function() return M.get(url) end)

        self.pending[url] = nil

        if not ok or answer == nil then
            self.failed:set(url, true)
            self.onSettled(url, false)
            return
        end

        local written = pcall(function() fs.writeFile(path, answer):await() end)

        if not written then
            self.failed:set(url, true)
            self.onSettled(url, false)
            return
        end

        self.byUrl:set(url, path)
        self.onSettled(url, true)
    end)

    return nil
end

--- Answers the bytes at a url, following the redirects a picture service answers with.
---
--- Every one of them answers a redirect to wherever the file actually is, and the client reports the
--- redirect rather than chasing it, so a fetch that stopped at the first answer read as a failure.
function M.get(url)
    local at = url

    for _ = 1, HOPS do
        local answer = http.client.requestRaw({ url = at }):await()

        if answer.status >= 200 and answer.status < 300 then
            return answer.body
        end

        if answer.status < 300 or answer.status >= 400 then
            return nil
        end

        local moved = nil

        for name, value in pairs(answer.headers or {}) do
            if name:lower() == "location" then
                moved = value
            end
        end

        if moved == nil then
            return nil
        end

        at = moved
    end

    return nil
end

--- Answers a picture as the bytes a renderer that shares no filesystem with the engine has to be handed.
---
--- A browser cannot open a path inside the engine's own filesystem, so it declares that it wants bytes
--- the way it already declares it wants a font's bytes, and is handed a data URI instead of a name.
---
--- Reading the file is asked for here and answered later, since this is reached from the middle of a
--- commit and a commit cannot wait on anything: it holds the tree, and a state change made while it
--- waited would land on a tree that is halfway between two of them.
function Store:bytes(path)
    local held = self.byPath:get(path)

    if held ~= nil then
        return held
    end

    if self.failed:get(path) ~= nil or self.reading[path] then
        return nil
    end

    self.reading[path] = true

    async.spawn(function()
        local ok, body = pcall(function() return fs.readFile(path):await() end)

        self.reading[path] = nil

        if not ok or body == nil then
            self.failed:set(path, true)
            self.onSettled(nil, false)
            return
        end

        local kind = TYPES[extensionOf(path)] or "image/png"

        self.byPath:set(path, "data:" .. kind .. ";base64," .. crypto.base64Encode(body))
        self.onSettled(nil, true)
    end)

    return nil
end

--- Builds the store a runtime resolves pictures through, told where to keep what it fetches.
function M.create(root, onSettled)
    fs.mkdir(root)

    return setmetatable({
        root = root,
        byUrl = cache.create(KNOWN),
        byPath = cache.create(HELD),
        pending = {},
        reading = {},
        failed = cache.create(KNOWN),
        onSettled = onSettled or function() end,
    }, Store)
end

return M
