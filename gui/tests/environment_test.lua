local gui = require("gui")
local wire = require("gui.bridge.wire")

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 320, height = 480 }
    return gui.start(description, renderer, options), renderer
end

-- A safe area turns the insets the platform reports into padding, with no platform check in the tree.
do
    local runtime, renderer = start(gui.SafeArea {
        style = { grow = 1 },
        gui.Text { text = "content" },
    })

    local before = renderer:find("text").frame
    assert(before.y == 0, "with no insets a safe area pads nothing")

    runtime:setInsets({ top = 47, bottom = 34, left = 0, right = 0 })
    runtime:commit()

    local after = renderer:find("text").frame
    assert(after.y == 47, "the top inset becomes padding, got " .. after.y)
    assert(renderer:find("safearea").frame.height == 480, "the area itself keeps the surface it fills")
end

-- A safe area avoids only the edges it was told to.
do
    local runtime, renderer = start(gui.SafeArea {
        edges = { "bottom" },
        style = { grow = 1 },
        gui.Text { text = "content" },
    })

    runtime:setInsets({ top = 47, bottom = 34, left = 0, right = 0 })
    runtime:commit()

    assert(renderer:find("text").frame.y == 0, "an edge that was not named is not avoided")
end

-- The keyboard is a layout input, so a screen leaves room for it without asking what platform it is on.
do
    local runtime, renderer = start(gui.KeyboardAvoiding {
        style = { grow = 1, justify = "end" },
        gui.TextInput { value = "", style = { height = 44 } },
    })

    assert(renderer:find("textinput").frame.y == 480 - 44, "the field sits at the bottom while nothing covers it")

    runtime:setKeyboard(300)
    runtime:commit()

    assert(renderer:find("textinput").frame.y == 480 - 300 - 44, "the field rises clear of the keyboard")

    runtime:setKeyboard(0)
    runtime:commit()

    assert(renderer:find("textinput").frame.y == 480 - 44, "the field returns when the keyboard goes")
end

-- An offset says how much of the keyboard is already accounted for.
do
    local runtime, renderer = start(gui.KeyboardAvoiding {
        offset = 50,
        style = { grow = 1, justify = "end" },
        gui.TextInput { value = "", style = { height = 44 } },
    })

    runtime:setKeyboard(300)
    runtime:commit()

    assert(renderer:find("textinput").frame.y == 480 - 250 - 44, "the offset is taken off the room made")
end

-- A node that asks for no avoidance gets none.
do
    local runtime, renderer = start(gui.KeyboardAvoiding {
        behavior = "none",
        style = { grow = 1, justify = "end" },
        gui.TextInput { value = "", style = { height = 44 } },
    })

    runtime:setKeyboard(300)
    runtime:commit()

    assert(renderer:find("textinput").frame.y == 480 - 44, "a node that avoids nothing stays where it is")
end

-- A transform is resolved into the fields every renderer applies, and layout ignores it.
do
    local _, renderer = start(gui.View {
        style = { width = 100, height = 50 },
        gui.Text { text = "spun", style = { transform = { rotate = 45, scale = 2 } } },
    })

    local label = renderer:find("text")
    local transform = label.props.style.transform

    assert(transform.rotate == 45, "a rotation reaches the renderer")
    assert(transform.scaleX == 2 and transform.scaleY == 2, "one scale sets both axes")
    assert(transform.translateX == 0 and transform.translateY == 0, "a field left out takes its neutral value")
    assert(label.frame.width == 100, "a transform moves what is drawn rather than what is measured")
end

-- A transform refuses a field no renderer knows what to do with.
do
    local ok, message = pcall(function()
        return gui.resolveStyle({ transform = { spin = 3 } }, gui.theme.create(), "compact")
    end)

    assert(not ok, "an unknown transform field must be refused")
    assert(tostring(message):find("spin"), "the refusal names the field")
end

-- A renderer receives concrete values, never a name only the theme knows.
do
    local runtime, renderer = start(gui.View {
        style = { background = "surface", padding = "md", radius = "lg" },
        gui.Text { text = "labelled", style = { color = "text", fontSize = "title" } },
    })

    local box = renderer:find("view").props.style
    local label = renderer:find("text").props.style

    assert(box.background:sub(1, 1) == "#", "a colour token resolves to a colour, got " .. tostring(box.background))
    assert(type(box.padding) == "number", "a spacing token resolves to a number")
    assert(type(box.radius) == "number", "a radius token resolves to a number")
    assert(type(label.fontSize) == "number", "a type scale token resolves to a size")

    local before = box.background
    runtime:setTheme(gui.theme.dark())
    runtime:commit()

    assert(renderer:find("view").props.style.background ~= before, "a new theme reaches every node that was already there")
end

-- A handler never travels, so a batch is json and nothing else.
do
    local encoded = wire.encode({
        {
            op = "create",
            id = 1,
            type = "button",
            props = {
                title = "Go",
                onPress = function() end,
                style = { color = "#ff0000", padding = 8 },
                cleared = gui.protocol.removed,
            },
        },
    })

    local props = encoded[1].props

    assert(props.onPress == true, "a handler becomes a marker the renderer binds")
    assert(props.cleared == "__varn_removed__", "the removed sentinel travels as text")
    assert(props.style.color == "#ff0000", "a nested table keeps its values")
    assert(props.title == "Go", "a plain value is left alone")
end

-- A prop that cannot cross is refused rather than sent as something else.
do
    local cyclic = {}
    cyclic.self = cyclic

    local ok = pcall(wire.encode, { { op = "update", id = 1, props = { style = cyclic } } })
    assert(not ok, "a cycle in a prop must be refused")
end

print("gui.environment ok")
