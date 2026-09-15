local gui = require("gui")

package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local Bazaar = require("apps.bazaar")
local Hail = require("apps.hail")
local Lull = require("apps.lull")
local Plate = require("apps.plate")
local Podcasts = require("apps.podcasts")
local Settings = require("apps.settings")
local Shop = require("apps.shop")
local Sprig = require("apps.sprig")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(gui.View { style = { grow = 1 }, description }, renderer, {
        size = { width = 390, height = 844 },
        platform = "ios",
    })

    for _ = 1, 8 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function settle(runtime)
    for _ = 1, 8 do
        runtime:commit()
    end
end

--- Answers every word on screen, which is what a reader sees.
---
--- A button carries its words as a prop rather than as a label inside it, so reading only the text
--- nodes misses every button on the screen.
local WORDS = { "text", "title", "label", "placeholder", "message" }

--- Answers whether anything above a node makes it invisible, which is what a covered screen is.
---
--- A stack keeps every screen it holds and draws the top one, so the words on the screen underneath are
--- in the tree and on nobody's screen. A case that reads them is a case that passes for what a reader
--- cannot see, and one that presses them is pressing through a screen.
local function under(renderer, node, wrong)
    local walk = node

    while walk ~= nil do
        if wrong(walk) then
            return true
        end

        walk = walk.parent ~= nil and renderer.nodes[walk.parent] or nil
    end

    return false
end

local function covered(renderer, node)
    return under(renderer, node, function(walk)
        return (walk.props.style or {}).opacity == 0
    end)
end

local function unreachable(renderer, node)
    return under(renderer, node, function(walk)
        return walk.props.pointerEvents == "none"
    end)
end

