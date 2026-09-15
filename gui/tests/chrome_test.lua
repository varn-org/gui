local chrome = require("gui.style.chrome")
local gui = require("gui")

local function start(description, platform, insets)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, {
        size = { width = 390, height = 844 },
        platform = platform,
        insets = insets,
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
    local function titled(back, trailing)
        local _, renderer = start(gui.NavigationStack {
            index = 2,
            trailing = trailing,
            screens = {
                { key = "one", title = back, content = gui.Text { text = "First" } },
                { key = "two", title = "Text", content = gui.Text { text = "Second" } },
            },
        }, "ios")

        -- A frame is relative to the box that holds it, and how the bar is built out of boxes is the
        -- bar's business, so where the title sits on the bar is read by walking back up to the bar.
        for _, node in pairs(renderer.nodes) do
            if node.type == "text" and node.props.text == "Text" and node.frame ~= nil then
                local x = node.frame.x
                local parent = renderer.nodes[node.parent]

                while parent ~= nil and parent.frame ~= nil and parent.frame.width ~= 390 do
                    x = x + parent.frame.x
                    parent = renderer.nodes[parent.parent]
                end

                return { x = x, width = node.frame.width }
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

--- Answers where a node sits on the surface, which is every frame above it added up.
local function placed(renderer, node)
    local top = node.frame.y
    local left = node.frame.x
    local parent = renderer.nodes[node.parent]

    while parent ~= nil and parent.frame ~= nil do
        top = top + parent.frame.y
        left = left + parent.frame.x
        parent = renderer.nodes[parent.parent]
    end

    return { top = top, left = left, bottom = top + node.frame.height, height = node.frame.height }
end

--- Answers the one node of a type whose named prop says what was asked for.
local function carrying(renderer, kind, name, value)
    for _, node in pairs(renderer.nodes) do
        if node.type == kind and node.props[name] == value then
            return node
        end
    end

    return nil
end

-- What a bar holds is centred in the bar, not on the strip the system draws its own bar over.
--
-- The bar runs to the top of the glass and takes that strip into itself, so what a reader sees is one
-- bar rather than a painted band with a bar under it. Centring in the whole of that would put the title
-- under the clock, so what it holds is centred in the part below the strip.
do
    local insets = { top = 59, right = 0, bottom = 34, left = 0 }

    local _, renderer = start(gui.NavigationStack {
        index = 2,
        screens = {
            { key = "one", title = "Library", content = gui.Text { text = "First" } },
            { key = "two", title = "Album", content = gui.Text { text = "Second" } },
        },
    }, "ios", insets)

    local title = carrying(renderer, "text", "text", "Album")
    local look = chrome.bar("ios")

    assert(title ~= nil, "the bar must carry the title of the screen being read")

    local where = placed(renderer, title)
    local middle = insets.top + look.height / 2

    assert(math.abs(where.top + where.height / 2 - middle) <= 1,
        "a title is centred in the bar, which is at " .. middle .. ", and it is at "
            .. (where.top + where.height / 2))

    assert(where.top >= insets.top,
        "and nothing it holds is drawn under the status bar, the title starts at " .. where.top)

    -- Everything in the bar is centred on the same line, whatever it is drawn out of.
    local back = carrying(renderer, "text", "text", "Library")
    local behind = placed(renderer, back)

    assert(math.abs(behind.top + behind.height / 2 - middle) <= 1,
        "the way back is centred on the same line, it is at " .. (behind.top + behind.height / 2))
end

-- A bar inside a safe area that already took the top inset does not take it again.
do
    local insets = { top = 59, right = 0, bottom = 34, left = 0 }

    local _, renderer = start(gui.SafeArea {
        style = { grow = 1 },

        gui.AppBar { title = "Inbox" },
    }, "ios", insets)

    local title = carrying(renderer, "text", "text", "Inbox")
    local look = chrome.bar("ios")
    local where = placed(renderer, title)

    assert(math.abs(where.top + where.height / 2 - (insets.top + look.height / 2)) <= 1,
        "a bar under a safe area is drawn once rather than inset twice, its title is at " .. where.top)
end

-- A bar takes items on either side, each of them something a finger can land on.
do
    local pressed = { leading = 0, trailing = 0 }

    local _, renderer = start(gui.AppBar {
        title = "Inbox",
        leading = { { key = "menu", icon = "menu", accessibilityLabel = "Menu",
            onPress = function() pressed.leading = pressed.leading + 1 end } },
        trailing = {
            { key = "search", icon = "search", accessibilityLabel = "Search",
                onPress = function() pressed.trailing = pressed.trailing + 1 end },
            { key = "edit", label = "Edit", onPress = function() pressed.trailing = pressed.trailing + 1 end },
        },
    }, "ios")

    local found = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" then
            found[node.props.accessibilityLabel] = node
        end
    end

    assert(found.Menu ~= nil, "an item on the leading side is drawn")
    assert(found.Search ~= nil and found.Edit ~= nil, "and every item on the trailing side")

    for name, node in pairs(found) do
        assert(node.frame.width >= chrome.touch and node.frame.height >= chrome.touch,
            name .. " is smaller than a finger, " .. node.frame.width .. " by " .. node.frame.height)
    end

    assert(holds(renderer, "Edit"), "an item carrying a word draws the word")
end

-- A bar item is refused where it was written rather than drawn as nothing.
do
    local refused = function(build, needle)
        local ok, problem = pcall(build)

        assert(not ok, "the bar should have refused " .. needle)
        assert(tostring(problem):find(needle, 1, true) ~= nil,
            "and said so, it said " .. tostring(problem))
    end

    refused(function() return gui.AppBar { title = "A", trailing = { {} } } end, "shows nothing")
    refused(function() return gui.AppBar { title = "A", trailing = { { icon = "nonsense" } } } end, "nonsense")
    refused(function() return gui.AppBar { title = "A", leading = { { label = "A", onPress = 3 } } } end, "function")
end

-- The large title belongs to the bar, and the bar's rule waits until it has collapsed.
--
-- Drawn inside the screen it is a heading with the bar's own rule cut straight across the top of it,
-- which is what the mail application looked like, and it can never give way to the small title.
do
    local function bar(scrolled)
        local _, renderer = start(gui.AppBar { title = "Inbox", largeTitle = true, scrolled = scrolled }, "ios")
        local look = chrome.bar("ios")
        local rules = 0
        local titles = {}

        for _, node in pairs(renderer.nodes) do
            if node.type == "divider" then
                rules = rules + 1
            end

            if node.type == "text" and node.props.text == "Inbox" and node.props.style ~= nil then
                titles[#titles + 1] = node
            end
        end

        -- A style crosses resolved, so the two titles are told apart by the size they are drawn at
        -- rather than by the name the bar asked for.
        table.sort(titles, function(first, second)
            return first.props.style.fontSize > second.props.style.fontSize
        end)

        if #titles == 1 then
            return { rules = rules, big = nil, small = titles[1], look = look, renderer = renderer }
        end

        return { rules = rules, big = titles[1], small = titles[2], look = look, renderer = renderer }
    end

    local open = bar(0)

    assert(open.big ~= nil, "the bar draws the large title")
    assert(open.rules == 0, "and draws no rule across it")
    assert(open.small ~= nil and open.small.props.style.opacity == 0,
        "and the small title is not shown while the large one is")

    local gone = bar(200)

    assert(gone.rules == 1, "once the reader has scrolled it away the bar draws its rule")
    assert(gone.small.props.style.opacity == 1, "and the small title is what is left")
    assert(gone.big == nil, "with nothing of the large one left")
end

-- A bar with no large title draws its own rule, so nothing around it has to.
do
    local _, renderer = start(gui.AppBar { title = "Inbox" }, "ios")
    local rules = 0

    for _, node in pairs(renderer.nodes) do
        if node.type == "divider" then
            rules = rules + 1
        end
    end

    assert(rules == 1, "a bar draws one rule of its own, drew " .. rules)
end

-- The first screen a stack ever shows is drawn where it is rather than arriving.
--
-- A push is a screen arriving over the one it covers, and the first screen covers nothing: it came from
-- nowhere, so animating it is the application sliding in from the side of the glass as it opens. Every
-- platform draws the first one and animates the rest, and a caller may ask for either.
do
    local function arriving(renderer)
        local found = 0

        for _, node in pairs(renderer.nodes) do
            if node.props.enter ~= nil then
                found = found + 1
            end
        end

        return found
    end

    local Stack = gui.component({
        name = "Pushing",
        state = { deep = 1 },

        render = function(self)
            return gui.NavigationStack {
                index = self.state.deep,
                transition = self.props.transition,
                animatesFirstScreen = self.props.animatesFirstScreen,
                screens = {
                    { key = "one", title = "One", content = gui.Text { text = "First" } },
                    { key = "two", title = "Two", content = gui.Text { text = "Second" } },
                },
            }
        end,
    })

    local runtime, renderer = start(Stack {}, "ios")

    assert(arriving(renderer) == 0, "the first screen is drawn where it is, "
        .. arriving(renderer) .. " arrived")

    runtime.root.instance:setState({ deep = 2 })
    runtime:commit()

    assert(arriving(renderer) == 1, "and a screen pushed over it arrives, " .. arriving(renderer) .. " did")

    -- A caller who wants no move at all gets none, on the first screen and on every push after it.
    local quiet, without = start(Stack { transition = "none" }, "ios")

    quiet.root.instance:setState({ deep = 2 })
    quiet:commit()

    assert(arriving(without) == 0, "a stack told to use no move animates nothing")

    -- And one that wants the application to arrive as it opens says so.
    local _, opening = start(Stack { animatesFirstScreen = true }, "ios")

    assert(arriving(opening) == 1, "a stack told to animate its first screen does")
end

-- A screen says which of the system's own bars the reader still sees, and it crosses as it was written.
do
    local renderer = gui.headless()

    gui.start(gui.SafeArea { style = { grow = 1 }, gui.Text { text = "whole" } },
        renderer, { size = { width = 390, height = 844 } })

    local area = renderer:find("safearea")

    assert(#area.props.bars == 2, "a screen that says nothing keeps both bars, kept " .. #area.props.bars)
end

do
    local renderer = gui.headless()

    gui.start(gui.SafeArea { bars = {}, style = { grow = 1 }, gui.Text { text = "whole" } },
        renderer, { size = { width = 390, height = 844 } })

    assert(#renderer:find("safearea").props.bars == 0, "a game takes the whole glass by naming none")
end

do
    local renderer = gui.headless()

    gui.start(gui.SafeArea { bars = { "status" }, style = { grow = 1 }, gui.Text { text = "half" } },
        renderer, { size = { width = 390, height = 844 } })

    local kept = renderer:find("safearea").props.bars

    assert(#kept == 1 and kept[1] == "status", "and one may be kept while the other goes")
end

-- A bar that is not a bar is refused where it was written rather than ignored by three renderers.
do
    local ok, problem = pcall(function()
        return gui.SafeArea { bars = { "toolbar" }, gui.Text { text = "no" } }
    end)

    assert(not ok, "a name the system has no bar for must be refused")
    assert(tostring(problem):find("toolbar", 1, true) ~= nil, "and the refusal must name it")
end

print("gui.chrome ok")
