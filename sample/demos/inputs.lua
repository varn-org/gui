local gui = require("gui")
local parts = require("parts")

local Fields = gui.component({
    name = "TextFieldsDemo",
    state = { name = "", notes = "", search = "" },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "One line",
                parts.Field("Your name", gui.TextInput {
                    value = self.state.name,
                    placeholder = "Ada Lovelace",
                    onChange = function(value) self:setState({ name = value }) end,
                }),
                parts.Field("Password", gui.TextInput { value = "", placeholder = "Secret", secure = true }),
                parts.Field("Email", gui.TextInput { value = "", placeholder = "you@example.com", keyboard = "email" }),
            },

            parts.Block {
                title = "Many lines",
                parts.Field("Notes", gui.TextArea {
                    value = self.state.notes,
                    placeholder = "Anything you like",
                    rows = 4,
                    onChange = function(value) self:setState({ notes = value }) end,
                }),
            },

            parts.Block {
                title = "Searching",
                gui.SearchBar {
                    value = self.state.search,
                    placeholder = "Search",
                    onChange = function(value) self:setState({ search = value }) end,
                },
                gui.Text { text = "Looking for " .. (self.state.search ~= "" and self.state.search or "nothing yet") },
            },
        }
    end,
})

local Toggles = gui.component({
    name = "TogglesDemo",
    state = { subscribed = true, agreed = false, plan = "monthly", segment = 1 },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "A switch",
                parts.Row("Subscribe to updates", gui.Switch {
                    value = self.state.subscribed,
                    onChange = function(value) self:setState({ subscribed = value }) end,
                }),
            },

            parts.Block {
                title = "A checkbox",
                gui.Checkbox {
                    value = self.state.agreed,
                    label = "I agree to the terms",
                    onChange = function(value) self:setState({ agreed = value }) end,
                },
            },

            parts.Block {
                title = "One of several",
                gui.RadioGroup {
                    value = self.state.plan,
                    options = { { value = "monthly", label = "Monthly" }, { value = "yearly", label = "Yearly" } },
                    onChange = function(value) self:setState({ plan = value }) end,
                },
                gui.Text { text = "Chosen: " .. self.state.plan, style = { color = "textMuted" } },
                gui.Radio {
                    value = "trial",
                    label = "Or a trial, on its own",
                    selected = self.state.plan == "trial",
                    onSelect = function() self:setState({ plan = "trial" }) end,
                },
            },

            parts.Block {
                title = "A segmented control",
                gui.SegmentedControl {
                    segments = { "Day", "Week", "Month" },
                    selectedIndex = self.state.segment,
                    onChange = function(index) self:setState({ segment = index }) end,
                },
            },
        }
    end,
})

local Sliders = gui.component({
    name = "SlidersDemo",
    state = { volume = 0.4, quantity = 2, rating = 3 },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "A slider",
                parts.Field("Volume", gui.Slider {
                    value = self.state.volume,
                    onChange = function(value) self:setState({ volume = value }) end,
                }),
                gui.Text { text = string.format("%.0f%%", self.state.volume * 100), style = { color = "textMuted" } },
            },

            parts.Block {
                title = "A stepper",
                parts.Row("Quantity", gui.Stepper {
                    value = self.state.quantity,
                    minimum = 0,
                    maximum = 10,
                    onChange = function(value) self:setState({ quantity = value }) end,
                }),
                gui.Text { text = self.state.quantity .. " of them", style = { color = "textMuted" } },
            },

            parts.Block {
                title = "A rating",
                gui.Rating {
                    value = self.state.rating,
                    count = 5,
                    onChange = function(value) self:setState({ rating = value }) end,
                },
            },
        }
    end,
})

local Pickers = gui.component({
    name = "PickersDemo",
    state = { country = "pt", colour = "#3b82f6" },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "From a list",
                parts.Field("Country", gui.Picker {
                    value = self.state.country,
                    options = {
                        { value = "pt", label = "Portugal" },
                        { value = "br", label = "Brazil" },
                        { value = "jp", label = "Japan" },
                    },
                    onChange = function(value) self:setState({ country = value }) end,
                }),
            },

            parts.Block {
                title = "A date and a time",
                parts.Field("Date", gui.DatePicker { value = "2026-09-05T00:00:00Z" }),
                parts.Field("Time", gui.TimePicker { value = "2026-09-05T09:30:00Z" }),
            },

            parts.Block {
                title = "A colour and a file",
                parts.Row("Colour", gui.ColorPicker {
                    value = self.state.colour,
                    onChange = function(value) self:setState({ colour = value }) end,
                }),
                gui.FilePicker { title = "Choose a file" },
            },
        }
    end,
})

local Buttons = gui.component({
    name = "ButtonsDemo",
    state = { pressed = 0, held = 0 },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Buttons",
                gui.Button { title = "Filled", onPress = function() self:setState({ pressed = self.state.pressed + 1 }) end },
                gui.Button { title = "Tinted", variant = "tinted" },
                gui.Button { title = "Outlined", variant = "outlined" },
                gui.Button { title = "Destructive", variant = "destructive" },
                gui.Button { title = "Disabled", disabled = true },
                gui.Text { text = "Pressed " .. self.state.pressed .. " times", style = { color = "textMuted" } },
            },

            parts.Block {
                title = "Anything can be pressed",
                gui.Pressable {
                    accessibilityLabel = "Press me",
                    onPress = function() self:setState({ held = self.state.held + 1 }) end,
                    parts.Swatch("Press me", { background = "success" }),
                },
                gui.Text { text = "Held " .. self.state.held .. " times", style = { color = "textMuted" } },
            },
        }
    end,
})

return {
    { key = "fields", title = "Text fields", summary = "One line, many lines and a search bar", render = function() return Fields {} end },
    { key = "toggles", title = "Toggles and choices", summary = "Switch, checkbox, radios, segments", render = function() return Toggles {} end },
    { key = "sliders", title = "Sliders and steppers", summary = "A value chosen by dragging or stepping", render = function() return Sliders {} end },
    { key = "pickers", title = "Pickers", summary = "A list, a date, a time, a colour, a file", render = function() return Pickers {} end },
    { key = "buttons", title = "Buttons", summary = "Every variant, and a pressable box", render = function() return Buttons {} end },
}