local function shown(renderer)
    local labels = {}

    for _, node in pairs(renderer.nodes) do
        if not covered(renderer, node) then
            for _, name in ipairs(WORDS) do
                if type(node.props[name]) == "string" then
                    labels[#labels + 1] = node.props[name]
                end
            end
        end
    end

    return labels
end

local function holds(renderer, wanted)
    for _, label in ipairs(shown(renderer)) do
        if label == wanted or label:find(wanted, 1, true) ~= nil then
            return true
        end
    end

    return false
end

--- Presses whatever was named for a reader who cannot see it, which is how a screen is driven.
local function press(runtime, renderer, label)
    for _, node in pairs(renderer.nodes) do
        if node.props.accessibilityLabel == label and node.props.onPress ~= nil
            and not unreachable(renderer, node) then
            runtime:dispatch(node.id, "onPress", nil)
            settle(runtime)
            return true
        end
    end

    return false
end

--- Answers whether something a reader could press is on screen under that name.
---
--- What a reader sees and what a reader can reach are two different questions. A mark carries no words
--- at all, so the only name it has is the one it was given for a reader who cannot see it.
local function offers(renderer, label)
    for _, node in pairs(renderer.nodes) do
        if node.props.accessibilityLabel == label and node.props.onPress ~= nil
            and not unreachable(renderer, node) then
            return true
        end
    end

    return false
end

--- Reports a change to whichever control of a type is on screen, which is what typing into one is.
local function change(runtime, renderer, type, value)
    for _, node in pairs(renderer.nodes) do
        if node.type == type and node.props.onChange ~= nil and not unreachable(renderer, node) then
            runtime:dispatch(node.id, "onChange", value)
            settle(runtime)
            return true
        end
    end

    return false
end

-- The shop goes from the window to a placed order, which is the path it exists to walk.
do
    local runtime, renderer = start(Shop {})

    assert(holds(renderer, "Shell Chair"), "the window shows what is for sale")

    assert(press(runtime, renderer, "Shell Chair"), "a product opens from the window")
    assert(holds(renderer, "Moulded ply"), "the product screen says what it is")
    assert(holds(renderer, "£340"), "the product screen says what it costs")

    assert(press(runtime, renderer, "Add to bag"), "a product is added to the bag")
    assert(holds(renderer, "Total"), "the bag totals what is in it")

    assert(press(runtime, renderer, "Checkout"), "the bag goes to checkout")
    assert(holds(renderer, "Where it goes"), "checkout asks where it goes")

    -- Nothing is ordered until it has somewhere to go.
    local placing = nil

    for _, node in pairs(renderer.nodes) do
        if node.props.accessibilityLabel == "Place the order" then
            placing = node
        end
    end

    assert(placing ~= nil, "checkout must offer to place the order")
    assert(placing.props.disabled == true, "an order with nowhere to go cannot be placed")

    assert(change(runtime, renderer, "textinput", "Paulo"), "a name is typed in")
    assert(change(runtime, renderer, "textarea", "A street"), "an address is typed in")

    assert(press(runtime, renderer, "Place the order"), "the order is placed")
    assert(holds(renderer, "Ordered"), "the order is confirmed")
    assert(holds(renderer, "Paulo"), "the confirmation says where it is going")
end

-- The player is a path rather than a set of tabs, and the path has no end.
--
-- Browsing goes categories, then the groups in one, then the shows in a group, then a show — and a show
-- names the category and the group it sits in as things a reader may press, which opens that screen on
-- top again. Going round that loop is what puts a stack under strain: the state each screen kept, the
-- way back through all of them, and what a pop costs when there are many behind it.
do
    local runtime, renderer = start(Podcasts {})

    assert(holds(renderer, "Society"), "it opens on the categories")
    assert(not holds(renderer, "Signal and Noise"), "which is not a list of every show")

    assert(press(runtime, renderer, "Making things"), "a category opens")
    assert(holds(renderer, "Software"), "and shows the groups inside it")

    assert(press(runtime, renderer, "Software"), "a group opens")
    assert(holds(renderer, "Signal and Noise"), "and shows what is in it")

    assert(press(runtime, renderer, "Signal and Noise"), "a show opens")
    assert(holds(renderer, "The first mile"), "and carries its episodes")

    assert(press(runtime, renderer, "The first mile"), "an episode plays when it is pressed")
    assert(holds(renderer, "0:00"), "and what is playing says how far in it is")

    -- The show names where it belongs, and pressing that opens it again on top.
    local rounds = 6
    local deep = 4

    for _ = 1, rounds do
        assert(press(runtime, renderer, "Making things"), "the category a show belongs to opens from it")
        assert(press(runtime, renderer, "Signal and Noise"), "and the show opens from that again")

        deep = deep + 2
    end

    -- What is playing followed the whole way down, since it is a field rather than a screen.
    assert(holds(renderer, "The first mile"), "what is playing follows down the path")

    -- And the way back unwinds every one of them, one screen at a time.
    local unwound = 0

    while press(runtime, renderer, "Back") do
        unwound = unwound + 1

        assert(unwound <= deep, "the way back never runs out, it has gone back " .. unwound .. " times")
    end

    assert(unwound == deep - 1,
        "the way back unwound " .. unwound .. " screens rather than " .. (deep - 1))
    assert(holds(renderer, "Society"), "and the whole way back lands on the categories")

    assert(change(runtime, renderer, "searchbar", "pass"), "a search answers as it is typed")
    assert(holds(renderer, "Crossing the pass"), "the search finds what matches")
    assert(not holds(renderer, "Bread, badly"), "the search leaves out what does not")
end

-- The account screen keeps a destructive action behind a confirmation.
do
    local runtime, renderer = start(Settings {})

    assert(holds(renderer, "Notifications"), "the settings show what can be changed")
    assert(holds(renderer, "Paulo Coutinho"), "the settings carry the profile above them")

    assert(press(runtime, renderer, "Delete the account"), "the destructive action is offered")
    assert(holds(renderer, "cannot be undone"), "a destructive action asks first")

    assert(press(runtime, renderer, "Keep it"), "the confirmation can be turned down")
    assert(not holds(renderer, "Account deleted"), "turning it down deletes nothing")

    assert(press(runtime, renderer, "Delete the account"), "the destructive action is offered again")
    assert(press(runtime, renderer, "Delete"), "the confirmation can be accepted")
    assert(holds(renderer, "Account deleted"), "accepting it does the thing")

    -- The profile behind it is a form that saves.
    assert(press(runtime, renderer, "Undo"), "the deletion can be undone")
    assert(press(runtime, renderer, "Profile"), "the profile opens")
    assert(change(runtime, renderer, "textinput", "Someone Else"), "the profile can be edited")
    assert(press(runtime, renderer, "Save"), "the profile saves")
    assert(holds(renderer, "Saved"), "saving says so")
end

--- Walks one of the five applications to the end of a path and back out of it again.
---
--- Each step names what a reader would press and what they would then be looking at, so a screen that
--- draws nothing, a row that opens nothing and a way back that lands somewhere else each fail here
--- rather than being noticed in a screenshot months later. The path is followed and then the whole
--- stack is unwound, since a path that ends deep in an application and a way back that runs out
--- somewhere along it are two different failures and both leave a reader stuck.
local function walk(what, App, path)
    local runtime, renderer = start(App {})

    for index = 1, #path do
        local step = path[index]

        if step.press ~= nil then
            assert(press(runtime, renderer, step.press),
                what .. ": nothing to press called " .. step.press .. " at step " .. index)
        end

        if step.type ~= nil then
            assert(change(runtime, renderer, step.type, step.value),
                what .. ": nothing to type into at step " .. index)
        end

        if step.shows ~= nil then
            assert(holds(renderer, step.shows),
                what .. ": " .. step.shows .. " is not on screen at step " .. index)
        end

        if step.hides ~= nil then
            assert(not holds(renderer, step.hides),
                what .. ": " .. step.hides .. " is still on screen at step " .. index)
        end

        if step.offers ~= nil then
            assert(offers(renderer, step.offers),
                what .. ": nothing offers " .. step.offers .. " at step " .. index)
        end

        if step.withholds ~= nil then
            assert(not offers(renderer, step.withholds),
                what .. ": " .. step.withholds .. " is still offered at step " .. index)
        end
    end

    local unwound = 0

    while press(runtime, renderer, "Back") do
        unwound = unwound + 1

        assert(unwound <= 8, what .. ": the way back never runs out, it has gone back " .. unwound .. " times")
    end

    assert(holds(renderer, path.home), what .. ": the whole way back lands on " .. path.home)
    runtime:stop()
end

-- Food delivery: the address, a place, a dish, the bag and an order, and the way out of each of them.
walk("Plate", Plate, {
    home = "Places near you",

    { shows = "Grill House" },
    { shows = "Deliver to" },
    { shows = "Places near you" },
    { shows = "Free", hides = "Double smash" },

    { press = "Deliver to Rua das Palmeiras, 220", shows = "Home" },
    { press = "Work", shows = "Places near you" },

    { press = "Grill House", shows = "Double smash" },
    { shows = "Two smashed patties" },
    { type = "segmented", value = 2, shows = "Fries with herbs", hides = "Double smash" },
    { type = "segmented", value = 1, shows = "Double smash" },

    { press = "Double smash", shows = "R$ 38,90" },
    { press = "Add R$ 38,90", shows = "Total" },
    { shows = "Grill House" },

    { press = "Place the order", shows = "Order placed" },
    { press = "Back to the start", shows = "Places near you" },
})
-- The bag empties when the last of what was in it is taken out.
do
    local runtime, renderer = start(Plate {})

    assert(press(runtime, renderer, "Grill House"), "a place opens")
    assert(press(runtime, renderer, "Double smash"), "a dish opens")
    assert(press(runtime, renderer, "Add R$ 38,90"), "the dish goes in the bag")
    assert(holds(renderer, "Total"), "the bag totals what is in it")

    assert(change(runtime, renderer, "stepper", 0), "the last of it is taken out")
    assert(holds(renderer, "Your bag is empty"), "and the bag says it is empty")
    assert(press(runtime, renderer, "Find somewhere"), "which offers the way back")
    assert(holds(renderer, "Places near you"), "and lands on the places")

    runtime:stop()
end

-- Ride hailing: a destination, a kind of car, a driver, and back out to the map.
walk("Hail", Hail, {
    home = "Where to?",

    { shows = "Where to?" },
    { shows = "Mercado do Porto" },

    { press = "Menu", shows = "Airport, terminal 2" },
    { press = "Back", shows = "Where to?" },

    { press = "Enter a destination" },
    { type = "textinput", value = "air", shows = "Airport, terminal 2" },
    { hides = "Mercado do Porto" },
    { press = "Airport, terminal 2", shows = "Hail Go" },

    { shows = "To Airport, terminal 2" },
    { shows = "Book Hail Go" },
    { press = "Hail Black", shows = "Book Hail Black" },

    { press = "Book Hail Black", shows = "Marcos" },
    { shows = "RTQ 4D18" },
    { press = "Back", shows = "Book Hail Black" },
    { press = "Back", shows = "Where to?" },
})
-- A marketplace: a product out of the grid, the basket, a search and the filters over it.
walk("Bazaar", Bazaar, {
    home = "Deals of the day",

    { shows = "Deals of the day" },
    { shows = "Search on Bazaar" },
    { shows = "Because you looked at phones" },

    { press = "Smartphone Aurora 12 256 GB 8 GB RAM, unlocked, dual chip", shows = "Free delivery" },
    { shows = "in 12x R$ 233 with no interest" },
    { shows = "Sold by AuroraStore" },
    { shows = "12 in stock" },

    { press = "Add to the basket", shows = "Buy now" },
    { press = "Buy now", shows = "Total" },
    { press = "Continue", shows = "Order confirmed" },
    { press = "Back to the start", shows = "Deals of the day" },

    { press = "Search", shows = "Relevance" },
    { press = "Cheapest", shows = "Running shoes with cushioned sole, sizes 38 to 45" },
    { press = "Back", shows = "Deals of the day" },
})
-- Messaging: the tabs, a conversation, something sent into it, and the way back out.
walk("Sprig", Sprig, {
    home = "Ana Ribeiro",

    { shows = "Ana Ribeiro" },
    { shows = "the small one is fine" },

    { press = "Status", shows = "Tap to add an update", hides = "the small one is fine" },
    { press = "Calls", shows = "Today, 13:20" },
    { press = "Chats", shows = "the small one is fine" },

    { press = "Ana Ribeiro", shows = "are you coming tonight?" },
    { shows = "yes, leaving in twenty minutes" },

    -- The mark beside the field is a microphone until there is something to send, and then it is an
    -- arrow, which is the one piece of behaviour everybody who has used one of these expects.
    { offers = "Record a message", withholds = "Send" },
    { type = "textinput", value = "on my way", offers = "Send", withholds = "Record a message" },
    { press = "Send", shows = "on my way", offers = "Record a message" },

    { press = "Back", shows = "Ana Ribeiro" },
    { shows = "on my way" },
})
-- An audiobook: a shelf, a book, its chapters, the player, and back up through all of it.
walk("Lull", Lull, {
    home = "Continue listening",

    { shows = "Continue listening" },
    { shows = "The Turning Tide" },
    { shows = "New this month" },

    { press = "Library", shows = "Due North" },
    { press = "Back", shows = "Continue listening" },

    { press = "Search" },
    { type = "textinput", value = "north", shows = "Due North" },
    { hides = "Ember Road" },
    { press = "Due North", shows = "Read by Peter Hale" },

    { shows = "Isabel Krohn" },
    { shows = "3 chapters" },
    { shows = "Base camp" },
    { shows = "Start listening" },

    { press = "Start listening", shows = "Now playing" },
    { offers = "Back fifteen seconds", shows = "15" },
    { offers = "On thirty seconds", shows = "30" },
    { offers = "Sleep timer", shows = "Off" },
    { press = "Pause", offers = "Play" },

    { press = "Close the player", shows = "3 chapters" },
    { offers = "Now playing, Due North" },
    { press = "Back", shows = "Continue listening" },
})
print("gui.apps ok")
