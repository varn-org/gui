local M = {}

local EDGES = { "top", "right", "bottom", "left" }

local function resolveLength(value, basis)
    if value == nil then
        return nil
    end

    if type(value) == "number" then
        return value
    end

    local percent = tostring(value):match("^(-?%d+%.?%d*)%%$")
    if percent ~= nil then
        if basis == nil then
            return nil
        end

        return basis * tonumber(percent) / 100
    end

    if value == "auto" then
        return nil
    end

    error("a length must be a number, a percentage or auto, got " .. tostring(value), 0)
end

--- The name each edge of each box property is written under, worked out once rather than per box.
---
--- Building these by concatenation is the hottest line in the engine: three properties by four edges is
--- twelve names built for every box on every pass, and a rotation lays the tree out on every frame.
local EDGE_NAMES = {}

for _, name in ipairs({ "margin", "padding", "border" }) do
    local named = { horizontal = name .. "Horizontal", vertical = name .. "Vertical" }

    for index = 1, 4 do
        local edge = EDGES[index]
        named[index] = name .. edge:sub(1, 1):upper() .. edge:sub(2)
    end

    EDGE_NAMES[name] = named
end

--- Reads a box property that may be given as one value, a pair, or a value per edge.
local function readEdges(style, name)
    local box = { top = 0, right = 0, bottom = 0, left = 0 }
    local whole = style[name]

    if type(whole) == "number" then
        for index = 1, 4 do
            box[EDGES[index]] = whole
        end
    elseif type(whole) == "table" then
        box.top = whole[1] or whole.vertical or 0
        box.right = whole[2] or whole.horizontal or box.top
        box.bottom = whole[3] or whole.vertical or box.top
        box.left = whole[4] or whole.horizontal or box.right
    end

    local named = EDGE_NAMES[name]

    for index = 1, 4 do
        local specific = style[named[index]]
        if specific ~= nil then
            box[EDGES[index]] = specific
        end
    end

    local horizontal = style[named.horizontal]
    if horizontal ~= nil then
        box.left = horizontal
        box.right = horizontal
    end

    local vertical = style[named.vertical]
    if vertical ~= nil then
        box.top = vertical
        box.bottom = vertical
    end

    return box
end

local function isRow(direction)
    return direction == "row" or direction == "row-reverse"
end

local function isReversed(direction)
    return direction == "row-reverse" or direction == "column-reverse"
end

local function clamp(value, minimum, maximum)
    if minimum ~= nil and value < minimum then
        value = minimum
    end

    if maximum ~= nil and value > maximum then
        value = maximum
    end

    return value
end

local Box = {}
Box.__index = Box

--- Answers how willing a box is to be squeezed, which a control with a size of its own is not.
---
--- A switch is the size the platform draws a switch at. Shrinking it to make room for a long label
--- would leave a control nobody can recognise or hit.
local function shrinkOf(node, style)
    if style.shrink ~= nil then
        return style.shrink
    end

    local natural = node.natural
    if natural ~= nil and (natural.width ~= nil or natural.height ~= nil) then
        return 0
    end

    return 1
end

local function readBox(node, parentWidth, parentHeight)
    local style = node.style or {}

    local box = setmetatable({
        node = node,
        pass = 0,
        style = style,
        direction = style.direction or "column",
        justify = style.justify or "start",
        align = style.align or "stretch",
        alignSelf = style.alignSelf,
        wrap = style.wrap == true,
        scrolls = node.scrolls,
        grow = style.grow or 0,
        shrink = shrinkOf(node, style),
        basis = style.basis,
        gap = style.gap or 0,
        position = style.position or "relative",
        margin = readEdges(style, "margin"),
        padding = readEdges(style, "padding"),
        border = readEdges(style, "border"),
        width = resolveLength(style.width, parentWidth),
        height = resolveLength(style.height, parentHeight),
        minWidth = resolveLength(style.minWidth, parentWidth),
        maxWidth = resolveLength(style.maxWidth, parentWidth),
        minHeight = resolveLength(style.minHeight, parentHeight),
        maxHeight = resolveLength(style.maxHeight, parentHeight),
        children = {},
    }, Box)

    -- What a type is never smaller than is a floor on the box, not on the text inside it. Applied to
    -- the text it is the padding over again, so a badge showing one digit came out half as wide again
    -- as the pill it is.
    local natural = node.natural

    if natural ~= nil then
        if natural.minWidth ~= nil then
            box.minWidth = math.max(box.minWidth or 0, natural.minWidth)
        end

        if natural.minHeight ~= nil then
            box.minHeight = math.max(box.minHeight or 0, natural.minHeight)
        end
    end

    box.rowGap = style.rowGap or box.gap
    box.columnGap = style.columnGap or box.gap
    box.row = isRow(box.direction)
    box.answers = { count = 0, at = 0 }
    box.declaredWidth = box.width
    box.declaredHeight = box.height
    return box
