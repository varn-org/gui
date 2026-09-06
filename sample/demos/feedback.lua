local gui = require("gui")
local parts = require("parts")

local Progress = gui.component({
    name = "ProgressDemo",
    state = { value = 0.35, refreshing = false },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Working",
                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.ActivityIndicator { size = "small" },
                    gui.ActivityIndicator { size = "medium" },
                    gui.ActivityIndicator { size = "large" },
                },
            },

            parts.Block {
                title = "How far along",
                gui.ProgressBar { value = self.state.value },
                gui.ProgressBar { indeterminate = true },
                gui.Button {
                    title = "Advance",
                    variant = "tinted",
                    onPress = function() self:setState({ value = math.min(1, self.state.value + 0.15) }) end,
                },
            },

            parts.Block {
                title = "Not there yet",
                gui.Skeleton { lines = 3 },
            },

            parts.Block {
                title = "Pull to refresh",
                gui.RefreshControl {
                    refreshing = self.state.refreshing,
                    title = "Refreshing",
                    onRefresh = function() self:setState({ refreshing = false }) end,
                },
            },
        }
    end,
})

local Labels = gui.component({
    name = "LabelsDemo",
    state = { selected = "one" },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Badges",
                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.Badge { value = 3 },
                    gui.Badge { value = 42 },
                    gui.Badge { value = 128, max = 99 },
                    gui.Badge { dot = true },
                },
            },

            parts.Block {
                title = "Chips",
                gui.View { style = { direction = "row", wrap = true, gap = "sm" },
                    gui.Chip { label = "One", selected = self.state.selected == "one",
                        onPress = function() self:setState({ selected = "one" }) end },
                    gui.Chip { label = "Two", selected = self.state.selected == "two",
                        onPress = function() self:setState({ selected = "two" }) end },
                    gui.Chip { label = "Removable" },
                },
            },

            parts.Block {
                title = "A card",
                gui.Card { style = { padding = "md", gap = "xs" },
                    gui.Text { text = "A card", style = { fontWeight = "700" } },
                    gui.Text { text = "Raised off the background, with its own padding.", style = { color = "textMuted" } },
                },
            },

            parts.Block {
                title = "A tooltip",
                gui.Tooltip { text = "Explains what a thing is for" },
            },
        }
    end,
})

return {
    { key = "progress", title = "Progress and waiting", summary = "Spinners, bars, skeletons, refresh", render = function() return Progress {} end },
    { key = "labels", title = "Badges, chips and cards", summary = "Small pieces that label things", render = function() return Labels {} end },
}
