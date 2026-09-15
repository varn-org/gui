local gui = require("gui")
local async = require("async")
local waitFor = require("gui.tests.waiting")

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

--- Answers the text of every label on screen, which is what a reader sees.
local function shown(renderer)
    local labels = renderer:findAll("text")
    local text = {}

    for index = 1, #labels do
        text[#text + 1] = tostring(labels[index].props.text)
    end

    return table.concat(text, "\n")
end

--- Answers the pressable carrying a name, which is what a finger would land on.
local function pressable(renderer, label)
    local found = renderer:findAll("pressable")

    for index = 1, #found do
        if found[index].props.accessibilityLabel == label then
            return found[index]
        end
    end

    error("nothing on screen is named " .. label, 2)
end

-- Nothing shown over the screen takes any room while it is not showing.
--
-- These were node types no renderer ever built, so pressing the button that shows one changed the
-- state, re-rendered, and put nothing at all on the screen.
do
    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Modal { visible = false, gui.Text { text = "inside the modal" } },
        gui.Sheet { visible = false, gui.Text { text = "inside the sheet" } },
        gui.Alert { visible = false, title = "Delete this?" },
        gui.ActionSheet { visible = false, title = "Choose one" },
        gui.Menu { visible = false, items = { { key = "edit", label = "Edit" } } },
        gui.Toast { visible = false, message = "Saved" },
    })

    assert(shown(renderer):find("inside the", 1, true) == nil, "nothing hidden is on screen")
    assert(#renderer:findAll("pressable") == 0, "nothing hidden can be pressed")
end

-- A modal covers the screen with what it was given, and the ground behind it dismisses it.
do
    local dismissed = false

    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Modal {
            visible = true,
            onDismiss = function() dismissed = true end,
            gui.Text { text = "inside the modal" },
        },
    })

    assert(shown(renderer):find("inside the modal", 1, true) ~= nil, "a modal shows what it was given")

    pressable(renderer, "Dismiss").props.onPress()
    assert(dismissed, "pressing the ground behind a modal dismisses it")
end

-- A modal that may not be dismissed offers no way to, rather than offering one that does nothing.
do
    local _, renderer = start(gui.Modal {
        visible = true,
        dismissible = false,
        onDismiss = function() error("a modal that may not be dismissed was") end,
        gui.Text { text = "held" },
    })

    assert(#renderer:findAll("pressable") == 0, "there is nothing to press behind a modal that is held")
end

-- A sheet rises from the bottom and stops at the detent it was told to.
do
    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Sheet { visible = true, detents = { "large" }, gui.Text { text = "inside the sheet" } },
    })

    assert(shown(renderer):find("inside the sheet", 1, true) ~= nil, "a sheet shows what it was given")

    local panels = renderer:findAll("view")
    local tall = false

    for index = 1, #panels do
        local frame = panels[index].frame

        if frame ~= nil and frame.height > 700 and frame.height < 844 then
            tall = true
        end
    end

    assert(tall, "a sheet at its large detent takes most of the screen and not all of it")
end

-- An alert asks its question and reports the answer that was pressed.
do
    local answered = nil

    local _, renderer = start(gui.Alert {
        visible = true,
        title = "Delete this?",
        message = "It cannot be brought back.",
        actions = { { key = "cancel", label = "Cancel" }, { key = "delete", label = "Delete", destructive = true } },
        onAction = function(key) answered = key end,
    })

    local text = shown(renderer)
    assert(text:find("Delete this?", 1, true) ~= nil, "an alert asks its question")
    assert(text:find("It cannot be brought back.", 1, true) ~= nil, "and says what it means")

    pressable(renderer, "Delete").props.onPress()
    assert(answered == "delete", "the answer that was pressed is the one reported, got " .. tostring(answered))
end

-- An action sheet offers its choices and a way out that is not one of them.
do
    local answered = nil
    local dismissed = false

    local _, renderer = start(gui.ActionSheet {
        visible = true,
        title = "Choose one",
        cancelLabel = "Cancel",
        actions = { { key = "copy", label = "Copy" }, { key = "share", label = "Share" } },
        onAction = function(key) answered = key end,
        onDismiss = function() dismissed = true end,
    })

    pressable(renderer, "Share").props.onPress()
    assert(answered == "share", "the choice that was pressed is the one reported")

    pressable(renderer, "Cancel").props.onPress()
    assert(dismissed, "the way out dismisses rather than choosing")