end

--- Answers the margin a box takes along the axis it is laid out on, which is space beside its size.
function Box:outerMain()
    if isRow(self.parentDirection) then
        return self.margin.left + self.margin.right
    end

    return self.margin.top + self.margin.bottom
end

local build

--- Answers the box a node is laid out as, keeping the one it already has when nothing about it changed.
---
--- A box carries what the last pass worked out, so a commit that touched one field of one screen relays
--- out that node and the boxes above it rather than every box there is. A rebuilt box also reports
--- itself upwards, since the boxes holding it can no longer stand on a size that is gone.
build = function(node, parentWidth, parentHeight, measure)
    local box = node.box
    local rebuilt = box == nil
        or box.revision ~= node.revision
        or box.parentWidth ~= parentWidth
        or box.parentHeight ~= parentHeight

    if rebuilt then
        box = readBox(node, parentWidth, parentHeight)
        box.revision = node.revision
        box.parentWidth = parentWidth
        box.parentHeight = parentHeight
        node.box = box
    else
        box.width = box.declaredWidth
        box.height = box.declaredHeight
    end

    box.measure = measure

    local children = node.children or {}
    for index = 1, #children do
        local child, childRebuilt = build(children[index], box.width, box.height, measure)
        box.children[index] = child
        rebuilt = rebuilt or childRebuilt
    end

    for index = #box.children, #children + 1, -1 do
        box.children[index] = nil
        rebuilt = true
    end

    -- What a box worked out is worth nothing once anything under it has changed, and that is both the
    -- last answer and every earlier one. A box is rebuilt afresh with none, so this is for the boxes
    -- above it, which keep theirs and would otherwise hand back a size taken before the change.
    if rebuilt then
        box.laid = false
        box.answers.count = 0
        box.answers.at = 0
    end

    return box, rebuilt
end

--- Answers the size a leaf wants when nothing else constrains it.
---
--- A leaf is worth what it measures, or what its type is naturally worth when it measures nothing. A
--- node with neither is zero, which is what a spacer is.
local function intrinsic(box, availableWidth)
    local node = box.node
    local natural = node.natural

    if node.measure ~= nil then
        local size = node.measure(box.width or availableWidth)
        return size.width, size.height
    end

    local width = natural ~= nil and natural.width or nil
    local height = natural ~= nil and natural.height or nil

    if box.measure ~= nil and node.text ~= nil then
        local padding = natural ~= nil and natural.padding or nil
        local horizontal = padding ~= nil and (padding.horizontal or 0) * 2 or 0
        local vertical = padding ~= nil and (padding.vertical or 0) * 2 or 0

        local bound = box.width or availableWidth
        local room = bound ~= nil and bound - horizontal or nil

        -- A node held to one line is measured as one, so it is trimmed rather than wrapped into a
        -- second line the frame was never given room for.
        if node.lines == 1 then
            room = nil
        end

        local size = box.measure(node.text, box.style, room)

        -- A bound of nothing is a box that has not been measured yet, not a box with no room in it.
        local limit = math.huge
        if bound ~= nil and bound > 0 then
            limit = bound
        end

        width = width or math.min(size.width + horizontal, limit)
        height = height or size.height + vertical
    end

    return width or 0, height or 0
end

local layout
local placeAbsolute

--- How many answers a box keeps.
---
--- Sharing out a row asks a child how large it is at each size it is considering, so one pass asks a
--- single box ten different questions and a screen holds several such rows. At eight the ring threw away
--- each answer before it was asked for again and every commit worked the whole subtree out afresh: a
--- scroll on a tablet with a screen open cost 21.7 ms. Measured against the gallery, it falls to 9.4 at
--- sixteen and 7.0 at thirty-two, and stops improving after that.
local ANSWERS = 32

