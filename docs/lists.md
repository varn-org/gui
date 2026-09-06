# 📜 Lists

A list is one component along either axis, whose cells the renderer may reuse per item type, and whose cells may hold anything a component can build.

```lua
gui.List {
    data = rows,
    horizontal = false,
    recycle = true,

    itemType = function(item) return item.kind end,
    itemExtent = function(item) return item.kind == "feature" and 96 or 44 end,
    keyExtractor = function(item) return item.id end,

    renderItem = function(item, index)
        return gui.View { style = { padding = "sm" }, gui.Text { text = item.label } }
    end,

    onEndReached = function() loadMore() end,
}
```

## The axis

`horizontal` changes the axis a list flows along and the axis its reuse pools measure. Nothing else changes, so a carousel and a feed are the same component with one field different.

## Item types

`itemType` names the kind of an entry. The renderer keeps **one reuse pool per name**, so a cell built for a section header is never handed back for a row. Without the field every entry shares one type, which is right for a uniform list.

This is what makes a mixed list cheap. A feed of rows, headers and feature cards recycles three pools rather than rebuilding a cell whenever the kind changes.

## Cell content

`renderItem` answers an ordinary element tree. Anything a component can build goes inside one, including state, another list, or a form. The cell is a plain box the subtree mounts into, so nothing about it constrains what it holds.

## Reuse

`recycle` is on by default and turning it off is one field. Off, every entry keeps its own cell.

Turn it off when a cell holds state a pool would recycle away, or when the list is short enough that a pool costs more than it saves. Turn it on for anything long.

## Extent

A cell's size normally comes from the layout engine, which measures it. `itemExtent` skips that, as a number for a uniform list or a function for a mixed one, and it is what makes fifty thousand rows scroll: offsets are then arithmetic rather than measurement.

`estimatedItemExtent` stands in until an entry has been measured, so a list with no fixed extent still knows roughly how tall it is.

## Windowing

Only what can be seen, plus `windowMargin` entries either side, is realised. The margin is what keeps a fast scroll from showing an empty cell before the next one is ready.

The realised set stays bounded however long the data is. A list of fifty thousand rows holds the same number of cells as a list of fifty.

## Identity

`keyExtractor` gives an entry an identity that survives a data change, so a measurement taken for it is kept when the array around it is replaced.

## Events

`onScroll`, `onEndReached`, `onItemAppear`, `onItemDisappear`, `onSelect` and `onRefresh`. A ref reaches `scrollToIndex` and `scrollTo`.

## Sections, grids and carousels

`SectionList` groups entries under headers that may stick. `Grid` lays them in a fixed or adaptive column count. `Carousel` pages them. All three carry the same item type, reuse and extent fields, because they are the same machinery with a different arrangement.
