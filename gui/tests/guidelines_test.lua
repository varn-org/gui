local chrome = require("gui.style.chrome")
local gui = require("gui")

package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local catalogue = require("catalogue")

local function start(description, platform)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, {
        size = { width = 390, height = 844 },
        platform = platform,
    })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- The types a finger lands on, which are the ones held to what the guidelines ask for.
local PRESSES = { onPress = true, onLongPress = true, onSelect = true }

--- Answers whether a node is one a reader is meant to hit, rather than one that only reports a change.
local function pressable(node)
    for name in pairs(PRESSES) do
        if node.props[name] ~= nil then
            return true
        end
    end

    return false
end

--- Answers how far a node reaches once the slop around it is counted in.
local function reach(node)
    local slop = node.props.hitSlop or 0
    return node.frame.width + slop * 2, node.frame.height + slop * 2
end

-- Nothing a finger has to land on is smaller than the guidelines allow.
--
-- Apple asks for forty-four points and Android for forty-eight density pixels, and a control that is
-- drawn smaller is one a reader misses and presses twice. A hit slop counts, since it is exactly what
-- it is for.
do
    local small = {}

    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local runtime, renderer = start(gui.View { style = { grow = 1 }, demo.render() })

            for _, node in pairs(renderer.nodes) do
                if node.frame ~= nil and pressable(node) then
                    local width, height = reach(node)

                    -- A row that spans the screen is as wide as it needs to be, so only the short
                    -- side of a target is what has to reach the minimum.
                    local shortest = math.min(width, height)

                    if shortest > 0 and shortest < chrome.touch then
                        small[#small + 1] = group.title .. " / " .. demo.title .. ": a " .. node.type
                            .. " reaches " .. width .. "x" .. height
                    end
                end
            end

            runtime:stop()
        end
    end

    assert(#small == 0, "these are smaller than a finger:\n  " .. table.concat(small, "\n  "))
end

-- The chrome is drawn at the proportions each system uses rather than at a number chosen per screen.
do
    for _, platform in ipairs({ "ios", "android", "web" }) do
        local bar = chrome.bar(platform)

        assert(bar.height >= chrome.touch,
            platform .. " draws its bar at " .. bar.height .. ", which nothing could be pressed in")
        assert(chrome.row(platform) >= 44,
            platform .. " draws a row at " .. chrome.row(platform) .. ", which is under what a finger needs")
    end
end

-- The type scale is the platform's own, so a body is a body and a caption is a caption.
do
    local sizes = gui.theme.create().typography.sizes

    assert(sizes.caption < sizes.footnote, "a caption is smaller than a footnote")
    assert(sizes.footnote < sizes.body, "a footnote is smaller than a body")
    assert(sizes.body >= 16, "a body is at least sixteen, which is what stops a reader zooming in")
    assert(sizes.body < sizes.headline, "a headline stands above a body")
    assert(sizes.headline < sizes.title, "a title stands above a headline")
    assert(sizes.title < sizes.heading and sizes.heading < sizes.display, "the scale climbs to the top")
end

-- Anything a reader can press says something to a reader who cannot see it.
--
-- A control announced by nothing is one nobody using a screen reader can find: they hear a button with
-- no name, or hear nothing at all where a control is. What is inside it counts, since that is what the
-- platform reads out, and a control drawn as a picture has to carry its own words.
do
    --- Answers whether anything under a node says words, at the depth a control is ever nested to.
    local function speaks(renderer, id, depth)
        if depth > 6 then
            return false
        end

        for _, node in pairs(renderer.nodes) do
            if node.parent == id then
                if node.type == "text" and node.props.text ~= nil then
                    return true
                end

                if node.props.accessibilityLabel ~= nil then
                    return true
                end

                if speaks(renderer, node.id, depth + 1) then
                    return true
                end
            end
        end

        return false
    end

    local silent = {}

    for index = 1, #catalogue.groups do
        local group = catalogue.groups[index]

        for position = 1, #group.data do
            local demo = group.data[position]
            local renderer = gui.headless()
            local runtime = gui.start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) },
                renderer, { size = { width = 390, height = 844 } })

            for _ = 1, 4 do
                if not runtime:needsCommit() then
                    break
                end

                runtime:commit()
            end

            for _, node in pairs(renderer.nodes) do
                if node.props.onPress ~= nil and node.props.accessibilityLabel == nil
                    and not speaks(renderer, node.id, 0) then
                    silent[#silent + 1] = group.title .. " / " .. demo.title .. ": a " .. node.type
                end
            end

            runtime:stop()
        end
    end

    assert(#silent == 0, "these can be pressed and say nothing at all:\n  " .. table.concat(silent, "\n  "))
end

print("gui.guidelines ok")