--- Gives back the size a box was worked out to be for this question, whenever it was asked.
---
--- Only the size is restored. A container that hands one back still holds, below it, whatever some other
--- question left there, so an answer given here stands on its own only while nothing reads further down.
local function answered(box, availableWidth, availableHeight)
    local held = box.answers

    for index = 1, held.count do
        local answer = held[index]

        if answer.availableWidth == availableWidth
            and answer.availableHeight == availableHeight
            and answer.width == box.width
            and answer.height == box.height
            and answer.stretchWidth == box.stretchWidth
            and answer.stretchHeight == box.stretchHeight then
            box.measuredWidth = answer.measuredWidth
            box.measuredHeight = answer.measuredHeight
            box.contentWidth = answer.contentWidth
            box.contentHeight = answer.contentHeight
            return true
        end
    end

    return false
end

local function remember(box)
    local held = box.answers

    held.at = held.at % ANSWERS + 1

    if held.at > held.count then
        held.count = held.at
        held[held.at] = {}
    end

    local answer = held[held.at]

    answer.availableWidth = box.laidAvailableWidth
    answer.availableHeight = box.laidAvailableHeight
    answer.width = box.width
    answer.height = box.height
    answer.stretchWidth = box.stretchWidth
    answer.stretchHeight = box.stretchHeight
    answer.measuredWidth = box.measuredWidth
    answer.measuredHeight = box.measuredHeight
    answer.contentWidth = box.contentWidth
    answer.contentHeight = box.contentHeight
end

--- Answers whether a box was worked out for exactly this question the last time it was laid out.
---
--- Only the last one counts. Everything a box holds is worked out during its own layout, so answering
--- an older question hands back a size while the boxes below it still hold what some other question
--- produced — a stretched row whose text kept its natural width. `gui/tests/layout_test.lua` lays a
--- tree out at several sizes and compares it with one that has never been laid out at all.
local function settled(box, availableWidth, availableHeight)
    return box.laid
        and box.laidAvailableWidth == availableWidth
        and box.laidAvailableHeight == availableHeight
        and box.laidWidth == box.width
        and box.laidHeight == box.height
        and box.laidStretchWidth == box.stretchWidth
        and box.laidStretchHeight == box.stretchHeight
end

local pass = 0

--- Records what this box was just worked out to be, which is what a repeat of the question is answered from.
local function record(box, availableWidth, availableHeight)
    box.laid = true
    box.pass = pass
    box.laidAvailableWidth = availableWidth
    box.laidAvailableHeight = availableHeight
    box.laidWidth = box.width
    box.laidHeight = box.height
    box.laidStretchWidth = box.stretchWidth
    box.laidStretchHeight = box.stretchHeight
    box.laidMeasuredWidth = box.measuredWidth
    box.laidMeasuredHeight = box.measuredHeight
end

local function settle(box, availableWidth, availableHeight)
    record(box, availableWidth, availableHeight)
    remember(box)
end

--- Restores what a pass produced, since a caller is free to overwrite a size it was answered.
local function replay(box)
    box.measuredWidth = box.laidMeasuredWidth
    box.measuredHeight = box.laidMeasuredHeight
end

