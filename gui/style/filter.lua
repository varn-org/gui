local M = {}

--- The matrix that leaves a colour as it was, which is what an unnamed filter is worth.
local IDENTITY = {
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
}

--- How much of a colour the eye reads as its brightness, which is what grey is made of.
local LUMA = { r = 0.2126, g = 0.7152, b = 0.0722 }

--- Answers one filter applied after another, which is what a run of them is.
---
--- A matrix is read as five columns of five, the last row being the one that carries nothing through, so
--- composing two is the ordinary product with the offset column carried across.
local function compose(after, before)
    local result = {}

    for row = 0, 3 do
        for column = 1, 5 do
            local sum = 0

            for term = 0, 3 do
                sum = sum + after[row * 5 + term + 1] * before[term * 5 + column]
            end

            if column == 5 then
                sum = sum + after[row * 5 + 5]
            end

            result[row * 5 + column] = sum
        end
    end

    return result
end

--- Answers the matrix that mixes a colour towards what a filter turns it into.
---
--- Every one of these is the matrix the filter is defined as: the browser applies exactly these for its
--- own filter functions, so writing them once here is what makes one filter one picture on all three
--- rather than three platforms each rounding their own way.
local MATRICES = {
    grayscale = function(amount)
        local kept = 1 - math.max(0, math.min(1, amount))

        return {
            LUMA.r + 0.7874 * kept, LUMA.g - LUMA.g * kept, LUMA.b - LUMA.b * kept, 0, 0,
            LUMA.r - LUMA.r * kept, LUMA.g + 0.2848 * kept, LUMA.b - LUMA.b * kept, 0, 0,
            LUMA.r - LUMA.r * kept, LUMA.g - LUMA.g * kept, LUMA.b + 0.9278 * kept, 0, 0,
            0, 0, 0, 1, 0,
        }
    end,

    sepia = function(amount)
        local kept = 1 - math.max(0, math.min(1, amount))

        return {
            0.393 + 0.607 * kept, 0.769 - 0.769 * kept, 0.189 - 0.189 * kept, 0, 0,
            0.349 - 0.349 * kept, 0.686 + 0.314 * kept, 0.168 - 0.168 * kept, 0, 0,
            0.272 - 0.272 * kept, 0.534 - 0.534 * kept, 0.131 + 0.869 * kept, 0, 0,
            0, 0, 0, 1, 0,
        }
    end,

    invert = function(amount)
        local share = math.max(0, math.min(1, amount))
        local kept = 1 - 2 * share

        return {
            kept, 0, 0, 0, share,
            0, kept, 0, 0, share,
            0, 0, kept, 0, share,
            0, 0, 0, 1, 0,
        }
    end,

    hue = function(degrees)
        local turn = math.rad(degrees)
        local cosine = math.cos(turn)
        local sine = math.sin(turn)

        return {
            0.213 + cosine * 0.787 - sine * 0.213,
            0.715 - cosine * 0.715 - sine * 0.715,
            0.072 - cosine * 0.072 + sine * 0.928,
            0, 0,

            0.213 - cosine * 0.213 + sine * 0.143,
            0.715 + cosine * 0.285 + sine * 0.140,
            0.072 - cosine * 0.072 - sine * 0.283,
            0, 0,

            0.213 - cosine * 0.213 - sine * 0.787,
            0.715 - cosine * 0.715 + sine * 0.715,
            0.072 + cosine * 0.928 + sine * 0.072,
            0, 0,

            0, 0, 0, 1, 0,
        }
    end,

    saturate = function(amount)
        local share = math.max(0, amount)

        return {
            0.213 + 0.787 * share, 0.715 - 0.715 * share, 0.072 - 0.072 * share, 0, 0,
            0.213 - 0.213 * share, 0.715 + 0.285 * share, 0.072 - 0.072 * share, 0, 0,
            0.213 - 0.213 * share, 0.715 - 0.715 * share, 0.072 + 0.928 * share, 0, 0,
            0, 0, 0, 1, 0,
        }
    end,

    brightness = function(amount)
        local share = math.max(0, amount)

        return {
            share, 0, 0, 0, 0,
            0, share, 0, 0, 0,
            0, 0, share, 0, 0,
            0, 0, 0, 1, 0,
        }
    end,

    contrast = function(amount)
        local share = math.max(0, amount)
        local lift = 0.5 - 0.5 * share

        return {
            share, 0, 0, 0, lift,
            0, share, 0, 0, lift,
            0, 0, share, 0, lift,
            0, 0, 0, 1, 0,
        }
    end,
}

--- The order the named filters are applied in, since the fields of a table have none of their own.
---
--- Colour matrices do not commute: saturating what has been made grey is grey, and greying what has been
--- saturated is a different grey, so the order is written once here rather than left to each caller.
M.order = { "grayscale", "sepia", "invert", "hue", "saturate", "brightness", "contrast" }

--- What each filter is worth when it is not named, which is the amount that changes nothing.
local neutral = {
    grayscale = 0, sepia = 0, invert = 0, hue = 0,
    saturate = 1, brightness = 1, contrast = 1,
}

--- Answers the one matrix a run of named filters comes to, which is what a renderer is sent.
---
--- A renderer applies a matrix rather than a list of names: the browser has one filter primitive, iOS a
--- `CIColorMatrix` and Android a `ColorMatrixColorFilter`, so the arithmetic is done once here and three
--- platforms cannot disagree about what a filter means.
function M.matrix(amounts)
    if type(amounts) ~= "table" then
        error("a filter is a table of amounts, got " .. type(amounts), 0)
    end

    for name, amount in pairs(amounts) do
        if neutral[name] == nil then
            error("a filter has no field named " .. tostring(name), 0)
        end

        if type(amount) ~= "number" then
            error("a filter's " .. name .. " is an amount, got " .. type(amount), 0)
        end
    end

    local built = IDENTITY

    for index = 1, #M.order do
        local name = M.order[index]
        local amount = amounts[name]

        if amount ~= nil and amount ~= neutral[name] then
            built = compose(MATRICES[name](amount), built)
        end
    end

    return built
end

--- The looks a picture is usually given, each written in the amounts it is made of.
---
--- They are a starting point rather than a fixed set: a caller writes the amounts themselves whenever
--- none of these is what they want, and one of these with a field changed is the same thing again.
M.looks = {
    mono = { grayscale = 1 },
    noir = { grayscale = 1, contrast = 1.35, brightness = 0.95 },
    sepia = { sepia = 0.8, contrast = 1.05 },
    vivid = { saturate = 1.6, contrast = 1.1 },
    fade = { saturate = 0.7, brightness = 1.1, contrast = 0.9 },
    cool = { hue = -18, saturate = 1.1 },
    warm = { hue = 14, saturate = 1.15, brightness = 1.05 },
    negative = { invert = 1 },
}

--- Answers whether a matrix is the one that leaves every colour as it was.
function M.transparent(matrix)
    for index = 1, #IDENTITY do
        if math.abs(matrix[index] - IDENTITY[index]) > 1e-9 then
            return false
        end
    end

    return true
end

return M
