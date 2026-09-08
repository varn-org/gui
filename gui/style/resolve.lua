local color = require("gui.style.color")

local M = {}

local cache = setmetatable({}, { __mode = "k" })

--- A resolved style is read rather than written, so a node with none of its own shares one answer.
local EMPTY = {}

local function apply(into, style, theme, breakpoint)
    for key, value in pairs(style) do
        if type(value) == "table" and value[breakpoint] ~= nil then
            into[key] = value[breakpoint]
        elseif type(value) == "table" and (value.compact ~= nil or value.medium ~= nil or value.expanded ~= nil) then
            into[key] = value.compact or value.medium or value.expanded
        else
            into[key] = value
        end
    end

    return into
end

local TOKENS = {
    padding = "space", paddingTop = "space", paddingRight = "space", paddingBottom = "space", paddingLeft = "space",
    paddingHorizontal = "space", paddingVertical = "space",
    margin = "space", marginTop = "space", marginRight = "space", marginBottom = "space", marginLeft = "space",
    marginHorizontal = "space", marginVertical = "space",
    gap = "space", rowGap = "space", columnGap = "space",
    radius = "radius",
    fontSize = "fontSize",
    color = "color", background = "color", borderColor = "color", tint = "color", placeholderColor = "color",
    shadow = "shadow",
}

local TRANSFORMS = {
    translateX = 0, translateY = 0,
    scale = 1, scaleX = 1, scaleY = 1,
    rotate = 0,
}

--- Normalises a transform into the fields every renderer applies, leaving layout untouched.
---
--- A transform moves what is drawn rather than what is measured, so a node keeps the frame the layout
--- engine gave it however it is scaled or rotated.
local function resolveTransform(style)
    local declared = style.transform
    if declared == nil then
        return style
    end

    if type(declared) ~= "table" then
        error("a transform must be a table of translate, scale, rotate and skew, got " .. type(declared), 2)
    end

    local transform = {}
    for name, neutral in pairs(TRANSFORMS) do
        transform[name] = declared[name] or neutral
    end

    for name in pairs(declared) do
        if TRANSFORMS[name] == nil then
            error("a transform has no field named " .. name, 2)
        end
    end

    if declared.scale ~= nil then
        transform.scaleX = declared.scaleX or declared.scale
        transform.scaleY = declared.scaleY or declared.scale
    end

    style.transform = transform
    return style
end

--- Answers a colour as the eight digit hex every renderer draws with.
---
--- A renderer reads a colour rather than parsing one, so a name from the theme, an `rgb` call and a
--- three digit hex all arrive in the one shape and three platforms cannot disagree about any of them.
function M.paint(value, theme)
    if value == nil then
        return nil
    end

    return color.toHex(theme:color(value))
end

local function paintShadow(declared, theme)
    local painted = {}

    for key, value in pairs(declared) do
        painted[key] = value
    end

    painted.color = M.paint(declared.color, theme)
    return painted
end

local function resolveTokens(style, theme)
    if type(style.shadow) == "string" then
        style.shadow = theme:shadow(style.shadow)
    end

    if type(style.shadow) == "table" then
        style.shadow = paintShadow(style.shadow, theme)
    end

    for key, kind in pairs(TOKENS) do
        local value = style[key]
        if value ~= nil and type(value) == "string" and kind ~= "shadow" then
            if kind == "space" then
                style[key] = theme:space(value)
            elseif kind == "radius" then
                style[key] = theme:radius(value)
            elseif kind == "fontSize" then
                style[key] = theme:fontSize(value)
            elseif kind == "color" then
                style[key] = M.paint(value, theme)
            end
        end
    end

    return style
end

--- Flattens a list of styles plus the inline one into the concrete values a renderer receives.
---
--- Names from the theme are turned into numbers and colours here, so a renderer never carries a
--- theme of its own and three of them cannot disagree about what a spacing step means.
function M.resolve(styles, theme, breakpoint)
    if styles == nil then
        return EMPTY
    end

    if type(styles) ~= "table" then
        error("a style must be a table or a list of them, got " .. type(styles), 2)
    end

    local isList = styles[1] ~= nil
    if not isList then
        local hit = cache[styles]
        if hit ~= nil and hit.theme == theme and hit.breakpoint == breakpoint then
            return hit.value
        end

        local resolved = resolveTransform(resolveTokens(apply({}, styles, theme, breakpoint), theme))
        cache[styles] = { theme = theme, breakpoint = breakpoint, value = resolved }
        return resolved
    end

    local merged = {}
    for index = 1, #styles do
        local entry = styles[index]
        if entry ~= nil and entry ~= false then
            apply(merged, entry, theme, breakpoint)
        end
    end

    return resolveTransform(resolveTokens(merged, theme))
end

return M