--- Splits the children into the ones that flow and the ones that are placed against an edge.
---
--- A stretch is something a parent hands down, and a box is laid out more than once while its own size
--- is still being worked out. Clearing it here means a pass never reads what an earlier one guessed.
local function flowChildren(box)
    local flow = {}
    local absolute = {}

    for index = 1, #box.children do
        local child = box.children[index]
        child.parentDirection = box.direction
        child.stretchWidth = nil
        child.stretchHeight = nil

        if child.position == "absolute" then
            absolute[#absolute + 1] = child
        else
            flow[#flow + 1] = child
        end
    end

    return flow, absolute
end

--- Answers how large a child is along the axis its container runs, as far as the child declares it.
local function declaredMain(box, child)
    if box.row then
        return child.width
    end

    return child.height
end

--- Works out how large a box is, which is the whole of what the pass that hands out shares reads of it.
---
--- Sizing a container asks every child how large it is, shares out what is left and lays each one out
--- for the share it was given, so asking is never what decides where anything below the child sits. An
--- answer the child has given before therefore stands here, and the layout that follows it is what puts
--- the boxes underneath in agreement with the size it was finally handed. Without this a subtree is
--- walked twice per level and a deep tree costs what it holds raised to its own depth.
local function measure(box, availableWidth, availableHeight)
    if #box.children > 0 and answered(box, availableWidth, availableHeight) then
        return
    end

    layout(box, availableWidth, availableHeight)
end

local function mainSizeOf(box, child, mainAvailable, crossAvailable)
    local row = box.row
    local declared = declaredMain(box, child)

    if child.basis ~= nil and child.basis ~= "auto" then
        return resolveLength(child.basis, mainAvailable) or declared or 0
    end

    if declared ~= nil then
        return declared
    end

    -- A child with no declared main size asks its content, which for a leaf is what it measures.
    if row then
        measure(child, mainAvailable, child.height or crossAvailable)
        return child.measuredWidth
    end

    measure(child, child.width or crossAvailable, mainAvailable)
    return child.measuredHeight
end

--- Answers whether the container decides this child's cross size rather than the child itself.
--- Answers whether the container decides this child's cross size rather than the child itself.
---
--- A control the platform gave a size to keeps it. A switch is fifty-one points across because that is
--- what a switch is, and one stretched down a tablet is a control drawn in the corner of a box the whole
--- width of the pane, with every point of it answering a finger. A platform that has no opinion about an
--- axis answers nothing for it, which is what a slider and a segmented control do, and those still fill
--- the room they are given.
local function stretches(box, child, row)
    local align = child.alignSelf or box.align
    if align ~= "stretch" then
        return false
    end

    local natural = child.node.natural

    if natural ~= nil then
        local given = row and natural.height or natural.width

        if given ~= nil and given > 0 then
            return false
        end
    end

    if row then
        return child.height == nil
    end

    return child.width == nil
end

--- Answers how large a child is across the axis its container runs along.
---
--- Written as one `and`/`or` this reads the width of a row's child whenever that child declares no
--- height, since the `and` yields nil and the `or` takes the other branch. A cell of a fixed width in a
--- row was then centred against its own width, which put every one of them above the row it belonged to.
local function crossSizeOf(box, child)
    if box.row then
        return child.height or child.measuredHeight
    end

    return child.width or child.measuredWidth
end

local function distribute(box, line, available)
    local used = 0
    for index = 1, #line do
        used = used + line[index].mainSize + line[index]:outerMain()
    end

    local gap = box.row and box.columnGap or box.rowGap
    used = used + gap * math.max(0, #line - 1)

    local free = available - used
    if free == 0 then
        return free
    end

    local totalGrow = 0
    local totalShrink = 0
    for index = 1, #line do
        totalGrow = totalGrow + line[index].grow
        totalShrink = totalShrink + line[index].shrink * line[index].mainSize
    end

    if free > 0 and totalGrow > 0 then
        for index = 1, #line do
            local child = line[index]
            child.mainSize = child.mainSize + free * (child.grow / totalGrow)
        end

        return 0
    end

    if free < 0 and totalShrink > 0 then
        for index = 1, #line do
            local child = line[index]
            local share = (child.shrink * child.mainSize) / totalShrink
            child.mainSize = math.max(0, child.mainSize + free * share)
        end

        return 0
    end

    return free
end

local function justifyOffsets(box, count, free)
    local justify = box.justify
    local leading = 0
    local between = 0

    if justify == "center" then
        leading = free / 2
    elseif justify == "end" then
        leading = free
    elseif justify == "space-between" then
        between = count > 1 and free / (count - 1) or 0
    elseif justify == "space-around" then
        between = count > 0 and free / count or 0
        leading = between / 2
    elseif justify == "space-evenly" then
        between = count > 0 and free / (count + 1) or 0
        leading = between
    end

    return leading, between
end

local function alignOffset(box, child, lineCross, childCross)
    local align = child.alignSelf or box.align
    if align == "center" then
        return (lineCross - childCross) / 2
    end

    if align == "end" then
        return lineCross - childCross
    end

    return 0
end

layout = function(box, availableWidth, availableHeight)
    if settled(box, availableWidth, availableHeight) then
        replay(box)
        return
    end

    -- A leaf holds nothing below it, so any answer it has given may be given again. Recording it leaves
    -- the box where a layout would have left it, this pass included, which is what says a frame has to
    -- be sent for it.
    if #box.children == 0 and answered(box, availableWidth, availableHeight) then
        record(box, availableWidth, availableHeight)
        return
    end

    local horizontalInsets = box.padding.left + box.padding.right + box.border.left + box.border.right
    local verticalInsets = box.padding.top + box.padding.bottom + box.border.top + box.border.bottom

    local contentWidth = box.width ~= nil and box.width - horizontalInsets or (availableWidth and availableWidth - horizontalInsets)
    local contentHeight = box.height ~= nil and box.height - verticalInsets or (availableHeight and availableHeight - verticalInsets)

    -- A percentage is measured against the box that holds it, which is known only once that box is, and
    -- it is worked out again on every pass. A pass that ran before this box had a size resolves it to
    -- zero, and zero is a size a box may have, so keeping the first answer keeps that one for good.
    for index = 1, #box.children do
        local child = box.children[index]

        if child.declaredWidth == nil and child.style.width ~= nil then
            child.width = resolveLength(child.style.width, contentWidth)
        end

        if child.declaredHeight == nil and child.style.height ~= nil then
            child.height = resolveLength(child.style.height, contentHeight)
        end
    end

    local flow, absolute = flowChildren(box)

    if #flow == 0 then
        local width, height = intrinsic(box, contentWidth)
        box.measuredWidth = clamp(box.width or box.stretchWidth or (width + horizontalInsets), box.minWidth, box.maxWidth)
        box.measuredHeight = clamp(box.height or box.stretchHeight or (height + verticalInsets), box.minHeight, box.maxHeight)
        box.contentWidth = box.measuredWidth - horizontalInsets
        box.contentHeight = box.measuredHeight - verticalInsets

        placeAbsolute(box, absolute)
        settle(box, availableWidth, availableHeight)
        return
    end

    local row = box.row
    local mainAvailable = row and contentWidth or contentHeight
    local crossAvailable = row and contentHeight or contentWidth

    -- Along the axis it scrolls, a view gives its children all the room they ask for.
    --
    -- Squeezing them to fit is the opposite of scrolling: a row of chips would be crushed narrow and
    -- its labels would wrap rather than run off the edge and wait to be scrolled to.
    local scrollsMain = box.scrolls ~= nil and (box.scrolls == "horizontal") == row

    if scrollsMain then
        mainAvailable = nil
    end

    for index = 1, #flow do
        local child = flow[index]
        child.mainSize = mainSizeOf(box, child, mainAvailable, crossAvailable)
    end

    local lines = {}
    if box.wrap and mainAvailable ~= nil then
        local current = {}
        local used = 0
        local gap = row and box.columnGap or box.rowGap

        for index = 1, #flow do
            local child = flow[index]
            local extent = child.mainSize + child:outerMain()
            local separator = #current > 0 and gap or 0

            if #current > 0 and used + separator + extent > mainAvailable then
                lines[#lines + 1] = current
                current = {}
                used = 0
                separator = 0
            end

            current[#current + 1] = child
            used = used + separator + extent
        end

        lines[#lines + 1] = current
    else
        lines[1] = flow
    end

    local mainGap = row and box.columnGap or box.rowGap
    local crossGap = row and box.rowGap or box.columnGap

    -- A stretched child fills the container's own cross size, which is not the same as the room it has.
    --
    -- A row with no height is as tall as its tallest child, so stretching to what is available would
    -- make it swallow the screen. Only a definite cross size, declared or handed down by the parent,
    -- decides a child's cross size before it is measured.
    local ownCross = nil
    local crossInsets = horizontalInsets

    if row then
        ownCross = box.height or box.stretchHeight
        crossInsets = verticalInsets
    else
        ownCross = box.width or box.stretchWidth
    end

    local definiteCross = nil
    if not box.wrap and ownCross ~= nil then
        definiteCross = ownCross - crossInsets
    end

    -- Growing and shrinking share out a definite size, so a box measured by its content shares nothing.
    --
    -- A container that grew its children and then measured itself from them would inflate to whatever
    -- room it was offered rather than to what it holds.
    local ownMain = nil
    local mainInsets = horizontalInsets

    if row then
        ownMain = box.width or box.stretchWidth
    else
        ownMain = box.height or box.stretchHeight
        mainInsets = verticalInsets
    end

    local definiteMain = nil
    if ownMain ~= nil and not scrollsMain then
        definiteMain = ownMain - mainInsets
    end

    local lineCrossSizes = {}
    local totalCross = 0

    for lineIndex = 1, #lines do
        local line = lines[lineIndex]
        local free = definiteMain ~= nil and distribute(box, line, definiteMain) or 0

        local lineCross = 0
        for index = 1, #line do
            local child = line[index]
            local childMain = child.mainSize
            local stretched = stretches(box, child, row) and definiteCross or nil

            -- A child given a share of a definite size has a definite size of its own to share on.
            if definiteMain ~= nil then
                if row then
                    child.stretchWidth = childMain + child.margin.left + child.margin.right
                else
                    child.stretchHeight = childMain + child.margin.top + child.margin.bottom
                end
            end
            if stretched ~= nil then
                if row then
                    child.stretchHeight = stretched - child.margin.top - child.margin.bottom
                else
                    child.stretchWidth = stretched - child.margin.left - child.margin.right
                end
            end

            if row then
                layout(child, childMain, stretched or crossAvailable)
                child.measuredWidth = clamp(childMain, child.minWidth, child.maxWidth)
                if stretched ~= nil then
                    child.measuredHeight = clamp(stretched - child.margin.top - child.margin.bottom, child.minHeight, child.maxHeight)
                end
            else
                layout(child, stretched or crossAvailable, childMain)
                child.measuredHeight = clamp(childMain, child.minHeight, child.maxHeight)
                if stretched ~= nil then
                    child.measuredWidth = clamp(stretched - child.margin.left - child.margin.right, child.minWidth, child.maxWidth)
                end
            end

            local cross = crossSizeOf(box, child)
            local outer = row and (cross + child.margin.top + child.margin.bottom)
                or (cross + child.margin.left + child.margin.right)
            lineCross = math.max(lineCross, outer)
        end

        lineCrossSizes[lineIndex] = lineCross
        totalCross = totalCross + lineCross
    end

    totalCross = totalCross + crossGap * math.max(0, #lines - 1)

    local measuredMain = 0
    for lineIndex = 1, #lines do
        local line = lines[lineIndex]
        local used = 0
        for index = 1, #line do
            used = used + line[index].mainSize + line[index]:outerMain()
        end

        used = used + mainGap * math.max(0, #line - 1)
        measuredMain = math.max(measuredMain, used)
    end

    local naturalWidth = row and measuredMain or totalCross
    local naturalHeight = row and totalCross or measuredMain

    -- Along the axis it scrolls, a viewport is what it was given rather than what it holds.
    if box.scrolls == "horizontal" then
        naturalWidth = 0
    elseif box.scrolls == "vertical" then
        naturalHeight = 0
    end

    box.measuredWidth = clamp(box.width or box.stretchWidth or (naturalWidth + horizontalInsets), box.minWidth, box.maxWidth)
    box.measuredHeight = clamp(box.height or box.stretchHeight or (naturalHeight + verticalInsets), box.minHeight, box.maxHeight)

    box.contentWidth = box.measuredWidth - horizontalInsets
    box.contentHeight = box.measuredHeight - verticalInsets

    local resolvedMain = row and box.contentWidth or box.contentHeight
    local crossCursor = 0

    for lineIndex = 1, #lines do
        local line = lines[lineIndex]
        local lineCross = #lines == 1 and (row and box.contentHeight or box.contentWidth) or lineCrossSizes[lineIndex]

        local used = 0
        for index = 1, #line do
            used = used + line[index].mainSize + line[index]:outerMain()
        end

        used = used + mainGap * math.max(0, #line - 1)

        local leading, between = justifyOffsets(box, #line, resolvedMain - used)
        local cursor = leading

        for index = 1, #line do
            local order = isReversed(box.direction) and (#line - index + 1) or index
            local child = line[order]

            local align = child.alignSelf or box.align
            local childCross = crossSizeOf(box, child)

            -- Whether a child is stretched is one question with one answer. Asked again here in its own
            -- words it answered differently, so a control the platform had sized was left alone while it
            -- was measured and stretched anyway when it was placed.
            if stretches(box, child, row) then
                childCross = lineCross - (row and (child.margin.top + child.margin.bottom) or (child.margin.left + child.margin.right))
                if row then
                    child.measuredHeight = childCross
                else
                    child.measuredWidth = childCross
                end

                layout(child, child.measuredWidth, child.measuredHeight)
                if row then
                    child.measuredHeight = childCross
                    child.measuredWidth = clamp(child.mainSize, child.minWidth, child.maxWidth)
                else
                    child.measuredWidth = childCross
                    child.measuredHeight = clamp(child.mainSize, child.minHeight, child.maxHeight)
                end
            end

            local crossOffset = alignOffset(box, child, lineCross, childCross)

            if row then
                child.x = cursor + child.margin.left
                child.y = crossCursor + crossOffset + child.margin.top
                cursor = cursor + child.mainSize + child.margin.left + child.margin.right + between + mainGap
            else
                child.x = crossCursor + crossOffset + child.margin.left
                child.y = cursor + child.margin.top
                cursor = cursor + child.mainSize + child.margin.top + child.margin.bottom + between + mainGap
            end
        end

        crossCursor = crossCursor + lineCross + crossGap
    end

    placeAbsolute(box, absolute)
    settle(box, availableWidth, availableHeight)
end

--- Places the children that left the flow, against the content box of the parent they are pinned to.
placeAbsolute = function(box, absolute)
    for index = 1, #absolute do
        local child = absolute[index]
        local style = child.style

        local left = resolveLength(style.left, box.contentWidth)
        local right = resolveLength(style.right, box.contentWidth)
        local top = resolveLength(style.top, box.contentHeight)
        local bottom = resolveLength(style.bottom, box.contentHeight)

        -- Both edges of an axis pin a size, and the subtree has to know it before it is laid out.
        if left ~= nil and right ~= nil then
            child.stretchWidth = box.contentWidth - left - right
        end

        if top ~= nil and bottom ~= nil then
            child.stretchHeight = box.contentHeight - top - bottom
        end

        layout(child, child.stretchWidth or box.contentWidth, child.stretchHeight or box.contentHeight)

        -- A margin moves a pinned box off the edge it is pinned to, which is how a box of a known size
        -- is centred on one: pinned at half the width and pulled back by half its own.
        if left ~= nil then
            child.x = left + child.margin.left
        elseif right ~= nil then
            child.x = box.contentWidth - right - child.measuredWidth - child.margin.right
        else
            child.x = child.margin.left
        end

        if top ~= nil then
            child.y = top + child.margin.top
        elseif bottom ~= nil then
            child.y = box.contentHeight - bottom - child.measuredHeight - child.margin.bottom
        else
            child.y = child.margin.top
        end
    end
end

--- Places a box and everything under it, each one relative to the node it sits inside.
---
--- A frame is relative rather than absolute because a renderer holds a tree of real views: a child is
--- added to its parent, so the parent's origin is already applied to it. Absolute frames would have to
--- be flattened into one layer, and then nothing could clip, scroll or move as a subtree.
---
--- A subtree that was not laid out again and sits where it sat is left alone, and only the frames that
--- moved are answered, so a screen sends the renderer what changed rather than everything it holds.
local function place(box, originX, originY, frames)
    local x = originX + (box.x or 0)
    local y = originY + (box.y or 0)

    if box.pass ~= pass and box.placedX == x and box.placedY == y then
        return frames
    end

    box.placedX = x
    box.placedY = y

    local frame = box.frame

    if frame == nil then
        box.frame = { x = x, y = y, width = box.measuredWidth, height = box.measuredHeight }
        frames[box.node] = box.frame
    elseif frame.x ~= x or frame.y ~= y
        or frame.width ~= box.measuredWidth or frame.height ~= box.measuredHeight then
        frame.x = x
        frame.y = y
        frame.width = box.measuredWidth
        frame.height = box.measuredHeight
        frames[box.node] = frame
    end

    local contentX = box.padding.left + box.border.left
    local contentY = box.padding.top + box.border.top

    for index = 1, #box.children do
        place(box.children[index], contentX, contentY, frames)
    end

    return frames
end

--- Answers where a node ended up, which a caller that needs a frame it was not told about reads.
function M.frameOf(node)
    local box = node.box
    return box ~= nil and box.frame or nil
end

--- Lays a tree out inside the given size, answering a frame per node that moved, relative to the node above it.
---
--- A node is `{ style, children, text, measure }`, and `measure` lets a caller answer for a leaf the
--- engine cannot size on its own, which is what text measurement on a platform is. A node that carries a
--- `revision` keeps its layout across calls and is worked out again only when that revision moves on.
function M.compute(root, options)
    options = options or {}
    pass = pass + 1

    local box = build(root, options.width, options.height, options.measureText)
    box.parentDirection = "column"

    -- A root fills the surface it was given, whatever its content would have measured.
    box.stretchWidth = options.width
    box.stretchHeight = options.height

    layout(box, options.width, options.height)

    box.x = 0
    box.y = 0
    return place(box, 0, 0, {})
end

return M
