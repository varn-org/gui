local animation = require("gui.style.animation")
local chrome = require("gui.style.chrome")
local icons = require("gui.style.icons")
local collections = require("gui.components.collections")
local feedback = require("gui.components.feedback")
local component = require("gui.component")
local visibility = require("gui.visibility")
local content = require("gui.components.content")
local input = require("gui.components.input")
local presentation = require("gui.components.presentation")
local environment = require("gui.environment")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

--- The containers are built from the declared components, so they carry the same look every screen does.
local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable

--- The proportions the containers are built from, which are the ones the platforms themselves use.
local TAB = 56
local HEADER = 48

--- Where a screen sits while it is going, which is over the one it is uncovering.
local COVERING = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0 }

--- Where a screen sits once another one has been pushed over it, which is exactly where it was.
---
--- It is held rather than shown. A screen is not required to be opaque, and one that is not lets what is
--- under it through: pushing a product over a grid drew the grid's own rows through the product's price.
--- Nothing below the top is drawn, so what shows is what the top screen draws and nothing else.
local COVERED = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0, opacity = 0 }

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
                content.Icon {
                    key = "mark",
                    name = open and "chevron-up" or "chevron-down",
                    size = 14,
                    color = "textMuted",
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

--- Answers what a tab says is waiting behind it, which is nothing at all when nothing is.
local function waiting(counts, tab, index)
    local count = (counts or {})[tab.key] or (counts or {})[index]

    if count == nil or count == 0 then
        return false
    end

    return feedback.Badge {
        key = "badge",
        value = count,
        -- A badge hangs off the corner of what it counts. Placed at a share of the tab's width it moved
        -- with the number of tabs and sat over the label it was meant to sit beside.
        style = { position = "absolute", top = -10, right = -18 },
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

        for index = 1, #spec.tabs do
            if spec.tabs[index].icon ~= nil and not icons.has(spec.tabs[index].icon) then
                return "the icon set does not know an icon called " .. tostring(spec.tabs[index].icon)
            end
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
                tab.icon ~= nil and content.Icon { key = "icon", name = tab.icon, size = 22, color = tint } or false,

                -- The label and what is waiting behind it are one box, so the badge hangs off the
                -- corner of the word rather than off a corner of the whole tab.
                View {
                    key = "label",
                    style = { align = "center", justify = "center" },

                    Text {
                        text = tab.label,
                        numberOfLines = 1,
                        style = { fontSize = "caption", fontWeight = "600", color = tint, textAlign = "center" },
                    },

                    waiting(self.props.badgeCounts, tab, index),
                },
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
    props = { "screens", "index", "title", "backTitle", "hidesBar", "barStyle", "actions" },
    events = { "onPop", "onIndexChange", "onBack" },
    defaults = { index = 1, hidesBar = false },
    validate = function(spec)
        if type(spec.screens) ~= "table" or #spec.screens == 0 then
            return "needs a screens list with at least one entry"
        end
    end,
}, component.define({
    name = "NavigationStack",
    state = { leaving = nil, going = false },

    --- Holds the screen that has just been left so it can be seen going, rather than cut.
    ---
    --- A caller derives its screens from what it is showing, so the one that was on top is gone from the
    --- list by the time the stack renders again and there is nothing left to draw leaving. The stack is
    --- the only thing that saw it, so it is the one that keeps it.
    onUpdate = function(self, before)
        -- It is put back where it was and told to go on the commit after, since a node born in the state
        -- it is leaving in has never been anywhere else and there is nothing to animate.
        if self.state.leaving ~= nil and not self.state.going then
            self:setState({ going = true })
            return
        end

        local depth = math.max(1, math.min(#self.props.screens, self.props.index or 1))
        local was = math.max(1, math.min(#before.screens, before.index or 1))

        if depth >= was then
            return
        end

        local timing = animation.transition({ duration = "fast", easing = "easeOut" })

        self:setState({ leaving = before.screens[was], going = false })
        self:after(timing.duration * 2, function() self:setState({ leaving = component.none }) end)
    end,

    pop = function(self)
        -- A stack at its first screen may still have somewhere to go: the detail column of a split view
        -- with no room for both is one, and so is any stack that is not the whole of the application.
        if (self.props.index or 1) <= 1 then
            if self.props.onBack == nil then
                return false
            end

            self.props.onBack()
            return true
        end

        local index = (self.props.index or 1) - 1

        if self.props.onPop ~= nil then
            self.props.onPop()
        end

        if self.props.onIndexChange ~= nil then
            self.props.onIndexChange(index)
        end

        return true
    end,

    --- The way back, which carries the previous screen's name on a platform that names it.
    Back = function(self, look, index)
        if index < 2 and self.props.onBack == nil then
            return false
        end

        local back = {
            content.Icon { key = "glyph", name = look.back.symbol, size = 20, color = "primary" },
        }

        if look.back.labelled then
            local behind = index > 1 and self.props.screens[index - 1].title or nil

            back[#back + 1] = Text {
                key = "label",
                text = self.props.backTitle or behind or "Back",
                numberOfLines = 1,
                style = { color = "primary", shrink = 1 },
            }
        end

        return Pressable {
            key = "back",
            -- The way back yields before the title does, since a long name behind is worth less than
            -- the name of the screen a reader is looking at.
            style = { minWidth = chrome.touch, shrink = 1, direction = "row", align = "center", gap = 2 },
            accessibilityLabel = self.props.backTitle or "Back",
            onPress = function() self:pop() end,
            table.unpack(back),
        }
    end,

    --- The bar the system this is running on draws, which is the one thing the chrome asks it.
    ---
    --- A centred title is centred on the bar, and that only holds when the two sides claim the same
    --- width — centring it in whatever they happen to leave over puts it wherever the way back is long.
    --- The trailing side is there with nothing in it for that reason. A title too long to fit between
    --- them shortens the way back first, since the name of the screen behind is worth less than the
    --- name of the one being read.
    Bar = function(self, screen, index)
        local surface = environment:read(self)
        local look = chrome.bar(surface.platform, surface.breakpoint)
        local centred = look.title.align == "center"
        local actions = screen.actions or self.props.actions

        local sides = centred and { grow = 1, basis = 0, shrink = 1 } or { shrink = 1 }
        local middle = centred and { shrink = 1 } or { grow = 1, shrink = 1 }

        return View {
            key = "bar",
            style = { { height = look.height, background = "background", direction = "row",
                align = "center", paddingHorizontal = "sm", gap = "sm" }, self.props.barStyle },

            View {
                key = "leading",
                style = { { direction = "row", align = "center" }, sides },
                self:Back(look, index),
            },

            Text {
                key = "title",
                text = screen.title or self.props.title or "",
                numberOfLines = 1,
                style = { { fontSize = look.title.size, fontWeight = look.title.weight,
                    textAlign = look.title.align }, middle },
            },

            View {
                key = "trailing",
                style = { { direction = "row", align = "center", justify = "end", gap = "sm" }, sides },
                actions,
            },
        }
    end,

    render = function(self)
        local screens = self.props.screens
        local index = math.max(1, math.min(#screens, self.props.index or 1))
        local screen = screens[index]
        local surface = environment:read(self)
        local look = chrome.bar(surface.platform, surface.breakpoint)

        local children = {}

        if not self.props.hidesBar then
            children[#children + 1] = self:Bar(screen, index)
            children[#children + 1] = Divider { key = "rule" }
        end

        -- Every screen in the stack stays where it is and the top one covers the rest.
        --
        -- Rendering only the top one unmounts everything under it, so a reader coming back arrives at a
        -- screen that has never been used: a list back at the top, a field emptied, a form forgetting
        -- what it was told. A platform keeps its whole stack alive and shows the top of it, and a screen
        -- that is still there is also what a push slides over.
        local stack = { key = "screens", style = { grow = 1 } }
        local moving = { duration = "fast", easing = "easeOut" }

        for at = 1, index do
            local top = at == index

            stack[#stack + 1] = View {
                key = "screen:" .. tostring(screens[at].key or at),
                style = top and { grow = 1 } or COVERED,
                pointerEvents = top and "auto" or "none",
                transition = top and moving or nil,
                enter = top and animation.states(look.push).enter or nil,
                visibility.Showing { value = top, contentOf(screens[at].content) },
            }
        end

        -- The screen that was left goes back the way it came, over the one it uncovers.
        if self.state.leaving ~= nil then
            stack[#stack + 1] = View {
                key = "leaving:" .. tostring(self.state.leaving.key or index),
                style = { COVERING, self.state.going and animation.states(look.push).exit or nil },
                transition = moving,
                pointerEvents = "none",
                contentOf(self.state.leaving.content),
            }
        end

        children[#children + 1] = View(stack)

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
        local panel = { position = "absolute", top = 0, bottom = 0, width = self.props.width,
            background = "elevated", shadow = "lg" }

        panel[self.props.side] = 0

        local travel = self.props.side == "right" and presentation.fromRight or presentation.fromLeft

        return presentation.over(self.props.open, function()
            if self.props.onClose ~= nil then
                self.props.onClose()
            end
        end, travel, panel, { contentOf(self.props.content) })
    end,
}))

return M
