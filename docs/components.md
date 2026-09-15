# 🧩 Components

Every component here is a declaration: the props it accepts, the events it reports, and the values it starts with. A prop it does not declare is refused at the call, so a typo is an error where it was written rather than something three renderers quietly ignore.

The table below is generated from those declarations by `gui/tools/reference.lua`, which means a component cannot document a prop it does not accept, and cannot accept one it does not document.

A declaration is also a promise. `gui/tests/promises_test.lua` reads every prop, event and action listed here, searches the three renderers and the components for it by name, and fails when nothing reads it, so a prop that appears in this page is one something honours rather than one somebody meant to get to later.

## Reading the table

- **Component** is what a caller writes: `gui.Text { ... }`.
- **Node** is what crosses the bridge, which is what a renderer implements. `Lua` means the component builds itself out of the others, so it works everywhere with nothing added to a renderer.
- **Props** are the fields that describe it. Every component also takes `key`, `style`, `ref`, `testID`,
  and the `transition` and `enter` that say how it arrives and how a change to it is drawn, which are
  described in [animation.md](animation.md).
- **Events** are the handlers it reports through. A handler is a Lua function that never leaves this side.
- **Actions** are what a caller asks of it imperatively through a ref: `self:ref("sound"):call("seek", { seconds = 90 })`. An action is something a reader did once rather than something the tree describes, which is why seeking, scrolling and taking a photograph are actions and not props. Asking for one a node cannot do is refused by name on all three platforms, and asking through a ref whose node has gone answers `false` rather than raising.
- **Defaults** are the values it takes when a caller says nothing.

## Every component

### Structure

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Blur` | `blur` | `intensity`, `tint` | `onLayout` | — | `intensity = 0.85` |
| `Controls` | Lua | `value` | — | — | — |
| `Divider` | `divider` | `color`, `inset`, `orientation`, `thickness` | — | — | `orientation = horizontal`, `thickness = 1` |
| `Gradient` | `gradient` | `colors`, `direction`, `locations` | `onLayout`, `onPress` | — | `direction = down` |
| `KeyboardAvoiding` | `keyboardavoiding` | `behavior`, `offset` | — | — | `behavior = padding`, `offset = 0` |
| `Look` | Lua | `value` | — | — | — |
| `NineSlice` | `nineslice` | `disabled`, `hitSlop`, `slice`, `sliceScale`, `source`, `sources` | `onLayout`, `onLongPress`, `onPress`, `onPressIn`, `onPressOut` | — | `sliceScale = 1` |
| `Portal` | `layer` | — | `onLayout` | — | — |
| `SafeArea` | Lua | `barContent`, `barStyle`, `bars`, `edges` | — | — | `bars = { … }`, `edges = { … }` |
| `ScrollView` | `scroll` | `bounces`, `contentStyle`, `horizontal`, `keyboardDismissMode`, `paging`, `refreshing`, `scrollEnabled`, `showsIndicator` | `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd` | `scrollTo` | `bounces = true`, `horizontal = false`, `scrollEnabled = true`, `showsIndicator = true` |
| `Spacer` | `spacer` | `size` | — | — | — |
| `View` | `view` | `opacity`, `overflow`, `pointerEvents`, `transform` | `onDoublePress`, `onEnterView`, `onExitView`, `onHoverIn`, `onHoverOut`, `onLayout`, `onLongPress`, `onPress` | — | — |

### Content

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Audio` | `audio` | `loop`, `playing`, `rate`, `source`, `volume` | `onEnd`, `onError`, `onProgress`, `onReady` | `seek` | `loop = false`, `playing = false`, `rate = 1`, `volume = 1` |
| `Camera` | `camera` | `audio`, `facing`, `filter`, `torch`, `zoom` | `onCapture`, `onError`, `onReady`, `onRecord` | `capturePhoto`, `startRecording`, `stopRecording` | `audio = false`, `facing = back`, `torch = false`, `zoom = 1` |
| `Canvas` | `canvas` | `commands` | `onLayout` | — | — |
| `Icon` | Lua | `color`, `name`, `size` | — | — | `color = text`, `size = 24` |
| `Image` | `image` | `filter`, `placeholder`, `resizeMode`, `source`, `tint` | `onError`, `onLayout`, `onLoad` | — | `resizeMode = cover` |
| `Recorder` | `recorder` | `recording` | `onError`, `onFinish`, `onProgress`, `onReady` | — | `recording = false` |
| `RichText` | `richtext` | `numberOfLines`, `spans` | `onLayout` | — | — |
| `Text` | `text` | `numberOfLines`, `text` | `onHoverIn`, `onHoverOut`, `onLayout`, `onLongPress`, `onPress` | — | — |
| `Video` | `video` | `autoplay`, `controls`, `filter`, `loop`, `muted`, `poster`, `rate`, `resizeMode`, `source`, `volume` | `onEnd`, `onError`, `onProgress`, `onReady` | `pause`, `play`, `seek` | `autoplay = false`, `controls = true`, `loop = false`, `muted = false`, `resizeMode = contain` |
| `WebView` | `webview` | `html`, `javaScriptEnabled`, `scrollEnabled`, `url` | `onError`, `onLoad`, `onWillLoad` | — | `javaScriptEnabled = true`, `scrollEnabled = true` |

