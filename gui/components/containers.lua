local chrome = require("gui.style.chrome")
local collections = require("gui.components.collections")
local component = require("gui.component")
local content = require("gui.components.content")
local input = require("gui.components.input")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local drawn = require("gui.controls.drawn")
local parts = require("gui.controls.parts")

local M = {}


--- The containers are built from the declared components, so they carry the same look every screen does.
local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable

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

--- Answers whether one value sorts before another, comparing numbers as numbers.
---
--- Comparing everything as text puts ten before nine, which is a table that looks sorted and is not.
local function precedes(first, second)
    if type(first) == "number" and type(second) == "number" then
        return first < second
    end

    return tostring(first) < tostring(second)
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
        local theme = parts.themeOf(self)
        local children = {}

        for index = 1, #sections do
            local section = sections[index]
            local open = opened(self.props.expanded, section.key)

            local about = { on = open }

            children[#children + 1] = Pressable {
                key = "header:" .. tostring(section.key),
                style = {
                    direction = "row",
                    align = "center",
                    justify = "space-between",
                    height = theme:metric("accordion", "row"),
                    paddingHorizontal = theme:metric("accordion", "paddingHorizontal"),
                    gap = theme:metric("accordion", "gap"),
                    radius = theme:metric("accordion", "radius"),
                    background = parts.paint(theme, "accordion", "row", about),
                },
                accessibilityLabel = section.title,
                accessibilityRole = "button",
                accessibilityState = { expanded = open },
                focusable = true,
                transition = parts.motion(theme, "accordion"),
                onPress = function()
                    if self.props.onChange ~= nil then
                        self.props.onChange(self:toggled(section.key))
                    end
                end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) and self.props.onChange ~= nil then
                        self.props.onChange(self:toggled(section.key))
                    end
                end,
                Text {
                    text = section.title,
                    numberOfLines = 1,
                    style = {
                        grow = 1,
                        fontWeight = "600",
                        color = parts.paint(theme, "accordion", "label", about),
                    },
                },
                content.Icon {
                    key = "mark",
                    name = open and "chevron-up" or "chevron-down",
                    size = theme:metric("accordion", "chevron"),
                    color = parts.paint(theme, "accordion", "chevron", about),
                },
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
            if ascending then
                return precedes(first[key], second[key])
            end

            return precedes(second[key], first[key])
        end)

        return sorted
    end,

    --- Answers the box one column's cells are laid out in, which is the same for its heading and its data.
    ---
    --- A heading that sits somewhere its column's data does not is a table nobody can read down. The two
    --- were laid out by the same line meaning two different things: a heading is a row, so centring it
    --- centred the title across the column, and a cell is a column, so the same word centred it
    --- vertically and left the text against the leading edge.
    column = function(self, column)
        local box = { direction = "row", align = "center", justify = column.align or "start",
            paddingHorizontal = "sm" }

        if column.width ~= nil then
            box.width = column.width
            return box
        end

        box.grow = 1
        box.basis = 0
        return box
    end,

    --- Answers the cell of one column, which is what the column renders or the field it names.
    Cell = function(self, column, row, index)
        local style = self:column(column)

        if column.render ~= nil then
            return View { key = tostring(column.key), style = style, column.render(row, index) }
        end

        return View {
            key = tostring(column.key),
            style = style,
            Text { text = tostring(row[column.key] or ""), numberOfLines = 1, style = { shrink = 1 } },
        }
    end,

    Header = function(self)
        local columns = self.props.columns
        local cells = {}

        for index = 1, #columns do
            local column = columns[index]
            local sorted = self.props.sortBy == column.key

            cells[#cells + 1] = Pressable {
                key = tostring(column.key),
                style = { self:column(column), { minHeight = chrome.touch, gap = 2 } },
                accessibilityLabel = column.title,
                onPress = function()
                    if self.props.onSort ~= nil then
                        self.props.onSort(column.key)
                    end
                end,

                Text {
                    key = "title",
                    text = column.title,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", fontWeight = "600", color = "textMuted",
                        shrink = 1 },
                },

                sorted and content.Icon {
                    key = "order",
                    name = self.props.sortOrder == "descending" and "chevron-down" or "chevron-up",
                    size = 11,
                    color = "textMuted",
                } or nil,
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


--- A row of numbered pages with a way forward and back, which a table on a wide screen needs.
M.Pagination = support.component("Pagination", {
    props = { "page", "count", "shown" },
    events = { "onChange" },
    defaults = { page = 1, shown = 7 },
    validate = function(spec)
        if type(spec.count) ~= "number" or spec.count < 1 then
            return "count is how many pages there are, at least one"
        end
    end,
}, drawn.pagination)

--- The numbered steps that say how far through something a reader is.
M.ProgressSteps = support.component("ProgressSteps", {
    props = { "steps", "step", "direction" },
    events = { "onChange" },
    defaults = { step = 1, direction = "horizontal" },
    validate = function(spec)
        if type(spec.steps) ~= "table" or #spec.steps == 0 then
            return "needs a steps list with at least one entry"
        end

        if not support.oneOf(spec.direction, { "horizontal", "vertical" }) then
            return support.expected("direction", spec.direction, { "horizontal", "vertical" })
        end
    end,
}, drawn.steps)

--- A list of rows that hold rows, each opening and closing.
M.TreeView = support.component("TreeView", {
    props = { "nodes", "open", "selected" },
    events = { "onOpen", "onSelect" },
    validate = function(spec)
        if type(spec.nodes) ~= "table" then
            return "nodes is a list of entries, each with a key and a label"
        end
    end,
}, drawn.tree)

--- A row a finger drags sideways to reach what can be done to it.
M.SwipeActions = support.component("SwipeActions", {
    props = { "leading", "trailing" },
    events = { "onAction" },
    validate = function(spec)
        if spec.leading == nil and spec.trailing == nil then
            return "needs something on one side or the other"
        end
    end,
}, drawn.swipe)

return M
