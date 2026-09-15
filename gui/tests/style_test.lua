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

-- A colour call missing a channel is refused where it is written, naming what was written.
--
-- Read as far as it goes and passed on, a colour with a channel missing is a nil arriving inside the
-- arithmetic that renders it: a commit that fails naming a line of the colour parser rather than the
-- colour an application wrote, on a screen a reader is looking at.
do
    local written = { "rgb(255, 0)", "rgb(255, 0, blue)", "rgba(1, 2, 3, none)", "hsl(0, 100%)", "hsl(x, 1%, 2%)" }

    for index = 1, #written do
        local ok, problem = pcall(color.parse, written[index])

        assert(not ok, written[index] .. " must be refused")
        assert(tostring(problem):find(written[index], 1, true) ~= nil,
            "and the refusal must name it, got " .. tostring(problem))
    end

    local ok = pcall(color.parse, { 10, 20 })
    assert(not ok, "a table of channels with one missing must be refused too")
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

    assert(dark.colors.background == "#101014", "dark must change the background")
    assert(dark.colors.indigo300 == "#7986cb", "and must keep every family it was built with")
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

-- A field a style carries is one something honours, and anything else is refused where it is written.
--
-- A misspelling reaches three renderers that each ignore it, so a caller who wrote `colr` is shown a box
-- with no colour and told nothing at all. The props of a node are held to what a component declares, and
-- a style is the other half of the same promise.
do
    local resolve = require("gui.style.resolve")
    local light = theme.create()

    local misspelled = { "colr", "backgroundd", "fontSizee", "paddingg", "onPress" }

    for index = 1, #misspelled do
        local wrong = { [misspelled[index]] = 1 }
        local ok, problem = pcall(resolve.resolve, wrong, light, "compact")

        assert(not ok, misspelled[index] .. " must be refused")
        assert(tostring(problem):find(misspelled[index], 1, true) ~= nil,
            "and the refusal must name it, got " .. tostring(problem))
    end

    local right = resolve.resolve({ color = "text", padding = "md", marginHorizontal = "sm", grow = 1 },
        light, "compact")

    assert(type(right.color) == "string" and right.padding > 0 and right.marginHorizontal > 0,
        "and every field the engine honours still resolves")
end

-- A distance below nothing, and a share that is not a number, are refused where they are written.
--
-- A negative size reaches three renderers that each make something different of it: an inverted rect on
-- one, a frame the platform refuses on another, and a declaration the browser drops. A share that is not
-- a number fails inside the arithmetic that lays the box out, naming a line of the layout engine.
do
    local resolve = require("gui.style.resolve")
    local light = theme.create()

    local refused = {
        { width = -100 }, { height = -1 }, { padding = -20 }, { gap = -8 }, { radius = -4 },
        { borderTop = -2 }, { minHeight = -1 }, { basis = -3 },
        { grow = "plenty" }, { grow = -1 }, { shrink = {} },
    }

    for index = 1, #refused do
        local name = next(refused[index])
        local ok, problem = pcall(resolve.resolve, refused[index], light, "compact")

        assert(not ok, name .. " of " .. tostring(refused[index][name]) .. " must be refused")
        assert(tostring(problem):find(name, 1, true) ~= nil,
            "and the refusal must name it, got " .. tostring(problem))
    end

    -- A margin pulls a box outside the one that holds it, which is how a panel wider than its anchor is
    -- centred on it, and an offset places a box relative to where it would have been.
    local pulled = resolve.resolve({ marginLeft = -34, top = -26, left = "50%", grow = 0 }, light, "compact")

    assert(pulled.marginLeft == -34 and pulled.top == -26,
        "a margin and an offset are still allowed below nothing")
end

-- A colour is painted whatever shape it was written in, and refused when it is no shape at all.
do
    local resolve = require("gui.style.resolve")
    local light = theme.create()

    local painted = resolve.resolve({ background = { 255, 0, 0 }, color = "primary" }, light, "compact")

    assert(painted.background == "#ff0000ff", "a table of channels is painted, got " .. tostring(painted.background))
    assert(painted.color == color.toHex(light.colors.primary),
        "and a name resolves to what the theme carries, got " .. tostring(painted.color))

    local ok, problem = pcall(resolve.resolve, { color = 42 }, light, "compact")

    assert(not ok, "a colour that is a number must be refused")
    assert(tostring(problem):find("colour", 1, true) ~= nil, "naming what it is, got " .. tostring(problem))
end

-- A theme is built from families of names, and one replaced by something else answers nothing at all.
do
    local ok, problem = pcall(theme.create, { colors = "blue" })

    assert(not ok, "a family that is not a table must be refused")
    assert(tostring(problem):find("colors", 1, true) ~= nil, "naming it, got " .. tostring(problem))

    assert(not pcall(theme.create, "dark"), "and so must a theme built from something that is not a table")
    assert(not pcall(theme.create().breakpoint, theme.create(), "wide"),
        "a breakpoint is chosen by how wide the surface is")
end

-- Every field the layout reads is one a caller may write, read from the layout rather than remembered.
--
-- A field added to the engine and forgotten here is a style that works everywhere except where it is
-- written, which is worse than one that was never offered.
do
    local async = require("async")
    local fs = require("fs")
    local resolve = require("gui.style.resolve")

-- A run of text is laid over the style of the paragraph it sits in, since that is what a run is.
--
-- A browser inherits the colour and the size from the element, and a phone builds each run's attributes
-- from that run's style alone. So a run that named a weight and nothing else came out in the paragraph's
-- colour on one and in black on the other, which on a dark screen is a sentence with a hole in it. The
-- laying over happens once, here, so the three cannot disagree.
do
    local gui = require("gui")
    local renderer = gui.headless()

    local runtime = gui.start(gui.RichText {
        style = { color = "#112233", fontSize = 21 },
        spans = {
            { text = "plain " },
            { text = "bold", style = { fontWeight = "700" } },
            { text = " red", style = { color = "#ff0000" } },
        },
    }, renderer, { size = { width = 320, height = 200 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local spans = renderer:find("richtext").props.spans

    assert(spans[1].style.color == "#112233ff", "a run with no style of its own is the paragraph's")
    assert(spans[2].style.color == "#112233ff", "a run that named a weight keeps the paragraph's colour")
    assert(spans[2].style.fontWeight == "700", "and its own weight")
    assert(spans[2].style.fontSize == 21, "and the paragraph's size")
    assert(spans[3].style.color == "#ff0000ff", "and a run that named a colour keeps its own")
end


    async.run(function()
        local source = fs.readFile("gui/layout/flex.lua"):await()
        local known = resolve.known()
        local missing = {}

        for name in source:gmatch("style%.(%a+)") do
            if known[name] == nil then
                missing[#missing + 1] = name
            end
        end

        for _, family in ipairs({ "margin", "padding", "border" }) do
            if source:find('readEdges(style, "' .. family .. '")', 1, true) == nil then
                missing[#missing + 1] = family .. " is no longer read as a box property"
            end
        end

        assert(#missing == 0, "the layout reads fields a style may not carry: " .. table.concat(missing, ", "))

        print("gui.style ok")
    end)
end
