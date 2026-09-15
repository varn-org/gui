local gui = require("gui")
local parts = require("parts")

--- The four the library ships, in the order a reader is most likely to want them.
local THEMES = {
    { key = "material3", title = "Material 3", controls = gui.controls.material3 },
    { key = "material2", title = "Material 2", controls = gui.controls.material2 },
    { key = "cupertino", title = "Cupertino", controls = gui.controls.cupertino },
    { key = "native", title = "Native", controls = gui.controls.native },
}

--- The variants a button is drawn in, each of them saying which one was pressed.
local VARIANTS = {
    { title = "Filled" },
    { title = "Tinted", variant = "tinted" },
    { title = "Outlined", variant = "outlined" },
    { title = "Plain", variant = "plain" },
    { title = "Delete", variant = "destructive" },
}

local function pressed(held, change)
    local built = {}

    for index = 1, #VARIANTS do
        local entry = VARIANTS[index]

        built[index] = gui.Button {
            key = entry.title,
            title = entry.title,
            variant = entry.variant,
            onPress = function() change({ said = entry.title .. " was pressed" }) end,
        }
    end

    built[#built + 1] = gui.Button { key = "off", title = "Off", disabled = true }

    return built
end

--- Every control the library draws, under one control theme, with something to press on each of them.
---
--- The state is held here rather than per control theme, so switching designs keeps what the reader has
--- already done: the same tree drawn another way is the point being shown.
local Every = gui.component({
    name = "EveryControl",

    render = function(self)
        local held = self.props.held
        local change = self.props.onChange

        return gui.View { style = { gap = "sm" },
            parts.Row("Switch", gui.Switch {
                accessibilityLabel = "Switch",
                value = held.on,
                onChange = function(value) change({ on = value }) end,
            }),

            gui.Checkbox {
                label = "A checkbox",
                value = held.ticked,
                onChange = function(value) change({ ticked = value }) end,
            },

            gui.Checkbox { label = "Neither one nor the other", indeterminate = true },
            gui.Checkbox { label = "One nobody may change", value = true, disabled = true },

            gui.Radio {
                value = "one",
                label = "The first",
                selected = held.chosen == "one",
                onSelect = function(value) change({ chosen = value }) end,
            },

            gui.Radio {
                value = "two",
                label = "The second",
                selected = held.chosen == "two",
                onSelect = function(value) change({ chosen = value }) end,
            },

            gui.SegmentedControl {
                segments = { "Day", "Week", "Month" },
                selectedIndex = held.span,
                onChange = function(index) change({ span = index }) end,
            },

            parts.Row("Stepper", gui.Stepper {
                accessibilityLabel = "How many",
                value = held.count,
                minimum = 0,
                maximum = 9,
                onChange = function(value) change({ count = value }) end,
            }),

            parts.Row("Rating", gui.Rating {
                accessibilityLabel = "How good",
                value = held.marks,
                onChange = function(value) change({ marks = value }) end,
            }),

            parts.Field("Slider", gui.Slider {
                value = held.level,
                onChange = function(value) change({ level = value }) end,
            }),

            parts.Field("A range", gui.RangeSlider {
                range = held.between,
                onChange = function(value) change({ between = value }) end,
            }),

            gui.View { style = { direction = "row", align = "center", gap = "md" },
                gui.ProgressBar { value = 0.6, style = { grow = 1 } },
                gui.ProgressCircle { value = 0.6 },
                gui.ActivityIndicator {},
            },

            gui.TextField {
                label = "Your name",
                helper = "As it is written on the card",
                value = held.name,
                placeholder = "Ada Lovelace",
                onChange = function(value) change({ name = value }) end,
            },

            gui.View { style = { direction = "row", gap = "md", wrap = true },
                gui.DatePicker {
                    value = held.day,
                    accessibilityLabel = "A day",
                    onChange = function(value) change({ day = value }) end,
                },

                gui.TimePicker {
                    value = held.hour,
                    accessibilityLabel = "A time",
                    onChange = function(value) change({ hour = value }) end,
                },
            },

            gui.ColorPicker {
                value = held.tint,
                accessibilityLabel = "A colour",
                onChange = function(value) change({ tint = value }) end,
            },

            gui.Picker {
                value = held.chosen,
                placeholder = "Choose one",
                title = "Which one",
                options = {
                    { value = "one", label = "The first" },
                    { value = "two", label = "The second" },
                    { value = "three", label = "The third" },
                },
                onChange = function(value) change({ chosen = value }) end,
            },

            gui.View { style = { direction = "row", gap = "sm", wrap = true },
                table.unpack(pressed(held, change)),
            },

            gui.Text {
                text = held.said,
                style = { fontSize = "footnote", color = "textMuted" },
            },
        }
    end,
})

--- A control theme drawn in a panel of its own, so four of them read as four designs of one screen.
local Panel = gui.component({
    name = "ControlPanel",

    render = function(self)
        return gui.View {
            key = self.props.title,
            style = {
                gap = "sm",
                padding = "md",
                radius = "md",
                background = "elevated",
                border = 1,
                borderColor = "separator",
            },

            gui.Text {
                text = self.props.title:upper(),
                style = { fontSize = "caption", fontWeight = "700", color = "textMuted" },
            },

            gui.Controls {
                value = self.props.controls,
                Every { held = self.props.held, onChange = self.props.onChange },
            },
        }
    end,
})

--- Every control in every control theme, side by side, with the whole application's own beside them.
local Side = gui.component({
    name = "ControlsSideBySide",
    state = { on = true, ticked = true, chosen = "one", span = 2, count = 3, marks = 3, level = 0.4, between = { 0.2, 0.7 }, name = "", said = "Nothing pressed yet" },

    render = function(self)
        local change = function(given) self:setState(given) end
        local panels = {}

        for index = 1, #THEMES do
            panels[index] = Panel {
                title = THEMES[index].title,
                controls = THEMES[index].controls,
                held = self.state,
                onChange = change,
            }
        end

        return parts.Page {
            parts.Block {
                title = "One screen, four designs",
                summary = "The same tree, drawn by the platform and by three control themes",
                table.unpack(panels),
            },
        }
    end,
})

--- The whole application put into another control theme, which is what an application actually does.
local Whole = gui.component({
    name = "ControlsChooser",
    state = { on = true, ticked = false, chosen = "two", span = 1, count = 1, marks = 4, level = 0.7, between = { 0.1, 0.5 }, name = "Ada", said = "Nothing pressed yet" },

    render = function(self)
        local wearing = gui.theming:read(self)
        local names = {}
        local at = 1

        for index = 1, #THEMES do
            names[index] = THEMES[index].title

            if THEMES[index].controls == wearing.controls then
                at = index
            end
        end

        return parts.Page {
            parts.Block {
                title = "The whole application",
                summary = "Choosing one here draws every control in the gallery that way",

                gui.SegmentedControl {
                    segments = names,
                    selectedIndex = at,
                    onChange = function(index) wearing.useControls(THEMES[index].controls) end,
                },
            },

            parts.Block {
                title = "Drawn in " .. THEMES[at].title,
                Every { held = self.state, onChange = function(given) self:setState(given) end },
            },
        }
    end,
})

return {
    {
        key = "side",
        title = "Four designs at once",
        summary = "Every control, drawn four ways on one screen",
        render = function() return Side {} end,
    },
    {
        key = "chooser",
        title = "Choosing one",
        summary = "Put the whole application into another control theme",
        render = function() return Whole {} end,
    },
}
