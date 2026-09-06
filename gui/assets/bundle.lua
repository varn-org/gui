local fs = require("fs")
local zip = require("zip")
local crypto = require("crypto")

local M = {}

local Bundle = {}
Bundle.__index = Bundle

local MARKER = ".varn-gui-complete"

local function join(...)
    return table.concat({ ... }, "/")
end

--- Answers the path an asset of the given kind and name expands to.
function Bundle:path(kind, name)
    local resolved = join(self.root, "assets", kind, name)
    if not fs.exists(resolved) then
        error("the bundle carries no " .. kind .. " named " .. name, 2)
    end

    return resolved
end

--- Answers the path of an image, choosing the density variant that suits the scale.
---
--- A renderer drawing at two or three times asks for the variant it wants, and the plain name is the
--- answer when the bundle carries no variant for that scale.
function Bundle:image(name, scale)
    scale = math.floor(scale or 1)

    for candidate = scale, 2, -1 do
        local suffix = name:gsub("(%.%w+)$", "@" .. candidate .. "x%1")
        local resolved = join(self.root, "assets", "images", suffix)

        if fs.exists(resolved) then
            return resolved
        end
    end

    return self:path("images", name)
end

--- Answers every font the manifest declares, as family and path pairs a renderer registers.
function Bundle:fonts()
    local fonts = {}

    for index = 1, #(self.manifest.fonts or {}) do
        local entry = self.manifest.fonts[index]
        fonts[index] = {
            family = entry.family,
            weight = entry.weight,
            style = entry.style,
            path = self:path("fonts", entry.file),
        }
    end

    return fonts
end

--- Answers the source of the entry point the manifest names.
function Bundle:entry()
    local path = join(self.root, self.manifest.entry or "app.lua")
    if not fs.exists(path) then
        error("the manifest names an entry point the bundle does not carry: " .. tostring(self.manifest.entry), 2)
    end

    return path
end

local function readManifest(root)
    local path = join(root, "manifest.lua")
    if not fs.exists(path) then
        error("the archive carries no manifest.lua", 0)
    end

    local chunk, problem = loadfile(path, "t", {})
    if chunk == nil then
        error("the manifest could not be read: " .. tostring(problem), 0)
    end

    local ok, manifest = pcall(chunk)
    if not ok or type(manifest) ~= "table" then
        error("the manifest must answer a table", 0)
    end

    if manifest.identifier == nil then
        error("the manifest needs an identifier", 0)
    end

    return manifest
end

--- Expands an archive into a cache keyed by its bytes, answering the bundle that reads it.
---
--- A second launch finds the cache and skips the work. A cache that was written only in part carries
--- no completion marker, so it is discarded and rebuilt rather than trusted.
function M.open(archive, cacheRoot)
    if not fs.exists(archive) then
        error("no archive at " .. archive, 2)
    end

    local bytes = fs.readFile(archive):await()
    local digest = crypto.digest("SHA256", bytes)
    local root = join(cacheRoot, digest:sub(1, 32))

    if not fs.exists(join(root, MARKER)) then
        if fs.exists(root) then
            fs.removeRecursive(root):await()
        end

        zip.extract(archive, root):await()
        fs.writeFile(join(root, MARKER), digest):await()
    end

    return setmetatable({
        archive = archive,
        root = root,
        digest = digest,
        manifest = readManifest(root),
    }, Bundle)
end

--- Opens a project directory directly, which is what a development loop wants instead of packing first.
function M.openDirectory(root)
    if not fs.exists(join(root, "manifest.lua")) then
        error("no manifest.lua under " .. root, 2)
    end

    return setmetatable({
        archive = nil,
        root = root,
        digest = nil,
        manifest = readManifest(root),
    }, Bundle)
end

M.marker = MARKER

return M
