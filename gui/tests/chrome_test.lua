local chrome = require("gui.style.chrome")
local gui = require("gui")

local function start(description, platform)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, {
        size = { width = 390, height = 844 },
        platform = platform,
    })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- Answers the text of every label on screen, which is what a reader sees.
local function shown(renderer)
    local labels = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" and node.props.text ~= nil then
            labels[#labels + 1] = node.props.text
        end
    end

    return labels
end

local function holds(renderer, text)
    for _, label in ipairs(shown(renderer)) do
        if label == text then
            return true
        end
    end

    return false
end

local function stack(platform)
    return start(gui.NavigationStack {
        index = 2,
        screens = {
            { key = "one", title = "Library", content = gui.Text { text = "First" } },
            { key = "two", title = "Album", content = gui.Text { text = "Second" } },
        },
    }, platform)
end

-- The chrome is the system's own, which is the one thing a tree cannot work out for itself.
--
-- A bar that is 44 tall with a centred title and a chevron carrying the previous screen's name is what
-- iOS draws. Android draws 56, the title against the leading edge, and an arrow with no label. Getting
-- either wrong is what makes an application read as something ported.
--- Answers whether the bar's back mark was drawn, which is what an icon is on every platform.
local function drawn(renderer)
    for _, node in pairs(renderer.nodes) do
        if node.type == "canvas" and node.props.commands ~= nil and #node.props.commands > 0 then
            return true
        end
    end

    return false
end

do
    local _, renderer = stack("ios")
    local bar = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "view" and node.frame ~= nil and node.frame.height == chrome.bar("ios").height
            and node.frame.y == 0 then
            bar = node
        end
    end

    assert(bar ~= nil, "an iOS bar is drawn at the height iOS draws one")
    assert(holds(renderer, "Library"), "an iOS back button carries the previous screen's title")

    -- The mark is drawn rather than written, so it is the same shape wherever it is drawn, and each
    -- platform still chooses which shape: a chevron on iOS and an arrow on Android.
    assert(chrome.bar("ios").back.symbol == "chevron-left", "an iOS back button is a chevron")
    assert(drawn(renderer), "and it is drawn rather than written as a character")
end

do
    local _, renderer = stack("android")

    assert(chrome.bar("android").back.symbol == "arrow-left", "an Android back button is an arrow")
    assert(drawn(renderer), "and it is drawn rather than written as a character")
    assert(not holds(renderer, "Library"), "an Android back button carries no label")

    local tall = false

    for _, node in pairs(renderer.nodes) do
        if node.frame ~= nil and node.frame.height == chrome.bar("android").height and node.frame.y == 0 then
            tall = true
        end
    end

    assert(tall, "an Android bar is drawn at the height Android draws one")
end

-- A centred title is centred on the bar, not on what the way back left over.
--
-- With a long name behind it and nothing on the other side, a title centred between the two sits
-- visibly right of the middle, which is what the bar did. The two sides claim the same width for this,
-- and the trailing one is there holding nothing precisely so that they can.
do
    local function titled(back, actions)
        local _, renderer = start(gui.NavigationStack {
            index = 2,
            actions = actions,
            screens = {
                { key = "one", title = back, content = gui.Text { text = "First" } },
                { key = "two", title = "Text", content = gui.Text { text = "Second" } },
            },
        }, "ios")

        for _, node in pairs(renderer.nodes) do
            if node.type == "text" and node.props.text == "Text" and node.frame ~= nil then
                return node.frame
            end
        end
    end

    for _, back in ipairs({ "A", "Varn GUI", "A rather long screen name" }) do
        local frame = titled(back)

        assert(frame ~= nil, "the bar must carry the title of the screen being read")
        assert(math.abs(frame.x + frame.width / 2 - 390 / 2) <= 1,
            "a title behind " .. back .. " must sit in the middle of a 390 wide bar, its middle is at "
                .. (frame.x + frame.width / 2))
    end

    -- Something on the trailing side moves the title no more than the same thing on the leading side.
    local balanced = titled("Varn GUI", { gui.Text { text = "Edit" } })

    assert(math.abs(balanced.x + balanced.width / 2 - 390 / 2) <= 1,
        "a title stays in the middle when the bar carries an action, its middle is at "
            .. (balanced.x + balanced.width / 2))
end

-- A back button is something a finger has to land on, so it is never smaller than the guidelines allow.
do
    local _, renderer = stack("ios")
    local smallest = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" and node.frame ~= nil then
            smallest = math.min(smallest or node.frame.width, node.frame.width)
        end
    end

    assert(smallest ~= nil, "the bar must carry a way back")
    assert(smallest >= chrome.touch,
        "a back button must be at least " .. chrome.touch .. " across, got " .. smallest)
end

-- Changing screen is something a reader sees happen.
do
    local Screens = gui.component({
        name = "Screens",
        state = { index = 1 },
        render = function(self)
            return gui.NavigationStack {
                index = self.state.index,
                screens = {
                    { key = "one", title = "One", content = gui.Text { text = "First" } },
                    { key = "two", title = "Two", content = gui.Text { text = "Second" } },
                },
            }
        end,
    })

    local runtime, renderer = start(Screens {}, "ios")

    runtime.root.instance:setState({ index = 2 })

    for _ = 1, 4 do
        runtime:commit()
    end

    local arriving = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.enter ~= nil and node.props.transition ~= nil then
            arriving = node
        end
    end

    assert(arriving ~= nil, "a screen pushed onto the stack must arrive rather than appear")
    assert(arriving.props.transition.duration > 0, "an arrival must be given a time to take")
    assert(arriving.props.enter.opacity == 0 or arriving.props.enter.transform ~= nil,
        "an arrival must be given somewhere to come from")
end

-- A stack with nowhere left to go hands the way back to the one above it.
--
-- An application inside a gallery is two stacks deep. The innermost is what a reader means when they
-- swipe, but once it is at its first screen it has nothing to pop, and a back press that stopped there
-- would leave them unable to get out of it at all.
do
    local inner = 0
    local outer = 0

    local Nested = gui.component({
        name = "Nested",
        state = { outer = 2, inner = 1 },
        render = function(self)
            return gui.NavigationStack {
                index = self.state.outer,
                onPop = function() outer = outer + 1 end,
                onIndexChange = function(index) self:setState({ outer = index }) end,
                screens = {
                    { key = "index", title = "Gallery", content = gui.Text { text = "Index" } },
                    { key = "app", title = "Application", content = gui.NavigationStack {
                        index = self.state.inner,
                        onPop = function() inner = inner + 1 end,
                        onIndexChange = function(index) self:setState({ inner = index }) end,
                        screens = {
                            { key = "home", title = "Home", content = gui.Text { text = "Home" } },
                            { key = "detail", title = "Detail", content = gui.Text { text = "Detail" } },
                        },
                    } },
                },
            }
        end,
    })

    local runtime = select(1, start(Nested {}, "ios"))

    -- With the inner stack at its first screen, the way back belongs to the one above it.
    assert(runtime:goBack(), "a back press with somewhere to go must be taken")
    assert(inner == 0, "a stack at its first screen must not claim the way back")
    assert(outer == 1, "the stack above it takes what the innermost declined")

    -- With the inner stack deeper in, it is the one that answers.
    runtime.root.instance:setState({ outer = 2, inner = 2 })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(runtime:goBack(), "a back press with somewhere to go must be taken")
    assert(inner == 1, "the innermost stack answers when it has somewhere to go")
    assert(outer == 1, "and the one above it is left alone")
end

-- Going back is something a reader sees happen, the same as going forward was.
--
-- A caller derives its screens from what it is showing, so the one that was on top is gone from the list
-- by the time the stack renders again. The stack is the only thing that saw it, so it keeps it long
-- enough to be drawn going back the way it came.
do
    local Screens = gui.component({
        name = "Screens",
        state = { deep = true },
        render = function(self)
            local screens = { { key = "one", title = "One", content = gui.Text { text = "First" } } }

            if self.state.deep then
                screens[2] = { key = "two", title = "Two", content = gui.Text { text = "Second" } }
            end

            return gui.NavigationStack { index = #screens, screens = screens }
        end,
    })

    local runtime, renderer = start(Screens {}, "ios")

    local function shows(text)
        for _, node in pairs(renderer.nodes) do
            if node.type == "text" and node.props.text == text then
                return true
            end
        end

        return false
    end

    assert(shows("Second"), "the screen on top must be on screen")

    runtime.root.instance:setState({ deep = false })

    for _ = 1, 4 do
        runtime:commit()
    end

    assert(shows("Second"), "the screen that was left is held while it goes")
    assert(shows("First"), "over the one it uncovers")

    local leaving = nil

    for _, node in pairs(renderer.nodes) do
        local style = node.props.style

        if style ~= nil and style.transform ~= nil then
            leaving = node
        end
    end

    assert(leaving ~= nil, "and it is drawn on its way out rather than cut")
    assert(leaving.props.transition ~= nil, "with a time to take over it")
end

print("gui.chrome ok")
