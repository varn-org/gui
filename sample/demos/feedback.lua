local gui = require("gui")
local parts = require("parts")

local Progress = gui.component({
    name = "ProgressDemo",
    state = { value = 0, refreshing = false },

    --- Fills the bar a step at a time and starts it again once it is full, which is what one looks like.
    onMount = function(self)
        self:every(400, function()
            local value = self.state.value + 0.1

            self:setState({ value = value > 1 and 0 or value })
        end)
    end,

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
                gui.Text {
                    text = math.floor(self.state.value * 100 + 0.5) .. "%",
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            parts.Block {
                title = "Not there yet",
                summary = "The shape of what is coming, drawn before it is there",
                gui.Skeleton { lines = 3 },
                gui.View { style = { direction = "row", gap = "sm", align = "center" },
                    gui.Skeleton { shape = "circle", style = { width = 44, height = 44 } },
                    gui.Skeleton { lines = 2, style = { grow = 1 } },
                },
            },

        }
    end,
})

--- Pull to refresh belongs to whatever owns the scrolling gesture, so it is shown on a real list.
local Refreshing = gui.component({
    name = "RefreshDemo",
    state = { refreshing = false, rounds = 0 },

    reload = function(self)
        self:setState({ refreshing = true })

        require("async").spawn(function()
            require("async").sleep(1200):await()

            if not self.gone then
                self:setState({ refreshing = false, rounds = self.state.rounds + 1 })
            end
        end)
    end,

    onUnmount = function(self)
        self.gone = true
    end,

    render = function(self)
        local rows = {}

        for index = 1, 24 do
            rows[index] = { key = index, label = "Row " .. index }
        end

        return gui.View { style = { grow = 1 },
            gui.View { style = { padding = "md", gap = "xs" },
                gui.Text { text = "Pull the list down", style = { fontWeight = "600" } },
                gui.Text {
                    text = self.state.refreshing and "Refreshing" or ("Refreshed " .. self.state.rounds .. " times"),
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.List {
                style = { grow = 1 },
                data = rows,
                itemExtent = 44,
                refreshing = self.state.refreshing,
                onRefresh = function() self:reload() end,
                keyExtractor = function(item) return item.key end,
                separator = gui.Divider {},
                renderItem = function(item)
                    return gui.View { style = { grow = 1, justify = "center", paddingHorizontal = "md" },
                        gui.Text { text = item.label },
                    }
                end,
            },
        }
    end,
})

local Labels = gui.component({
    name = "LabelsDemo",
    state = { selected = "one", kept = { "Coffee", "Tea", "Cocoa" } },

    --- The chips somebody is building a set out of, each one able to take itself back out of it.
    Kept = function(self)
        local chips = {}

        for index = 1, #self.state.kept do
            local label = self.state.kept[index]

            chips[#chips + 1] = gui.Chip {
                key = label,
                label = label,
                onRemove = function()
                    local left = {}

                    for at = 1, #self.state.kept do
                        if self.state.kept[at] ~= label then
                            left[#left + 1] = self.state.kept[at]
                        end
                    end

                    self:setState({ kept = left })
                end,
            }
        end

        return chips
    end,

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
                summary = "One of a set, or one somebody is building and can take back",
                gui.View { style = { direction = "row", wrap = true, gap = "sm" },
                    gui.Chip { label = "One", selected = self.state.selected == "one",
                        onPress = function() self:setState({ selected = "one" }) end },
                    gui.Chip { label = "Two", selected = self.state.selected == "two",
                        onPress = function() self:setState({ selected = "two" }) end },
                },
                gui.View { style = { direction = "row", wrap = true, gap = "sm" }, table.unpack(self:Kept()) },
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
    { key = "refresh", title = "Pull to refresh", summary = "A list that fetches again when it is pulled",
        render = function() return Refreshing {} end },
    { key = "progress", title = "Progress and waiting", summary = "Spinners, bars and skeletons", render = function() return Progress {} end },
    { key = "labels", title = "Badges, chips and cards", summary = "Small pieces that label things", render = function() return Labels {} end },
}
