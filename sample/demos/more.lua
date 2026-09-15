local gui = require("gui")
local parts = require("parts")

--- The controls a reader meets on a phone that this library had none of.
---
--- Each is drawn by the engine under every control theme including `native`, since none of them is a
--- control the platform itself draws: what a system has instead is a different control with a different
--- behaviour, or nothing at all.
local Screen = gui.component({
    name = "MoreControls",
    state = {
        page = 3,
        step = 2,
        rail = 1,
        open = { docs = true },
        chosen = "readme",
        saying = false,
        banner = true,
        popover = false,
        anchor = nil,
        said = "Nothing yet",
    },

    render = function(self)
        local held = self.state

        return parts.Page {
            parts.Block {
                title = "A message that waits to be answered",
                summary = "A banner stays until it is answered and a snackbar offers to undo something",

                gui.Banner {
                    visible = held.banner,
                    message = "Two of these have not been backed up",
                    icon = "info",
                    actions = { { key = "later", label = "Later" }, { key = "now", label = "Back up" } },
                    onAction = function(key)
                        self:setState({ banner = false, said = "The banner said " .. key })
                    end,
                },

                gui.Button {
                    title = "Delete it",
                    variant = "destructive",
                    onPress = function() self:setState({ saying = true }) end,
                },

                gui.Text { text = held.said, style = { fontSize = "footnote", color = "textMuted" } },
            },

            parts.Block {
                title = "A row dragged sideways",
                summary = "What can be done to it is behind the row rather than beside it",

                gui.SwipeActions {
                    trailing = {
                        { key = "flag", label = "Flag", icon = "star" },
                        { key = "bin", label = "Delete", icon = "trash", destructive = true },
                    },
                    onAction = function(key) self:setState({ said = "The row was told " .. key }) end,

                    gui.View {
                        style = { padding = "md", background = "elevated", gap = "xs" },
                        gui.Text { text = "Drag me to the left" },
                        gui.Text {
                            text = "There is something behind this row",
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },
                },
            },

            parts.Block {
                title = "How far through something a reader is",

                gui.ProgressSteps {
                    steps = {
                        { key = "who", label = "Who" },
                        { key = "where", label = "Where" },
                        { key = "pay", label = "Pay" },
                    },
                    step = held.step,
                    onChange = function(step) self:setState({ step = step }) end,
                },
            },

            parts.Block {
                title = "A long list of results",

                gui.Pagination {
                    page = held.page,
                    count = 24,
                    onChange = function(page) self:setState({ page = page }) end,
                },
            },

            parts.Block {
                title = "Rows that hold rows",

                gui.TreeView {
                    nodes = {
                        {
                            key = "docs",
                            label = "Documents",
                            children = {
                                { key = "readme", label = "Readme" },
                                {
                                    key = "notes",
                                    label = "Notes",
                                    children = { { key = "monday", label = "Monday" } },
                                },
                            },
                        },
                        { key = "pictures", label = "Pictures" },
                    },
                    open = held.open,
                    selected = held.chosen,
                    onOpen = function(key, open)
                        local held = {}

                        for name, value in pairs(self.state.open) do
                            held[name] = value
                        end

                        held[key] = open or nil
                        self:setState({ open = held })
                    end,
                    onSelect = function(key) self:setState({ chosen = key }) end,
                },
            },

            parts.Block {
                title = "The tab bar of a wide screen",

                gui.View { style = { direction = "row", gap = "md", height = 240 },
                    gui.NavigationRail {
                        tabs = {
                            { key = "inbox", label = "Inbox", icon = "mail" },
                            { key = "sent", label = "Sent", icon = "send" },
                            { key = "bin", label = "Bin", icon = "trash" },
                        },
                        selectedIndex = held.rail,
                        onChange = function(index) self:setState({ rail = index }) end,
                    },

                    gui.View {
                        style = { grow = 1, justify = "center", align = "center", background = "surface", radius = "md" },
                        gui.Text { text = "Whatever the rail chose", style = { color = "textMuted" } },
                    },
                },
            },

            parts.Block {
                title = "Something anchored to what opened it",

                gui.Button {
                    title = "Show a popover",
                    variant = "outlined",
                    onLayout = function(frame) self:setState({ anchor = frame }) end,
                    onPress = function() self:setState({ popover = true }) end,
                },
            },

            parts.Block {
                title = "A button that floats over the screen",

                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.FloatingActionButton {
                        icon = "plus",
                        accessibilityLabel = "New",
                        onPress = function() self:setState({ said = "The floating button was pressed" }) end,
                    },

                    gui.FloatingActionButton {
                        icon = "send",
                        label = "Write",
                        onPress = function() self:setState({ said = "Write was pressed" }) end,
                    },
                },
            },

            gui.Snackbar {
                visible = held.saying,
                message = "One thing was deleted",
                actions = { { key = "undo", label = "Undo" } },
                onAction = function() self:setState({ saying = false, said = "It was put back" }) end,
            },

            gui.Popover {
                visible = held.popover,
                anchor = held.anchor,
                onDismiss = function() self:setState({ popover = false }) end,

                gui.Text { text = "This came out of the button", style = { padding = "sm" } },
            },
        }
    end,
})

return {
    {
        key = "more",
        title = "The rest of the controls",
        summary = "A rail, a snackbar, a banner, a popover, pages, steps, a tree and a swipe",
        render = function() return Screen {} end,
    },
}