### Writing

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `RichEditor` | `richeditor` | `autoCapitalize`, `autoCorrect`, `autoFocus`, `editable`, `linkColor`, `maxLength`, `placeholder`, `placeholderColor`, `value` | `onBlur`, `onChange`, `onFocus`, `onSelectionChange` | `blur`, `clearLink`, `copy`, `cut`, `focus`, `paste`, `selectAll`, `setLink`, `toggleMark` | `autoCapitalize = sentences`, `autoCorrect = true`, `editable = true` |
| `RichToolbar` | Lua | `disabled`, `editor`, `marks`, `tools` | `onLink` | — | — |

### Input

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Button` | `button` or Lua | `disabled`, `size`, `title`, `variant` | `onHoverIn`, `onHoverOut`, `onLongPress`, `onPress` | — | `disabled = false`, `size = medium`, `variant = filled` |
| `Checkbox` | `checkbox` or Lua | `color`, `disabled`, `indeterminate`, `label`, `value` | `onChange` | — | `disabled = false`, `indeterminate = false`, `value = false` |
| `ColorPicker` | `colorpicker` or Lua | `disabled`, `value` | `onChange` | — | — |
| `DatePicker` | `datepicker` or Lua | `disabled`, `maximum`, `minimum`, `value` | `onChange` | — | — |
| `FilePicker` | `filepicker` | `accept`, `disabled`, `kind`, `maxBytes`, `multiple`, `title` | `onPick` | — | `kind = file`, `maxBytes = 8388608`, `multiple = false` |
| `FloatingActionButton` | Lua | `disabled`, `icon`, `label`, `size` | `onPress` | — | `disabled = false`, `size = medium` |
| `Picker` | `picker` or Lua | `disabled`, `options`, `placeholder`, `title`, `value` | `onChange` | — | — |
| `Pressable` | `pressable` | `autoFocus`, `disabled`, `focusable`, `hitSlop`, `panAxis` | `onBlur`, `onContextPress`, `onDoublePress`, `onFocus`, `onHoverIn`, `onHoverOut`, `onKeyDown`, `onKeyUp`, `onLongPress`, `onPanEnd`, `onPanMove`, `onPanStart`, `onPress`, `onPressIn`, `onPressOut`, `onSwipe` | `blur`, `focus` | `autoFocus = false`, `disabled = false`, `focusable = false` |
| `Radio` | `radio` or Lua | `color`, `disabled`, `label`, `selected`, `value` | `onSelect` | — | `disabled = false`, `selected = false` |
| `RangeSlider` | Lua | `disabled`, `maximum`, `minimum`, `range`, `step` | `onChange`, `onCommit` | — | `disabled = false`, `maximum = 1`, `minimum = 0` |
| `Rating` | `rating` or Lua | `color`, `count`, `size`, `value` | `onChange` | — | `count = 5`, `size = 24` |
| `SearchBar` | `searchbar` | `autoFocus`, `placeholder`, `value` | `onBlur`, `onChange`, `onFocus`, `onKeyDown`, `onKeyUp`, `onSelectionChange`, `onSubmit` | `blur`, `focus` | — |
| `SegmentedControl` | `segmented` or Lua | `disabled`, `segments`, `selectedIndex` | `onChange` | — | `disabled = false`, `selectedIndex = 1` |
| `Slider` | `slider` or Lua | `continuous`, `disabled`, `maximum`, `minimum`, `step`, `thumbColor`, `trackColor`, `value` | `onChange`, `onCommit` | — | `continuous = true`, `disabled = false`, `maximum = 1`, `minimum = 0` |
| `Stepper` | `stepper` or Lua | `disabled`, `maximum`, `minimum`, `step`, `value` | `onChange` | — | `disabled = false`, `step = 1` |
| `Switch` | `switch` or Lua | `disabled`, `offColor`, `onColor`, `thumbColor`, `value` | `onChange` | — | `disabled = false`, `value = false` |
| `TextArea` | `textarea` | `autoFocus`, `editable`, `grows`, `maxLength`, `placeholder`, `rows`, `value` | `onBlur`, `onChange`, `onFocus`, `onKeyDown`, `onKeyUp`, `onSelectionChange` | `blur`, `focus` | `editable = true`, `grows = false`, `rows = 3` |
| `TextField` | Lua | `autoCapitalize`, `autoCorrect`, `autoFocus`, `editable`, `grows`, `helper`, `invalid`, `keyboard`, `label`, `leading`, `maxLength`, `multiline`, `placeholder`, `returnKey`, `rows`, `searching`, `secure`, `trailing`, `value` | `onBlur`, `onChange`, `onFocus`, `onKeyDown`, `onKeyUp`, `onSelectionChange`, `onSubmit` | — | `editable = true`, `invalid = false`, `multiline = false`, `searching = false` |
| `TextInput` | `textinput` | `autoCapitalize`, `autoCorrect`, `autoFocus`, `editable`, `keyboard`, `maxLength`, `placeholder`, `placeholderColor`, `returnKey`, `secure`, `value` | `onBlur`, `onChange`, `onFocus`, `onKeyDown`, `onKeyUp`, `onSelectionChange`, `onSubmit` | `blur`, `focus` | `autoCapitalize = sentences`, `autoCorrect = true`, `editable = true`, `keyboard = default`, `returnKey = done`, `secure = false` |
| `TimePicker` | `timepicker` or Lua | `disabled`, `value` | `onChange` | — | — |

### Forms

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Field` | Lua | `hint`, `label`, `name`, `render`, `required`, `rules` | — | — | `required = false` |
| `Form` | Lua | `disabled`, `initialValues`, `rules`, `validateOn` | `onChange`, `onInvalid`, `onSubmit` | — | `disabled = false`, `validateOn = blur` |

