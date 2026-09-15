local gui = require("gui")
local parts = require("parts")

local Dialogs = gui.component({
    name = "DialogsDemo",
    state = { modal = false, sheet = false, alert = false, actions = false, toast = false, note = false },

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
                    gui.Button { title = "Pin a note over everything", variant = "outlined", onPress = show("note") },
                },
            },

            -- Written inside the page and drawn over the whole application, bar and tabs included.
            self.state.note and gui.Portal {
                gui.Pressable {
                    style = {
                        position = "absolute", top = 16, left = 16, right = 16,
                        padding = "md", radius = "md", background = "primary",
                    },
                    accessibilityLabel = "Dismiss the note",
                    onPress = hide("note"),
                    gui.Text { text = "Pinned over the application. Press to dismiss.", style = { color = "onPrimary" } },
                },
            } or false,

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
    state = { menu = false, drawer = false, side = "left", chosen = "nothing yet" },

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
                        onPress = function() self:setState({ drawer = true, side = "left" }) end },
                    gui.Button { title = "Open it from the other side", variant = "tinted",
                        onPress = function() self:setState({ drawer = true, side = "right" }) end },
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

            -- The side outlives the open, since a drawer leaves the way it came and is still leaving
            -- after it has been closed: told the other side while it goes, it slides out across the
            -- screen it came from.
            gui.Drawer {
                open = self.state.drawer,
                side = self.state.side,
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

--- The shape every screen is built into, drawn by the library rather than by hand on each one.
local Shape = gui.component({
    name = "ShapeDemo",
    state = { added = 0, tab = 1 },

    render = function(self)
        return gui.Scaffold {
            bar = gui.AppBar {
                title = "Inbox",
                subtitle = self.state.added == 0 and "Nothing added yet" or (self.state.added .. " added"),
                leading = {
                    { key = "menu", icon = "menu", accessibilityLabel = "Menu",
                        onPress = function() self:setState({ added = 0 }) end },
                },
                trailing = {
                    { key = "search", icon = "search", accessibilityLabel = "Search",
                        onPress = function() self:setState({ added = self.state.added + 1 }) end },
                },
            },

            bottom = gui.TabBar {
                tabs = {
                    { key = "all", label = "All", icon = "home" },
                    { key = "unread", label = "Unread", icon = "bell" },
                },
                selectedIndex = self.state.tab,
                onChange = function(index) self:setState({ tab = index }) end,
            },

            floating = gui.Button {
                title = "+",
                onPress = function() self:setState({ added = self.state.added + 1 }) end,
                style = { width = 56, height = 56, radius = "pill" },
            },

            gui.View { style = { padding = "md", gap = "sm" },
                gui.Text {
                    text = "The bar, the screen, the bar along the bottom and what floats over all of it.",
                    style = { color = "textMuted" },
                },
                gui.Text { text = "Added " .. self.state.added .. " so far", style = { fontWeight = "600" } },
            },
        }
    end,
})

return {
    { key = "shape", title = "A bar and a shape", summary = "The arrangement every screen is built into", render = function() return Shape {} end },
    { key = "dialogs", title = "Modals, sheets and alerts", summary = "Everything shown over the screen", render = function() return Dialogs {} end },
    { key = "menus", title = "Menus and drawers", summary = "Chosen from, or slid in from a side", render = function() return Menus {} end },
    { key = "grouping", title = "Accordion, tabs and a stack", summary = "Ways of holding several screens", render = function() return Grouping {} end },
}
