local collections = require("gui.components.collections")
local feedback = require("gui.components.feedback")
local component = require("gui.component")
local content = require("gui.components.content")
local input = require("gui.components.input")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

--- The containers are built from the declared components, so they carry the same look every screen does.
local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable

--- The proportions the containers are built from, which are the ones the platforms themselves use.
local BAR = 44
local TAB = 56
local HEADER = 48

--- Answers whether a section of an accordion is open, which is one key or a set of them.
local function opened(expanded, key)
    if type(expanded) == "table" then
        for index = 1, #expanded do
            if expanded[index] == key then
                return true
            end
        end

        return false
    end

    return expanded == key
end

--- Answers what the caller gave as the content of a section or a screen, ready to be a child.
---
--- A caller writes either an element or a string, and a string is what a caller writing a demo reaches
--- for first, so it is turned into the label it obviously means.
local function contentOf(value)
    if type(value) == "string" then
        return Text { text = value }
    end

    return value
end

--- Sections that open one at a time, or several at once, each one a header over what it holds.
---
--- The content of a section is an ordinary element, built by this component into the tree rather than
--- handed to a renderer, which is what lets it hold anything at all.
M.Accordion = support.component("Accordion", {
    props = { "sections", "expanded", "multiple" },
    events = { "onChange" },
    defaults = { multiple = false },
    validate = function(spec)
        if type(spec.sections) ~= "table" then
            return "sections must be a list of { key, title, content } entries"
        end
    end,
}, component.define({
    name = "Accordion",

    --- Answers what `expanded` becomes when a section is pressed, which depends on whether several may open.
    toggled = function(self, key)
        if not self.props.multiple then
            if self.props.expanded == key then
                return nil
            end

            return key
        end

        local kept = {}
        local found = false

        for index = 1, #(self.props.expanded or {}) do
            local open = self.props.expanded[index]

            if open == key then
                found = true
            else
                kept[#kept + 1] = open
            end
        end

        if not found then
            kept[#kept + 1] = key
        end

        return kept
    end,

    render = function(self)
        local sections = self.props.sections
        local children = {}

        for index = 1, #sections do
            local section = sections[index]
            local open = opened(self.props.expanded, section.key)

            children[#children + 1] = Pressable {
                key = "header:" .. tostring(section.key),
                style = { direction = "row", align = "center", justify = "space-between",
                    height = HEADER, paddingHorizontal = "md", gap = "sm" },
                accessibilityLabel = section.title,
                onPress = function()
                    if self.props.onChange ~= nil then
                        self.props.onChange(self:toggled(section.key))
                    end
                end,
                Text { text = section.title, numberOfLines = 1, style = { grow = 1, fontWeight = "600" } },
                Text { text = open and "⌃" or "⌄", style = { color = "textMuted" } },
            }

            if open then
                children[#children + 1] = View {
                    key = "content:" .. tostring(section.key),
                    style = { paddingHorizontal = "md", paddingBottom = "md" },
                    contentOf(section.content),
                }
            end

            if index < #sections then
                children[#children + 1] = Divider { key = "rule:" .. tostring(section.key) }
            end
        end

        return View { style = self.props.style, table.unpack(children) }
    end,
}))

--- One choice out of several, each shown as a radio that reports itself when it is pressed.
---
--- The group draws the radios rather than taking them as children, since a group that only surrounded
--- them had nothing to bind its own change to: no platform reports a choice made inside a plain box.
M.RadioGroup = support.component("RadioGroup", {
    props = { "value", "options", "disabled", "orientation" },
    events = { "onChange" },
    defaults = { orientation = "vertical" },
    validate = function(spec)
        if type(spec.options) ~= "table" or #spec.options == 0 then
            return "options must be a list of { value, label } entries"
        end

        local choices = { "vertical", "horizontal" }
        if not support.oneOf(spec.orientation, choices) then
            return support.expected("orientation", spec.orientation, choices)
        end
    end,
}, component.define({
    name = "RadioGroup",

    render = function(self)
        local options = self.props.options
        local children = {}

        for index = 1, #options do
            local option = options[index]

            children[#children + 1] = input.Radio {
                key = tostring(option.value),
                value = option.value,
                label = option.label,
                selected = self.props.value == option.value,
                disabled = self.props.disabled,
                onSelect = function()
                    if self.props.onChange ~= nil then
                        self.props.onChange(option.value)
                    end
                end,
            }
        end

        local direction = "column"

        if self.props.orientation == "horizontal" then
            direction = "row"
        end

        return View { style = { { direction = direction, gap = "sm" }, self.props.style }, table.unpack(children) }
    end,
}))

--- Answers what a tab says is waiting behind it, which is nothing at all when nothing is.
local function waiting(counts, tab, index)
    local count = (counts or {})[tab.key] or (counts or {})[index]

    if count == nil or count == 0 then
        return false
    end

    return feedback.Badge {
        key = "badge",
        value = count,
        style = { position = "absolute", top = 6, left = "56%" },
    }
end

--- A row of destinations, one of which is chosen, sitting at the edge the platform puts one at.
M.TabBar = support.component("TabBar", {
    props = { "tabs", "selectedIndex", "position", "badgeCounts" },
    events = { "onChange" },
    defaults = { selectedIndex = 1, position = "bottom" },
    validate = function(spec)
        if type(spec.tabs) ~= "table" or #spec.tabs == 0 then
            return "needs a tabs list with at least one entry"
        end

        local choices = { "top", "bottom" }
        if not support.oneOf(spec.position, choices) then
            return support.expected("position", spec.position, choices)
        end
    end,
}, component.define({
    name = "TabBar",

    render = function(self)
        local tabs = self.props.tabs
        local children = {}

        for index = 1, #tabs do
            local tab = tabs[index]
            local chosen = index == self.props.selectedIndex
            local tint = "textMuted"

            if chosen then
                tint = "primary"
            end

            children[#children + 1] = Pressable {
                key = tostring(tab.key or index),
                style = { grow = 1, basis = 0, align = "center", justify = "center", gap = 2, height = TAB },
                accessibilityLabel = tab.label,
                onPress = function()
                    if self.props.onChange ~= nil then
                        self.props.onChange(index)
                    end
                end,
                Text {
                    text = tab.label,
                    numberOfLines = 1,
                    style = { fontSize = "caption", fontWeight = "600", color = tint, textAlign = "center" },
                },

                waiting(self.props.badgeCounts, tab, index),
            }
        end

        local edge = Divider {}
        local rows = { edge, View { style = { direction = "row", background = "background" },
            table.unpack(children) } }

        if self.props.position == "top" then
            rows = { rows[2], edge }
        end

        return View { style = self.props.style, table.unpack(rows) }
    end,
}))

--- The screen at the top of a stack, over a bar carrying its title and the way back to the one beneath.
M.NavigationStack = support.component("NavigationStack", {
    props = { "screens", "index", "title", "backTitle", "hidesBar", "barStyle" },
    events = { "onPop", "onIndexChange" },
    defaults = { index = 1, hidesBar = false },
    validate = function(spec)
        if type(spec.screens) ~= "table" or #spec.screens == 0 then
            return "needs a screens list with at least one entry"
        end
    end,
}, component.define({
    name = "NavigationStack",

    pop = function(self)
        local index = math.max(1, (self.props.index or 1) - 1)

        if self.props.onPop ~= nil then
            self.props.onPop()
        end

        if self.props.onIndexChange ~= nil then
            self.props.onIndexChange(index)
        end
    end,

    Bar = function(self, screen, index)
        local children = {
            View {
                key = "title",
                style = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
                    justify = "center", align = "center", paddingHorizontal = 64 },
                Text {
                    text = screen.title or self.props.title or "",
                    numberOfLines = 1,
                    style = { fontSize = "headline", fontWeight = "600", textAlign = "center" },
                },
            },
        }

        if index > 1 then
            children[#children + 1] = Pressable {
                key = "back",
                style = { position = "absolute", left = 0, top = 0, bottom = 0,
                    direction = "row", align = "center", paddingHorizontal = "sm", gap = 2 },
                accessibilityLabel = self.props.backTitle or "Back",
                onPress = function() self:pop() end,
                Text { text = "‹", style = { fontSize = "title", color = "primary" } },
                Text {
                    text = self.props.backTitle or self.props.screens[index - 1].title or "Back",
                    numberOfLines = 1,
                    style = { color = "primary" },
                },
            }
        end

        return View {
            key = "bar",
            style = { { height = BAR, background = "background" }, self.props.barStyle },
            table.unpack(children),
        }
    end,

    render = function(self)
        local screens = self.props.screens
        local index = math.max(1, math.min(#screens, self.props.index or 1))
        local screen = screens[index]

        local children = {}

        if not self.props.hidesBar then
            children[#children + 1] = self:Bar(screen, index)
            children[#children + 1] = Divider { key = "rule" }
        end

        children[#children + 1] = View {
            key = "screen:" .. tostring(screen.key or index),
            style = { grow = 1 },
            contentOf(screen.content),
        }

        return View { style = { { grow = 1 }, self.props.style }, table.unpack(children) }
    end,
}))

--- Rows under a header of columns, each cell either the field it names or whatever the column renders.
---
--- A table is a header row over a list, so it windows and reuses its rows the way any other list does
--- rather than being a second thing a renderer has to know how to build.
M.Table = support.component("Table", {
    props = { "columns", "rows", "sortBy", "sortOrder", "striped", "rowExtent" },
    events = { "onSort", "onSelect", "onRowPress" },
    defaults = { sortOrder = "ascending", striped = false, rowExtent = 44 },
    validate = function(spec)
        if type(spec.columns) ~= "table" then
            return "columns must be a list of { key, title, width, render } entries"
        end

        if type(spec.rows) ~= "table" then
            return "rows must be an array of entries"
        end

        local choices = { "ascending", "descending" }
        if not support.oneOf(spec.sortOrder, choices) then
            return support.expected("sortOrder", spec.sortOrder, choices)
        end
    end,
}, component.define({
    name = "Table",

    --- Answers the rows in the order the caller asked for, which is untouched unless a column was named.
    ordered = function(self)
        local rows = self.props.rows

        if self.props.sortBy == nil then
            return rows
        end

        local sorted = {}
        for index = 1, #rows do
            sorted[index] = rows[index]
        end

        local key = self.props.sortBy
        local ascending = self.props.sortOrder ~= "descending"

        table.sort(sorted, function(first, second)
            local before = tostring(first[key])
            local after = tostring(second[key])

            if ascending then
                return before < after
            end

            return after < before
        end)

        return sorted
    end,

    --- Answers the cell of one column, which is what the column renders or the field it names.
    Cell = function(self, column, row, index)
        local style = { grow = 1, basis = 0, justify = "center", paddingHorizontal = "sm" }

        if column.width ~= nil then
            style = { width = column.width, justify = "center", paddingHorizontal = "sm" }
        end

        if column.render ~= nil then
            return View { key = tostring(column.key), style = style, column.render(row, index) }
        end

        return View {
            key = tostring(column.key),
            style = style,
            Text { text = tostring(row[column.key] or ""), numberOfLines = 1 },
        }
    end,

    Header = function(self)
        local columns = self.props.columns
        local cells = {}

        for index = 1, #columns do
            local column = columns[index]
            local style = { grow = 1, basis = 0, justify = "center", paddingHorizontal = "sm" }

            if column.width ~= nil then
                style = { width = column.width, justify = "center", paddingHorizontal = "sm" }
            end

            local mark = ""
            if self.props.sortBy == column.key then
                mark = self.props.sortOrder == "descending" and " ⌄" or " ⌃"
            end

            cells[#cells + 1] = Pressable {
                key = tostring(column.key),
                style = style,
                accessibilityLabel = column.title,
                onPress = function()
                    if self.props.onSort ~= nil then
                        self.props.onSort(column.key)
                    end
                end,
                Text {
                    text = column.title .. mark,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", fontWeight = "600", color = "textMuted" },
                },
            }
        end

        return View {
            key = "header",
            style = { direction = "row", align = "center", height = self.props.rowExtent,
                background = "surface" },
            table.unpack(cells),
        }
    end,

    render = function(self)
        local rows = self:ordered()
        local columns = self.props.columns

        return View { style = { { grow = 1 }, self.props.style },
            self:Header(),
            Divider { key = "rule" },

            collections.List {
                key = "rows",
                style = { grow = 1 },
                data = rows,
                itemExtent = self.props.rowExtent,
                separator = Divider {},
                onSelect = self.props.onRowPress,

                renderItem = function(row, index)
                    local cells = {}

                    for position = 1, #columns do
                        cells[#cells + 1] = self:Cell(columns[position], row, index)
                    end

                    local ground = nil

                    if self.props.striped and index % 2 == 0 then
                        ground = "surface"
                    end

                    return View {
                        style = { grow = 1, direction = "row", align = "center", background = ground },
                        table.unpack(cells),
                    }
                end,
            },
        }
    end,
}))

--- A panel that slides in from an edge over the rest of the screen, with the screen dimmed behind it.
M.Drawer = support.component("Drawer", {
    props = { "open", "side", "width", "content" },
    events = { "onClose" },
    defaults = { open = false, side = "left", width = 280 },
    validate = function(spec)
        local choices = { "left", "right" }
        if not support.oneOf(spec.side, choices) then
            return support.expected("side", spec.side, choices)
        end
    end,
}, component.define({
    name = "Drawer",

    render = function(self)
        if not self.props.open then
            return View { style = self.props.style }
        end

        local panel = { position = "absolute", top = 0, bottom = 0, width = self.props.width,
            background = "background" }

        panel[self.props.side] = 0

        return View {
            style = { { position = "absolute", left = 0, right = 0, top = 0, bottom = 0 }, self.props.style },

            Pressable {
                key = "scrim",
                style = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, background = "overlay" },
                accessibilityLabel = "Close",
                onPress = function()
                    if self.props.onClose ~= nil then
                        self.props.onClose()
                    end
                end,
            },

            View { key = "panel", style = panel, contentOf(self.props.content) },
        }
    end,
}))

return M
