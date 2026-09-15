local animation = require("gui.style.animation")
local filters = require("gui.style.filter")
local natural = require("gui.layout.natural")
local protocol = require("gui.bridge.protocol")
local reads = require("gui.runtime.reads")
local resolve = require("gui.style.resolve")

--- What a batch carries once the tokens a caller wrote have been turned into values.
---
--- Resolution happens here rather than in the diff, so three renderers cannot disagree about what a
--- spacing step or a theme colour means and none of them carries a theme of its own. A colour, a
--- picture, a filter and a run of stops are each resolved on the way out, and a look that changes sends
--- every one of them again.
return function(Runtime)

--- Answers the look a node is drawn in, which is the application's unless something above it named another.
function Runtime:themeAt(id)
    local node = self.byId[id]

    return node ~= nil and node.wearing or self.theme
end

--- Answers the style a renderer receives, which is concrete values rather than the tokens a caller wrote.
function Runtime:styleOf(style, wearing)
    return resolve.resolve(style, wearing or self.theme, self.breakpoint)
end

--- Answers a list of entries with the style each one carries resolved, leaving the entries themselves alone.
function Runtime:resolveEntries(entries, under, wearing)
    local resolved = {}

    for index = 1, #entries do
        local entry = entries[index]
        local copy = {}

        for key, value in pairs(entry) do
            copy[key] = value
        end

        -- A run is laid over the style of the paragraph it is in, since that is what a run of text in a
        -- sentence is. A browser inherits it and a phone does not, so a run that named a weight and no
        -- colour came out in the paragraph's colour on one and in black on the other, which on a dark
        -- screen is a sentence with a hole in it.
        copy.style = self:styleOf(entry.style, wearing)

        if under ~= nil then
            local laid = {}

            for key, value in pairs(under) do
                laid[key] = value
            end

            for key, value in pairs(copy.style) do
                laid[key] = value
            end

            copy.style = laid
        end

        resolved[index] = copy
    end

    return resolved
end

--- Answers drawing commands with the colour each one carries resolved, leaving the drawing itself alone.
function Runtime:resolvePainted(entries, wearing)
    local resolved = {}

    for index = 1, #entries do
        local entry = entries[index]
        local copy = {}

        for key, value in pairs(entry) do
            copy[key] = value
        end

        if type(entry.color) == "string" then
            copy.color = resolve.paint(entry.color, wearing or self.theme)
        end

        resolved[index] = copy
    end

    return resolved
end

--- Answers the type of the node an operation names, which a create carries and an update does not.
function Runtime:typeOf(op)
    if op.type ~= nil then
        return op.type
    end

    local node = self.byId[op.id]
    return node ~= nil and node.type or nil
end

