local color = require("gui.style.color")

local M = {}

--- The classic colour families, at the ten tones each of them is published in.
---
--- A screen names a tone directly — `color = "indigo400"` — or the family, which is its 500. What a
--- component names instead is one of the roles below, so a project that replaces a role replaces it
--- everywhere at once rather than hunting through screens for a literal.
local FAMILIES = {
    red = { "#ffebee", "#ffcdd2", "#ef9a9a", "#e57373", "#ef5350", "#f44336", "#e53935", "#d32f2f", "#c62828", "#b71c1c" },
    pink = { "#fce4ec", "#f8bbd0", "#f48fb1", "#f06292", "#ec407a", "#e91e63", "#d81b60", "#c2185b", "#ad1457", "#880e4f" },
    purple = { "#f3e5f5", "#e1bee7", "#ce93d8", "#ba68c8", "#ab47bc", "#9c27b0", "#8e24aa", "#7b1fa2", "#6a1b9a", "#4a148c" },
    deepPurple = { "#ede7f6", "#d1c4e9", "#b39ddb", "#9575cd", "#7e57c2", "#673ab7", "#5e35b1", "#512da8", "#4527a0", "#311b92" },
    indigo = { "#e8eaf6", "#c5cae9", "#9fa8da", "#7986cb", "#5c6bc0", "#3f51b5", "#3949ab", "#303f9f", "#283593", "#1a237e" },
    blue = { "#e3f2fd", "#bbdefb", "#90caf9", "#64b5f6", "#42a5f5", "#2196f3", "#1e88e5", "#1976d2", "#1565c0", "#0d47a1" },
    lightBlue = { "#e1f5fe", "#b3e5fc", "#81d4fa", "#4fc3f7", "#29b6f6", "#03a9f4", "#039be5", "#0288d1", "#0277bd", "#01579b" },
    cyan = { "#e0f7fa", "#b2ebf2", "#80deea", "#4dd0e1", "#26c6da", "#00bcd4", "#00acc1", "#0097a7", "#00838f", "#006064" },
    teal = { "#e0f2f1", "#b2dfdb", "#80cbc4", "#4db6ac", "#26a69a", "#009688", "#00897b", "#00796b", "#00695c", "#004d40" },
    green = { "#e8f5e9", "#c8e6c9", "#a5d6a7", "#81c784", "#66bb6a", "#4caf50", "#43a047", "#388e3c", "#2e7d32", "#1b5e20" },
    lightGreen = { "#f1f8e9", "#dcedc8", "#c5e1a5", "#aed581", "#9ccc65", "#8bc34a", "#7cb342", "#689f38", "#558b2f", "#33691e" },
    lime = { "#f9fbe7", "#f0f4c3", "#e6ee9c", "#dce775", "#d4e157", "#cddc39", "#c0ca33", "#afb42b", "#9e9d24", "#827717" },
    yellow = { "#fffde7", "#fff9c4", "#fff59d", "#fff176", "#ffee58", "#ffeb3b", "#fdd835", "#fbc02d", "#f9a825", "#f57f17" },
    amber = { "#fff8e1", "#ffecb3", "#ffe082", "#ffd54f", "#ffca28", "#ffc107", "#ffb300", "#ffa000", "#ff8f00", "#ff6f00" },
    orange = { "#fff3e0", "#ffe0b2", "#ffcc80", "#ffb74d", "#ffa726", "#ff9800", "#fb8c00", "#f57c00", "#ef6c00", "#e65100" },
    deepOrange = { "#fbe9e7", "#ffccbc", "#ffab91", "#ff8a65", "#ff7043", "#ff5722", "#f4511e", "#e64a19", "#d84315", "#bf360c" },
    brown = { "#efebe9", "#d7ccc8", "#bcaaa4", "#a1887f", "#8d6e63", "#795548", "#6d4c41", "#5d4037", "#4e342e", "#3e2723" },
    grey = { "#fafafa", "#f5f5f5", "#eeeeee", "#e0e0e0", "#bdbdbd", "#9e9e9e", "#757575", "#616161", "#424242", "#212121" },
    blueGrey = { "#eceff1", "#cfd8dc", "#b0bec5", "#90a4ae", "#78909c", "#607d8b", "#546e7a", "#455a64", "#37474f", "#263238" },
}

local TONES = { 50, 100, 200, 300, 400, 500, 600, 700, 800, 900 }

local function palette(roles)
    local colors = {}

    for family, tones in pairs(FAMILIES) do
        for index = 1, #TONES do
            colors[family .. TONES[index]] = tones[index]
        end

        colors[family] = tones[6]
    end

    for name, value in pairs(roles) do
        colors[name] = value
    end

    return colors
end

