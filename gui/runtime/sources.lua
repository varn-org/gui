local reads = require("gui.runtime.reads")

--- Where a picture comes from, which is the one thing between a name a screen wrote and a file a
--- renderer can open.
return function(Runtime)

--- Answers whether a source names something outside the bundle rather than a file inside it.
---
--- A name in the bundle is a name and nothing more, so anything carrying a scheme or standing at the root
--- of a filesystem is somewhere else: what a camera wrote, what a chooser answered, a picture on the web.
--- Matching a scheme only when it was followed by two slashes left every other one — the `blob:` a page
--- captures into, a `file:` a platform hands back — read as the name of a picture nobody bundled.
local function elsewhere(source)
    return source:find("^%a[%w+.-]*:") ~= nil or source:find("^/") ~= nil
end

--- Answers whether a source is one the engine fetches itself rather than one a platform can open.
---
--- A phone hands an `https://` string to its image view and quietly draws nothing, so the engine fetches
--- those once and answers a local file. Everything else with a scheme is already something the platform
--- opens, and fetching it would be the engine downloading what it is already holding.
local function fetchable(source)
    return source:find("^https?://") ~= nil
end

--- Answers the path an asset name expands to, which is what a renderer can actually open.
---
--- A screen names the file it wants and nothing else, so the density variant, the cache the archive was
--- expanded into and the shape of that path are the runtime's business rather than every screen's. A
--- picture from somewhere else is fetched once and answered as a local file, since a phone hands an
--- `https://` string to its image view and quietly draws nothing.
function Runtime:assetPath(source)
    if fetchable(source) then
        return self:fetched(source)
    end

    if elsewhere(source) then
        return source
    end

    if self.assets == nil then
        return source
    end

    local ok, resolved = pcall(self.assets.image, self.assets, source, self.environment.scale)

    if not ok then
        error("the bundle carries no image named " .. source, 0)
    end

    return self:openable(resolved)
end

--- Answers the path of a picture that is used at its own pixels, which is the file the caller named.
function Runtime:pixelPath(source)
    if fetchable(source) then
        return self:fetched(source)
    end

    if elsewhere(source) then
        return source
    end

    if self.assets == nil then
        return source
    end

    local ok, resolved = pcall(self.assets.image, self.assets, source, 1)

    if not ok then
        error("the bundle carries no image named " .. source, 0)
    end

    return self:openable(resolved)
end

--- Answers what a player is given for a source, which is a file in the bundle or the address itself.
function Runtime:streamPath(source)
    if elsewhere(source) then
        return source
    end

    if self.assets == nil then
        return source
    end

    local ok, resolved = pcall(self.assets.path, self.assets, "media", source)

    if not ok then
        error("the bundle carries no media named " .. source, 0)
    end

    return self:openable(resolved)
end

--- Answers where a picture from somewhere else landed, or nothing at all while it is still on its way.
function Runtime:fetched(source)
    if self.pictures == nil or source:find("^data:") ~= nil or source:find("^/") ~= nil then
        return source
    end

    local landed = self.pictures:fetch(source)

    if landed == nil then
        return nil
    end

    return self:openable(landed)
end

--- Answers a picture in the shape the renderer said it wants, which is a path unless it asked for bytes.
---
--- A browser cannot open a file inside the engine's own filesystem, so it declares that it wants the
--- bytes the way it already declares it wants a font's, and is handed a data URI instead of a name.
function Runtime:openable(path)
    if not self.wantsImageBytes or self.pictures == nil then
        return path
    end

    return self.pictures:bytes(path)
end

--- Sends every picture again, which is what a fetch landing means for whatever was waiting on it.
---
--- A source that had not arrived was sent as its placeholder, so the tree has to be told again once it
--- has. Nothing else about the tree changed, so this is a restyle rather than a render.
function Runtime:invalidatePictures(url, ok)
    if self.stopped then
        return
    end

    -- A picture that never arrived changes nothing on screen, since what is drawn is already the
    -- placeholder, and repainting for it would ask for it again and repaint again for that answer too.
    if ok then
        self.repainting = true
        self:schedule()
    end

    self:reportPicture(url, ok)
end

--- Tells whatever was waiting on a picture that it arrived, or that it never will.
---
--- The engine is what fetches it, so the engine is what knows. A renderer that reported this itself
--- would report it three different ways, and two of them never reported it at all.
function Runtime:reportPicture(url, ok)
    if url == nil then
        return
    end

    local name = ok and "onLoad" or "onError"

    for _, node in pairs(self.byId) do
        if node.type == "image" and node.props.source == url and type(node.props[name]) == "function" then
            self:runHandler(name, node.props[name])
        end
    end
end

--- Sends every picture again, so one that has just been fetched reaches the screen it was asked for by.
---
--- A source that had not landed was sent as its placeholder, and a restyle sends styles rather than
--- props, so the picture only ever appeared the next time the application was opened: the run that
--- fetched it never showed it.
function Runtime:repaintPictures(ops)
    for id, node in pairs(self.byId) do
        local assets = reads.assets[node.type]
        local pixels = reads.pixels[node.type]

        if assets ~= nil then
            local resolved = {}

            for name in pairs(assets) do
                if type(node.props[name]) == "string" then
                    resolved[name] = self:assetPath(node.props[name])
                end
            end

            if resolved.source == nil and node.props.source ~= nil then
                resolved.source = resolved.placeholder
            end

            if next(resolved) ~= nil then
                ops[#ops + 1] = { op = "update", id = id, props = resolved }
            end
        end

        if pixels ~= nil then
            local resolved = {}

            for name in pairs(pixels) do
                if type(node.props[name]) == "string" then
                    resolved[name] = self:pixelPath(node.props[name])
                end
            end

            for name in pairs(reads.pixelSets[node.type] or {}) do
                if type(node.props[name]) == "table" then
                    resolved[name] = self:pixelPaths(node.props[name])
                end
            end

            if next(resolved) ~= nil then
                ops[#ops + 1] = { op = "update", id = id, props = resolved }
            end
        end
    end
end

--- Answers a set of pictures with every name in it resolved, which is what a source per state is.
function Runtime:pixelPaths(given)
    local resolved = {}

    for state, source in pairs(given) do
        if type(source) == "string" then
            resolved[state] = self:pixelPath(source)
        end
    end

    return resolved
end

end