--- Replaces the tokens a batch carries with the values they resolve to.
---
--- A node is always created with a style, even an empty one, since a renderer that is told nothing
--- leaves its widget at the platform's own defaults and draws at a size the engine never measured.
function Runtime:resolveStyles(ops)
    for index = 1, #ops do
        local op = ops[index]
        local props = op.props

        if props ~= nil then
            local styled = props.style ~= nil or op.op == "create"
            local moves = props.transition ~= nil or props.enter ~= nil
            local touched = styled or moves

            for name in pairs(reads.nested) do
                touched = touched or type(props[name]) == "table"
            end

            for name in pairs(reads.painted) do
                touched = touched or type(props[name]) == "table"
            end

            local kind = self:typeOf(op)
            local assets = reads.assets[kind] or {}
            local pixels = reads.pixels[kind] or {}
            local streamed = reads.streamed[kind] or {}

            for name in pairs(assets) do
                touched = touched or type(props[name]) == "string"
            end

            for name in pairs(pixels) do
                touched = touched or type(props[name]) == "string"
            end

            for name in pairs(reads.pixelSets[kind] or {}) do
                touched = touched or type(props[name]) == "table"
            end

            for name in pairs(streamed) do
                touched = touched or type(props[name]) == "string"
            end

            for name in pairs(reads.tints) do
                touched = touched or type(props[name]) == "string"
            end

            touched = touched or reads.focusing[kind] == true
            touched = touched or natural.scrolling[kind] == true

            for name in pairs(reads.seeing) do
                touched = touched or type(props[name]) == "function"
            end

            touched = touched or type(props[reads.filtered]) == "table"

            for name in pairs(reads.palettes) do
                touched = touched or type(props[name]) == "table"
            end

            if touched then
                local resolved = {}
                local wearing = self:themeAt(op.id)

                for key, value in pairs(props) do
                    resolved[key] = value
                end

                if styled then
                    resolved.style = self:styleOf(props.style, wearing)
                end

                if props.transition ~= nil then
                    resolved.transition = animation.transition(props.transition)
                end

                if props.enter ~= nil then
                    resolved.enter = self:styleOf(props.enter, wearing)
                end

                for name in pairs(reads.nested) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:resolveEntries(props[name], resolved.style, wearing)
                    end
                end

                for name in pairs(reads.painted) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:resolvePainted(props[name], wearing)
                    end
                end

                for name in pairs(assets) do
                    if type(props[name]) == "string" then
                        resolved[name] = self:assetPath(props[name])
                    end
                end

                for name in pairs(pixels) do
                    if type(props[name]) == "string" then
                        resolved[name] = self:pixelPath(props[name])
                    end
                end

                for name in pairs(reads.pixelSets[kind] or {}) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:pixelPaths(props[name])
                    end
                end

                if reads.focusing[kind] then
                    resolved.onFocus = resolved.onFocus or true
                    resolved.onBlur = resolved.onBlur or true
                end

                -- A box says nothing about being seen, since the engine works that out from the frames
                -- it laid out and the offsets it is told. What it needs from the platform is the offset,
                -- which is asked of a surface only while something under it is watching, because a
                -- scroll is reported by the pixel and there is no sense in crossing for nothing.
                for name in pairs(reads.seeing) do
                    resolved[name] = nil
                end

                if natural.scrolling[kind] and self:needsOffset() then
                    resolved.onScroll = resolved.onScroll or true
                end

                for name in pairs(streamed) do
                    if type(props[name]) == "string" then
                        resolved[name] = self:streamPath(props[name])
                    end
                end

                if resolved.source == nil and props.source ~= nil then
                    resolved.source = resolved.placeholder
                end

                for name in pairs(reads.palettes) do
                    if type(props[name]) == "table" then
                        local painted = {}

                        for index = 1, #props[name] do
                            painted[index] = resolve.paint(props[name][index], wearing)
                        end

                        resolved[name] = painted
                    end
                end

                if type(props[reads.filtered]) == "table" then
                    local matrix = filters.matrix(props[reads.filtered])

                    resolved[reads.filtered] = not filters.transparent(matrix) and matrix or protocol.removed
                end

                for name in pairs(reads.tints) do
                    if type(props[name]) == "string" and assets[name] == nil then
                        resolved[name] = resolve.paint(props[name], wearing)
                    end
                end

                op.props = resolved
            end
        end
    end
end

--- Answers everything a node draws that is painted from the look it is drawn in.
---
--- A colour reaches a renderer four ways and a style is only one of them: the tint of a control, the run
--- of colours a gradient is, the commands a canvas draws and the colour a mark is drawn in are each a
--- prop. Sending the styles alone left a switch, a slider, a spinner and the chevron of a way back in
--- the colours of the look before it, which is every part of a screen the platform draws rather than the
--- tree, and exactly the parts a reader notices did not follow.
function Runtime:paintedProps(kind, props, wearing)
    local painted = {}
    local assets = reads.assets[kind] or {}

    wearing = wearing or self.theme

    if props.style ~= nil then
        painted.style = self:styleOf(props.style, wearing)
    end

    for name in pairs(reads.nested) do
        if type(props[name]) == "table" then
            painted[name] = self:resolveEntries(props[name], nil, wearing)
        end
    end

    for name in pairs(reads.painted) do
        if type(props[name]) == "table" then
            painted[name] = self:resolvePainted(props[name], wearing)
        end
    end

    for name in pairs(reads.palettes) do
        if type(props[name]) == "table" then
            local run = {}

            for index = 1, #props[name] do
                run[index] = resolve.paint(props[name][index], wearing)
            end

            painted[name] = run
        end
    end

    for name in pairs(reads.tints) do
        if type(props[name]) == "string" and assets[name] == nil then
            painted[name] = resolve.paint(props[name], wearing)
        end
    end

    return painted
end

--- Paints every node again, which a new look means for the whole tree at once.

function Runtime:restyle(ops)
    for id, node in pairs(self.byId) do
        local painted = self:paintedProps(node.type, node.props, node.wearing)

        if next(painted) ~= nil then
            ops[#ops + 1] = { op = "update", id = id, props = painted }
        end
    end
end

end
