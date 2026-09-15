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

    -- The field declares no handler for focus, because a screen has no reason to and this one is what
    -- every screen with a field looks like. Declaring one here is what hid the defect: a renderer binds
    -- an event when a handler for it crosses, so nothing was bound, nothing was reported, the engine
    -- never learnt which field had the keyboard, and the keyboard came up over the field that had just
    -- been pressed. A field says it has taken focus because the engine needs to know, not because the
    -- screen asked.
    rows[#rows + 1] = gui.TextInput {
        key = "field",
        value = "",
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

-- A screen that fits is given the room the keyboard takes, and is put back where it was afterwards.
--
-- A surface has nothing to scroll while its content fits inside it, so a reveal that asked it to move
-- anyway pushed the screen off its own top with no row below to come back from: every field screen was
-- thrown up when the keyboard arrived and left there for the rest of the session. The room the keyboard
-- needs is made by the layout, which is what every platform's own inset is, and taking it back is what
-- brings the screen down again.
do
    local renderer = gui.headless()

    local runtime = gui.start(
        gui.ScrollView { style = { grow = 1 },
            gui.View { key = "above", style = { height = 700 } },
            gui.TextInput { key = "field", value = "", onChange = function() end, style = { height = 44 } },
        },
        renderer,
        { size = { width = 390, height = 844 } }
    )

    for _ = 1, 4 do
        runtime:commit()
    end

    local surface = renderer:find("scroll")

    assert(surface.props.contentExtent == 744,
        "a surface holding 744 points of content says so, said " .. tostring(surface.props.contentExtent))

    runtime:dispatch(renderer:find("textinput").id, "onFocus", nil)
    runtime:setKeyboard(336)
    runtime:commit()

    assert(surface.props.contentExtent == 744 + 336,
        "the room the keyboard took is given back to the surface, which says "
            .. tostring(surface.props.contentExtent))

    assert(#renderer.calls == 1, "the field behind the keyboard is revealed once")

    local lifted = renderer.calls[1].arguments.y

    assert(lifted > 0 and lifted <= 336,
        "and it is lifted by no more than the room it was given, by " .. lifted)

    runtime:setKeyboard(0)
    runtime:commit()

    assert(surface.props.contentExtent == 744, "the room goes back when the keyboard does")
    assert(#renderer.calls == 2, "and the surface is brought back inside its own content")
    assert(renderer.calls[2].arguments.y == 0,
        "which is the top again, got " .. renderer.calls[2].arguments.y)
end

-- A surface is asked for its offset while the keyboard is up, and not once it has gone.
do
    local renderer = gui.headless()

    local runtime = gui.start(
        gui.ScrollView { style = { grow = 1 },
            gui.View { key = "above", style = { height = 2000 } },
            gui.TextInput { key = "field", value = "", onChange = function() end, style = { height = 44 } },
        },
        renderer,
        { size = { width = 390, height = 844 } }
    )

    for _ = 1, 4 do
        runtime:commit()
    end

    local surface = renderer:find("scroll")

    assert(surface.props.onScroll == nil, "a surface nothing is watching keeps its offset to itself")

    runtime:setKeyboard(336)
    runtime:commit()

    assert(surface.props.onScroll == true,
        "and reports it while there is a keyboard to lift a field clear of")

    runtime:setKeyboard(0)
    runtime:commit()

    assert(surface.props.onScroll == nil, "and stops once there is not")
end

-- Every type that takes the keyboard says so, whether or not the screen it is on cares.
do
    local renderer = gui.headless()

    gui.start(gui.ScrollView { style = { grow = 1 },
        gui.TextInput { key = "one", value = "", onChange = function() end },
        gui.TextArea { key = "two", value = "", onChange = function() end },
        gui.SearchBar { key = "three", value = "", onChange = function() end },
    }, renderer, { size = { width = 390, height = 844 } })

    for _, kind in ipairs({ "textinput", "textarea", "searchbar" }) do
        local node = renderer:find(kind)

        assert(node.props.onFocus == true, "a " .. kind .. " must report taking the keyboard")
        assert(node.props.onBlur == true, "and giving it up")
    end
end


-- A field told to grow is as tall as what is in it, and one told a number of rows is not.
--
-- The height of a growing field is a measurement of its own text, which changes on every keystroke and
-- is the one measurement the engine caches. A field that ignored it would be the right height once and
-- then wrong for the rest of the typing.
do
    local function tall(value, grows)
        local renderer = gui.headless()

        local runtime = gui.start(gui.View { style = { width = 300 },
            gui.TextArea { value = value, grows = grows, onChange = function() end },
        }, renderer, { size = { width = 300, height = 900 } })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        return renderer:find("textarea").frame.height
    end

    local many = string.rep("a long line of words ", 20)

    assert(tall("one", false) == tall(many, false),
        "a field of a fixed number of rows is that tall whatever is written into it")

    local empty = tall("", true)
    local two = tall("one\ntwo", true)
    local lots = tall(many, true)

    assert(empty > 0, "a growing field that is empty is still a field, was " .. empty)
    assert(two > empty, "and is taller with two lines in it, " .. two .. " against " .. empty)
    assert(lots > two, "and taller again with many, " .. lots .. " against " .. two)
end

print("gui.keyboard ok")
