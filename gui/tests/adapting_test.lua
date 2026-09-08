local gui = require("gui")

package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local app = require("app")

--- The widths a real device actually hands an application, which is what adapting has to answer to.
---
--- None of these is a device: they are how much room there is. A tablet, a phone turned sideways, a
--- window sharing a screen with another and a folding phone that has just been opened are one thing.
local ROOMS = {
    { name = "a phone", width = 390, height = 844, together = false },
    { name = "a phone turned sideways", width = 844, height = 390, together = true },
    { name = "a folding phone, closed", width = 374, height = 819, together = false },
    { name = "a folding phone, opened", width = 717, height = 819, together = true },
    { name = "a tablet", width = 1024, height = 1366, together = true },
    { name = "a tablet, a third of the screen", width = 320, height = 1366, together = false },
    { name = "a tablet, half the screen", width = 507, height = 1366, together = false },
    { name = "a tablet, two thirds of the screen", width = 694, height = 1366, together = true },
}

local function start(description, room)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, {
        size = { width = room.width, height = room.height },
        platform = "ios",
    })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function holds(renderer, wanted)
    for _, node in pairs(renderer.nodes) do
        if node.props.text == wanted or node.props.title == wanted then
            return true
        end
    end

    return false
end

--- Answers whether something is actually on screen rather than merely held somewhere in the tree.
---
--- Both panes stay mounted whichever there is room for, since taking one down loses everything a reader
--- put into it. The one there is no room for is held out of sight instead.
local function seen(renderer, wanted)
    for _, node in pairs(renderer.nodes) do
        if node.props.text == wanted or node.props.title == wanted then
            local up = node

            while up ~= nil do
                local style = up.props.style

                if style ~= nil and style.opacity == 0 then
                    return false
                end

                up = renderer.nodes[up.parent]
            end

            return true
        end
    end

    return false
end

local Screen = gui.component({
    name = "Adapting",
    render = function(self)
        return gui.SplitView {
            sidebar = gui.Text { text = "The list" },
            content = gui.Text { text = "What is open" },
            showing = self.props.showing,
        }
    end,
})

-- A split shows both where there is room and one at a time where there is not.
do
    for _, room in ipairs(ROOMS) do
        local _, renderer = start(Screen { showing = true }, room)

        assert(holds(renderer, "The list") and holds(renderer, "What is open"),
            room.name .. " must keep both panes, or a turn of the phone empties one of them")

        if room.together then
            assert(seen(renderer, "The list") and seen(renderer, "What is open"),
                room.name .. " has room for both, and showed only one")
        else
            assert(seen(renderer, "What is open") and not seen(renderer, "The list"),
                room.name .. " has room for one, and showed both")
        end
    end
end

-- With room for one and nothing open, the list is the screen.
do
    local _, renderer = start(Screen { showing = false }, ROOMS[1])

    assert(seen(renderer, "The list"), "with nothing open the list is what is on screen")
    assert(not seen(renderer, "What is open"), "nothing is open, so nothing open is shown")
end

-- The room changing is something the tree answers, rather than something it is told once at start.
--
-- A window being dragged wider, a device being turned and a folding phone being opened all arrive as
-- exactly this, so answering it is answering all three.
do
    local renderer = gui.headless()
    local runtime = gui.start(Screen { showing = true }, renderer, {
        size = { width = 390, height = 844 },
        platform = "ios",
    })

    for _ = 1, 6 do
        runtime:commit()
    end

    assert(not seen(renderer, "The list"), "a narrow window shows one at a time")

    runtime:resize(1024, 844)

    for _ = 1, 6 do
        runtime:commit()
    end

    assert(seen(renderer, "The list"), "a window opened wider shows both")
    assert(seen(renderer, "What is open"), "and keeps what was open")

    runtime:resize(390, 844)

    for _ = 1, 6 do
        runtime:commit()
    end

    assert(not seen(renderer, "The list"), "a window closed back down shows one again")
end