end

-- A menu lists what it holds and reports the one that was chosen.
do
    local chosen = nil

    local _, renderer = start(gui.Menu {
        visible = true,
        items = {
            { key = "edit", label = "Edit" },
            { key = "delete", label = "Delete", destructive = true },
        },
        onSelect = function(key) chosen = key end,
    })

    assert(shown(renderer):find("Edit", 1, true) ~= nil, "a menu lists what it holds")

    pressable(renderer, "Delete").props.onPress()
    assert(chosen == "delete", "the item that was pressed is the one reported, got " .. tostring(chosen))
end

-- A toast says what happened, and offers what to do about it when it was given one.
do
    local acted = false

    local _, renderer = start(gui.Toast {
        visible = true,
        message = "Saved",
        action = "Undo",
        onAction = function() acted = true end,
        onDismiss = function() end,
    })

    assert(shown(renderer):find("Saved", 1, true) ~= nil, "a toast says what happened")

    pressable(renderer, "Undo").props.onPress()
    assert(acted, "what to do about it reports when it is pressed")
end

-- A ground fades where it is and a panel travels, since they are two different moves.
--
-- Both were one node under one transition, so dismissing anything slid the darkness down with the panel
-- and uncovered the screen from the top while the overlay was still on its way out.
do
    local Shown = gui.component({
        name = "Shown",
        state = { open = true },
        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Sheet {
                    visible = self.state.open,
                    onDismiss = function() self:setState({ open = false }) end,
                    gui.Text { text = "A sheet" },
                },
            }
        end,
    })

    local _, renderer = start(Shown {})

    local ground = nil
    local travelling = nil

    for _, node in pairs(renderer.nodes) do
        local enter = node.props.enter

        if enter ~= nil then
            if enter.transform ~= nil then
                travelling = node
            else
                ground = node
            end
        end
    end

    assert(ground ~= nil, "the ground behind a sheet must arrive")
    assert(ground.props.enter.opacity == 0, "and it arrives by fading, since it has nowhere to travel to")
    assert(ground.props.enter.transform == nil, "a ground that travels drags the screen out from under it")

    assert(travelling ~= nil, "the panel must arrive by travelling")
    assert(travelling.props.enter.transform.translateY == "100%",
        "a panel anchored to an edge travels the whole of its own height, travels "
            .. tostring(travelling.props.enter.transform.translateY))

    -- A travel written as a share of the node is a share of the panel, so the panel is the node that
    -- carries it rather than a screen-sized sheet of glass with the panel somewhere inside.
    assert(travelling.frame.height < 844,
        "the travelling node is the panel, is " .. travelling.frame.height .. " tall")
    assert(ground.frame.height == 844, "and the ground is what covers the screen")
end

