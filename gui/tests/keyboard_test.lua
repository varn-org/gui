local gui = require("gui")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end


-- Focus is remembered wherever it is reported, which is what a reveal needs to know.
do
    local Screen = gui.component({
        name = "Screen",
        state = { text = "" },
        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.TextInput {
                    value = self.state.text,
                    onFocus = function() end,
                    onBlur = function() end,
                    onChange = function(value) self:setState({ text = value }) end,
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})
    local field = renderer:find("textinput")

    assert(runtime.focused == nil, "nothing has focus before anything is touched")

    runtime:dispatch(field.id, "onFocus", nil)
    assert(runtime.focused == field.id, "a field that reported focus is the one the runtime holds")

    runtime:dispatch(field.id, "onBlur", nil)
    assert(runtime.focused == nil, "a field that lost focus is let go of")
end

-- A field low in a scroll view is scrolled clear of the keyboard when the keyboard comes up.
--
-- Padding the bottom of a page does nothing for a field halfway down what scrolls, so the engine works
-- out how far short it falls from what its own layout already told it, and asks the surface to move.
do
    local renderer = gui.headless()
    local rows = {}

    for index = 1, 20 do
        rows[index] = gui.View { key = "row:" .. index, style = { height = 60 },
            gui.Text { text = "Row " .. index },
        }
    end

    rows[#rows + 1] = gui.TextInput {
        key = "field",
        value = "",
        onFocus = function() end,
        onChange = function() end,
        style = { height = 44 },
    }

    local runtime = gui.start(
        gui.ScrollView { style = { grow = 1 }, table.unpack(rows) },
        renderer,
        { size = { width = 390, height = 844 } }
    )

    for _ = 1, 4 do
        runtime:commit()
    end

    local field = renderer:find("textinput")
    local surface = renderer:find("scroll")

    runtime:dispatch(field.id, "onFocus", nil)
    assert(#renderer.calls == 0, "nothing is revealed while there is no keyboard to be behind")

    runtime:setKeyboard(336)
    runtime:commit()

    assert(#renderer.calls == 1, "a focused field behind the keyboard must be revealed once")

    local call = renderer.calls[1]
    assert(call.id == surface.id, "the surface holding the field is the one asked to move")
    assert(call.method == "scrollTo", "revealing a field is a scroll")

    -- The field sits 1200 down the content, is 44 tall, and 508 of the screen is left above the
    -- keyboard, so the surface has to be scrolled at least that far short.
    local clear = 844 - 336
    assert(call.arguments.y >= 1200 + 44 - clear,
        "the surface must be scrolled far enough to clear the keyboard, got " .. call.arguments.y)
    assert(call.arguments.animated == true, "a reveal is something a reader sees happen")
end

-- A field already clear of the keyboard is left where it is.
do
    local renderer = gui.headless()
    local runtime = gui.start(
        gui.ScrollView { style = { grow = 1 },
            gui.TextInput { value = "", onFocus = function() end, onChange = function() end,
                style = { height = 44 } },
        },
        renderer,
        { size = { width = 390, height = 844 } }
    )

    for _ = 1, 4 do
        runtime:commit()
    end

    runtime:dispatch(renderer:find("textinput").id, "onFocus", nil)
    runtime:setKeyboard(336)
    runtime:commit()

    assert(#renderer.calls == 0, "a field the keyboard does not cover is left alone")
end

print("gui.keyboard ok")