### Place

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Location` | `location` | `accuracy`, `watch` | `onChange`, `onError` | — | `accuracy = fine`, `watch = false` |
| `Map` | `map` | `center`, `interactive`, `markers`, `zoom` | `onLayout`, `onMarkerPress`, `onPress`, `onRegionChange` | — | `interactive = true`, `zoom = 14` |

### Collections

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Carousel` | Lua | `autoplay`, `autoplayInterval`, `bounces`, `data`, `empty`, `horizontal`, `index`, `indicator`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `loop`, `peek`, `recycle`, `renderItem`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onIndexChange`, `onLayout`, `onScroll`, `onScrollEnd`, `onSelect` | `contentExtent`, `indexAt`, `scrollTo`, `scrollToIndex` | `autoplay = false`, `autoplayInterval = 4000`, `horizontal = true`, `index = 1`, `indicator = true`, `loop = false`, `recycle = true`, `showsIndicator = false`, `spacing = 0` |
| `Grid` | Lua | `bounces`, `columns`, `data`, `empty`, `endThreshold`, `footer`, `footerExtent`, `header`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `minColumnWidth`, `recycle`, `refreshing`, `renderItem`, `rowExtent`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `contentExtent`, `indexAt`, `scrollTo`, `scrollToIndex` | `recycle = true`, `scrollEnabled = true`, `spacing = 8` |
| `List` | Lua | `bounces`, `data`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `footerExtent`, `header`, `headerExtent`, `horizontal`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `keyboardDismissMode`, `paging`, `recycle`, `refreshing`, `renderItem`, `scrollEnabled`, `separator`, `separatorExtent`, `showsIndicator`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `contentExtent`, `indexAt`, `scrollTo`, `scrollToIndex` | `bounces = true`, `horizontal = false`, `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `windowMargin = 2` |
| `SectionList` | Lua | `bounces`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `footerExtent`, `header`, `headerExtent`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `recycle`, `refreshing`, `renderFooter`, `renderHeader`, `renderItem`, `scrollEnabled`, `sectionFooterExtent`, `sections`, `separator`, `separatorExtent`, `showsIndicator`, `stickyHeaders`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `contentExtent`, `indexAt`, `scrollTo`, `scrollToIndex` | `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `stickyHeaders = true`, `windowMargin = 2` |

### Containers

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Accordion` | Lua | `expanded`, `multiple`, `sections` | `onChange` | — | `multiple = false` |
| `Pagination` | Lua | `count`, `page`, `shown` | `onChange` | — | `page = 1`, `shown = 7` |
| `ProgressSteps` | Lua | `direction`, `step`, `steps` | `onChange` | — | `direction = horizontal`, `step = 1` |
| `RadioGroup` | Lua | `disabled`, `options`, `orientation`, `value` | `onChange` | — | `orientation = vertical` |
| `SwipeActions` | Lua | `leading`, `trailing` | `onAction` | — | — |
| `Table` | Lua | `columns`, `rowExtent`, `rows`, `sortBy`, `sortOrder`, `striped` | `onRowPress`, `onSelect`, `onSort` | — | `rowExtent = 44`, `sortOrder = ascending`, `striped = false` |
| `TreeView` | Lua | `nodes`, `open`, `selected` | `onOpen`, `onSelect` | — | — |

### Bars

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `AppBar` | Lua | `largeTitle`, `leading`, `rule`, `scrolled`, `subtitle`, `title`, `titleView`, `trailing`, `underStatusBar` | — | — | `largeTitle = false`, `rule = true`, `scrolled = 0`, `underStatusBar = true` |
| `NavigationRail` | Lua | `header`, `selectedIndex`, `tabs` | `onChange` | — | `selectedIndex = 1` |
| `Scaffold` | Lua | `bar`, `bottom`, `floating` | — | — | — |
| `TabBar` | Lua | `badgeCounts`, `position`, `selectedIndex`, `tabs` | `onChange` | — | `position = bottom`, `selectedIndex = 1` |

