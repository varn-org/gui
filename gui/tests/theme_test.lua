local gui = require("gui")
local theme = require("gui.style.theme")

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 390, height = 844 }

    local runtime = gui.start(description, renderer, options)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- Answers the background a box was drawn with, which is what a theme decided.
local function painted(renderer, kind)
    return renderer:find(kind or "view").props.style.background
end

local OCEAN = theme.define({
    name = "ocean",
    spacing = { md = 20 },
    typography = { family = "Inter" },
    light = { colors = { primary = "#00668b", background = "#f2fbff" } },
    dark = { colors = { primary = "#7fd0ff", background = "#04121a" } },
})

-- A look is one design with an appearance on each side of it, rather than two designs.
do
    assert(theme.isLook(OCEAN), "what define answers is a look")
    assert(OCEAN.light:color("primary") == "#00668b", "the light side carries the light colours")
    assert(OCEAN.dark:color("primary") == "#7fd0ff", "and the dark side its own")

    -- Everything written outside the two sides belongs to both, since a design is one thing.
    assert(OCEAN.light:space("md") == 20, "what both sides share is on the light one")
    assert(OCEAN.dark:space("md") == 20, "and on the dark one")
    assert(OCEAN.dark.typography.family == "Inter", "including the face it is all set in")

    -- What the framework carries is a look like any other, so nothing is a special case.
    assert(theme.isLook(theme.builtin), "the framework's own is a look too")
end

-- An application with a look of its own still follows the device, since a look has both sides in it.
do
    local runtime, renderer = start(gui.View { style = { grow = 1, background = "background" } },
        { theme = OCEAN })

    assert(painted(renderer) == "#f2fbffff", "it opens on the side the device is set to, got " .. painted(renderer))

    runtime:setAppearance("dark")
    runtime:commit()

    assert(painted(renderer) == "#04121aff",
        "and follows the device into the dark rather than staying where it was, got " .. painted(renderer))

    runtime:setAppearance("light")
    runtime:commit()

    assert(painted(renderer) == "#f2fbffff", "and back again")
end

-- One theme rather than a look is an application pinned to it, whatever the device is set to.
do
    local runtime, renderer = start(gui.View { style = { grow = 1, background = "background" } },
        { theme = theme.create({ colors = { background = "#fff8e1" } }) })

    assert(painted(renderer) == "#fff8e1ff", "it is drawn in the theme it was given")

    runtime:setAppearance("dark")
    runtime:commit()

    assert(painted(renderer) == "#fff8e1ff", "and stays there, since one theme is a look with one side")
end

-- A look changed while the application runs redraws everything in it.
do
    local runtime, renderer = start(gui.View { style = { grow = 1, background = "background" } })

    assert(painted(renderer) == "#ffffffff", "it opens in the framework's own look")

    runtime:setTheme(OCEAN)
    runtime:commit()

    assert(painted(renderer) == "#f2fbffff", "and is drawn in the one it was given, got " .. painted(renderer))
end

-- What a platform paints around the tree is the theme's, since none of it is a node.
do
    local runtime, renderer = start(gui.View { style = { grow = 1 } }, { theme = OCEAN })

    assert(renderer.ground ~= nil, "the renderer is told what to paint its own ground in")
    assert(renderer.ground.background == "#f2fbffff", "which is the ground the look carries")
    assert(renderer.ground.primary == "#00668bff", "and what it draws a selection and an accent in")
    assert(renderer.ground.family == "Inter", "and the face a control the platform owns writes in")
    assert(renderer.ground.appearance == "light", "and the scheme it resolves its own colours against")

    runtime:setAppearance("dark")
    runtime:commit()

    assert(renderer.ground.background == "#04121aff", "a device turned dark repaints the ground too")
    assert(renderer.ground.appearance == "dark", "and says which scheme it is now in")
end

-- A look reaches every component through the theme the tree is drawn with, rather than through a global.
do
    local Reader = gui.component({
        name = "ThemeReader",
        render = function(self)
            return gui.Text { text = "read", style = { color = "primary" } }
        end,
    })

    local _, renderer = start(Reader {}, { theme = OCEAN, appearance = "dark" })

    assert(renderer:find("text").props.style.color == "#7fd0ffff",
        "a component is drawn in the side of the look the device is set to")
end