local BASE = {
    colors = palette({
        background = "#ffffff",
        surface = "#f4f5fa",
        elevated = "#ffffff",
        text = "#1c1b1f",
        textMuted = "#5b5866",
        separator = "#0000001f",
        border = "#c9c6d0",
        primary = "#3f51b5",
        onPrimary = "#ffffff",
        success = "#2e7d32",
        warning = "#ef6c00",
        danger = "#c62828",
        overlay = "rgba(0, 0, 0, 0.4)",
    }),
    typography = {
        -- The framework ships this one and registers it before the first layout, so the same tree is
        -- drawn in the same face on every platform rather than in whatever each calls its system font.
        family = "Roboto",
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
        background = "#101014",
        surface = "#1c1b21",
        elevated = "#26252c",
        text = "#e7e2ea",
        textMuted = "#b3aec0",
        separator = "#ffffff1f",
        border = "#454150",
        primary = "#8c9eff",
        onPrimary = "#121533",
        success = "#81c784",
        warning = "#ffb74d",
        danger = "#ef5350",
        overlay = "rgba(0, 0, 0, 0.6)",
    },
}

--- The roles a drawn control names, worked out from the ones a look already carries.
---
--- A control theme names roles rather than colours, so the roles it needs have to exist in every look
--- including one written before this library drew a control at all. Each is derived from what the look
--- does carry, so a look that names none of them is still a complete palette and one that names any of
--- them is taken at its word.
local function control(colors, appearance)
    local dark = appearance == "dark"

    local derived = {
        outline = colors.border,
        surfaceVariant = colors.surface,
        onSurfaceVariant = colors.textMuted,
        primaryHover = dark and color.lighten(colors.primary, 0.12) or color.darken(colors.primary, 0.12),
        primaryMuted = dark and color.darken(colors.primary, 0.6) or color.lighten(colors.primary, 0.82),
        secondaryContainer = dark and color.darken(colors.primary, 0.55) or color.lighten(colors.primary, 0.78),
        disabledSurface = dark and color.lighten(colors.background, 0.12) or color.darken(colors.background, 0.1),
        disabledText = dark and color.darken(colors.textMuted, 0.3) or color.lighten(colors.textMuted, 0.45),
        disabledOutline = dark and color.darken(colors.border, 0.25) or color.lighten(colors.border, 0.45),
    }

    for name, value in pairs(derived) do
        if colors[name] == nil then
            colors[name] = color.toHex(value)
        end
    end

    -- What is written on a container is readable against it rather than fixed, since a look chooses the
    -- container and nothing else can know which of the two sides of its own text will be legible on it.
    if colors.onSecondaryContainer == nil then
        colors.onSecondaryContainer = color.toHex(color.readable(colors.secondaryContainer, colors.text, colors.background))
    end

    return colors
end

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
    if type(width) ~= "number" then
        error("a breakpoint is chosen by how wide the surface is, got a " .. type(width), 2)
    end

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

--- Answers what a platform paints outside the tree, which is the ground the application stands on.
---
--- A page, a window and an activity each draw something of their own around what the tree draws: the
--- ground behind the surface, the colour a browser writes its own captions in, what a selection is drawn
--- in, and the face everything is set in. None of that is a node, so none of it reaches a renderer as
--- one, and a dark application on a white page is what leaving it out looks like.
function Theme:ground()
    -- A renderer reads a colour rather than parsing one, the way every colour that crosses the bridge
    -- already arrives, so the ground is painted here rather than by each of the three.
    return {
        appearance = self.appearance,
        background = color.toHex(self.colors.background),
        text = color.toHex(self.colors.text),
        primary = color.toHex(self.colors.primary),
        family = self.typography.family,
    }
end

--- Builds a theme from the defaults plus whatever an application wants to change.
function M.create(overrides)
    if overrides ~= nil then
        if type(overrides) ~= "table" then
            error("a theme is built from a table of the families to change, got a " .. type(overrides), 2)
        end

        -- A family replaced by something that is not one is every lookup in it gone: `colors = "blue"`
        -- answers nothing for every name a screen asks for, and each of them reaches a renderer as the
        -- name itself.
        for name, family in pairs(overrides) do
            if type(BASE[name]) == "table" and type(family) ~= "table" then
                error("the " .. name .. " of a theme is a table of names, got a " .. type(family), 2)
            end
        end
    end

    local built = setmetatable(merge(BASE, overrides), Theme)
    built.appearance = "light"
    control(built.colors, "light")

    return built
end

--- Builds the dark counterpart of the defaults, plus whatever an application wants to change.
function M.dark(overrides)
    local built = setmetatable(merge(merge(BASE, DARK), overrides), Theme)
    built.appearance = "dark"
    control(built.colors, "dark")

    return built
