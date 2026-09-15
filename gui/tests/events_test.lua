local gui = require("gui")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

-- A box says a finger landed twice, which is the platform's own gesture rather than two presses counted.
--
-- Each of the three waits for the second tap before it reports the first, so a box that counted them
-- itself would answer the first press as well and open whatever it was for before the second landed.
do
    local told = {}

    local runtime, renderer = start(gui.Pressable {
        accessibilityLabel = "Twice",
        onPress = function() told[#told + 1] = "press" end,
        onDoublePress = function() told[#told + 1] = "double" end,
    })

    local box = renderer:find("pressable")

    assert(type(box.props.onDoublePress) == "function",
        "a box listening for a double press says so to the platform")

    runtime:dispatch(box.id, "onDoublePress", nil)
    runtime:commit()

    assert(#told == 1 and told[1] == "double", "and a double press is reported on its own")
end

-- A key reaches the handler by the name the browser publishes, with what was held down beside it.
do
    local keys = {}

    local Screen = gui.component({
        name = "Keys",
        state = { last = "" },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.TextInput {
                    value = "",
                    onChange = function() end,
                    onKeyDown = function(key) keys[#keys + 1] = key end,
                    onKeyUp = function(key) keys[#keys + 1] = key end,
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})
    local field = renderer:find("textinput")

    assert(type(field.props.onKeyDown) == "function" and type(field.props.onKeyUp) == "function",
        "a field listening for keys says so to the platform")

    runtime:dispatch(field.id, "onKeyDown",
        { key = "Enter", shift = false, ctrl = false, alt = false, meta = true, repeat_ = false })
    runtime:dispatch(field.id, "onKeyUp", { key = "a", shift = true })
    runtime:commit()

    assert(#keys == 2, "both ends of a key are reported, got " .. #keys)
    assert(keys[1].key == "Enter", "a named key carries the name every platform is mapped onto")
    assert(keys[1].meta == true, "and what was held down with it")
    assert(keys[2].key == "a" and keys[2].shift == true, "a printable key carries the character itself")
end

-- A field told to take the keyboard as the screen opens says so, which is what a search screen is.
do
    local _, renderer = start(gui.TextInput { value = "", autoFocus = true, onChange = function() end })

    assert(renderer:find("textinput").props.autoFocus == true,
        "the field asks the platform for the keyboard rather than waiting to be pressed")
end

-- Where the caret is inside a field is reported, which is what an editor and a formatter both need.
do
    local where = nil

    local runtime, renderer = start(gui.TextInput {
        value = "Ada Lovelace",
        onChange = function() end,
        onSelectionChange = function(at) where = at end,
    })

    local field = renderer:find("textinput")

    assert(type(field.props.onSelectionChange) == "function",
        "a field asked where its caret is says so to the platform")

    runtime:dispatch(field.id, "onSelectionChange", { start = 4, ["end"] = 12, marks = {} })
    runtime:commit()

    assert(where ~= nil and where.start == 4 and where["end"] == 12,
        "and the selection is reported as two counts of characters")
end

-- Every moment a component is told about is one it may declare, and no name is a method it already has.
do
    local told = {}

    local Watched = gui.component({
        name = "Watched",

        onWillMount = function() told[#told + 1] = "willMount" end,
        onMount = function() told[#told + 1] = "mount" end,
        onWillAppear = function() told[#told + 1] = "willAppear" end,
        onAppear = function() told[#told + 1] = "appear" end,
        onUpdate = function() told[#told + 1] = "update" end,
        onWillDisappear = function() told[#told + 1] = "willDisappear" end,
        onDisappear = function() told[#told + 1] = "disappear" end,
        onWillUnmount = function() told[#told + 1] = "willUnmount" end,
        onUnmount = function() told[#told + 1] = "unmount" end,
        onPause = function() told[#told + 1] = "pause" end,
        onResume = function() told[#told + 1] = "resume" end,

        render = function() return gui.Text { text = "watched" } end,
    })

    local runtime = start(Watched {})

    local function had(moment)
        for _, name in ipairs(told) do
            if name == moment then
                return true
            end
        end

        return false
    end

    assert(had("willMount") and had("mount"), "a component is told before and after it is built")
    assert(had("willAppear") and had("appear"), "and before and after it is shown")

    runtime:setLifecycle("background")
    runtime:commit()

    assert(had("pause"), "and when the application goes away")

    runtime:setLifecycle("active")
    runtime:commit()

    assert(had("resume"), "and when it comes back")

    runtime:stop()

    assert(had("willUnmount") and had("unmount"), "and before and after it is taken down")
end

-- A component that declares one of the two application moments is never told the other one.
--
-- Written `away and instance.onPause or instance.onResume`, a component with nothing to call for going
-- away reached for the other one through the `or`: a screen that only wanted to be told it had come back
-- was told so at the moment it went, carrying the state it was going to.
do
    local told = {}

    local Coming = gui.component({
        name = "Coming",
        onResume = function() told[#told + 1] = "resume" end,
        render = function() return gui.Text { text = "coming" } end,
    })

    local runtime = start(Coming {})

    runtime:setLifecycle("background")
    runtime:commit()

    assert(#told == 0, "a component with no onPause is told nothing when the application goes away")

    runtime:setLifecycle("active")
    runtime:commit()

    assert(#told == 1 and told[1] == "resume", "and is told once when it comes back")
end

-- A moment a component may not declare is refused where it is written rather than quietly taking over.
do
    for _, name in ipairs({ "ref", "after", "every", "setState", "visible" }) do
        local ok = pcall(function()
            return gui.component({ name = "Clashing", [name] = function() end, render = function() end })
        end)

        assert(not ok, "a component must not be allowed a method named " .. name)
    end
end

print("gui.events ok")