### Navigation

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Drawer` | Lua | `content`, `open`, `side`, `width` | `onClose`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `open = false`, `side = left`, `width = 280` |
| `NavigationStack` | Lua | `animatesFirstScreen`, `backTitle`, `barStyle`, `hidesBar`, `index`, `largeTitle`, `screens`, `scrolled`, `title`, `trailing`, `transition` | `onBack`, `onIndexChange`, `onPop` | — | `animatesFirstScreen = false`, `hidesBar = false`, `index = 1`, `largeTitle = false`, `scrolled = 0` |
| `Router` | Lua | `animatesFirstScreen`, `notFound`, `routes`, `transition` | `onChange` | — | `animatesFirstScreen = false` |

### Adapting

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `SplitView` | Lua | `collapseAt`, `content`, `showing`, `sidebar`, `sidebarWidth` | `onShowingChange` | — | `collapseAt = medium`, `sidebarWidth = 320` |

### Presence

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `Presence` | Lua | `delay`, `duration`, `easing`, `transition`, `visible` | `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `transition = fade`, `visible = false` |

### Presentation

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `ActionSheet` | Lua | `actions`, `cancelLabel`, `message`, `title`, `visible` | `onAction`, `onDismiss`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `cancelLabel = Cancel`, `visible = false` |
| `Alert` | Lua | `actions`, `message`, `title`, `visible` | `onAction`, `onDismiss`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `visible = false` |
| `Banner` | Lua | `actions`, `icon`, `message`, `tone`, `visible` | `onAction` | — | `tone = neutral`, `visible = true` |
| `Menu` | Lua | `items`, `visible` | `onDismiss`, `onHide`, `onSelect`, `onShow`, `onWillHide`, `onWillShow` | — | `visible = false` |
| `Modal` | Lua | `dismissible`, `transparent`, `visible` | `onDismiss`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `dismissible = true`, `transparent = false`, `visible = false` |
| `Popover` | Lua | `anchor`, `dismissLabel`, `visible` | `onDismiss` | — | `visible = false` |
| `Sheet` | Lua | `detents`, `dismissible`, `grabber`, `selectedDetent`, `visible` | `onDismiss`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `detents = { … }`, `dismissible = true`, `grabber = true`, `visible = false` |
| `Snackbar` | Lua | `actions`, `message`, `visible` | `onAction`, `onDismiss` | — | `visible = false` |
| `Toast` | Lua | `action`, `duration`, `message`, `position`, `visible` | `onAction`, `onDismiss`, `onHide`, `onShow`, `onWillHide`, `onWillShow` | — | `duration = 3000`, `position = bottom`, `visible = false` |

### Feedback

| Component | Node | Props | Events | Actions | Defaults |
|---|---|---|---|---|---|
| `ActivityIndicator` | `activity` or Lua | `animating`, `color`, `size` | — | — | `animating = true`, `size = medium` |
| `Avatar` | Lua | `badge`, `color`, `initials`, `shape`, `size`, `source`, `textColor` | — | — | `shape = circle`, `size = 40` |
| `Badge` | Lua | `color`, `dot`, `max`, `textColor`, `value` | — | — | `dot = false`, `max = 99` |
| `Card` | `card` or Lua | `elevation`, `outlined`, `padded` | `onPress` | — | `elevation = sm`, `outlined = false`, `padded = true` |
| `Chip` | Lua | `color`, `disabled`, `label`, `selected` | `onPress`, `onRemove` | — | `disabled = false`, `selected = false` |
| `ProgressBar` | `progress` or Lua | `color`, `indeterminate`, `thickness`, `trackColor`, `value` | — | — | `indeterminate = false`, `thickness = 4` |
| `ProgressCircle` | Lua | `color`, `indeterminate`, `thickness`, `trackColor`, `value` | — | — | `indeterminate = false`, `thickness = 4` |
| `Skeleton` | Lua | `lines`, `shape` | — | — | `lines = 1`, `shape = rect` |
| `Tooltip` | `tooltip` or Lua | `text`, `visible` | — | — | — |

## What is not in the table

`style` is documented in [styling.md](styling.md), the layout fields in [layout.md](layout.md), and the fields shared by every collection in [lists.md](lists.md).

Three components take a value that is itself a tree rather than a plain value: `List.renderItem`, `SectionList.renderHeader` and `Grid.renderItem`. Those are functions that answer an element, which is why a cell may hold anything a component can build.

## Examples

Every component appears in the sample application, under `sample/demos/`. Its first screen is an index of what there is to see, grouped by the kind of thing it is — inputs, content, drawing, maps and location, lists, layout, feedback, presentation, tabs, animation and whole applications — and each entry opens a demo of its own. Run it with `python3 run.py sample` and open it in whichever host you have to hand. `gui/tests/sample_test.lua` renders every demo and fails naming the one that broke, and refuses a component that appears in none of them.

```lua
local gui = require("gui")

local Counter = gui.component({
    name = "Counter",
    state = { count = 0 },

    render = function(self)
        return gui.View {
            style = { direction = "row", align = "center", gap = "sm", padding = "md" },
            gui.Text { text = "Pressed " .. self.state.count .. " times", style = { color = "text" } },
            gui.Button {
                title = "Press",
                onPress = function() self:setState({ count = self.state.count + 1 }) end,
            },
        }
    end,
})
```

