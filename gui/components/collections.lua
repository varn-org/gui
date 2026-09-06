local support = require("gui.components.support")
local virtual = require("gui.collections.list")

local M = {}

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
        "windowMargin", "initialCount", "endThreshold", "inverted", "contentInset",
        "separator", "separatorExtent", "header", "headerExtent", "footer", "footerExtent", "empty",
        "showsIndicator", "scrollEnabled", "bounces", "paging", "refreshing", "keyboardDismissMode",
    },
    events = {
        "onScroll", "onScrollEnd", "onEndReached", "onItemAppear", "onItemDisappear",
        "onSelect", "onRefresh", "onLayout",
    },
    defaults = {
        horizontal = false,
        recycle = true,
        windowMargin = 2,
        inverted = false,
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

        if spec.itemExtent ~= nil and type(spec.itemExtent) ~= "number" and type(spec.itemExtent) ~= "function" then
            return "itemExtent must be a number or a function answering one per entry"
        end
    end,
}, virtual.List)

--- A list whose entries are grouped, with headers that may stick to the edge while their section scrolls.
M.SectionList = support.component("SectionList", {
    props = {
        "sections", "renderItem", "renderHeader", "renderFooter", "itemType", "keyExtractor",
        "stickyHeaders", "recycle", "itemExtent", "estimatedItemExtent", "windowMargin",
        "initialCount", "endThreshold", "headerExtent", "sectionFooterExtent",
        "separator", "separatorExtent", "header", "footer", "empty",
        "showsIndicator", "scrollEnabled", "bounces", "refreshing",
    },
    events = {
        "onScroll", "onScrollEnd", "onEndReached", "onItemAppear", "onItemDisappear",
        "onSelect", "onRefresh", "onLayout",
    },
    defaults = { stickyHeaders = true, recycle = true, windowMargin = 2, showsIndicator = true, scrollEnabled = true },
    validate = function(spec)
        if type(spec.sections) ~= "table" then
            return "sections must be an array of { key, data } groups"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end
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
    defaults = { columns = 2, spacing = 8, recycle = true, scrollEnabled = true },
    validate = function(spec)
        if type(spec.data) ~= "table" then
            return "data must be an array of entries"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end

        if spec.columns ~= nil and spec.minColumnWidth ~= nil then
            return "give either a fixed column count or a minimum column width, not both"
        end
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
    defaults = {
        horizontal = true,
        index = 1,
        loop = false,
        autoplay = false,
        autoplayInterval = 4000,
        spacing = 0,
        recycle = true,
        indicator = true,
    },
    validate = function(spec)
        if type(spec.data) ~= "table" then
            return "data must be an array of entries"
        end

        if type(spec.renderItem) ~= "function" then
            return "renderItem must be a function answering the subtree for one entry"
        end
    end,
}, virtual.Carousel)

return M
