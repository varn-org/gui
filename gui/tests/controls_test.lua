local controls = require("gui.controls")
local gui = require("gui")
local headless = require("gui.bridge.headless")

--- Answers the tree a description is drawn as under a control theme, and the runtime holding it.
local function drawn(description, theme)
    local renderer = headless.create()
    local app = gui.start(description, renderer, { size = { width = 360, height = 640 }, controls = theme })

    return renderer, app
end

--- Answers every node of a type, in the order the renderer was told to build them.
local function every(renderer, type)
    local order = {}

    for id in pairs(renderer.nodes) do
        order[#order + 1] = id
    end

    table.sort(order)

    local found = {}

    for index = 1, #order do
        local node = renderer.nodes[order[index]]

        if type == nil or node.type == type then
            found[#found + 1] = node
        end
    end

    return found
end

--- Answers the nodes under a node, which is how a drawn control's own parts are reached.
---
--- Walking the whole tree by type reaches whatever the test wrapped the control in as well, so a switch
--- inside a column is asserted against the column. A control's parts are the ones under it.
local function under(renderer, node)
    local found = {}

    local function walk(held)
        local children = held.children or {}

        for index = 1, #children do
            local child = renderer.nodes[children[index]]

            found[#found + 1] = child
            walk(child)
        end
    end

    walk(node)
    return found
end

--- Answers the nodes of a type under a node.
local function partsOf(renderer, node, type)
    local found = {}

    for _, held in ipairs(under(renderer, node)) do
        if held.type == type then
            found[#found + 1] = held
        end
    end

    return found
end

--- Commits until nothing more is owed, which is what a control that shows something over the screen needs.
local function settle(app)
    for _ = 1, 6 do
        if not app:needsCommit() then
            return
        end

        app:commit()
    end
end

--- Answers the first node carrying a role, which is what a drawn control announces itself as.
local function byRole(renderer, role)
    local nodes = every(renderer)

    for index = 1, #nodes do
        if nodes[index].props.accessibilityRole == role then
            return nodes[index]
        end
    end

    return nil
end

-- A control theme is a complete set, and one that leaves a control out is refused where it is written.
do
    local ok, problem = pcall(controls.define, { name = "half", controls = { button = controls.platform } })

    assert(not ok, "a control theme that says nothing about a control must be refused")
    assert(tostring(problem):find("say nothing about", 1, true) ~= nil,
        "and it must name what is missing, it said " .. tostring(problem))

    local named = pcall(controls.define, {
        name = "odd",
        controls = { sprocket = controls.platform },
    })

    assert(not named, "a control theme describing something that is not a control must be refused")
end

-- A part painted in no state at all is refused, since rest is what every other state falls back to.
do
    local entry = {
        metrics = { size = 1 },
        paint = { box = { on = "primary" } },
        motion = { duration = 1 },
        press = "none",
    }

    local built = {}

    for _, name in ipairs(controls.kinds()) do
        built[name] = controls.platform
    end

    built.checkbox = entry

    local ok, problem = pcall(controls.define, { name = "restless", controls = built })

    assert(not ok, "a part with no rest must be refused")
    assert(tostring(problem):find("rest is the one it needs", 1, true) ~= nil,
        "and it must say what is missing, it said " .. tostring(problem))
end

-- A state is a refinement, so a theme carries only what it changes and the rest falls through.
do
    local theme = controls.material3

    assert(theme:paint("switch", "track", {}) == "surfaceVariant", "a switch at rest takes the rest colour")
    assert(theme:paint("switch", "track", { "on" }) == "primary", "and the on colour when it is on")

    -- Nothing says what pressing does to a switch that is on, so it stays painted as one that is on.
    assert(theme:paint("switch", "track", { "pressed", "on" }) == "primary",
        "a state a theme says nothing about falls through to the one under it")
end

-- A control theme extended from another is the one it came from with what it changes written over it.
do
    local squared = controls.extend(controls.material3, {
        name = "squared",
        controls = { button = { metrics = { radius = 4 } } },
    })

    assert(squared.name == "squared", "the new name is taken")
    assert(squared:metric("button", "radius") == 4, "what it changed is changed")
    assert(squared:metric("button", "height") == controls.material3:metric("button", "height"),
        "and everything it did not name is what it came from")
    assert(controls.material3:metric("button", "radius") == "pill",
        "the theme it came from is untouched")
end

-- Under the platform's own controls a switch is one node, and the renderer builds the control itself.
do
    local renderer = drawn(gui.View { gui.Switch { value = true } }, nil)
    local switches = every(renderer, "switch")

    assert(#switches == 1, "the platform draws a switch, so there is one of them, got " .. #switches)
    assert(switches[1].props.value == true, "and it is told what it is")
    assert(#every(renderer, "pressable") == 0, "nothing is drawn around it")
end

-- Under a drawn control theme the same description is a track, a thumb and the mark inside it.
do
    local renderer, app = drawn(gui.View { gui.Switch { value = true } }, controls.material3)

    assert(#every(renderer, "switch") == 0, "no platform switch is built")

    local pressed = byRole(renderer, "switch")

    assert(pressed ~= nil, "the drawn switch says what it is")
    assert(pressed.props.accessibilityState.checked == true, "and that it is on")

    local boxes = partsOf(renderer, pressed, "view")

    assert(#boxes == 2, "a track and a thumb, got " .. #boxes .. " boxes")

    local track = boxes[1]
    local thumb = boxes[2]

    assert(track.props.style.width == controls.material3:metric("switch", "width"),
        "the track is as wide as the theme says")
    assert(thumb.props.style.width == controls.material3:metric("switch", "thumbOn"),
        "and a switch that is on carries the larger thumb")

    -- The thumb travels rather than being laid out where it lands, since a transform is what animates.
    local travel = controls.material3:metric("switch", "width")
        - controls.material3:metric("switch", "thumbOn")
        - controls.material3:metric("switch", "inset") * 2

    assert(thumb.props.style.transform.translateX == travel,
        "the thumb is moved to the far end, by " .. tostring(thumb.props.style.transform.translateX))

    local frame = app.frames[pressed.id]

    assert(frame.width == math.max(controls.material3:metric("switch", "width"),
        controls.material3:metric("switch", "touch")),
        "a drawn control is its own width rather than the column's, it is " .. frame.width)
end

-- A switch that is off carries the smaller thumb and does not travel, which is what the theme says.
do
    local renderer = drawn(gui.View { gui.Switch { value = false } }, controls.material3)
    local thumb = partsOf(renderer, byRole(renderer, "switch"), "view")[2]

    assert(thumb.props.style.width == controls.material3:metric("switch", "thumb"),
        "an unchosen switch carries the smaller thumb")
    assert(thumb.props.style.transform.translateX == 0, "and it has not moved")
end

-- Two control themes draw the same switch at two different sizes, which is the whole point of one.
do
    local apple = drawn(gui.View { gui.Switch { value = true } }, controls.cupertino)
    local material = drawn(gui.View { gui.Switch { value = true } }, controls.material3)

    local one = partsOf(apple, byRole(apple, "switch"), "view")[1].props.style
    local other = partsOf(material, byRole(material, "switch"), "view")[1].props.style

    assert(one.width ~= other.width,
        "two designs draw a switch at two widths, both came out " .. tostring(one.width))
end

-- A checkbox draws the mark as a path, so it is the same shape everywhere rather than a glyph.
do
    local renderer = drawn(gui.View { gui.Checkbox { value = true, label = "Keep it" } }, controls.material3)
    local marks = every(renderer, "canvas")

    assert(#marks == 1, "a ticked checkbox draws one mark, got " .. #marks)
    assert(#marks[1].props.commands >= 1, "and the mark is drawn rather than written")

    local box = byRole(renderer, "checkbox")

    assert(box.props.accessibilityState.checked == true, "it says it is ticked")
    assert(box.props.accessibilityLabel == "Keep it", "and it is called what it says")
end

-- A checkbox that is neither on nor off draws a bar rather than a tick.
do
    local renderer = drawn(gui.View { gui.Checkbox { indeterminate = true } }, controls.material3)
    local mark = every(renderer, "canvas")[1]

    assert(mark ~= nil, "a checkbox in between draws something")
    assert(#mark.props.commands[1].path == 2, "and what it draws is a bar rather than a tick")

    assert(byRole(renderer, "checkbox").props.accessibilityState.checked == false,
        "a checkbox in between is not ticked")
end

-- A radio keeps its dot at every moment and scales it, since what a renderer animates is the transform.
do
    local chosen = drawn(gui.View { gui.Radio { value = "a", selected = true } }, controls.material3)
    local not_chosen = drawn(gui.View { gui.Radio { value = "a", selected = false } }, controls.material3)

    local one = partsOf(chosen, byRole(chosen, "radio"), "view")[2].props.style
    local other = partsOf(not_chosen, byRole(not_chosen, "radio"), "view")[2].props.style

    assert(one.opacity == 1 and other.opacity == 0, "the dot is shown or hidden rather than built")
    assert(one.transform.scale == 1 and other.transform.scale < 1, "and it grows into place")
end

-- Pressing a drawn control reports the value it was not at, which is what the native one reports.
do
    local told = nil
    local renderer, app = drawn(gui.View {
        gui.Switch { value = false, onChange = function(value) told = value end },
    }, controls.material3)

    local pressed = byRole(renderer, "switch")

    app:dispatch(pressed.id, "onPress", nil)

    assert(told == true, "a switch that was off reports being turned on, it said " .. tostring(told))
end

-- A button carries the shape its control theme draws, and the variant chooses what it is made of.
do
    local renderer = drawn(gui.View {
        gui.Button { title = "Send" },
        gui.Button { title = "Cancel", variant = "outlined" },
    }, controls.material3)

    local buttons = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        if node.props.accessibilityRole == "button" then
            buttons[#buttons + 1] = node
        end
    end

    assert(#buttons == 2, "two buttons, got " .. #buttons)
    assert(buttons[1].props.style.background ~= nil, "a filled button has a ground")
    assert(buttons[2].props.style.background == nil, "an outlined one does not")
    assert(buttons[2].props.style.border == controls.material3:metric("button", "border"),
        "and it carries the outline the theme draws")
end

-- A segmented control says which segment is chosen, one segment at a time.
do
    local renderer = drawn(gui.View {
        gui.SegmentedControl { segments = { "Day", "Week", "Month" }, selectedIndex = 2 },
    }, controls.cupertino)

    local chosen = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        if node.props.accessibilityRole == "tab" then
            chosen[#chosen + 1] = node.props.accessibilityState.selected == true
        end
    end

    assert(#chosen == 3, "three segments, got " .. #chosen)
    assert(not chosen[1] and chosen[2] and not chosen[3],
        "the second is the chosen one and nothing else is")
end

-- A stepper refuses the press that would take it past its end rather than reporting the same value.
do
    local told = {}
    local renderer, app = drawn(gui.View {
        gui.Stepper { value = 9, minimum = 0, maximum = 9, onChange = function(value) told[#told + 1] = value end },
    }, controls.material3)

    local keys = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        keys[node.props.accessibilityLabel] = node
    end

    assert(keys.More.props.disabled == true, "a stepper at its end cannot be pressed further")
    assert(keys.Less.props.disabled == false, "and it can still come back")

    app:dispatch(keys.Less.id, "onPress", nil)

    assert(#told == 1 and told[1] == 8, "pressing down reports one step down, it said " .. tostring(told[1]))
end

-- A rating draws one mark per count and fills them up to the value.
do
    local renderer = drawn(gui.View { gui.Rating { value = 3, count = 5 } }, controls.material3)
    local marks = every(renderer, "canvas")

    assert(#marks == 5, "five marks, got " .. #marks)

    local filled = 0

    for index = 1, #marks do
        if marks[index].props.commands[1].op == "fill" then
            filled = filled + 1
        end
    end

    assert(filled == 3, "three of them are filled, " .. filled .. " were")
end

-- A select shows what is chosen and opens the rest, which is one control rather than three.
do
    local told = nil
    local renderer, app = drawn(gui.View {
        gui.Picker {
            value = "two",
            placeholder = "Choose one",
            options = { { value = "one", label = "The first" }, { value = "two", label = "The second" } },
            onChange = function(value) told = value end,
        },
    }, controls.material3)

    local field = byRole(renderer, "button")

    assert(field ~= nil, "the field is what opens it")
    assert(field.props.accessibilityState.expanded == false, "and it says it is closed")

    local labels = {}

    for _, node in ipairs(every(renderer, "text")) do
        labels[#labels + 1] = node.props.text
    end

    assert(labels[1] == "The second", "a select shows what is chosen, it showed " .. tostring(labels[1]))

    app:dispatch(field.id, "onPress", nil)
    settle(app)

    local rows = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        if node.props.accessibilityRole == "listitem" then
            rows[#rows + 1] = node
        end
    end

    assert(#rows == 2, "opening it shows every choice, it showed " .. #rows)
    assert(byRole(renderer, "button").props.accessibilityState.expanded == true, "and it says it is open")

    app:dispatch(rows[1].id, "onPress", nil)
    settle(app)

    assert(told == "one", "choosing one reports its value, it said " .. tostring(told))
    assert(byRole(renderer, "button").props.accessibilityState.expanded == false, "and it closes again")
end

-- Changing the control theme while the application runs draws every control again.
do
    local renderer = headless.create()
    local app = gui.start(gui.View { gui.Switch { value = true } }, renderer,
        { size = { width = 360, height = 640 }, controls = controls.native })

    assert(#every(renderer, "switch") == 1, "it opens on the platform's own switch")

    app:setControls(controls.material3)
    app:commit()

    assert(#every(renderer, "switch") == 0, "the platform's switch is gone")
    assert(byRole(renderer, "switch") ~= nil, "and a drawn one stands where it was")

    app:setControls(controls.native)
    app:commit()

    assert(#every(renderer, "switch") == 1, "and it goes back")
end

-- A look and a control theme are two things, so changing one leaves the other alone.
do
    local renderer = headless.create()
    local app = gui.start(gui.View { gui.Switch { value = true } }, renderer,
        { size = { width = 360, height = 640 }, controls = controls.material3 })

    local before = partsOf(renderer, byRole(renderer, "switch"), "view")[1].props.style.background

    app:setTheme(gui.theme.looks.blossom)
    app:commit()

    local after = partsOf(renderer, byRole(renderer, "switch"), "view")[1].props.style.background

    assert(before ~= after, "a switch drawn in another look is painted differently, both were " .. tostring(before))
    assert(partsOf(renderer, byRole(renderer, "switch"), "view")[1].props.style.width == controls.material3:metric("switch", "width"),
        "and it is still built the same way")
end

-- Every drawn control is a stop on the way through with a keyboard and says when it is the one reached.
do
    local renderer = drawn(gui.View {
        gui.Switch { value = false },
        gui.Checkbox { label = "Keep it" },
        gui.Button { title = "Send", onPress = function() end },
    }, controls.material3)

    for _, node in ipairs(every(renderer, "pressable")) do
        assert(node.props.focusable == true,
            "a drawn control is reachable with a keyboard, a " .. tostring(node.props.accessibilityRole) .. " is not")
        assert(type(node.props.onFocus) == "function", "and it says when the keyboard has reached it")
        assert(type(node.props.onBlur) == "function", "and when it has gone")
    end
end

-- A control the keyboard has reached draws a ring around itself, which is the whole of seeing where it is.
do
    local renderer, app = drawn(gui.View { gui.Button { title = "Send", onPress = function() end } },
        controls.material3)

    local pressed = byRole(renderer, "button")

    local function ringed()
        local found = 0

        for _, node in ipairs(partsOf(renderer, byRole(renderer, "button"), "view")) do
            -- A role reaches the renderer as the colour the look turns it into, so the ring is found by
            -- the shape it has rather than by the name the theme wrote.
            if node.props.style.position == "absolute"
                and node.props.style.border == controls.material3:focus().width then
                found = found + 1
            end
        end

        return found
    end

    assert(ringed() == 0, "a control nothing has reached draws no ring")

    app:dispatch(pressed.id, "onFocus", nil)
    app:commit()

    assert(ringed() == 1, "a control the keyboard has reached draws one")

    app:dispatch(byRole(renderer, "button").id, "onBlur", nil)
    app:commit()

    assert(ringed() == 0, "and it goes when the keyboard does")

    -- A design that wants no ring says a width of nothing, and every control then draws none.
    local bare = controls.extend(controls.material3, { name = "bare", focus = { width = 0, color = "primary" } })
    local plain, held = drawn(gui.View { gui.Button { title = "Send", onPress = function() end } }, bare)

    held:dispatch(byRole(plain, "button").id, "onFocus", nil)
    held:commit()

    for _, node in ipairs(partsOf(plain, byRole(plain, "button"), "view")) do
        assert(node.props.style.position ~= "absolute", "a design that draws no ring draws none")
    end
end

-- Space and return use a control, which is what every system means by them.
do
    local told = nil
    local renderer, app = drawn(gui.View {
        gui.Switch { value = false, onChange = function(value) told = value end },
    }, controls.material3)

    local pressed = byRole(renderer, "switch")

    app:dispatch(pressed.id, "onKeyDown", { key = "a" })
    assert(told == nil, "a key that means nothing to a switch does nothing")

    app:dispatch(pressed.id, "onKeyDown", { key = " " })
    assert(told == true, "space turns a switch on, it said " .. tostring(told))

    app:dispatch(pressed.id, "onKeyDown", { key = "Enter" })
    assert(told == true, "and so does return")
end

-- The arrows walk a set, and home and end go to either end of it.
do
    local told = {}
    local renderer, app = drawn(gui.View {
        gui.SegmentedControl {
            segments = { "Day", "Week", "Month" },
            selectedIndex = 2,
            onChange = function(index) told[#told + 1] = index end,
        },
    }, controls.material3)

    local tabs = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        if node.props.accessibilityRole == "tab" then
            tabs[#tabs + 1] = node
        end
    end

    app:dispatch(tabs[2].id, "onKeyDown", { key = "ArrowRight" })
    assert(told[#told] == 3, "the right arrow moves on, it said " .. tostring(told[#told]))

    app:dispatch(tabs[2].id, "onKeyDown", { key = "ArrowLeft" })
    assert(told[#told] == 1, "the left arrow moves back")

    app:dispatch(tabs[2].id, "onKeyDown", { key = "End" })
    assert(told[#told] == 3, "end goes to the last")

    app:dispatch(tabs[2].id, "onKeyDown", { key = "Home" })
    assert(told[#told] == 1, "and home to the first")
end

-- A stepper steps with the arrows and refuses the one that would take it past its end.
do
    local told = {}
    local renderer, app = drawn(gui.View {
        gui.Stepper { value = 9, minimum = 0, maximum = 9, onChange = function(v) told[#told + 1] = v end },
    }, controls.material3)

    local keys = {}

    for _, node in ipairs(every(renderer, "pressable")) do
        keys[node.props.accessibilityLabel] = node
    end

    app:dispatch(keys.More.id, "onKeyDown", { key = "ArrowUp" })
    assert(#told == 0, "a stepper at its end is not moved past it by a key either")

    app:dispatch(keys.More.id, "onKeyDown", { key = "ArrowDown" })
    assert(told[1] == 8, "and it steps down, it said " .. tostring(told[1]))
end

-- A select opens with the down arrow and closes with escape, which is what every one of them does.
do
    local renderer, app = drawn(gui.View {
        gui.Picker { value = "one", options = { { value = "one", label = "The first" } } },
    }, controls.material3)

    local field = byRole(renderer, "button")

    app:dispatch(field.id, "onKeyDown", { key = "ArrowDown" })
    settle(app)

    assert(byRole(renderer, "button").props.accessibilityState.expanded == true, "the down arrow opens it")

    app:dispatch(byRole(renderer, "button").id, "onKeyDown", { key = "Escape" })
    settle(app)

    assert(byRole(renderer, "button").props.accessibilityState.expanded == false, "and escape closes it")
end

-- A slider follows a finger, and where the finger is on the track is what it is worth.
do
    local told = {}
    local committed = nil
    local renderer, app = drawn(gui.View {
        gui.Slider {
            value = 0,
            minimum = 0,
            maximum = 100,
            onChange = function(value) told[#told + 1] = value end,
            onCommit = function(value) committed = value end,
        },
    }, controls.material3)

    local track = byRole(renderer, "slider")

    assert(track.props.panAxis == "horizontal",
        "a slider claims the axis it is dragged along, so a list under it keeps the other")

    -- The engine reports the width, which is what a position along the track is measured against.
    app:dispatch(track.id, "onLayout", { x = 0, y = 0, width = 200, height = 48 })
    app:commit()

    app:dispatch(byRole(renderer, "slider").id, "onPanStart", { x = 100, y = 20, dx = 0, dy = 0 })

    assert(math.abs(told[#told] - 50) < 0.01,
        "a finger landing halfway along asks for the middle, it said " .. tostring(told[#told]))

    app:dispatch(byRole(renderer, "slider").id, "onPanMove", { x = 200, y = 20, dx = 100, dy = 0 })
    assert(told[#told] == 100, "and dragging to the end asks for the end")

    app:dispatch(byRole(renderer, "slider").id, "onPanMove", { x = -40, y = 20, dx = -140, dy = 0 })
    assert(told[#told] == 0, "a finger dragged off the near end is held to it")

    app:dispatch(byRole(renderer, "slider").id, "onPanEnd", { x = 50, y = 20, dx = -50, dy = 0 })
    assert(math.abs(committed - 25) < 0.01, "letting go reports where it was left, it said " .. tostring(committed))
end

-- A slider holds to its step, and the arrows move it by one of them.
do
    local told = {}
    local renderer, app = drawn(gui.View {
        gui.Slider {
            value = 4,
            minimum = 0,
            maximum = 10,
            step = 2,
            onChange = function(value) told[#told + 1] = value end,
        },
    }, controls.material3)

    local track = byRole(renderer, "slider")

    app:dispatch(track.id, "onLayout", { x = 0, y = 0, width = 100, height = 48 })
    app:commit()

    app:dispatch(byRole(renderer, "slider").id, "onPanStart", { x = 33, y = 20, dx = 0, dy = 0 })
    assert(told[#told] == 4, "a slider that steps lands on a step, it said " .. tostring(told[#told]))

    app:dispatch(byRole(renderer, "slider").id, "onKeyDown", { key = "ArrowRight" })
    assert(told[#told] == 6, "the right arrow moves it one step on")

    app:dispatch(byRole(renderer, "slider").id, "onKeyDown", { key = "Home" })
    assert(told[#told] == 0, "and home takes it to the start")

    assert(byRole(renderer, "slider").props.accessibilityValue.now == 4,
        "and it says where it is for a reader who cannot see it")
end

-- A range is two thumbs, and the one the finger is nearest to is the one that moves.
do
    local told = nil
    local renderer, app = drawn(gui.View {
        gui.RangeSlider {
            range = { 20, 80 },
            minimum = 0,
            maximum = 100,
            onChange = function(value) told = value end,
        },
    }, controls.material3)

    local track = byRole(renderer, "slider")

    app:dispatch(track.id, "onLayout", { x = 0, y = 0, width = 100, height = 48 })
    app:commit()

    app:dispatch(byRole(renderer, "slider").id, "onPanStart", { x = 30, y = 20, dx = 0, dy = 0 })

    assert(told[1] == 30 and told[2] == 80, "the near thumb moves, it said "
        .. tostring(told[1]) .. " to " .. tostring(told[2]))

    -- The thumb that was taken keeps the drag, so a finger crossing the other one does not swap them.
    app:dispatch(byRole(renderer, "slider").id, "onPanMove", { x = 10, y = 20, dx = -20, dy = 0 })
    assert(told[1] == 10 and told[2] == 80, "and it keeps the drag as the finger moves")
end

-- A control somebody writes is a control in every sense, and a theme carries it like any other.
do
    local component = require("gui.component")
    local structure = require("gui.components.structure")
    local content = require("gui.components.content")

    local Gauge = gui.control("Gauge", {
        parts = { "track", "needle" },
        props = { "value", "label" },
        defaults = { value = 0 },
        drawn = {
            metrics = { height = 6 },
            paint = { track = { rest = "surfaceVariant" }, needle = { rest = "primary" } },
            motion = { duration = 150 },
            press = "none",
        },
    }, component.define({
        name = "DrawnGauge",

        render = function(self)
            local theme = self.props.theme

            return structure.View {
                accessibilityRole = "progressbar",
                accessibilityValue = { now = self.props.value, least = 0, most = 1 },
                style = {
                    height = theme:metric("gauge", "height"),
                    background = gui.controls.parts.paint(theme, "gauge", "track", {}),
                },

                content.Text { text = self.props.label or "" },
            }
        end,
    }))

    assert(gui.controls.partsOf("gauge")[1] == "needle", "the kind is registered with its parts")

    -- A kind added after a theme was written leaves that theme working, drawn as the control declared.
    local plain = drawn(gui.View { Gauge { value = 0.25, label = "Quarter" } }, controls.material3)
    local asDeclared = byRole(plain, "progressbar")

    assert(asDeclared ~= nil, "a theme that says nothing about a new kind still draws it")
    assert(asDeclared.props.style.height == 6, "at the size the control declared for itself")

    local withGauge = controls.extend(controls.material3, {
        name = "gauged",
        controls = {
            gauge = {
                metrics = { height = 8 },
                paint = { track = { rest = "primary" }, needle = { rest = "onPrimary" } },
                motion = { duration = 120 },
                press = "none",
            },
        },
    })

    local renderer = drawn(gui.View { Gauge { value = 0.5, label = "Half" } }, withGauge)
    local shown = byRole(renderer, "progressbar")

    assert(shown ~= nil, "the control draws itself")
    assert(shown.props.style.height == 8, "at the size the theme gave its kind")
    assert(shown.props.accessibilityValue.now == 0.5, "and says what it is at")
end

-- A control theme may replace how a control is drawn rather than only recolour it.
do
    local component = require("gui.component")
    local content = require("gui.components.content")

    local Worded = component.define({
        name = "WordedSwitch",
        render = function(self) return content.Text { text = self.props.value and "ON" or "OFF" } end,
    })

    local spelled = controls.extend(controls.material3, {
        name = "spelled",
        controls = { switch = { draw = Worded } },
    })

    local renderer = drawn(gui.View { gui.Switch { value = true } }, spelled)

    assert(byRole(renderer, "switch") == nil, "the theme's own drawing is what is drawn")
    assert(every(renderer, "text")[1].props.text == "ON", "and it is the one the theme named")

    -- The theme it came from is untouched, so the two are two designs rather than one changed.
    local ordinary = drawn(gui.View { gui.Switch { value = true } }, controls.material3)

    assert(byRole(ordinary, "switch") ~= nil, "the theme it was extended from still draws its own")
end

-- Every drawn control says what it is, answers a keyboard, and reports every moment of being used.
--
-- A control that reports only its value is one a screen cannot animate around, and one that names no
-- role is invisible to a reader who cannot see it. Each is a promise the whole set keeps rather than a
-- feature some of them have, so the whole set is read rather than one control at a time.
do
    local drawn = {
        { name = "Switch", built = gui.Switch { value = true }, role = "switch" },
        { name = "Checkbox", built = gui.Checkbox { label = "One" }, role = "checkbox" },
        { name = "Radio", built = gui.Radio { value = "a", label = "One" }, role = "radio" },
        { name = "Button", built = gui.Button { title = "Send" }, role = "button" },
        { name = "SegmentedControl", built = gui.SegmentedControl { segments = { "A", "B" } }, role = "tab" },
        { name = "Stepper", built = gui.Stepper { value = 1 }, role = "button" },
        { name = "Rating", built = gui.Rating { value = 2 }, role = "button" },
        { name = "Slider", built = gui.Slider { value = 0.5 }, role = "slider" },
        { name = "Picker", built = gui.Picker { options = {}, value = nil }, role = "button" },
        { name = "FloatingActionButton", built = gui.FloatingActionButton { icon = "plus" }, role = "button" },
        { name = "Pagination", built = gui.Pagination { count = 3, page = 2, onChange = function() end }, role = "button" },
        { name = "ProgressSteps", built = gui.ProgressSteps { steps = { { key = "a", label = "A" } }, onChange = function() end }, role = "tab" },
        { name = "TreeView", built = gui.TreeView { nodes = { { key = "a", label = "A" } } }, role = "listitem" },
        { name = "NavigationRail", built = gui.NavigationRail { tabs = { { key = "a", label = "A" } } }, role = "tab" },
    }

    local wrong = {}

    for _, entry in ipairs(drawn) do
        local built, app = (function()
            local made = headless.create()
            local runtime = gui.start(gui.View { entry.built }, made,
                { size = { width = 360, height = 640 }, controls = controls.material3 })

            return made, runtime
        end)()

        local said = byRole(built, entry.role)

        if said == nil then
            wrong[#wrong + 1] = entry.name .. " says it is nothing a reader can find"
        else
            if type(said.props.onFocus) ~= "function" or said.props.focusable ~= true then
                wrong[#wrong + 1] = entry.name .. " cannot be reached with a keyboard"
            end

            -- A control that takes a press answers the keys its kind owns, or it is a control a reader
            -- using a keyboard can reach and cannot use.
            if type(said.props.onPress) == "function" and type(said.props.onKeyDown) ~= "function" then
                wrong[#wrong + 1] = entry.name .. " takes a press and answers no key"
            end
        end

        app:stop()
    end

    assert(#wrong == 0, "these do not keep what every drawn control promises:\n  "
        .. table.concat(wrong, "\n  "))
end

-- A control the platform draws is drawn by the platform, and a drawn one is not, and nothing is both.
--
-- A kind registered with an entry of its own is one `native` leaves alone, which is right for a control
-- no system has and wrong for one every system has: a card and a tooltip were drawn by the engine under
-- every control theme, so the platform's own were never reached at all.
do
    local cases = {
        { name = "Switch", built = gui.Switch { value = true } },
        { name = "Checkbox", built = gui.Checkbox { label = "A" } },
        { name = "Radio", built = gui.Radio { value = "a", label = "A" } },
        { name = "Button", built = gui.Button { title = "A" } },
        { name = "SegmentedControl", built = gui.SegmentedControl { segments = { "A", "B" } } },
        { name = "Stepper", built = gui.Stepper { value = 1 } },
        { name = "Rating", built = gui.Rating { value = 1 } },
        { name = "Slider", built = gui.Slider { value = 0.5 } },
        { name = "Picker", built = gui.Picker { options = {} } },
        { name = "ProgressBar", built = gui.ProgressBar { value = 0.5 } },
        { name = "ActivityIndicator", built = gui.ActivityIndicator {} },
        { name = "Card", built = gui.Card {} },
        { name = "Tooltip", built = gui.Tooltip { text = "A" } },
        { name = "DatePicker", built = gui.DatePicker { value = "2026-01-01" } },
        { name = "TimePicker", built = gui.TimePicker { value = "09:00" } },
        { name = "ColorPicker", built = gui.ColorPicker { value = "#ff0000" } },
    }

    local function shapeOf(tree, theme)
        local renderer = headless.create()
        local app = gui.start(gui.View { tree }, renderer,
            { size = { width = 390, height = 800 }, controls = theme })

        local kinds = {}

        for _, node in pairs(renderer.nodes) do
            kinds[#kinds + 1] = node.type
        end

        app:stop()
        table.sort(kinds)

        return table.concat(kinds, " ")
    end

    local same = {}

    for _, case in ipairs(cases) do
        if shapeOf(case.built, controls.native) == shapeOf(case.built, controls.material3) then
            same[#same + 1] = case.name
        end
    end

    assert(#same == 0, "these are drawn the same way whether the platform draws them or not:\n  "
        .. table.concat(same, "\n  "))

    -- And every one of them draws without raising under every control theme the library ships.
    local broken = {}

    for _, case in ipairs(cases) do
        for _, name in ipairs({ "native", "material2", "material3", "cupertino" }) do
            local ok, problem = pcall(shapeOf, case.built, controls[name])

            if not ok then
                broken[#broken + 1] = case.name .. " in " .. name .. ": " .. tostring(problem)
            end
        end
    end

    assert(#broken == 0, "these did not draw:\n  " .. table.concat(broken, "\n  "))
end

-- Starting on something that is not a control theme is refused where it is written.
do
    local ok, problem = pcall(gui.start, gui.View {}, headless.create(),
        { size = { width = 10, height = 10 }, controls = { name = "not one" } })

    assert(not ok, "a table that is not a control theme must be refused")
    assert(tostring(problem):find("gui.controls.define", 1, true) ~= nil,
        "and it must say what one is, it said " .. tostring(problem))
end

print("gui.controls ok")