## Gestures

A press, a hold and a swipe are three different things, and a box answers whichever the finger actually made. A finger that travels past what its platform allows a tap is a swipe, not a press, so scrolling past a row does not open it.

```lua
gui.Pressable {
    onPress = function() self:open(item) end,
    onLongPress = function() self:choose(item) end,
    onSwipe = function(swipe)
        if swipe.direction == "left" then
            self:archive(item)
        end
    end,

    row,
}
```

`onSwipe` carries the direction the finger went — `left`, `right`, `up` or `down`. `onPressIn` and `onPressOut` report the two edges of a press, for anything that has to look pressed while a finger is down.

## An interface that changes shape

`SplitView` shows a list beside what it opens where there is room for both, and one at a time where there is not. It reads the room it has rather than the device it is on, so a tablet, a phone held sideways, a window sharing a screen and a folding phone that has just been opened are all one thing.

Both panes stay mounted whichever there is room for. That is what makes a turn of the phone keep everything a reader had put into the screen: rendering one tree with room for both and another with room for one crosses between two trees, and everything under either is built again.

```lua
gui.SplitView {
    sidebarWidth = 340,
    showing = self.state.open ~= nil,
    sidebar = <the list>,
    content = <what it opened>,
}
```

With no room for both, what was opened covers the list. The detail column is then a screen a reader has to be able to leave, so the stack inside it takes `onBack`: a stack at its first screen may still have somewhere to go, and the platform's own back gesture reaches it through the same call.

## Tabs

A `TabBar` takes a list of tabs, the index of the one that is chosen, and reports the one that was pressed. Each tab may carry an icon from the engine's own set and a count of what is waiting behind it.

```lua
gui.TabBar {
    tabs = {
        { key = "home", label = "Home", icon = "home" },
        { key = "saved", label = "Saved", icon = "heart" },
    },
    selectedIndex = self.state.tab,
    badgeCounts = { saved = 3 },
    onChange = function(index) self:setState({ tab = index }) end,
}
```

What a tab shows is the caller's. Rendering every screen and showing the chosen one is what keeps each of them holding what it was left with, the same way a navigation stack does.

The gallery carries four shapes of it under **Tabs**: the standard bar, a floating pill over the screen, a bar built around a round picture the reader chooses, and tabs over pages that can be swiped as well as pressed. Every one of them is built from the ordinary pieces, which is what makes a fifth shape somebody else needs possible.

## A badge is as wide as what it says

A `Badge` sizes itself to the number it carries rather than to the box it is in, which it does by aligning itself to the start of that box. A column that aligns its children to the end therefore leaves the badge where it is, so a badge that belongs at the end of one says so:

```lua
gui.Badge { value = waiting, style = { alignSelf = "end" } }
```

## A chip that can be taken away

A `Chip` is a label in a pill: one of a set that can be chosen, and, when it is given somewhere to report it, one somebody is building that can be taken back out.

```lua
gui.Chip {
    label = flavour,
    onRemove = function() self:setState({ kept = without(self.state.kept, flavour) }) end,
}
```

The mark that removes it is drawn from the engine's own icon set, so it is the same shape everywhere, and what a finger has to land on is a full target even though the mark is small. A chip nobody chose carries an edge as well as its fill, so it reads as a chip on a screen standing on the surface it is filled with rather than as a label lying loose in a row.

## An address names a screen

`Router` turns an address into the screen that answers it, and a link arriving from outside lands on that screen with what was already open underneath it.

```lua
gui.Router {
    routes = {
        { path = "/", title = "Catalogue", render = function() return Catalogue {} end },
        {
            path = "/items/:id",
            title = function(where) return where.params.id end,
            render = function(where) return Item { id = where.params.id } end,
        },
    },
    notFound = function(where) return gui.Text { text = "Nothing answers " .. where.path } end,
}
```

A route is drawn by a function taking `where`, which carries `address`, `path`, `params`, `query`, `scheme` and `host`. A path segment written `:name` becomes a parameter. A `title` is a string or a function of `where`.

Any screen under it reaches the router without being handed anything:

```lua
local route = gui.navigation:read(self)

gui.Text { text = "This screen is at " .. route.path }
gui.Button { title = "Open", onPress = function() route.go("/items/kettle") end }
gui.Button { title = "Back", onPress = function() route.back() end }
```

`go` opens an address on top of what is there, `replace` swaps what is on top for it, and `back` answers whether there was anywhere to go. A screen reads the address **it was opened at** rather than the one the router is on now, so a screen the reader has left — and a stack holds one for as long as its exit takes — still draws its own parameters rather than the ones it is leaving for.

A deep link, an app link and a plain path all arrive as an address, so `varn://items/3`, `https://varn.dev/items/3` and `/items/3` land on the same screen. A host that has somewhere to show one keeps it in step, which is what a browser's own history is.

