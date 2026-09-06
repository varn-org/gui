local component = require("gui.component")
local element = require("gui.element")
local pool = require("gui.collections.pool")
local ref = require("gui.ref")
local window = require("gui.collections.window")

local M = {}

local View = element.define("view")

local SURFACE = {
    list = element.define("list"),
    sectionlist = element.define("sectionlist"),
    grid = element.define("grid"),
    carousel = element.define("carousel"),
}

--- The props that reach the surface node, which are the ones a renderer acts on.
local CARRIED = {
    "style", "testID", "horizontal", "showsIndicator", "scrollEnabled", "bounces",
    "refreshing", "inverted", "paging", "contentInset", "keyboardDismissMode",
    "accessibilityLabel", "indicator", "onRefresh", "onScrollEnd",
}

local Virtual = {}

--- Answers whether the extent the entries are laid out by is a different one from the one in force.
---
--- An extent given as a function is written at the point of use and is a fresh closure on every render,
--- so it is the data it reads that says whether the offsets still hold. Taking a new closure for a new
--- rule would rebuild every offset in the list on every frame it scrolls.
local function extentChanged(before, after)
    if before == after then
        return false
    end

    return not (type(before) == "function" and type(after) == "function")
end

--- Answers the window and the pools this list scrolls through, rebuilding them when the data changes.
function Virtual:ensure(spec)
    if self.window == nil or self.recycle ~= (spec.recycle ~= false) then
        self.window = window.create(spec)
        self.pool = pool.create({ recycle = spec.recycle })
        self.recycle = spec.recycle ~= false
        self.data = spec.data
        return
    end

    local rebuild = extentChanged(self.window.itemExtent, spec.itemExtent)
    self.window.itemExtent = spec.itemExtent

    if rebuild then
        self.window:setData(spec.data)
        self.data = spec.data
    end

    self.window.itemType = spec.itemType
    self.window.keyExtractor = spec.keyExtractor

    if self.data ~= spec.data then
        self.window:setData(spec.data)
        self.data = spec.data
    end
end

--- Answers the extent of the viewport along the scrolling axis, which decides how much is realised.
function Virtual:viewport(spec)
    if self.state.viewport > 0 then
        return self.state.viewport
    end

    return (spec.initialCount or 10) * (spec.estimatedItemExtent or 44)
end

--- Answers the identity of a cell, which decides whether a scrolled cell is reused or rebuilt.
---
--- With reuse on, the identity belongs to the pooled cell, so the entry that takes it patches the
--- subtree already there. With reuse off, the identity belongs to the entry, so a cell that leaves
--- the window is destroyed and a returning one is built again.
function Virtual:cellKey(spec, index, cell)
    if spec.recycle == false then
        return "item:" .. tostring(self.window:keyOf(index))
    end

    return "cell:" .. tostring(cell.id)
end

--- Positions a cell in content coordinates, which the surface scrolls over.
function Virtual:cellStyle(spec, offset, extent)
    if spec.horizontal then
        return { position = "absolute", top = 0, bottom = 0, left = offset, width = extent }
    end

    return { position = "absolute", left = 0, right = 0, top = offset, height = extent }
end

--- Answers the rule drawn at the trailing edge of a cell, which separates one entry from the next.
function Virtual:separator(spec)
    local thickness = spec.separatorExtent or 1

    if spec.horizontal then
        return View {
            style = { position = "absolute", top = 0, bottom = 0, right = 0, width = thickness },
            spec.separator,
        }
    end

    return View {
        style = { position = "absolute", left = 0, right = 0, bottom = 0, height = thickness },
        spec.separator,
    }
end