end

local Look = {}
Look.__index = Look

--- Answers the side of a look the device is set to, which is what the runtime draws with.
function Look:of(appearance)
    return appearance == "dark" and self.dark or self.light
end

--- Answers whether a value is a look rather than one of the two themes inside it.
function M.isLook(value)
    return getmetatable(value) == Look
end

--- The families a look carries for both of its sides rather than for one of them.
local SIDES = { name = true, light = true, dark = true }

--- Builds one look, which is a named appearance on each side of the same design.
---
--- A design is one thing and light and dark are two views of it: the spacing, the corners, the face and
--- the sizes are the same on both sides, and only the colours differ. Written as two themes an
--- application either repeats itself or drifts, and choosing one of them outright is an application that
--- stops following the device the moment it has a look of its own.
---
--- Anything written outside `light` and `dark` belongs to both, so a look that only changes its colours
--- says so twice and everything else once.
function M.define(spec)
    if type(spec) ~= "table" then
        error("a look is built from a table of what it changes, got a " .. type(spec), 2)
    end

    local shared = {}

    for name, family in pairs(spec) do
        if not SIDES[name] then
            shared[name] = family
        end
    end

    return setmetatable({
        name = spec.name or "a look",
        light = M.create(merge(shared, spec.light)),
        dark = M.dark(merge(shared, spec.dark)),
    }, Look)
end

--- The look the framework carries, which is what an application that names none is drawn in.
M.builtin = M.define({ name = "varn" })

--- The looks a reader will recognise, since a design is a thing people already have opinions about.
---
--- Each is the palette, the corners and the spacing that design is known for rather than an impression
--- of it: a tree put in one of these reads as something built with it. They are looks like any other, so
--- one of them with a field changed is the starting point rather than a wall.
M.looks = {
    nuxt = M.define({
        name = "nuxt",
        radii = { sm = 4, md = 8, lg = 12, pill = 999 },
        typography = { lineHeight = 1.45 },
        light = {
            colors = {
                primary = "#00dc82", onPrimary = "#00291a", background = "#ffffff", surface = "#f4f4f5",
                elevated = "#ffffff", text = "#18181b", textMuted = "#52525b", border = "#e4e4e7",
                separator = "#18181b14", success = "#00c16a", warning = "#f59e0b", danger = "#f43f5e",
            },
        },
        dark = {
            colors = {
                primary = "#00dc82", onPrimary = "#00291a", background = "#020420", surface = "#0c1032",
                elevated = "#141a45", text = "#f4f4f5", textMuted = "#a1a1aa", border = "#27274a",
                separator = "#f4f4f514", success = "#00c16a", warning = "#fbbf24", danger = "#fb7185",
            },
        },
    }),

    bootstrap = M.define({
        name = "bootstrap",
        radii = { sm = 4, md = 6, lg = 8, pill = 999 },
        spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 48 },
        light = {
            colors = {
                primary = "#0d6efd", onPrimary = "#ffffff", background = "#ffffff", surface = "#f8f9fa",
                elevated = "#ffffff", text = "#212529", textMuted = "#6c757d", border = "#dee2e6",
                separator = "#00000020", success = "#198754", warning = "#ffc107", danger = "#dc3545",
            },
        },
        dark = {
            colors = {
                primary = "#6ea8fe", onPrimary = "#03224f", background = "#212529", surface = "#2b3035",
                elevated = "#343a40", text = "#dee2e6", textMuted = "#adb5bd", border = "#495057",
                separator = "#ffffff20", success = "#75b798", warning = "#ffda6a", danger = "#ea868f",
            },
        },
    }),

    blossom = M.define({
        name = "blossom",
        radii = { sm = 10, md = 18, lg = 28, pill = 999 },
        spacing = { xs = 4, sm = 10, md = 18, lg = 26, xl = 36 },
        typography = { lineHeight = 1.45 },
        light = {
            colors = {
                primary = "#d6336c", onPrimary = "#ffffff", background = "#fff5f8", surface = "#ffe3ec",
                elevated = "#ffffff", text = "#3d1a2a", textMuted = "#8a5f72", border = "#f3c2d4",
                separator = "#3d1a2a14", success = "#2f9e77", warning = "#e8a33d", danger = "#c92a54",
            },
        },
        dark = {
            colors = {
                primary = "#ff8fb1", onPrimary = "#420d22", background = "#1c0d15", surface = "#2b1420",
                elevated = "#3a1c2b", text = "#f7e3ea", textMuted = "#c2a0ae", border = "#4d2637",
                separator = "#f7e3ea14", success = "#63c9a4", warning = "#f0bf6b", danger = "#ff7d95",
            },
        },
    }),
}

M.base = BASE

return M