## A stack keeps its screens

`NavigationStack` renders every screen up to `index` and the top one covers the rest, which is what the platforms do. A screen pushed over is still there: its state, the row a list was scrolled to and what was half typed into a field are all where the reader left them, and coming back is the screen they left rather than a new one.

A covered screen takes no touches and is not laid out into the flow — it stays exactly where it was, under the one over it. That is also what a push has to slide over.

```lua
gui.NavigationStack {
    index = self.state.depth,
    onIndexChange = function(index) self:setState({ depth = index }) end,
    screens = {
        { key = "index", title = "Library", content = self:Index() },
        { key = "album", title = "Album", content = self:Album() },
    },
}
```

The caller owns the index, so the way back reports where it goes rather than moving on its own, and the same press is what the platform's own back gesture reaches through `gui.back`.

## A camera, and what it captures

`Camera` draws what the camera sees for as long as it is on screen, and lets the device go when it leaves. The permission each platform requires is asked for the first time one is mounted, and a reader who refuses is reported through `onError` rather than left looking at a black box.

```lua
gui.Camera {
    ref = self:ref("camera"),
    facing = self.state.facing,
    zoom = self.state.zoom,
    torch = self.state.torch,
    audio = true,
    filter = gui.filter.looks.noir,
    style = { height = 260, radius = "md" },
    onReady = function(ready) end,
    onError = function(problem) end,
    onCapture = function(photo) self:setState({ taken = photo.path }) end,
    onRecord = function(clip) self:setState({ clip = clip.path }) end,
}
```

What it captures is asked for through a ref and reported rather than answered, since a photograph is taken over several frames on all three:

```lua
self:ref("camera"):call("capturePhoto")
self:ref("camera"):call("startRecording")
self:ref("camera"):call("stopRecording")
```

`onCapture` carries `{ path, width, height }` and `onRecord` carries `{ path, duration }`, each a file the tree can hand straight to `gui.Image` or `gui.Video`. A camera draws and takes pictures, and the microphone is a permission of its own on every platform, so one that will record sound as well says `audio` — and it is the only kind a reader is asked about the microphone for.

A look is drawn over the preview and written into a photograph, so what a reader sees before they capture is the picture they get. A film is recorded as the camera sees it, since every platform writes frames straight from the hardware.

`Recorder` is the microphone on its own, which is what a voice note is:

```lua
gui.Recorder {
    recording = self.state.recording,
    onReady = function() self:setState({ said = "Recording" }) end,
    onFinish = function(clip) self:setState({ clip = clip.path }) end,
}
```

It is told whether it should be running rather than asked to start, and stopping it is what produces the file. Being told to record and recording are two moments: the microphone has to be asked for, and a reader may be looking at a permission sheet in between, so a screen that says "Recording" on the press says it before anything is being recorded. `onReady` is the moment it is.