-- What a portal holds is laid out against the surface rather than against the box it was written in.
--
-- An overlay written inside a screen would otherwise cover that screen and nothing else: a drawer raised
-- from a screen inside a stack opened under the bar above it, and an alert raised from a panel was
-- trapped in the panel.
do
    local _, renderer = start(gui.View { style = { grow = 1, padding = 40 },
        gui.View { style = { height = 100, overflow = "hidden" },
            gui.Portal {
                gui.View { style = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0 },
                    gui.Text { text = "over everything" },
                },
            },
        },
    })

    local found = renderer:findAll("layer")

    assert(#found == 1, "a portal draws one layer, drew " .. #found)

    local layer = found[1]

    assert(layer.frame.x == 0 and layer.frame.y == 0,
        "a layer stands at the corner of the surface, stands at " .. layer.frame.x .. "," .. layer.frame.y)
    assert(layer.frame.width == 390 and layer.frame.height == 844,
        "and it is the whole of it, is " .. layer.frame.width .. "x" .. layer.frame.height)
    assert(shown(renderer):find("over everything", 1, true) ~= nil, "and what it holds is on screen")
end

-- A portal is where it was written for everything but where it is drawn, so what it holds reads the
-- state of the component that raised it and goes when that component does.
do
    local Screen = gui.component({
        name = "PortalScreen",
        state = { count = 0, gone = false },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Pressable {
                    accessibilityLabel = "Add",
                    onPress = function() self:setState({ count = self.state.count + 1 }) end,
                    gui.Text { text = "add" },
                },

                gui.Pressable {
                    accessibilityLabel = "Leave",
                    onPress = function() self:setState({ gone = true }) end,
                    gui.Text { text = "leave" },
                },

                not self.state.gone and gui.Portal {
                    gui.Text { text = "counted " .. self.state.count },
                } or false,
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    assert(shown(renderer):find("counted 0", 1, true) ~= nil, "a portal draws what the tree gave it")

    pressable(renderer, "Add").props.onPress()
    runtime:commit()

    assert(shown(renderer):find("counted 1", 1, true) ~= nil,
        "and it follows the state it was written under, shows " .. shown(renderer))

    pressable(renderer, "Leave").props.onPress()
    runtime:commit()

    assert(#renderer:findAll("layer") == 0, "a portal goes when what raised it goes")
end

async.run(function()
    -- A screen that goes while what it raised is still leaving takes the layer with it.
    --
    -- The exit is held open for the length of the move, so a screen dismissed and then left in the same
    -- tick has an overlay outliving the tree that raised it. It would stay over the application for good,
    -- since nothing below is holding it any more and nothing above knows it is there.
    do
        local Leaving = gui.component({
            name = "Leaving",
            state = { open = true, gone = false },

            render = function(self)
                if self.state.gone then
                    return gui.View { style = { grow = 1 } }
                end

                return gui.View { style = { grow = 1 },
                    gui.Sheet {
                        visible = self.state.open,
                        onDismiss = function() end,
                        gui.Text { text = "inside" },
                    },
                }
            end,
        })

        local runtime, renderer = start(Leaving {})

        assert(#renderer:findAll("layer") == 1, "the sheet is drawn through a layer")

        runtime.root.instance:setState({ open = false })
        runtime:commit()
        runtime.root.instance:setState({ gone = true })
        runtime:commit()

        -- The layer goes when the travel out ends, which is waited for rather than slept through.
        waitFor(function()
            runtime:commit()
            return #renderer:findAll("layer") == 0
        end)

        local left = #renderer:findAll("layer")
        assert(left == 0, "nothing is left over the application, " .. left .. " left")
    end

    -- Everything shown over a screen reports both ends of both moves, the way a platform tells a screen.
    --
    -- Told only that something was dismissed, a caller has to guess when it actually went: a video paused
    -- while a sheet is still travelling is paused on screen, and one freed too late holds a decoder open
    -- over a screen nobody is looking at. Each of the four is a moment, and each has its other half.
    do
        local async = require("async")

            -- Each is written the way it is written, since a modal takes children and a toast a message.
        local shown = {
            { gui.Modal, { gui.Text { text = "inside" } } },
            { gui.Sheet, { gui.Text { text = "inside" } } },
            { gui.Menu, { items = { { key = "one", label = "One" } } } },
            { gui.Toast, { message = "said" } },
            { gui.Alert, { title = "asked", actions = { { key = "ok", label = "OK" } } } },
            { gui.ActionSheet, { title = "asked", cancelLabel = "No",
                actions = { { key = "ok", label = "OK" } } } },
        }

        for index = 1, #shown do
            local told = {}

            local Screen = gui.component({
                name = "MomentScreen" .. index,
                state = { open = true },

                render = function(self)
                    local spec = {
                        visible = self.state.open,
                        onDismiss = function() end,
                        onWillShow = function() told[#told + 1] = "onWillShow" end,
                        onShow = function() told[#told + 1] = "onShow" end,
                        onWillHide = function() told[#told + 1] = "onWillHide" end,
                        onHide = function() told[#told + 1] = "onHide" end,
                    }

                    for key, value in pairs(shown[index][2]) do
                        spec[key] = value
                    end

                    return gui.View { style = { grow = 1 }, shown[index][1](spec) }
                end,
            })

            local runtime = start(Screen {})

            assert(told[1] == "onWillShow",
                "it says it is about to arrive, " .. tostring(shown[index][3] or index)
                    .. " said " .. tostring(told[1]))

            waitFor(function()
                runtime:commit()
                return told[2] ~= nil
            end)

            assert(told[2] == "onShow", "and says it has, said " .. tostring(told[2]))

            runtime.root.instance:setState({ open = false })
            runtime:commit()

            assert(told[3] == "onWillHide", "it says it is about to go, said " .. tostring(told[3]))

            waitFor(function()
                runtime:commit()
                return told[4] ~= nil
            end)

            assert(told[4] == "onHide", "and says it has gone, said " .. tostring(told[4]))
        end
    end

    print("gui.presentation ok")
end)
