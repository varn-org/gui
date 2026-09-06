local M = {}

local NAMED = {
    transparent = { 0, 0, 0, 0 },
    black = { 0, 0, 0, 1 },
    white = { 255, 255, 255, 1 },
    red = { 255, 0, 0, 1 },
    green = { 0, 128, 0, 1 },
    blue = { 0, 0, 255, 1 },
    yellow = { 255, 255, 0, 1 },
    orange = { 255, 165, 0, 1 },
    purple = { 128, 0, 128, 1 },
    gray = { 128, 128, 128, 1 },
    grey = { 128, 128, 128, 1 },
}

local function clampChannel(value)
    if value < 0 then
        return 0
    end

    if value > 255 then
        return 255
    end

    return value
end

local function fromHex(text)
    local digits = text:sub(2)
    local length = #digits

    if length == 3 or length == 4 then
        local expanded = digits:gsub("(%x)", "%1%1")
        digits = expanded
        length = #digits
    end

    if length ~= 6 and length ~= 8 then
        error("a hex colour takes three, four, six or eight digits, got " .. text, 0)
    end

    local red = tonumber(digits:sub(1, 2), 16)
    local green = tonumber(digits:sub(3, 4), 16)
    local blue = tonumber(digits:sub(5, 6), 16)
    local alpha = length == 8 and tonumber(digits:sub(7, 8), 16) / 255 or 1

    if red == nil or green == nil or blue == nil or alpha == nil then
        error("a hex colour carries only hexadecimal digits, got " .. text, 0)
    end

    return { red, green, blue, alpha }
end

local function fromFunction(text)
    local name, body = text:match("^(%a+)%(([^)]*)%)$")
    if name == nil then
        return nil
    end

    local parts = {}
    for piece in body:gmatch("[^,%s]+") do
        parts[#parts + 1] = piece
    end

    if name == "rgb" or name == "rgba" then
        local alpha = parts[4] ~= nil and tonumber(parts[4]) or 1
        return { tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]), alpha }
    end

    if name == "hsl" or name == "hsla" then
        local hue = tonumber((parts[1]:gsub("deg", ""))) % 360 / 360
        local saturation = tonumber((parts[2]:gsub("%%", ""))) / 100
        local lightness = tonumber((parts[3]:gsub("%%", ""))) / 100
        local alpha = parts[4] ~= nil and tonumber(parts[4]) or 1

        local function channel(shift)
            local value = (hue + shift) % 1
            local chroma = lightness < 0.5 and lightness * (1 + saturation) or lightness + saturation - lightness * saturation
            local base = 2 * lightness - chroma

            if value < 1 / 6 then
                return base + (chroma - base) * 6 * value
            end
            if value < 1 / 2 then
                return chroma
            end
            if value < 2 / 3 then
                return base + (chroma - base) * (2 / 3 - value) * 6
            end

            return base
        end

        return { channel(1 / 3) * 255, channel(0) * 255, channel(-1 / 3) * 255, alpha }
    end

    return nil
end

--- Reads a colour written as a name, a hex string, or an rgb, rgba, hsl or hsla call.
function M.parse(value)
    if type(value) == "table" then
        return { value[1] or 0, value[2] or 0, value[3] or 0, value[4] == nil and 1 or value[4] }
    end

    if type(value) ~= "string" then
        error("a colour is a string or a table of channels, got " .. type(value), 0)
    end

    local named = NAMED[value]
    if named ~= nil then
        return { named[1], named[2], named[3], named[4] }
    end

    if value:sub(1, 1) == "#" then
        return fromHex(value)
    end

    local parsed = fromFunction(value)
    if parsed ~= nil then
        return parsed
    end

    error("a colour must be a name, a hex string or an rgb, rgba, hsl or hsla call, got " .. value, 0)
end

--- Renders a colour back as the eight digit hex a renderer receives.
function M.toHex(value)
    local channels = M.parse(value)
    return string.format(
        "#%02x%02x%02x%02x",
        math.floor(clampChannel(channels[1]) + 0.5),
        math.floor(clampChannel(channels[2]) + 0.5),
        math.floor(clampChannel(channels[3]) + 0.5),
        math.floor(channels[4] * 255 + 0.5)
    )
end

local function mix(value, towards, amount)
    local channels = M.parse(value)
    return {
        channels[1] + (towards - channels[1]) * amount,
        channels[2] + (towards - channels[2]) * amount,
        channels[3] + (towards - channels[3]) * amount,
        channels[4],
    }
end

--- Moves a colour towards white by the given fraction.
function M.lighten(value, amount)
    return mix(value, 255, amount)
end

--- Moves a colour towards black by the given fraction.
function M.darken(value, amount)
    return mix(value, 0, amount)
end

--- Answers the relative luminance, which is what deciding a readable foreground rests on.
function M.luminance(value)
    local channels = M.parse(value)

    local function component(raw)
        local channel = raw / 255
        if channel <= 0.03928 then
            return channel / 12.92
        end

        return ((channel + 0.055) / 1.055) ^ 2.4
    end

    return 0.2126 * component(channels[1]) + 0.7152 * component(channels[2]) + 0.0722 * component(channels[3])
end

--- Answers the contrast ratio between two colours, the way the accessibility guidelines define it.
function M.contrast(first, second)
    local a = M.luminance(first)
    local b = M.luminance(second)
    local lighter = math.max(a, b)
    local darker = math.min(a, b)

    return (lighter + 0.05) / (darker + 0.05)
end

--- Answers whichever of the two candidates reads better on the given background.
function M.readable(background, dark, light)
    dark = dark or "#000000"
    light = light or "#ffffff"

    if M.contrast(background, dark) >= M.contrast(background, light) then
        return dark
    end

    return light
end

return M