An application carrying either has to declare it the way its platform requires: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` and, for keeping what was captured, `NSPhotoLibraryAddUsageDescription` on iOS, and `CAMERA` and `RECORD_AUDIO` in the Android manifest. iOS does not refuse an undeclared one, it ends the process: a keep that asks the photo library without the sentence saying why takes the application down rather than being turned away. Android also asks a reader through the activity rather than through a view, so a host wires `onPermission` once — the same one a map already needs — and every permission a tree asks for goes through it.

## The bars the system draws

A phone draws a status bar across the top and a home indicator or a navigation bar across the bottom. `SafeArea` says three things about them, and they are three things rather than one.

```lua
gui.SafeArea {
    edges = { "top", "bottom" },
    bars = { "status" },
    barContent = "light",
    barStyle = { background = "primary" },
    style = { grow = 1 },
}
```

`edges` is which of them the tree keeps clear of. `bars` is which of them the reader still sees, and naming fewer hides the rest — a game takes the whole glass with `bars = {}`. `barContent` is whether the marks in them are light or dark, and saying nothing is right for almost every screen, since each platform already draws them from the appearance. `barStyle` fills the strips behind them so a bar of the application's own can run all the way up.

Hiding one gives its room back, so the insets the tree is avoiding change with it and a screen stays correct across the change without doing anything.

What each platform can actually do differs, and a screen that must know asks `renderer:can("systemBars")` first. iOS takes the status bar away outright. It will not take the home indicator away at all — what it does is let the line fade while nothing is touched and bring it back at a touch, which is as far as the platform goes. Android hides either, and leaves the reader's own swipe to bring one back, since taking that away is how an application traps somebody inside itself. A browser has neither bar and full screen instead, which a reader must grant and which a browser only grants inside a gesture, so the page asks the next time a finger lands and leaves it as soon as a screen asks for the bars back.

## Being seen, and the application coming and going

A component is told nine things about its screen — it is about to mount, it mounted, it is about to appear, it appeared, it updated, it is about to disappear, it disappeared, it is about to unmount, it unmounted — and two about the application it is in.

```lua
gui.component({
    name = "Draft",
    onPause = function(self, state)
        if state == "background" then
            self:save()
        end
    end,
    onResume = function(self) self:refresh() end,
    render = function(self) return gui.Text { text = self.state.body } end,
})
```

`onPause` carries which way the application went. `inactive` is in front and not taking input — a call arriving, the control centre pulled down, a window losing focus — which is where a game pauses and a video need not. `background` is out of sight and may be ended without another word, which is where a draft is saved. Going from one way of being away to the other is not a return and is not announced as one. `gui.environment` carries the same thing as `state`, for a screen that draws differently while it is away rather than one with work to do.

What the engine owns stops while the application is away and carries on when it comes back: anything a component asked for through `self:after` or `self:every` waits. A suspended application on one platform runs nothing at all, an activity on another goes on running while it is paused, and a hidden tab on the third is throttled without being stopped, so the same timer would otherwise fire three different ways.

Appearing is not the same as being seen. A stack keeps a screen mounted and shown while a box inside it is scrolled a thousand points out of sight, so a box says for itself when the reader can actually see it:

```lua
gui.View {
    style = { height = 200 },
    onEnterView = function() picture:load() end,
    onExitView = function() film:pause() end,
}
```

The engine works this out from the frames it laid out and the offsets the surfaces report, so the answer is arithmetic rather than three implementations that agree by luck. The rectangle is carried up through every surface between the box and the screen and cut by each of them in turn, since a box sitting perfectly inside a list that is itself scrolled away is not visible. Any part of the box being on screen counts as seen. A handler runs after the commit rather than inside it, so it is free to change state.

A surface is asked for its offset only while something under it is watching, because a scroll is reported by the pixel and a screen watching nothing has no use for any of them.

## A frame drawn from artwork

A picture cut into nine draws a box of any size out of one small file: the four corners are never stretched, each edge stretches along one axis only, and the middle stretches both ways. It is how an interface made of artwork is built, and it is what the browser calls a border image, what iOS draws from a layer told where the middle of its contents is, and what Android and most game engines call a nine-patch.

```lua
gui.NineSlice {
    source = "window.png",
    slice = 28,
    sliceScale = 2,
    style = { padding = 28, gap = "md" },

    gui.Text { text = "New version of the application found." },
}
```

`slice` says where the cuts are. One number cuts all four edges the same, and `{ top, right, bottom, left }` cuts each on its own, which is what a window with a bar across its top needs — cut deeper along the top, the bar belongs to the corner pieces and is never stretched downwards.

**The cuts are written in the pixels of the picture that was named.** They point at that file and nothing else, so the engine hands a renderer that file rather than a density variant of it: an `@2x` twice the size cut at the same four numbers would draw every corner at half the width it was authored at. A frame that has to be crisper is shipped larger and drawn smaller, which is the workflow in any case.

`sliceScale` says how many points one pixel of the border is drawn at. At one, a fourteen-pixel corner comes out fourteen points across. At two it comes out twenty-eight, which is how a small piece of pixel art is drawn at the weight it was designed to read at. The pieces are drawn without smoothing on all three, since a frame is artwork and a two-pixel rule drawn larger and smoothed comes out as a smear rather than a rule.

A frame holds what is written inside it the way a `View` does, and it reports both edges of a press as well as the press itself, which is what makes the same component a window, a dialogue and a button. `onPress` arrives when the finger lifts, so a frame that shows it is being held listens for `onPressIn` and `onPressOut` — one that drives its own look from `onPress` alone plays the whole of that look after the press is already over:

```lua
gui.NineSlice {
    source = "button-green.png",
    slice = 14,
    sliceScale = 2,
    style = { paddingHorizontal = 26, paddingVertical = 14, align = "center" },
    onPress = function() accept() end,

    gui.Text { text = "Update", style = { fontWeight = "700" } },
}
```

A frame is worth at least the two corners it is cut at, drawn at the scale it is drawn at, since narrower than that the corners overlap and what comes out is not the picture. A picture cut wider than itself has no middle left to stretch and is drawn whole instead.

A frame is drawn over the box rather than inside it, so the padding a style names is what puts content clear of the border and the children the engine placed are where the engine placed them. The gallery's **Frames from artwork** screen is built out of the five pictures in `sample/assets/images/`, which `tools/draw-frames.py` draws.

## A look over a picture

A picture carries a `filter`, written as the amounts it is made of: how much grey, how much sepia, how much it is inverted, how far the hue is turned, and how saturated, bright and contrasted it is drawn.

```lua
gui.Image { source = "scene.png", filter = { grayscale = 1, contrast = 1.35 } }
gui.Image { source = "scene.png", filter = gui.filter.looks.noir }
```

`gui.filter.looks` carries the ones a picture is usually given — `mono`, `noir`, `sepia`, `vivid`, `fade`, `cool`, `warm` and `negative` — each written in those same amounts, so one of them with a field changed is the same thing again.

Every one of the seven is a colour matrix, which is why all three platforms draw the same picture: the engine works the amounts out into one matrix and sends that, so the browser applies it as a filter primitive, iOS as a `CIColorMatrix` and Android as a `ColorMatrixColorFilter` rather than each of them rounding its own way. They are applied in a fixed order — grey, sepia, inverted, hue, saturation, brightness, contrast — since the fields of a table have no order and colour matrices do not commute.

A tint replaces the colours of a picture outright, so a picture carrying both is drawn in its tint and the filter has nothing left to change.

The same field applies to a film and to a camera preview, so one look reaches all three:

```lua
gui.Video { source = clip, filter = gui.filter.looks.mono }
gui.Camera { filter = gui.filter.looks.mono }
```

A picture and a preview are drawn through it, and a picture taken by a camera carries it into the file. A film keeps the pixels the camera produced, since every platform's encoder takes frames straight from the hardware, so a look over a film is drawn as it plays rather than written into it.

## Both ends of both moves

Everything shown over a screen reports four moments, which is the model a platform tells a screen in:

```lua
gui.Sheet {
    visible = self.state.open,
    onDismiss = function() self:setState({ open = false }) end,

    onWillShow = function() end,
    onShow = function() self:ref("player"):call("play") end,
    onWillHide = function() self:ref("player"):call("pause") end,
    onHide = function() self:setState({ loaded = false }) end,
}
```

`onDismiss` is the reader asking to close it, which is a request rather than a moment. The four moments are what actually happened: told only that something was dismissed, a caller has to guess when it has gone and guesses with a timer of its own, written again in every screen.

`Modal`, `Sheet`, `Alert`, `ActionSheet`, `Menu`, `Toast` and `Drawer` all carry them, since all of them are drawn through the same portal.

The second half of each pair is announced when the move has had the time it was given, which the framework knows because it is the framework that decides how long the move takes. No renderer reports it, so the four are the same four on all three rather than whatever each platform happens to call back.

Every component also reports the moments of its own life, in the same pairs: `onWillMount` and `onMount`, `onWillAppear` and `onAppear`, `onWillDisappear` and `onDisappear`, `onWillUnmount` and `onUnmount`. Appearing is not mounting: a stack keeps the screen under the one on top and a tab bar keeps every tab, so a screen that is built is not necessarily one a reader can see.

## Keeping what was captured

A camera writes where the application may write, which is a place only the application can reach. `gui.files` is how a reader ends up with it:

```lua
local answer = gui.files.save(photo.path):await()