--- Queues the entries that entered and left the window, which a handler is told about after the commit.
---
--- A report cannot run during render, since a handler is free to call setState and a commit may not
--- start inside a commit.
function Virtual:report(spec, arrived, left)
    if spec.onItemAppear == nil and spec.onItemDisappear == nil then
        return
    end

    local queued = self.reports

    for position = 1, #arrived do
        local index = arrived[position].index
        queued[#queued + 1] = { handler = spec.onItemAppear, item = spec.data[index], index = index }
    end

    for position = 1, #left do
        local index = left[position]
        queued[#queued + 1] = { handler = spec.onItemDisappear, item = spec.data[index], index = index }
    end
end

--- Tells every queued handler what appeared and disappeared, which runs once the commit is over.
function Virtual:flush()
    local queued = self.reports
    self.reports = {}

    for index = 1, #queued do
        local entry = queued[index]
        if entry.handler ~= nil then
            entry.handler({ item = entry.item, index = entry.index })
        end
    end
end

--- Builds the cells the window says exist, each holding whatever `renderItem` answered for its entry.
---
--- The cells are given in the order their pool slots were claimed rather than in the order they are
--- read. Every cell is placed by a frame of its own, so where it sits among its siblings is nothing a
--- reader can see, and handing them over in reading order would move every row on the screen each time
--- the window slides by one.
function Virtual:cells(spec)
    local count = #spec.data

    if count == 0 then
        return spec.empty ~= nil and { spec.empty } or {}
    end

    local leading = self.leading
    local range = self.window:visible(math.max(0, self.state.scroll - leading), self:viewport(spec))
    local arrived, left = self.pool:reconcile(range, function(index) return self.window:typeOf(index) end)

    self:report(spec, arrived, left)

    local cells = {}
    local slot = {}

    for index = range.first, range.last do
        local cell = self.pool:cellFor(index)
        local offset = leading + self.window:offsetOf(index)
        local content = spec.renderItem(spec.data[index], index)
        local select = nil

        if spec.onSelect ~= nil then
            select = function() spec.onSelect({ item = spec.data[index], index = index }) end
        end

        local node = View {
            key = self:cellKey(spec, index, cell),
            style = self:cellStyle(spec, offset, self.window:extentAt(index)),
            onPress = select,
            content,
            spec.separator ~= nil and index < count and self:separator(spec) or false,
        }

        slot[node] = cell.id or index
        cells[#cells + 1] = node
    end

    table.sort(cells, function(first, second) return slot[first] < slot[second] end)
    return cells
end

--- Answers the extent the surface scrolls over, which is every entry plus a header and a footer.
function Virtual:contentExtent()
    return self.leading + self.window:totalExtent() + self.trailing
end

--- Records the scroll offset the renderer reported and says what reached the end.
function Virtual:scrolled(spec, payload)
    local offset = spec.horizontal and (payload.x or 0) or (payload.y or 0)
    self:setState({ scroll = offset })

    if spec.onScroll ~= nil then
        spec.onScroll(payload)
    end

    if spec.onEndReached == nil then
        return
    end

    local viewport = self:viewport(spec)
    local remaining = self:contentExtent() - offset - viewport

    if remaining > (spec.endThreshold or viewport) then
        self.endReported = false
        return
    end

    if not self.endReported then
        self.endReported = true
        spec.onEndReached({ offset = offset })
    end
end

--- Records the size the layout engine gave the surface, which bounds the realised set.
function Virtual:measured(spec, frame)
    local extent = spec.horizontal and frame.width or frame.height

    if extent ~= self.state.viewport or frame.width ~= self.state.width then
        self:setState({ viewport = extent, width = frame.width, height = frame.height })
    end

    if spec.onLayout ~= nil then
        spec.onLayout(frame)
    end
end

--- Answers the handle a ref reaches this list through, which is what scrolls it to an index.
function Virtual:handle()
    local spec = self.spec

    return {
        scrollTo = function(arguments)
            return self:reach("scrollTo", arguments)
        end,

        scrollToIndex = function(arguments)
            local viewport = self:viewport(spec)
            local extent = self.window:extentAt(arguments.index)
            local offset = self.leading + self.window:offsetOf(arguments.index)

            if arguments.align == "end" then
                offset = offset - viewport + extent
            elseif arguments.align == "center" then
                offset = offset - (viewport - extent) / 2
            end

            offset = math.max(0, offset)

            local target = spec.horizontal and { x = offset, y = 0 } or { x = 0, y = offset }
            target.animated = arguments.animated

            return self:reach("scrollTo", target)
        end,

        indexAt = function(arguments)
            return self.window:indexAt(math.max(0, arguments.offset - self.leading))
        end,

        contentExtent = function()
            return self:contentExtent()
        end,
    }
end

--- Calls an action on the surface node, which is the one native view this component owns.
function Virtual:reach(method, arguments)
    if self.surfaceRef.current == nil then
        error("the list is not mounted, so " .. method .. " has nowhere to go", 0)
    end

    return self.surfaceRef.current.call(method, arguments)
end

--- Answers the props the surface node carries, which never include a function the wire cannot take.
function Virtual:surfaceProps(spec, extra)
    local props = {}

    for index = 1, #CARRIED do
        local name = CARRIED[index]
        if spec[name] ~= nil then
            props[name] = spec[name]
        end
    end

    props.key = "surface"
    props.ref = self.surfaceRef
    props.contentExtent = self:contentExtent()
    props.itemCount = #spec.data
    props.recycle = spec.recycle ~= false
    props.onScroll = function(payload) self:scrolled(spec, payload) end
    props.onLayout = function(frame) self:measured(spec, frame) end

    for name, value in pairs(extra or {}) do
        props[name] = value
    end

    return props
end

--- Builds the surface with its header, its cells and its footer, which is the whole of what a list is.
function Virtual:build(spec, kind, extra)
    self.spec = spec
    self.leading = spec.header ~= nil and (spec.headerExtent or 0) or 0
    self.trailing = spec.footer ~= nil and (spec.footerExtent or 0) or 0

    self:ensure(spec)

    local children = {}

    if spec.header ~= nil then
        children[#children + 1] = View {
            key = "header",
            style = self:cellStyle(spec, 0, self.leading),
            spec.header,
        }
    end

    local cells = self:cells(spec)
    for index = 1, #cells do
        children[#children + 1] = cells[index]
    end

    if spec.footer ~= nil then
        children[#children + 1] = View {
            key = "footer",
            style = self:cellStyle(spec, self.leading + self.window:totalExtent(), self.trailing),
            spec.footer,
        }
    end

    local surface = self:surfaceProps(spec, extra)
    for index = 1, #children do
        surface[index] = children[index]
    end

    return SURFACE[kind](surface)
end

local BASE = {
    ensure = Virtual.ensure,
    viewport = Virtual.viewport,
    cellKey = Virtual.cellKey,
    cellStyle = Virtual.cellStyle,
    separator = Virtual.separator,
    report = Virtual.report,
    flush = Virtual.flush,
    cells = Virtual.cells,
    contentExtent = Virtual.contentExtent,
    scrolled = Virtual.scrolled,
    measured = Virtual.measured,
    handle = Virtual.handle,
    reach = Virtual.reach,
    surfaceProps = Virtual.surfaceProps,
    build = Virtual.build,
}

--- Declares a collection sharing the whole of the virtual list, differing only in how it arranges cells.
local function define(name, kind, definition)
    local merged = {
        name = name,
        state = { scroll = 0, viewport = 0 },

        onMount = function(self)
            self:flush()
        end,

        onUpdate = function(self)
            self:flush()
        end,

        render = function(self)
            if self.surfaceRef == nil then
                self.surfaceRef = ref.create()
                self.reports = {}
                self.leading = 0
                self.trailing = 0
            end

            return definition.render(self, kind)
        end,
    }

    for key, value in pairs(BASE) do
        merged[key] = value
    end

    for key, value in pairs(definition) do
        if key ~= "render" then
            merged[key] = value
        end
    end

    return component.define(merged)
end

M.List = define("List", "list", {
    render = function(self, kind)
        return self:build(self.props, kind)
    end,
})

M.Carousel = define("Carousel", "carousel", {
    --- Answers the list description of a carousel, which is a list whose cells fill the viewport.
    describe = function(self)
        local props = self.props
        local horizontal = props.horizontal ~= false

        -- A page that leaves the edge of the next one showing is narrower than the viewport by that much.
        local extent = props.itemExtent or (self:viewport(props) - 2 * (props.peek or 0))

        return setmetatable({
            horizontal = horizontal,
            itemExtent = extent + (props.spacing or 0),
            estimatedItemExtent = extent,
            paging = true,
        }, { __index = props })
    end,

    onMount = function(self)
        self:flush()
        self:turn()
    end,

    onUpdate = function(self)
        self:flush()
        self:turn()
    end,

    onUnmount = function(self)
        self.stopped = true
    end,

    --- Turns to the next page on its own, which is what a carousel told to play does.
    turn = function(self)
        if not self.props.autoplay or self.turning or self.stopped then
            return
        end

        self.turning = true

        require("async").spawn(function()
            require("async").sleep(self.props.autoplayInterval):await()
            self.turning = false

            if self.stopped or not self.props.autoplay then
                return
            end

            local spec = self.spec
            local landed = self.window:indexAt(self.state.scroll)
            local next = landed + 1

            if next > #spec.data then
                next = 1
            end

            self:handle().scrollToIndex({ index = next, animated = true })
        end)
    end,

    render = function(self, kind)
        local spec = self:describe()
        local node = self:build(spec, kind, { index = self.props.index })

        if self.props.onIndexChange ~= nil then
            local landed = self.window:indexAt(self.state.scroll)
            if landed ~= self.reportedIndex then
                self.reportedIndex = landed
                self.reports[#self.reports + 1] = {
                    handler = function(payload) self.props.onIndexChange(payload.index) end,
                    index = landed,
                }
            end
        end

        return node
    end,
})

M.Grid = define("Grid", "grid", {
    --- Answers how many columns fit, which is either the declared count or as many as the width allows.
    columnCount = function(self)
        if self.props.minColumnWidth == nil then
            return self.props.columns or 2
        end

        local width = self.state.width or 0
        if width == 0 then
            return 1
        end

        return math.max(1, math.floor(width / self.props.minColumnWidth))
    end,

    --- Answers the grid as a list of rows, so one window and one pool serve it like any other list.
    describe = function(self, columns)
        local props = self.props
        local spacing = props.spacing or 0
        local extent = props.rowExtent or props.itemExtent or 120
        local rows = {}

        for index = 1, #props.data, columns do
            rows[#rows + 1] = index
        end

        return setmetatable({
            data = rows,
            horizontal = false,
            itemExtent = extent + spacing,
            keyExtractor = function(_, index) return index end,
            itemType = props.itemType ~= nil and function() return "row" end or nil,

            renderItem = function(first)
                local cells = {}

                for column = 1, columns do
                    local index = first + column - 1
                    local entry = props.data[index]

                    if entry ~= nil then
                        cells[#cells + 1] = View {
                            key = "column:" .. column,
                            style = {
                                position = "absolute",
                                top = 0,
                                height = extent,
                                left = (100 / columns * (column - 1)) .. "%",
                                width = (100 / columns) .. "%",
                            },
                            props.renderItem(entry, index),
                        }
                    end
                end

                return cells
            end,
        }, { __index = props })
    end,

    render = function(self, kind)
        local columns = self:columnCount()
        return self:build(self:describe(columns), kind, { columns = columns })
    end,
})

--- Flattens the sections into one array of entries, so one window serves headers and rows alike.
local function flatten(sections)
    local entries = {}

    for position = 1, #sections do
        local section = sections[position]

        entries[#entries + 1] = { header = true, section = section, sectionIndex = position }

        for index = 1, #(section.data or {}) do
            entries[#entries + 1] = {
                item = section.data[index],
                section = section,
                sectionIndex = position,
                itemIndex = index,
            }
        end

        if section.footer ~= nil then
            entries[#entries + 1] = { footer = true, section = section, sectionIndex = position }
        end
    end

    return entries
end

M.SectionList = define("SectionList", "sectionlist", {
    --- Answers the sections as one flat list, so headers, rows and footers share a window and a pool.
    describe = function(self)
        local props = self.props

        if self.sections ~= props.sections then
            self.sections = props.sections
            self.entries = flatten(props.sections)
        end

        local headerExtent = props.headerExtent or 32

        return setmetatable({
            data = self.entries,

            keyExtractor = function(entry)
                if entry.header then
                    return "header:" .. entry.sectionIndex
                end

                if entry.footer then
                    return "footer:" .. entry.sectionIndex
                end

                return "row:" .. entry.sectionIndex .. ":" .. entry.itemIndex
            end,

            itemType = function(entry)
                if entry.header then
                    return "header"
                end

                if entry.footer then
                    return "footer"
                end

                return props.itemType ~= nil and props.itemType(entry.item, entry.itemIndex) or "row"
            end,

            itemExtent = function(entry)
                if entry.header then
                    return headerExtent
                end

                if entry.footer then
                    return props.sectionFooterExtent or headerExtent
                end

                if type(props.itemExtent) == "function" then
                    return props.itemExtent(entry.item, entry.itemIndex)
                end

                return props.itemExtent or props.estimatedItemExtent or 44
            end,

            renderItem = function(entry)
                if entry.header then
                    return props.renderHeader(entry.section, entry.sectionIndex)
                end

                if entry.footer then
                    return props.renderFooter(entry.section, entry.sectionIndex)
                end

                return props.renderItem(entry.item, entry.itemIndex, entry.section)
            end,

            onSelect = props.onSelect ~= nil
                and function(payload) props.onSelect({ item = payload.item.item, index = payload.index }) end
                or nil,
        }, { __index = props })
    end,

    --- Answers the header that has scrolled past the leading edge, which is the one that stays pinned.
    ---
    --- A header still in its own place needs no copy of itself, so nothing is pinned until one of them
    --- has gone under the edge.
    pinnedIndex = function(self, entries, first)
        local found = nil

        for index = 1, first do
            if entries[index].header and self.window:offsetOf(index) < self.state.scroll then
                found = index
            end
        end

        return found
    end,

    render = function(self, kind)
        local spec = self:describe()
        local node = self:build(spec, kind, { stickyHeaders = self.props.stickyHeaders ~= false })

        if self.props.stickyHeaders == false or #spec.data == 0 then
            return node
        end

        -- The pinned header is the last one above the top of the viewport, which is not the top of the
        -- realised range: that starts a margin of cells earlier, so searching only that far leaves the
        -- header of the group before the one on screen pinned over it.
        local index = self:pinnedIndex(spec.data, self.window:indexAt(math.max(0, self.state.scroll)))

        if index ~= nil then
            local entry = spec.data[index]

            -- The pinned header is the last child, so it draws over the rows sliding beneath it.
            node.children[#node.children + 1] = View {
                key = "pinned",
                style = self:cellStyle(spec, self.state.scroll, self.props.headerExtent or 32),
                self.props.renderHeader(entry.section, entry.sectionIndex),
            }
        end

        return node
    end,
})

return M