-- What a reader put into a pane is still there when the room changes, which is the whole point of both
-- of them staying mounted.
--
-- Rendering one tree with room for both and another with room for one crosses between two trees on a
-- turn of the phone, and everything under them is taken down and built again. A reader loses what they
-- typed for having held the device sideways.
do
    local Typing = gui.component({
        name = "Typing",
        state = { text = "" },
        render = function(self)
            return gui.TextInput { value = self.state.text,
                onChange = function(value) self:setState({ text = value }) end }
        end,
    })

    local Adapting = gui.component({
        name = "AdaptingTyping",
        render = function()
            return gui.SplitView {
                showing = true,
                sidebar = gui.Text { text = "The list" },
                content = Typing {},
            }
        end,
    })

    local renderer = gui.headless()
    local runtime = gui.start(Adapting {}, renderer, {
        size = { width = 390, height = 844 },
        platform = "ios",
    })

    for _ = 1, 6 do
        runtime:commit()
    end

    renderer:find("textinput").props.onChange("typed by a reader")

    for _ = 1, 6 do
        runtime:commit()
    end

    runtime:resize(844, 390)

    for _ = 1, 6 do
        runtime:commit()
    end

    local field = renderer:find("textinput")

    assert(field ~= nil, "the pane must still be there after the room changed")
    assert(field.props.value == "typed by a reader",
        "and it must still hold what was typed into it, holds " .. tostring(field.props.value))
end

-- The gallery itself adapts, since it is the thing a reader judges the split by.
do
    local _, wide = start(app.root, ROOMS[5])

    assert(holds(wide, "Varn GUI"), "the index stays beside what it opens on a tablet")
    assert(holds(wide, "Pick something on the left"), "with nothing open the tablet says so")

    local _, narrow = start(app.root, ROOMS[1])

    assert(holds(narrow, "Varn GUI"), "on a phone the index is the screen")
end

-- A width that changes the arrangement is reported, since a caller keeps its own idea of what is open.
do
    local told = {}

    local runtime = gui.start(
        gui.SplitView {
            sidebar = gui.Text { text = "index" },
            content = gui.Text { text = "detail" },
            onShowingChange = function(both) told[#told + 1] = both end,
        },
        gui.headless(),
        { size = { width = 1024, height = 768 }, platform = "ios" }
    )

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    assert(#told == 0, "nothing is reported for the room it opened in")

    runtime:resize(390, 844)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    assert(#told == 1 and told[1] == false,
        "a room too narrow for both is reported once, got " .. #told .. " reports")

    runtime:resize(1024, 768)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    assert(#told == 2 and told[2] == true, "and so is the room widening again")
end

-- A tablet is not a large phone, which the guideline says control by control.
--
-- Keeping a phone's proportions on a large screen is what makes an application read as one that was
-- stretched: a bar that stays 44 tall, a margin of 16 at the edge of a thirteen inch screen, and a
-- sheet from the bottom edge covering all of it for one field and a button.
do
    local chrome = require("gui.style.chrome")

    assert(chrome.bar("ios").height == 44, "iOS draws a bar 44 tall on a phone")
    assert(chrome.bar("ios", "compact").height == 44, "which is what a compact width is")
    assert(chrome.bar("ios", "expanded").height == 50, "and 50 on a large screen")
    assert(chrome.bar("android", "expanded").height == 56, "Android draws the same bar at either width")

    assert(chrome.margin("compact") == 16, "a phone keeps 16 at its edges")
    assert(chrome.margin("expanded") == 20, "and a large screen keeps 20")

    assert(chrome.panel("compact").centred == false, "a phone shows a panel against an edge")
    assert(chrome.panel("expanded").centred == true, "and a large screen centres one")
    assert(chrome.panel("expanded").width == 540, "at the width the system gives a form sheet")

    assert(chrome.readable > 600 and chrome.readable < 800,
        "and a run of text is capped at a width somebody can read, which is " .. chrome.readable)
end

-- What is shown over a screen follows the same rule, since that is what a reader sees it as.
do
    local renderer = gui.headless()
    local runtime = gui.start(gui.Modal { visible = true, gui.Text { text = "Inside" } }, renderer,
        { size = { width = 1024, height = 768 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    local panel = nil

    for _, node in pairs(renderer.nodes) do
        local style = node.props.style

        if style ~= nil and style.width == 540 then
            panel = node
        end
    end

    assert(panel ~= nil, "a modal on a large screen is a panel rather than the whole screen")
    assert(panel.frame.width == 540, "it is as wide as the system draws one, got " .. panel.frame.width)
    assert(panel.frame.x > 100, "and it is centred rather than against an edge, at " .. panel.frame.x)

    runtime:stop()
end

print("gui.adapting ok")
