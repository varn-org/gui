local gui = require("gui")

package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local Podcasts = require("apps.podcasts")
local Settings = require("apps.settings")
local Shop = require("apps.shop")

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

local function shown(renderer)
    local labels = {}

    for _, node in pairs(renderer.nodes) do
        for _, name in ipairs(WORDS) do
            if type(node.props[name]) == "string" then
                labels[#labels + 1] = node.props[name]
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
        if node.props.accessibilityLabel == label and node.props.onPress ~= nil then
            runtime:dispatch(node.id, "onPress", nil)
            settle(runtime)
            return true
        end
    end

    return false
end

--- Reports a change to whichever control of a type is on screen, which is what typing into one is.
local function change(runtime, renderer, type, value)
    for _, node in pairs(renderer.nodes) do
        if node.type == type and node.props.onChange ~= nil then
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

-- The player browses, searches, keeps and plays, and what is playing follows between tabs.
do
    local runtime, renderer = start(Podcasts {})

    assert(holds(renderer, "Signal and Noise"), "the home screen shows the shows")
    assert(holds(renderer, "The first mile"), "the home screen shows the episodes")

    assert(press(runtime, renderer, "The first mile"), "an episode plays when it is pressed")
    assert(holds(renderer, "0:00"), "what is playing says how far in it is")

    -- The bar that says what is playing follows you to another tab.
    local tabs = nil

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" and node.props.accessibilityLabel == "Search" then
            tabs = node
        end
    end

    assert(tabs ~= nil, "the player must offer its tabs")
    runtime:dispatch(tabs.id, "onPress", nil)
    settle(runtime)

    assert(holds(renderer, "The first mile"), "what is playing follows between tabs")

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

print("gui.apps ok")
