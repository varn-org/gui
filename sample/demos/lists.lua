local gui = require("gui")
local parts = require("parts")

local FRUIT = { "Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape", "Lemon" }

local function rows(count)
    local data = {}

    for index = 1, count do
        data[index] = {
            id = index,
            label = "Row " .. index,
            kind = index % 12 == 1 and "feature" or "row",
        }
    end

    return data
end

local Simple = gui.component({
    name = "SimpleListDemo",
    state = { chosen = "nothing yet" },

    render = function(self)
        return gui.View { style = { grow = 1 },
            gui.View { style = { padding = "md" },
                gui.Text { text = "Chosen: " .. self.state.chosen, style = { color = "textMuted" } },
            },
            gui.List {
                style = { grow = 1 },
                data = FRUIT,
                itemExtent = 56,
                keyExtractor = function(item) return item end,
                separator = gui.Divider {},
                onSelect = function(event) self:setState({ chosen = event.item }) end,
                renderItem = function(item)
                    return gui.View { style = { paddingHorizontal = "md", justify = "center", grow = 1 },
                        gui.Text { text = item },
                    }
                end,
            },
        }
    end,
})

local Sections = gui.component({
    name = "SectionListDemo",

    render = function()
        return gui.SectionList {
            style = { grow = 1 },
            itemExtent = 52,
            headerExtent = 40,
            stickyHeaders = true,
            sections = {
                { key = "berries", title = "Berries", data = { "Cherry", "Elderberry", "Grape" } },
                { key = "citrus", title = "Citrus", data = { "Lemon", "Orange", "Lime" } },
                { key = "rest", title = "The rest", data = { "Apple", "Banana", "Date", "Fig" } },
            },
            renderHeader = function(section)
                return gui.View { style = { background = "surface", paddingHorizontal = "md", justify = "center", grow = 1 },
                    gui.Text { text = section.title, style = { fontWeight = "700" } },
                }
            end,
            renderItem = function(item)
                return gui.View { style = { paddingHorizontal = "md", justify = "center", grow = 1 },
                    gui.Text { text = item },
                }
            end,
        }
    end,
})

local Columns = gui.component({
    name = "GridDemo",

    render = function()
        return gui.Grid {
            style = { grow = 1 },
            data = FRUIT,
            columns = 2,
            spacing = 12,
            rowExtent = 96,
            keyExtractor = function(item) return item end,
            renderItem = function(item)
                return gui.View {
                    style = { grow = 1, margin = "sm", background = "surface", radius = "md", justify = "center", align = "center" },
                    gui.Text { text = item, style = { fontWeight = "600" } },
                }
            end,
        }
    end,
})

local Paged = gui.component({
    name = "CarouselDemo",
    state = { page = 1 },

    render = function(self)
        return gui.View { style = { grow = 1, gap = "md", padding = "md" },
            gui.Carousel {
                style = { height = 220 },
                data = FRUIT,
                index = self.state.page,
                keyExtractor = function(item) return item end,
                onIndexChange = function(index) self:setState({ page = index }) end,
                renderItem = function(item)
                    return gui.View {
                        style = { grow = 1, margin = "sm", background = "surface", radius = "lg", justify = "center", align = "center" },
                        gui.Text { text = item, style = { fontSize = "title", fontWeight = "700" } },
                    }
                end,
            },
            gui.Text { text = "Page " .. self.state.page .. " of " .. #FRUIT, style = { color = "textMuted" } },
        }
    end,
})

local Long = gui.component({
    name = "LongListDemo",
    state = { data = rows(50000) },

    render = function(self)
        return gui.View { style = { grow = 1 },
            gui.View { style = { padding = "md" },
                gui.Text { text = "Fifty thousand rows, two kinds of cell, reuse on", style = { color = "textMuted" } },
            },
            gui.List {
                style = { grow = 1 },
                data = self.state.data,
                recycle = true,
                separator = gui.Divider {},
                keyExtractor = function(item) return item.id end,
                itemType = function(item) return item.kind end,
                itemExtent = function(item) return item.kind == "feature" and 108 or 56 end,
                renderItem = function(item)
                    if item.kind == "feature" then
                        return gui.View { style = { padding = "md", direction = "row", gap = "md", align = "center", grow = 1 },
                            gui.Avatar { initials = tostring(item.id % 100), size = 44 },
                            gui.View { style = { grow = 1, gap = "xs" },
                                gui.Text { text = item.label, style = { fontWeight = "700" } },
                                gui.Text { text = "A taller cell of its own kind", style = { color = "textMuted" } },
                            },
                            gui.Badge { value = item.id % 9 },
                        }
                    end

                    return gui.View { style = { paddingHorizontal = "md", justify = "center", grow = 1 },
                        gui.Text { text = item.label },
                    }
                end,
            },
        }
    end,
})

local Rows = gui.component({
    name = "TableDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "Columns, sorting and selection",
                gui.Table {
                    style = { height = 280 },
                    columns = {
                        { key = "name", title = "Name" },
                        { key = "kind", title = "Kind" },
                    },
                    rows = {
                        { name = "Apple", kind = "Pome" },
                        { name = "Cherry", kind = "Drupe" },
                        { name = "Grape", kind = "Berry" },
                    },
                    sortBy = "name",
                },
            },
        }
    end,
})

return {
    { key = "list", title = "A simple list", summary = "Rows, separators and selection", render = function() return Simple {} end },
    { key = "sections", title = "Sections", summary = "Groups under headers that stick", render = function() return Sections {} end },
    { key = "grid", title = "Grid", summary = "A fixed number of columns", render = function() return Columns {} end },
    { key = "carousel", title = "Carousel", summary = "Paged along its axis", render = function() return Paged {} end },
    { key = "long", title = "Fifty thousand rows", summary = "Two cell kinds, reuse, windowing", render = function() return Long {} end },
    { key = "table", title = "Table", summary = "Columns and rows", render = function() return Rows {} end },
}
