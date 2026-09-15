local color = require("gui.style.color")

local M = {}

local cache = setmetatable({}, { __mode = "k" })

--- A resolved style is read rather than written, so a node with none of its own shares one answer.
local EMPTY = {}

--- The fields the engine lays out with, which never reach a renderer, since it sends finished frames.
---
--- A field nothing honours is a caller who wrote `colr` and is shown a box with no colour, told nothing
--- and left to work out why: the props of a node are held to what a component declares, and a style is
--- the other half of the same promise. The suite holds this list to the fields the layout itself reads,
--- and the one below it to what all three renderers name.
local LAID = {
    direction = true, justify = true, align = true, alignSelf = true, wrap = true,
    gap = true, rowGap = true, columnGap = true,
    width = true, height = true, minWidth = true, maxWidth = true, minHeight = true, maxHeight = true,
    grow = true, shrink = true, basis = true,
    position = true, left = true, top = true, right = true, bottom = true,
}

for _, family in ipairs({ "margin", "padding", "border" }) do
    LAID[family] = true
    LAID[family .. "Horizontal"] = true
    LAID[family .. "Vertical"] = true

    for _, edge in ipairs({ "Top", "Right", "Bottom", "Left" }) do
        LAID[family .. edge] = true
    end
end

--- The fields that cross to a renderer, which all three of them have to honour.
---
--- A colour a control carries rather than a box — the tint of a picture, the colour of a placeholder —
--- is a prop and not one of these: it is painted by the runtime and read by a renderer as a prop, so a
--- style carrying one is a field two platforms out of three would ignore.
local DRAWN = {
    background = true, color = true, border = true, borderColor = true,
    radius = true, shadow = true, opacity = true, overflow = true, transform = true,

    fontSize = true, fontFamily = true, fontWeight = true, fontStyle = true,
    letterSpacing = true, lineHeight = true, textAlign = true, textDecoration = true,
}

local KNOWN = {}

for name in pairs(LAID) do
    KNOWN[name] = true
end

for name in pairs(DRAWN) do
    KNOWN[name] = true
end

--- Answers every field a style may carry, which is what a check outside this reads.
function M.known()
    return KNOWN
end

--- Answers the fields that reach a renderer, which is what each of them is held to honouring.
function M.drawn()
    return DRAWN
end

local function apply(into, style, theme, breakpoint)
    for key, value in pairs(style) do
        if KNOWN[key] == nil then
            error("a style carries no field named " .. tostring(key), 0)
        end

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
    color = "color", background = "color", borderColor = "color",
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

        -- A colour is painted whatever shape it was written in, since one written as anything but a name
        -- or a literal is a field that reaches three renderers as itself and is drawn by none of them.
        if value ~= nil and kind == "color" then
            style[key] = M.paint(value, theme)
        elseif value ~= nil and type(value) == "string" and kind ~= "shadow" then
            if kind == "space" then
                style[key] = theme:space(value)
            elseif kind == "radius" then
                style[key] = theme:radius(value)
            elseif kind == "fontSize" then
                style[key] = theme:fontSize(value)
            end
        end
    end

    return style
end

--- The fields that may be given a number below nothing, since a length below nothing is a mistake.
---
--- A margin pulls a box outside the one that holds it, which is how a panel wider than its anchor is
--- centred on it, and an offset places a box relative to where it would have been. Everything else — a
--- size, the space inside a box, the space between children, a corner, a border — is a distance, and a
--- distance below nothing reaches three renderers that each make something different of it: an inverted
--- rect on one, a frame the platform refuses on another, and a declaration the browser drops.
local SIGNED = {
    left = true, top = true, right = true, bottom = true,
}

for _, edge in ipairs({ "", "Top", "Right", "Bottom", "Left", "Horizontal", "Vertical" }) do
    SIGNED["margin" .. edge] = true
end

--- The fields that say how a box shares out the room left over, which are counts rather than lengths.
local SHARES = { grow = true, shrink = true }

--- Refuses a value the field it was written under cannot carry, naming both.
local function checkValues(style)
    for key, value in pairs(style) do
        if SHARES[key] then
            if type(value) ~= "number" or value < 0 then
                error(key .. " is how much of the room left over a box takes, which is a number, at least"
                    .. " nothing, got " .. tostring(value), 0)
            end
        elseif type(value) == "number" and value < 0 and not SIGNED[key] then
            error(key .. " is a distance, and a distance is never below nothing, got " .. tostring(value), 0)
        end
    end

    return style
end

--- Flattens a list of styles plus the inline one into the concrete values a renderer receives.
---
--- Names from the theme are turned into numbers and colours here, so a renderer never carries a
--- theme of its own and three of them cannot disagree about what a spacing step means.
--- Fills in the typeface and the line the theme carries, which is what a theme's typography is for.
---
--- A face and a line named in one place is the same tree drawn the same way on every platform, and it
--- is also what makes a measurement agree with what is drawn: both read the style, so a line the theme
--- declares and nobody writes into the style is a string measured in one line and drawn in another.
local function typeset(style, theme)
    local typography = theme ~= nil and theme.typography or nil

    if typography == nil then
        return style
    end

    if style.fontFamily == nil and typography.family ~= nil then
        style.fontFamily = typography.family
    end

    if style.lineHeight == nil and typography.lineHeight ~= nil then
        style.lineHeight = typography.lineHeight
    end

    return style
end

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

        local resolved = checkValues(typeset(resolveTransform(resolveTokens(apply({}, styles, theme, breakpoint), theme)), theme))
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

    return checkValues(typeset(resolveTransform(resolveTokens(merged, theme)), theme))
end

return M
