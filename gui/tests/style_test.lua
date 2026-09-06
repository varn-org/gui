local color = require("gui.style.color")
local theme = require("gui.style.theme")

local function channels(value)
    local parsed = color.parse(value)
    return math.floor(parsed[1] + 0.5), math.floor(parsed[2] + 0.5), math.floor(parsed[3] + 0.5), parsed[4]
end

local function near(actual, expected, what)
    assert(math.abs(actual - expected) < 0.01, what .. ": expected " .. expected .. ", got " .. actual)
end

-- Six and eight digit hex both parse, and the short forms expand.
do
    local r, g, b, a = channels("#ff8000")
    assert(r == 255 and g == 128 and b == 0 and a == 1, "six digits must parse")

    r, g, b, a = channels("#ff800080")
    near(a, 128 / 255, "alpha")

    r, g, b = channels("#f80")
    assert(r == 255 and g == 136 and b == 0, "three digits must expand")
end

-- The functional forms parse, with and without alpha.
do
    local r, g, b, a = channels("rgb(10, 20, 30)")
    assert(r == 10 and g == 20 and b == 30 and a == 1, "rgb must parse")

    local _, _, _, alpha = channels("rgba(10, 20, 30, 0.5)")
    near(alpha, 0.5, "alpha")
end

-- A named colour resolves, and an unknown one is refused rather than silently black.
do
    local r, g, b = channels("white")
    assert(r == 255 and g == 255 and b == 255, "a name must resolve")

    local ok = pcall(color.parse, "chartreuse-ish")
    assert(not ok, "an unknown colour must be refused")
end

-- Hsl round-trips to the rgb it names.
do
    local r, g, b = channels("hsl(0, 100%, 50%)")
    assert(r == 255 and g == 0 and b == 0, "hsl red must be rgb red, got " .. r .. "," .. g .. "," .. b)
end

-- A renderer receives eight digit hex whatever the input form was.
do
    assert(color.toHex("rgb(255, 0, 0)") == "#ff0000ff", "got " .. color.toHex("rgb(255, 0, 0)"))
    assert(color.toHex("transparent") == "#00000000", "got " .. color.toHex("transparent"))
end

-- Lighten and darken move towards white and black without touching alpha.
do
    local lighter = color.parse(color.lighten("#000000", 0.5))
    near(lighter[1], 127.5, "lightened channel")

    local darker = color.parse(color.darken("#ffffff", 0.5))
    near(darker[1], 127.5, "darkened channel")

    local kept = color.parse(color.lighten("rgba(0, 0, 0, 0.25)", 0.5))
    near(kept[4], 0.25, "alpha must survive")
end

-- Contrast answers the ratio the accessibility guidelines define, and readable picks the better side.
do
    near(color.contrast("#ffffff", "#000000"), 21, "black on white is the maximum")
    assert(color.readable("#ffffff") == "#000000", "dark text reads on a light background")
    assert(color.readable("#000000") == "#ffffff", "light text reads on a dark background")
end

-- A theme resolves its own names and passes anything else through.
do
    local light = theme.create()

    assert(light:color("primary") == light.colors.primary, "a theme colour resolves by name")
    assert(light:color("#123456") == "#123456", "a literal colour passes through")
    assert(light:space("md") == 16, "a spacing step resolves by name")
    assert(light:space(7) == 7, "a number passes through")
    assert(light:fontSize("body") == 16, "a font size resolves by name")
end

-- Overriding a theme replaces only what it names.
do
    local branded = theme.create({ colors = { primary = "#ff0088" }, spacing = { md = 20 } })

    assert(branded.colors.primary == "#ff0088", "the override must win")
    assert(branded.colors.background == "#ffffff", "an untouched value must survive")
    assert(branded.spacing.md == 20, "a nested override must win")
    assert(branded.spacing.lg == 24, "an untouched nested value must survive")
end

-- The dark theme changes the surfaces and keeps the scale.
do
    local dark = theme.dark()

    assert(dark.colors.background == "#0b0b0f", "dark must change the background")
    assert(dark.spacing.md == 16, "dark must keep the spacing scale")
end

-- Two themes built from the same defaults do not share their tables.
do
    local first = theme.create()
    local second = theme.create()

    first.colors.primary = "#000000"
    assert(second.colors.primary ~= "#000000", "one theme must not mutate another")
    assert(theme.base.colors.primary ~= "#000000", "a theme must not mutate the defaults")
end

-- A width resolves to the breakpoint it falls into.
do
    local light = theme.create()

    assert(light:breakpoint(320) == "compact", "a phone is compact")
    assert(light:breakpoint(700) == "medium", "a small tablet is medium")
    assert(light:breakpoint(1200) == "expanded", "a desktop is expanded")
end

-- Asking for a name the theme does not carry is refused rather than answered with nil.
do
    local light = theme.create()
    assert(not pcall(light.space, light, "enormous"), "an unknown spacing must be refused")
    assert(not pcall(light.radius, light, "enormous"), "an unknown radius must be refused")
end

print("gui.style ok")
