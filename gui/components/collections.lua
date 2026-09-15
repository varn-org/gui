local support = require("gui.components.support")
local virtual = require("gui.collections.list")

local M = {}

--- Answers what is wrong with an extent a caller declared, or nothing when it is a length.
---
--- Nought is what makes a wrong extent dangerous rather than merely wrong: every entry shares it, so
--- the offset of the one under a finger is a division by nothing, and a list of a thousand rows is
--- either one row or a number no index can be made of.
local function wrongExtent(spec, name)
    local value = spec[name]

    if value == nil or type(value) == "function" then
        return nil
    end

    if type(value) ~= "number" then
        return name .. " is a length in points, or a function answering one per entry"
    end

    if value <= 0 then
        return name .. " is a length in points, greater than zero"
    end

    return nil
end

--- A list of any length, along either axis, whose cells the renderer may reuse per item type.
---
--- The data is a plain array. `renderItem` answers the subtree for one entry, which is an ordinary
--- element tree and may hold anything a component can build, including another list. `itemType`
--- names the kind of an entry, and the renderer keeps one reuse pool per name, so a cell built for a
--- header is never handed to a row. Reuse is opt-in, because a short list does not need a pool and a
--- cell holding its own state would lose it to one.
M.List = support.component("List", {
    props = {
        "data", "renderItem", "itemType", "keyExtractor",
        "horizontal", "recycle", "itemExtent", "estimatedItemExtent",
        "windowMargin", "initialCount", "endThreshold",
        "separator", "separatorExtent", "header", "headerExtent", "footer", "footerExtent", "empty",
        "showsIndicator", "scrollEnabled", "bounces", "paging", "refreshing", "keyboardDismissMode",
    },
    events = {
        "onScroll", "onScrollEnd", "onEndReached", "onItemAppear", "onItemDisappear",
        "onSelect", "onRefresh", "onLayout",
    },
    actions = { "scrollTo", "scrollToIndex", "indexAt", "contentExtent" },
    defaults = {
        horizontal = false,
        recycle = true,
        windowMargin = 2,
        showsIndicator = true,
        scrollEnabled = true,
        bounces = true,
    },
    validate = function(spec)
        if type(spec.data) ~= "table" then
            return "data must be an array of entries"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end

        if spec.itemType ~= nil and type(spec.itemType) ~= "function" then
            return "itemType must be a function answering the name of an entry's kind"
        end

        return wrongExtent(spec, "itemExtent")
    end,
}, virtual.List)

--- A list whose entries are grouped, with headers that may stick to the edge while their section scrolls.
M.SectionList = support.component("SectionList", {
    props = {
        "sections", "renderItem", "renderHeader", "renderFooter", "itemType", "keyExtractor",
        "stickyHeaders", "recycle", "itemExtent", "estimatedItemExtent", "windowMargin",
        "initialCount", "endThreshold", "headerExtent", "sectionFooterExtent",
        "separator", "separatorExtent", "header", "headerExtent", "footer", "footerExtent", "empty",
        "showsIndicator", "scrollEnabled", "bounces", "refreshing",
    },
    events = {
        "onScroll", "onScrollEnd", "onEndReached", "onItemAppear", "onItemDisappear",
        "onSelect", "onRefresh", "onLayout",
    },
    actions = { "scrollTo", "scrollToIndex", "indexAt", "contentExtent" },
    defaults = { stickyHeaders = true, recycle = true, windowMargin = 2, showsIndicator = true, scrollEnabled = true },
    validate = function(spec)
        if type(spec.sections) ~= "table" then
            return "sections must be an array of { key, data } groups"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end

        -- Every section carries a header, so a list without one to draw dies inside the window rather
        -- than here, on the first section it reaches.
        if type(spec.renderHeader) ~= "function" then
            return "renderHeader must be a function answering the subtree for a section's header"
        end

        for index = 1, #spec.sections do
            local section = spec.sections[index]

            if type(section) ~= "table" or type(section.data) ~= "table" then
                return "section " .. index .. " must be a table carrying its own data"
            end

            if section.footer ~= nil and type(spec.renderFooter) ~= "function" then
                return "section " .. index .. " carries a footer, which needs renderFooter to draw it"
            end
        end

        return wrongExtent(spec, "itemExtent")
    end,
}, virtual.SectionList)

M.Grid = support.component("Grid", {
    props = {
        "data", "renderItem", "itemType", "keyExtractor",
        "columns", "minColumnWidth", "spacing", "recycle", "rowExtent", "itemExtent",
        "windowMargin", "initialCount", "endThreshold",
        "header", "headerExtent", "footer", "footerExtent", "empty",
        "showsIndicator", "scrollEnabled", "bounces", "refreshing",
    },
    events = {
        "onScroll", "onScrollEnd", "onEndReached", "onItemAppear", "onItemDisappear",
        "onSelect", "onRefresh", "onLayout",
    },
    actions = { "scrollTo", "scrollToIndex", "indexAt", "contentExtent" },
    defaults = { spacing = 8, recycle = true, scrollEnabled = true },
    validate = function(spec)
        if type(spec.data) ~= "table" then
            return "data must be an array of entries"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end

        -- A default column count would be a caller writing one, so neither is filled in and a grid
        -- given no opinion at all falls back to two where the columns are counted.
        if spec.columns ~= nil and spec.minColumnWidth ~= nil then
            return "give either a fixed column count or a minimum column width, not both"
        end

        if spec.columns ~= nil and (type(spec.columns) ~= "number" or spec.columns < 1 or spec.columns % 1 ~= 0) then
            return "columns is a whole number of columns, at least one"
        end

        if spec.minColumnWidth ~= nil and (type(spec.minColumnWidth) ~= "number" or spec.minColumnWidth <= 0) then
            return "minColumnWidth is a width in points, greater than zero"
        end

        -- Every row of a grid is the same height, so an extent per entry is a question it cannot ask.
        local height = spec.rowExtent or spec.itemExtent

        if height ~= nil and type(height) ~= "number" then
            return "rowExtent is the height every row of a grid shares, which is a number"
        end

        return wrongExtent(spec, "rowExtent") or wrongExtent(spec, "itemExtent")
    end,
}, virtual.Grid)

--- A paged list, which is the same machinery as a list with one entry filling the viewport.
M.Carousel = support.component("Carousel", {
    props = {
        "data", "renderItem", "itemType", "keyExtractor",
        "horizontal", "index", "loop", "autoplay", "autoplayInterval",
        "peek", "spacing", "recycle", "indicator", "itemExtent", "windowMargin",
        "initialCount", "empty", "showsIndicator", "scrollEnabled", "bounces",
    },
    events = { "onIndexChange", "onScroll", "onScrollEnd", "onSelect", "onLayout" },
    actions = { "scrollTo", "scrollToIndex", "indexAt", "contentExtent" },
    defaults = {
        horizontal = true,
        index = 1,
        loop = false,
        autoplay = false,
        autoplayInterval = 4000,
        spacing = 0,
        recycle = true,
        indicator = true,
        showsIndicator = false,
    },
    validate = function(spec)
        if type(spec.data) ~= "table" then
            return "data must be an array of entries"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end

        if spec.autoplayInterval ~= nil and (type(spec.autoplayInterval) ~= "number" or spec.autoplayInterval <= 0) then
            return "autoplayInterval is a number of milliseconds, greater than zero"
        end

        return wrongExtent(spec, "itemExtent")
    end,
}, virtual.Carousel)

return M