-- A screen deep in the tree puts the application in another look, and knows which one it is in.
do
    local Settings = gui.component({
        name = "LookSettings",
        render = function(self)
            local wearing = gui.theming:read(self)

            return gui.View { style = { grow = 1, background = "background" },
                gui.Text { text = "wearing " .. wearing.name },

                gui.Pressable {
                    accessibilityLabel = "Ocean",
                    onPress = function() wearing.use(OCEAN) end,
                    gui.Text { text = "ocean" },
                },
            }
        end,
    })

    local runtime, renderer = start(Settings {})

    local function said()
        local found = {}

        for _, node in pairs(renderer.nodes) do
            if node.type == "text" then
                found[#found + 1] = node.props.text
            end
        end

        return table.concat(found, ",")
    end

    assert(said():find("wearing varn", 1, true) ~= nil, "a screen is told which look it is in, said " .. said())

    local pressable = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.accessibilityLabel == "Ocean" then
            pressable = node
        end
    end

    runtime:dispatch(pressable.id, "onPress", nil)
    runtime:commit()

    assert(painted(renderer) == "#f2fbffff",
        "and putting the application in another one draws it in that one, got " .. tostring(painted(renderer)))
    assert(said():find("wearing ocean", 1, true) ~= nil,
        "and the screen that asked is told what it is now in, said " .. said())
end

-- A tree nobody is holding says so rather than doing nothing at all.
do
    assert(not pcall(gui.theming.default.use, OCEAN), "a look asked for with no runtime holding it is refused")
end

-- The looks the framework ships are looks like any other, with both sides and a design of their own.
do
    local shipped = { "nuxt", "bootstrap", "blossom" }

    for index = 1, #shipped do
        local name = shipped[index]
        local look = theme.looks[name]

        assert(theme.isLook(look), name .. " is a look")
        assert(look.name == name, "named as what it is, is named " .. tostring(look.name))
        -- A brand colour is often the same on both sides, which is the point of it, so what has to
        -- differ is the ground: light and dark are two views of one design rather than two designs.
        assert(look.light:color("background") ~= look.dark:color("background"),
            name .. " stands on a different ground on each side of itself")
        assert(look.light:color("primary") ~= theme.builtin.light:color("primary"),
            name .. " is a design of its own rather than the framework's")
        assert(look.light:radius("md") == look.dark:radius("md"),
            name .. " carries one set of corners, since a design is one thing")
    end
end

-- Changing the look repaints everything painted from it, not only what a style paints.
--
-- A colour reaches a renderer four ways: a style, the tint a control draws its own mark in, the run of
-- colours a gradient is, and the commands a canvas draws. A look change re-sent the styles alone, so a
-- switch, a spinner and the chevron of a way back stayed in the colours of the look before it — which is
-- every part of a screen the platform draws rather than the tree.
do
    local renderer = gui.headless()
    local runtime = gui.start(
        gui.View { style = { grow = 1 },
            gui.Icon { name = "chevron-left", size = 20, color = "primary" },
            gui.Switch { value = true, onColor = "primary" },
            gui.Gradient { colors = { "primary", "background" }, style = { height = 40 } },
        },
        renderer,
        { size = { width = 320, height = 640 } }
    )

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local function painted(kind, name)
        local found = renderer:findAll(kind)

        assert(#found > 0, "the tree must draw a " .. kind)
        return found[1].props[name]
    end

    local before = {
        mark = painted("canvas", "commands")[1].color,
        switch = painted("switch", "onColor"),
        gradient = painted("gradient", "colors")[1],
    }

    runtime:setTheme(theme.looks.blossom)
    runtime:commit()

    assert(painted("canvas", "commands")[1].color ~= before.mark,
        "the colour a mark is drawn in follows the look, stayed " .. tostring(before.mark))
    assert(painted("switch", "onColor") ~= before.switch,
        "and so does the tint of a control the platform draws, stayed " .. tostring(before.switch))
    assert(painted("gradient", "colors")[1] ~= before.gradient,
        "and so does a run of colours, stayed " .. tostring(before.gradient))
end

-- A subtree wears a look of its own and nothing around it moves.
--
-- An application wears one look and that is nearly always the whole of it, but a gallery showing five
-- applications, a page serving two brands and a product drawn in a customer's colours all need one
-- branch of a tree coloured differently from the rest. Every colour is resolved on the way out of the
-- runtime, so this is the runtime knowing which look governs which node rather than anything a screen
-- carries, which is why it is worth a case of its own.
do
    local ORANGE = theme.define({
        name = "orange",
        light = { colors = { primary = "#ff7a00" } },
        dark = { colors = { primary = "#ff9a3c" } },
    })

    local Two = gui.component({
        name = "TwoLooks",

        render = function()
            return gui.View { style = { grow = 1 },
                gui.View { key = "outside", testID = "outside", style = { height = 10, background = "primary" } },

                gui.Look { value = ORANGE, style = { grow = 1 },
                    gui.View { key = "inside", testID = "inside",
                        style = { height = 10, background = "primary" } },
                },
            }
        end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(Two {}, renderer, { size = { width = 320, height = 480 } })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local function ground(id)
        for _, node in pairs(renderer.nodes) do
            if node.props.testID == id then
                return (node.props.style or {}).background
            end
        end

        return nil
    end

    assert(ground("inside") == "#ff7a00ff",
        "what is under a Look is painted in it, painted " .. tostring(ground("inside")))
    assert(ground("outside") ~= ground("inside"),
        "and what is beside it is painted in the application's own, painted " .. tostring(ground("outside")))

    -- The device turning dark reaches both sides of both looks, since a look carries two of itself.
    local before = ground("inside")

    runtime:setAppearance("dark")
    runtime:commit()
    runtime:commit()

    assert(ground("inside") == "#ff9a3cff",
        "a subtree follows the device between light and dark, painted " .. tostring(ground("inside")))
    assert(ground("inside") ~= before, "which is a different colour from the light side")

    runtime:stop()
end

print("gui.theme ok")
