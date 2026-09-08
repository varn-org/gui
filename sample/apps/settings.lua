local gui = require("gui")

--- An account: grouped rows, the controls a settings screen is made of, and a profile behind them.
---
--- This is the screen every application has and nobody shows off, which is exactly why it is here: it
--- is where grouped rows, a destructive action behind a confirmation and a form that behaves around the
--- keyboard all have to be right at once.
local LANGUAGES = {
    { value = "en", label = "English" },
    { value = "pt", label = "Português" },
    { value = "sv", label = "Svenska" },
}

local Settings = gui.component({
    name = "Settings",
    state = {
        screen = "settings",
        notifications = true,
        sounds = false,
        language = "en",
        quiet = 3,
        reminder = nil,
        confirming = false,
        goodbye = false,
        name = "Paulo Coutinho",
        email = "paulo@example.com",
        saved = false,
    },

    --- A row of a grouped list, which is a label, whatever control it carries, and a rule under it.
    Row = function(self, key, label, control, note)
        return gui.View {
            key = key,
            style = { direction = "row", align = "center", justify = "space-between", gap = "md",
                minHeight = 52, paddingHorizontal = "md" },

            gui.View { style = { grow = 1, gap = 1 },
                gui.Text { text = label, numberOfLines = 1 },
                note ~= nil and gui.Text {
                    text = note,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted" },
                } or false,
            },

            control,
        }
    end,

    Group = function(self, title, rows)
        local children = {}

        for index = 1, #rows do
            children[#children + 1] = rows[index]

            if index < #rows then
                children[#children + 1] = gui.Divider { key = "rule:" .. index }
            end
        end

        return gui.View { style = { gap = "xs" },
            gui.Text {
                text = title:upper(),
                style = { fontSize = "caption", fontWeight = "600", color = "textMuted",
                    paddingHorizontal = "md" },
            },
            gui.View { style = { background = "elevated", radius = "md", overflow = "hidden" },
                table.unpack(children),
            },
        }
    end,

    Main = function(self)
        return gui.ScrollView {
            style = { grow = 1 },
            contentStyle = { gap = "lg", paddingVertical = "md" },
            keyboardDismissMode = "on-drag",

            gui.Pressable {
                style = { direction = "row", align = "center", gap = "md", minHeight = 72,
                    paddingHorizontal = "md", background = "elevated" },
                accessibilityLabel = "Profile",
                onPress = function() self:setState({ screen = "profile" }) end,

                gui.Avatar { initials = "PC", size = 52 },
                gui.View { style = { grow = 1, gap = 2 },
                    gui.Text { text = self.state.name, numberOfLines = 1, style = { fontWeight = "600" } },
                    gui.Text {
                        text = self.state.email,
                        numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },
                gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
            },

            self:Group("Alerts", {
                self:Row("notifications", "Notifications", gui.Switch {
                    value = self.state.notifications,
                    onChange = function(value) self:setState({ notifications = value }) end,
                }),
                self:Row("sounds", "Sounds", gui.Switch {
                    value = self.state.sounds,
                    disabled = not self.state.notifications,
                    onChange = function(value) self:setState({ sounds = value }) end,
                }),
                self:Row("quiet", "Quiet hours", gui.Stepper {
                    value = self.state.quiet,
                    minimum = 0,
                    maximum = 12,
                    onChange = function(value) self:setState({ quiet = value }) end,
                }, self.state.quiet .. " hours after midnight"),
            }),

            self:Group("Reading", {
                self:Row("language", "Language", gui.Picker {
                    options = LANGUAGES,
                    value = self.state.language,
                    onChange = function(value) self:setState({ language = value }) end,
                    style = { width = 148 },
                }),
                self:Row("reminder", "Remind me", gui.TimePicker {
                    value = self.state.reminder,
                    onChange = function(value) self:setState({ reminder = value }) end,
                }),
            }),

            gui.View { style = { paddingHorizontal = "md" },
                gui.Button {
                    title = "Delete the account",
                    variant = "destructive",
                    onPress = function() self:setState({ confirming = true }) end,
                },
            },
        }
    end,

    Profile = function(self)
        return gui.KeyboardAvoiding {
            style = { grow = 1 },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", padding = "md" },
                keyboardDismissMode = "on-drag",

                gui.View { style = { align = "center", gap = "sm", paddingVertical = "md" },
                    gui.Avatar { initials = "PC", size = 88 },
                    gui.Button { title = "Change the picture", variant = "plain", onPress = function() end },
                },

                gui.TextInput {
                    placeholder = "Name",
                    value = self.state.name,
                    returnKey = "next",
                    onChange = function(value) self:setState({ name = value, saved = false }) end,
                },

                gui.TextInput {
                    placeholder = "Email",
                    keyboard = "email",
                    autoCapitalize = "none",
                    value = self.state.email,
                    onChange = function(value) self:setState({ email = value, saved = false }) end,
                },

                gui.TextArea { placeholder = "Anything else", rows = 4, onChange = function() end },

                gui.Button {
                    title = self.state.saved and "Saved" or "Save",
                    disabled = self.state.saved,
                    onPress = function() self:setState({ saved = true }) end,
                },
            },
        }
    end,

    render = function(self)
        if self.state.goodbye then
            return gui.View { style = { grow = 1, justify = "center", align = "center", gap = "md" },
                gui.Text { text = "Account deleted", style = { fontSize = "heading", fontWeight = "700" } },
                gui.Button {
                    title = "Undo",
                    variant = "tinted",
                    onPress = function() self:setState({ goodbye = false }) end,
                },
            }
        end

        local screens = {
            { key = "settings", title = "Settings", content = self:Main() },
        }

        if self.state.screen == "profile" then
            screens[2] = { key = "profile", title = "Profile", content = self:Profile() }
        end

        return gui.View { style = { grow = 1, background = "surface" },
            gui.NavigationStack {
                style = { grow = 1 },
                screens = screens,
                index = #screens,
                onPop = function() self:setState({ screen = "settings" }) end,
            },

            gui.Alert {
                visible = self.state.confirming,
                title = "Delete the account",
                message = "Everything in it goes with it, and it cannot be undone.",
                onDismiss = function() self:setState({ confirming = false }) end,
                actions = {
                    { key = "cancel", label = "Keep it", cancel = true },
                    { key = "delete", label = "Delete", destructive = true },
                },
                onAction = function(key)
                    self:setState({ confirming = false, goodbye = key == "delete" })
                end,
            },
        }
    end,
})

return Settings
