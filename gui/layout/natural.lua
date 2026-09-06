local M = {}

--- What each node type is worth when nothing else gives it a size, keyed by the type a renderer sees.
local declared = {}

--- The size a control is worth is the one the platform draws it at, which only the platform knows.
---
--- A number written here is a number that was true of one platform on one day: a switch was 51 across
--- until it was 61, and a frame worked out from the old one spills the control out of the box it was
--- given. A type that stands this in for its size is measured rather than assumed.
M.platform = setmetatable({}, { __tostring = function() return "platform" end })

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

--- Answers the size a node takes when nothing else constrains it, and the padding around its text.
function M.sizeOf(kind, props, measureControl)
    local natural = declared[kind]

    if natural == nil then
        return nil
    end

    local size = natural.size

    if size == M.platform then
        size = measureControl ~= nil and measureControl(kind) or nil
    elseif type(size) == "function" then
        size = size(props)
    end

    if size == nil and natural.padding == nil then
        return nil
    end

    return {
        width = size ~= nil and size.width or nil,
        height = size ~= nil and size.height or nil,
        minWidth = natural.minWidth,
        minHeight = natural.minHeight,
        padding = natural.padding,
    }
end

--- The types that scroll, and so are a viewport rather than a box the size of what is inside them.
local SCROLLING = {
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
    if not SCROLLING[kind] then
        return nil
    end

    return props.horizontal == true and "horizontal" or "vertical"
end

return M
