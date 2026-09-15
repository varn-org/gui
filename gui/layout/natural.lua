local M = {}

--- What each node type is worth when nothing else gives it a size, keyed by the type a renderer sees.
local declared = {}

--- The size a control is worth is the one the platform draws it at, which only the platform knows.
---
--- A number written here is a number that was true of one platform on one day: a switch was 51 across
--- until it was 61, and a frame worked out from the old one spills the control out of the box it was
--- given. A type that stands this in for its size is measured rather than assumed.
M.platform = setmetatable({}, { __tostring = function() return "platform" end })

--- The height a control is worth is the platform's and its width is the row's, which several controls are.
---
--- A slider and a segmented control run the width they are given on every platform, and each of them
--- answers a width of its own when it is asked for one with nothing in it — the browser says a slider is
--- 129 across, UIKit says about 150 and Android says something else again, so the same screen came out a
--- different width on each of the three. Which axes a platform decides is the declaration's to say, since
--- a renderer answering it is three renderers disagreeing about it.
M.platformHeight = setmetatable({}, { __tostring = function() return "platform height" end })

--- Records the natural size of a type, which is what a component declares once and every screen reads.
---
--- A node with no children, no text and no size would otherwise be nothing. A switch is the size the
--- platform draws a switch at, a chip is its label plus its padding, and an icon is whatever size it
--- was asked for.
function M.declare(kind, natural)
    if natural == nil then
        return
    end

    declared[kind] = natural
end

--- Answers the text a node is measured by, which is not always the prop called text.
---
--- A chip carries its label, a button its title and a badge its value, and each of them has to be
--- measured or it collapses to nothing.
function M.textOf(kind, props)
    local natural = declared[kind]

    if natural == nil or natural.text == nil then
        return props.text
    end

    if type(natural.text) == "function" then
        return natural.text(props)
    end

    local value = props[natural.text]
    return value ~= nil and tostring(value) or nil
end

--- Answers a least extent, which a type whose smallest size depends on how it was asked for computes.
---
--- A frame drawn from a picture cut into nine cannot be narrower than the two corners it is cut at, and
--- what those are is written on the node rather than fixed for the type.
local function least(declared, props)
    if type(declared) == "function" then
        return declared(props)
    end

    return declared
end

--- Answers the size a node takes when nothing else constrains it, and the padding around its text.
function M.sizeOf(kind, props, measureControl)
    local natural = declared[kind]

    if natural == nil then
        return nil
    end

    local size = natural.size

    if type(size) == "function" then
        size = size(props)
    end

    -- A type whose size depends on how it was asked for answers the sentinel from its own function, so
    -- what the platform draws is asked for after the type has had its say rather than before.
    if size == M.platform or size == M.platformHeight then
        local measured = measureControl ~= nil and measureControl(kind) or nil

        if measured ~= nil and size == M.platformHeight then
            measured = { height = measured.height }
        end

        size = measured
    end

    if size == nil and natural.padding == nil and natural.minWidth == nil and natural.minHeight == nil then
        return nil
    end

    return {
        width = size ~= nil and size.width or nil,
        height = size ~= nil and size.height or nil,
        minWidth = least(natural.minWidth, props),
        minHeight = least(natural.minHeight, props),
        padding = natural.padding,
    }
end

--- The types that scroll, and so are a viewport rather than a box the size of what is inside them.
M.scrolling = {
    scroll = true,
    list = true,
    sectionlist = true,
    grid = true,
    carousel = true,
}

--- Answers the axis a node scrolls along, or nothing when it does not scroll.
---
--- A scrolling view is as large as it was given room to be, never as large as what is inside it. That
--- is what scrolling means, and a view that grew to its content would push everything around it out.
function M.scrollAxisOf(kind, props)
    if not M.scrolling[kind] then
        return nil
    end

    return props.horizontal == true and "horizontal" or "vertical"
end

return M
