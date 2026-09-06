local M = {}

local BASE = {
    colors = {
        background = "#ffffff",
        surface = "#f5f5f7",
        text = "#111114",
        separator = "#00000014",
        textMuted = "#6b6b76",
        primary = "#3b82f6",
        onPrimary = "#ffffff",
        success = "#16a34a",
        warning = "#d97706",
        danger = "#dc2626",
        border = "#d8d8de",
        overlay = "rgba(0, 0, 0, 0.4)",
    },
    typography = {
        family = nil,
        sizes = { caption = 12, footnote = 13, body = 16, headline = 17, title = 22, heading = 28, display = 34 },
        weights = { regular = "400", medium = "500", semibold = "600", bold = "700" },
        lineHeight = 1.35,
    },
    spacing = { none = 0, xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48 },
    radii = { none = 0, sm = 4, md = 8, lg = 16, pill = 999 },
    shadows = {
        none = nil,
        sm = { color = "rgba(0, 0, 0, 0.12)", radius = 4, offsetY = 1 },
        md = { color = "rgba(0, 0, 0, 0.16)", radius = 12, offsetY = 4 },
        lg = { color = "rgba(0, 0, 0, 0.2)", radius = 28, offsetY = 12 },
    },
    breakpoints = { compact = 0, medium = 600, expanded = 900 },
}

local DARK = {
    colors = {
        background = "#0b0b0f",
        surface = "#17171d",
        text = "#f4f4f7",
        separator = "#ffffff1f",
        textMuted = "#9a9aa6",
        primary = "#60a5fa",
        onPrimary = "#08121f",
        border = "#2a2a34",
        overlay = "rgba(0, 0, 0, 0.6)",
    },
}

local function merge(base, overrides)
    local result = {}

    for key, value in pairs(base) do
        if type(value) == "table" and not value[1] then
            result[key] = merge(value, {})
        else
            result[key] = value
        end
    end

    if overrides == nil then
        return result
    end

    for key, value in pairs(overrides) do
        local existing = result[key]
        if type(value) == "table" and type(existing) == "table" and not value[1] and not existing[1] then
            result[key] = merge(existing, value)
        else
            result[key] = value
        end
    end

    return result
end

local Theme = {}
Theme.__index = Theme

--- Answers a colour by theme name, or the value itself when it is already one.
function Theme:color(name)
    if name == nil then
        return nil
    end

    return self.colors[name] or name
end

--- Answers a spacing step by name, or the number itself when one was given.
function Theme:space(name)
    if type(name) == "number" then
        return name
    end

    local value = self.spacing[name]
    if value == nil then
        error("the theme carries no spacing named " .. tostring(name), 2)
    end

    return value
end

--- Answers a corner radius by name, or the number itself when one was given.
function Theme:radius(name)
    if type(name) == "number" then
        return name
    end

    local value = self.radii[name]
    if value == nil then
        error("the theme carries no radius named " .. tostring(name), 2)
    end

    return value
end

--- Answers the shadow a raised box is drawn with, by the step it names.
function Theme:shadow(name)
    if type(name) == "table" then
        return name
    end

    if name == nil or name == "none" then
        return nil
    end

    local value = self.shadows[name]
    if value == nil then
        error("the theme carries no shadow named " .. tostring(name), 2)
    end

    return value
end

--- Answers a font size by name, or the number itself when one was given.
function Theme:fontSize(name)
    if type(name) == "number" then
        return name
    end

    local value = self.typography.sizes[name]
    if value == nil then
        error("the theme carries no font size named " .. tostring(name), 2)
    end

    return value
end

--- Answers the breakpoint a width falls into, which is what a responsive value resolves against.
function Theme:breakpoint(width)
    local best = "compact"
    local bestValue = -1

    for name, threshold in pairs(self.breakpoints) do
        if width >= threshold and threshold > bestValue then
            best = name
            bestValue = threshold
        end
    end

    return best
end

--- Builds a theme from the defaults plus whatever an application wants to change.
function M.create(overrides)
    return setmetatable(merge(BASE, overrides), Theme)
end

--- Builds the dark counterpart of the defaults, plus whatever an application wants to change.
function M.dark(overrides)
    return setmetatable(merge(merge(BASE, DARK), overrides), Theme)
end

M.base = BASE

return M
