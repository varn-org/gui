local gui = require("gui")
local parts = require("parts")

local Dialogs = gui.component({
    name = "DialogsDemo",
    state = { modal = false, sheet = false, alert = false, actions = false, toast = false },

    render = function(self)
        local function show(field)
            return function() self:setState({ [field] = true }) end
        end

        local function hide(field)
            return function() self:setState({ [field] = false }) end
        end

        return gui.View { style = { grow = 1 },
            parts.Page {
                parts.Block {
                    title = "Over the screen",
                    gui.Button { title = "Show a modal", onPress = show("modal") },
                    gui.Button { title = "Show a sheet", variant = "tinted", onPress = show("sheet") },
                },

                parts.Block {
                    title = "Asking something",
                    gui.Button { title = "Show an alert", variant = "outlined", onPress = show("alert") },
                    gui.Button { title = "Show an action sheet", variant = "outlined", onPress = show("actions") },
                },

                parts.Block {
                    title = "Saying something",
                    gui.Button { title = "Show a toast", variant = "tinted", onPress = show("toast") },
                },
            },

            gui.Modal { visible = self.state.modal, onDismiss = hide("modal"),
                gui.View { style = { padding = "lg", gap = "md" },
                    gui.Text { text = "A modal", style = { fontSize = "heading", fontWeight = "700" } },
                    gui.Text { text = "It covers the screen until it is dismissed." },
                    gui.Button { title = "Close", onPress = hide("modal") },
                },
            },

            gui.Sheet { visible = self.state.sheet, detents = { "medium", "large" }, onDismiss = hide("sheet"),
                gui.View { style = { padding = "lg", gap = "md" },
                    gui.Text { text = "A sheet", style = { fontSize = "heading", fontWeight = "700" } },
                    gui.Text { text = "It rises from the bottom and stops where it was told to." },
                    gui.Button { title = "Close", onPress = hide("sheet") },
                },
            },

            gui.Alert {
                visible = self.state.alert,
                title = "Delete this?",
                message = "It cannot be brought back.",
                actions = { { key = "cancel", label = "Cancel" }, { key = "delete", label = "Delete", destructive = true } },
                onAction = hide("alert"),
                onDismiss = hide("alert"),
            },

            gui.ActionSheet {
                visible = self.state.actions,
                title = "Choose one",
                cancelLabel = "Cancel",
                actions = { { key = "copy", label = "Copy" }, { key = "share", label = "Share" } },
                onAction = hide("actions"),
                onDismiss = hide("actions"),
            },

            gui.Toast {
                visible = self.state.toast,
                message = "Saved",
                duration = 2000,
                onDismiss = hide("toast"),
            },
        }
    end,
})

local Menus = gui.component({
    name = "MenusDemo",
    state = { menu = false, drawer = false, chosen = "nothing yet" },

    render = function(self)
        return gui.View { style = { grow = 1 },
            parts.Page {
                parts.Block {
                    title = "A menu",
                    gui.Button { title = "Open the menu", onPress = function() self:setState({ menu = true }) end },
                    gui.Text { text = "Chosen: " .. self.state.chosen, style = { color = "textMuted" } },
                },

                parts.Block {
                    title = "A drawer",
                    gui.Button { title = "Open the drawer", variant = "tinted",
                        onPress = function() self:setState({ drawer = true }) end },
                },
            },

            gui.Menu {
                visible = self.state.menu,
                items = {
                    { key = "edit", label = "Edit" },
                    { key = "duplicate", label = "Duplicate" },
                    { key = "delete", label = "Delete", destructive = true },
                },
                onSelect = function(key) self:setState({ menu = false, chosen = key }) end,
                onDismiss = function() self:setState({ menu = false }) end,
            },

            gui.Drawer {
                open = self.state.drawer,
                side = "left",
                width = 260,
                onClose = function() self:setState({ drawer = false }) end,
                content = gui.View { style = { padding = "lg", gap = "sm" },
                    gui.Text { text = "A drawer", style = { fontWeight = "700" } },
                    gui.Button { title = "Close", onPress = function() self:setState({ drawer = false }) end },
                },
            },
        }
    end,
})

local Grouping = gui.component({
    name = "GroupingDemo",
    state = { expanded = "first", tab = 1, screen = 1 },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "An accordion",
                gui.Accordion {
                    expanded = self.state.expanded,
                    onChange = function(key) self:setState({ expanded = key }) end,
                    sections = {
                        { key = "first", title = "The first", content = "What is inside the first section." },
                        { key = "second", title = "The second", content = "And what is inside the second." },
                    },
                },
            },

            parts.Block {
                title = "A tab bar",
                gui.TabBar {
                    tabs = { { key = "home", label = "Home" }, { key = "search", label = "Search" }, { key = "you", label = "You" } },
                    selectedIndex = self.state.tab,
                    onChange = function(index) self:setState({ tab = index }) end,
                },
            },

            parts.Block {
                title = "A navigation stack",
                gui.NavigationStack {
                    style = { height = 220 },
                    index = self.state.screen,
                    title = "Pushed",
                    onIndexChange = function(index) self:setState({ screen = index }) end,
                    screens = {
                        {
                            key = "first",
                            title = "First",
                            content = gui.View { style = { padding = "md", gap = "sm" },
                                gui.Text { text = "The platform pushes with its own transition." },
                                gui.Button { title = "Push", onPress = function() self:setState({ screen = 2 }) end },
                            },
                        },
                        {
                            key = "second",
                            title = "Second",
                            content = gui.View { style = { padding = "md", gap = "sm" },
                                gui.Text { text = "And its own back gesture brings you here." },
                                gui.Button { title = "Back", variant = "tinted",
                                    onPress = function() self:setState({ screen = 1 }) end },
                            },
                        },
                    },
                },
            },
        }
    end,
})

return {
    { key = "dialogs", title = "Modals, sheets and alerts", summary = "Everything shown over the screen", render = function() return Dialogs {} end },
    { key = "menus", title = "Menus and drawers", summary = "Chosen from, or slid in from a side", render = function() return Menus {} end },
    { key = "grouping", title = "Accordion, tabs and a stack", summary = "Ways of holding several screens", render = function() return Grouping {} end },
}