if answer.problem ~= nil then
    self:setState({ said = answer.problem })
end
```

`save` puts it where the platform keeps pictures and films — the photo library on a phone, a download in a browser — and `share` hands it to the system's own sheet, which is also where a reader puts it somewhere the application never hears about. Both answer where it ended up, or a `problem` saying why it did not: a reader who refused the library and a sheet they closed without choosing anything are ordinary rather than failures.

## Over the whole application

Everything shown over a screen — a modal, a sheet, an alert, an action sheet, a menu, a drawer — is drawn through a portal, and `gui.Portal` is that on its own for anything a caller wants over the application itself.

What a portal holds is laid out against the surface rather than against the box it was written in, so a drawer raised from a screen inside a stack darkens the bar above it too. It stays where it was written for everything else: it reads the state of the component that raised it, it is under the same context, and it goes when that component goes.

```lua
gui.View { style = { grow = 1 },
    parts.Page { ... },

    self.state.note and gui.Portal {
        gui.Pressable {
            style = { position = "absolute", top = 16, left = 16, right = 16, padding = "md", background = "primary" },
            onPress = function() self:setState({ note = false }) end,
            gui.Text { text = "Pinned over the application", style = { color = "onPrimary" } },
        },
    } or false,
}
```

Layers stack in the order they were inserted, so a portal written inside content that opens later stands over one written earlier. A layer takes no press of its own, which is what lets a portal with nothing shown in it sit over a screen without swallowing what a finger meant for it.

## Choosing a file

`FilePicker` opens the chooser the platform ships — the photo library when `kind` is `image`, the files app otherwise — and reports what came back. Each entry is named, measured and typed, and carries its bytes as base64 unless it is larger than `maxBytes`, in which case it arrives unread so a reader can be told why.

Nothing is written anywhere. Where a chosen file belongs is the application's to decide, and one line puts it there:

```lua
local crypto = require("crypto")
local fs = require("fs")

gui.FilePicker {
    title = "Choose a picture",
    kind = "image",
    accept = { "image/png", "image/jpeg" },

    onPick = function(files)
        local file = files[1]

        if file.bytes == nil then
            return self:setState({ problem = file.name .. " is too large" })
        end

        local path = "/cache/" .. file.name

        fs.writeFile(path, crypto.base64Decode(file.bytes)):await()
        self:setState({ picture = path })
    end,
}
```

## Capabilities

A renderer declares what it can do at start, and a screen that needs something asks before it draws it rather than drawing a node the platform has no answer for.

```lua
if not runtime.renderer:can("camera") then
    return gui.Text { text = "This device has no camera" }
end
```

An undeclared capability answers false, so a name no renderer has ever heard of is the same as one it cannot do. The capability names are listed in [bridge.md](bridge.md).
