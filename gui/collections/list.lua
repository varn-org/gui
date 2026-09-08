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

--- How many dots a carousel draws at once, however many pages it holds.
local DOTS = 7

--- The props that reach the surface node, which are the ones a renderer acts on.
local CARRIED = {
    "style", "testID", "horizontal", "showsIndicator", "scrollEnabled", "bounces",
    "refreshing", "paging", "keyboardDismissMode",
    "accessibilityLabel", "onRefresh", "onScrollEnd",
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
    -- A list told what its entries measure places them at exactly that, and one that was not lets each
    -- cell be as large as what is in it and reports back what that turned out to be.
    local sized = spec.itemExtent ~= nil

    if spec.horizontal then
        if sized then
            return { position = "absolute", top = 0, bottom = 0, left = offset, width = extent }
        end

        return { position = "absolute", top = 0, bottom = 0, left = offset, minWidth = extent }
    end

    if sized then
        return { position = "absolute", left = 0, right = 0, top = offset, height = extent }
    end

    return { position = "absolute", left = 0, right = 0, top = offset, minHeight = extent }
end

--- Records what a cell turned out to measure, so the offsets below it stop being an estimate.
---
--- A list with no declared extent placed every entry at the estimate forever, so its offsets and the
--- extent it reported were both wrong and its scroll bar was sized against a number nobody checked.
function Virtual:measuredCell(spec, index, frame)
    if spec.itemExtent ~= nil then
        return
    end

    local extent = spec.horizontal and frame.width or frame.height

    if self.window:measure(index, extent) then
        self:setState({ measured = (self.state.measured or 0) + 1 })
    end
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

        local at = index
        local node = View {
            key = self:cellKey(spec, index, cell),
            style = self:cellStyle(spec, offset, self.window:extentAt(index)),
            onLayout = function(frame) self:measuredCell(spec, at, frame) end,
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

--- Answers whether an offset would put anything different on screen from the one in force.
---
--- The surface holds a pinned header against its own scrolling, so a list that pins one re-renders when
--- the header being pinned changes rather than for every pixel a finger moves.
function Virtual:realises(spec, offset)
    local viewport = self:viewport(spec)
    local was = self.window:visible(math.max(0, self.state.scroll - self.leading), viewport)
    local now = self.window:visible(math.max(0, offset - self.leading), viewport)

    if was.first ~= now.first or was.last ~= now.last then
        return true
    end

    return self:pinnedAt(spec, self.state.scroll) ~= self:pinnedAt(spec, offset)
end

--- Answers the entry pinned to the leading edge at an offset, which a list of rows never has.
function Virtual:pinnedAt(spec, offset)
    return nil
end

--- Records the scroll offset the renderer reported and says what reached the end.
---
--- A platform reports every pixel a finger moves, and a commit lays the whole tree out, so a list that
--- re-rendered for each of them would spend a frame's budget on a window that has not moved.
function Virtual:scrolled(spec, payload)
    local offset = spec.horizontal and (payload.x or 0) or (payload.y or 0)

    -- A paged surface says which page it is on, so it follows the page even when every page is already
    -- realised and the window it draws from has not moved. A carousel of a few pages is exactly that,
    -- and its dots, the index it reports and the page it plays to all read the offset kept here.
    local paged = spec.paging == true
        and self.window:indexAt(offset) ~= self.window:indexAt(self.state.scroll)

    if paged or self:realises(spec, offset) then
        self:setState({ scroll = offset })
    end

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

--- Calls an action on the surface node, answering whether there was a surface to call it on.
---
--- A caller holds a ref across time — a timer that scrolls to a row, a handler that runs once an answer
--- comes back — and by then the screen may have gone, which is life rather than a mistake.
function Virtual:reach(method, arguments)
    return self.surfaceRef:call(method, arguments)
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
    measuredCell = Virtual.measuredCell,
    realises = Virtual.realises,
    pinnedAt = Virtual.pinnedAt,
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

        self:after(self.props.autoplayInterval, function()
            self.turning = false

            if self.stopped or not self.props.autoplay then
                return
            end

            local spec = self.spec
            local landed = self.window:indexAt(self.state.scroll)
            local next = landed + 1

            -- Past the last entry it either starts over or it stops, which is what `loop` says.
            if next > #spec.data then
                if not self.props.loop then
                    return
                end

                next = 1
            end

            self:handle().scrollToIndex({ index = next, animated = true })
        end)
    end,

    --- The surface with the dots over it, which is what a carousel is.
    ---
    --- The dots are a sibling of the scrolling surface rather than one of its children, since anything
    --- inside it travels with the page it was added to and is only ever seen over that one.
    render = function(self, kind)
        local spec = self:describe()
        local surface = self:build(spec, kind, { index = self.props.index, style = { grow = 1 } })

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

        return View {
            style = self.props.style,
            surface,
            self.props.indicator ~= false and #spec.data > 1 and self:Dots(#spec.data) or nil,
        }
    end,

    --- The dots that say which page is showing, which no platform draws for a surface it is only scrolling.
    ---
    --- A carousel of many pages cannot draw one dot each and stay inside its own width, so the row is a
    --- window of at most seven that travels with the page being read.
    Dots = function(self, count)
        local landed = self.window:indexAt(self.state.scroll)
        local shown = math.min(count, DOTS)
        local first = math.max(1, math.min(landed - math.floor(shown / 2), count - shown + 1))
        local dots = {}

        for index = first, first + shown - 1 do
            dots[#dots + 1] = View {
                key = "dot:" .. index,
                style = {
                    width = 7,
                    height = 7,
                    radius = "pill",
                    background = index == landed and "primary" or "separator",
                },
            }
        end

        return View {
            key = "dots",
            style = {
                position = "absolute",
                left = 0,
                right = 0,
                bottom = 10,
                direction = "row",
                justify = "center",
                align = "center",
                gap = 6,
            },
            table.unpack(dots),
        }
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

    --- Answers where each row of the grid starts, kept while the data and the column count both hold.
    ---
    --- The window is rebuilt whenever it is handed data it has not seen, so a fresh list of rows on
    --- every render threw away every offset the grid had each time it scrolled by a pixel.
    rowsOf = function(self, data, columns)
        if self.rows ~= nil and self.rowsFor == data and self.rowsAcross == columns then
            return self.rows
        end

        local rows = {}

        for index = 1, #data, columns do
            rows[#rows + 1] = index
        end

        self.rows = rows
        self.rowsFor = data
        self.rowsAcross = columns
        return rows
    end,

    --- Answers the grid as a list of rows, so one window and one pool serve it like any other list.
    describe = function(self, columns)
        local props = self.props
        local spacing = props.spacing or 0
        local extent = props.rowExtent or props.itemExtent or 120
        local rows = self:rowsOf(props.data, columns)

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
                        -- A column takes its share of the width and holds what it shows away from its
                        -- neighbours, since a share worked out with the gaps taken off first is a length
                        -- and a percentage at once, which a style cannot say. Half a gap on each of two
                        -- adjacent cells is the whole of one between them, and the outer edges keep the
                        -- padding the grid itself was given.
                        cells[#cells + 1] = View {
                            key = "column:" .. column,
                            style = {
                                position = "absolute",
                                top = 0,
                                height = extent,
                                left = (100 / columns * (column - 1)) .. "%",
                                width = (100 / columns) .. "%",
                                paddingLeft = column > 1 and spacing / 2 or 0,
                                paddingRight = column < columns and spacing / 2 or 0,
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
    --- has gone under the edge. A cell is placed at the list's leading header plus its own offset, so
    --- the offset a header is compared against has that header taken back off it.
    pinnedAt = function(self, spec, offset)
        if self.props.stickyHeaders == false or #spec.data == 0 then
            return nil
        end

        local top = math.max(0, offset - self.leading)

        -- The search starts at the top of the viewport rather than at the top of the realised range,
        -- which begins a margin of cells earlier: from there it finds the header of the group before
        -- the one on screen.
        for index = self.window:indexAt(top), 1, -1 do
            if spec.data[index].header and self.window:offsetOf(index) < top then
                return index
            end
        end

        return nil
    end,

    --- Answers where the section a header belongs to ends, which is where the next one pushes it off.
    sectionEnd = function(self, entries, index)
        for at = index + 1, #entries do
            if entries[at].header then
                return self.window:offsetOf(at)
            end
        end

        return self.window:totalExtent()
    end,

    render = function(self, kind)
        local spec = self:describe()
        local node = self:build(spec, kind, { stickyHeaders = self.props.stickyHeaders ~= false })
        local index = self:pinnedAt(spec, self.state.scroll)

        if index == nil then
            return node
        end

        local entry = spec.data[index]
        local from = self.leading + self.window:offsetOf(index)

        -- The pinned header is the last child, so it draws over the rows sliding beneath it, and the
        -- surface holds it against its own scrolling: placed from here it would follow a finger a
        -- commit late, which is a header drifting over the rows it is meant to cover.
        node.children[#node.children + 1] = View {
            key = "pinned",
            pinned = { from = from, to = self.leading + self:sectionEnd(spec.data, index) },
            style = { position = "absolute", left = 0, right = 0, top = from,
                height = self.window:extentAt(index) },
            self.props.renderHeader(entry.section, entry.sectionIndex),
        }

        return node
    end,
})

return M
