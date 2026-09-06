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

print("gui.presentation ok")
