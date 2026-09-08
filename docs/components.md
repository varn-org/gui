# 🧩 Components

Every component here is a declaration: the props it accepts, the events it reports, and the values it starts with. A prop it does not declare is refused at the call, so a typo is an error where it was written rather than something three renderers quietly ignore.

The table below is generated from those declarations by `gui/tools/reference.lua`, which means a component cannot document a prop it does not accept, and cannot accept one it does not document.

A declaration is also a promise. `gui/tests/promises_test.lua` reads every prop and event listed here, searches the three renderers and the components for it by name, and fails when nothing reads it, so a prop that appears in this page is one something honours rather than one somebody meant to get to later.

## Reading the table

- **Component** is what a caller writes: `gui.Text { ... }`.
- **Node** is what crosses the bridge, which is what a renderer implements. `Lua` means the component builds itself out of the others, so it works everywhere with nothing added to a renderer.
- **Props** are the fields that describe it. Every component also takes `key`, `style`, `ref`, `testID`,
  and the `transition` and `enter` that say how it arrives and how a change to it is drawn, which are
  described in [animation.md](animation.md).
- **Events** are the handlers it reports through. A handler is a Lua function that never leaves this side.
- **Defaults** are the values it takes when a caller says nothing.

## Every component

### Structure

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Blur` | `blur` | `intensity`, `tint` | `onLayout` | `intensity = 0.85` |
| `Divider` | `divider` | `color`, `inset`, `orientation`, `thickness` | — | `orientation = horizontal`, `thickness = 1` |
| `Gradient` | `gradient` | `colors`, `direction`, `locations` | `onLayout`, `onPress` | `direction = down` |
| `KeyboardAvoiding` | `keyboardavoiding` | `behavior`, `offset` | — | `behavior = padding`, `offset = 0` |
| `SafeArea` | Lua | `barContent`, `barStyle`, `edges` | — | `edges = { … }` |
| `ScrollView` | `scroll` | `bounces`, `contentStyle`, `horizontal`, `keyboardDismissMode`, `paging`, `refreshing`, `scrollEnabled`, `showsIndicator` | `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd` | `bounces = true`, `horizontal = false`, `scrollEnabled = true`, `showsIndicator = true` |
| `Spacer` | `spacer` | `size` | — | — |
| `View` | `view` | `opacity`, `overflow`, `pointerEvents`, `transform` | `onLayout`, `onLongPress`, `onPress` | — |

### Content

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Audio` | `audio` | `loop`, `playing`, `position`, `rate`, `source`, `volume` | `onEnd`, `onProgress`, `onReady` | `loop = false`, `playing = false`, `rate = 1`, `volume = 1` |
| `Canvas` | `canvas` | `commands` | `onLayout` | — |
| `Icon` | Lua | `color`, `name`, `size` | — | `color = text`, `size = 24` |
| `Image` | `image` | `placeholder`, `resizeMode`, `source`, `tint` | `onError`, `onLayout`, `onLoad` | `resizeMode = cover` |
| `RichText` | `richtext` | `numberOfLines`, `spans` | `onLayout` | — |
| `Text` | `text` | `numberOfLines`, `text` | `onLayout`, `onLongPress`, `onPress` | — |
| `Video` | `video` | `autoplay`, `controls`, `loop`, `muted`, `poster`, `rate`, `resizeMode`, `source`, `volume` | `onEnd` | `autoplay = false`, `controls = true`, `loop = false`, `muted = false`, `resizeMode = contain` |
| `WebView` | `webview` | `html`, `javaScriptEnabled`, `scrollEnabled`, `url` | — | `javaScriptEnabled = true`, `scrollEnabled = true` |

### Input

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Button` | `button` | `disabled`, `size`, `title`, `variant` | `onLongPress`, `onPress` | `disabled = false`, `size = medium`, `variant = filled` |
| `Checkbox` | `checkbox` | `color`, `disabled`, `indeterminate`, `label`, `value` | `onChange` | `disabled = false`, `indeterminate = false`, `value = false` |
| `ColorPicker` | `colorpicker` | `disabled`, `value` | `onChange` | — |
| `DatePicker` | `datepicker` | `disabled`, `display`, `maximum`, `minimum`, `value` | `onChange` | `display = compact` |
| `FilePicker` | `filepicker` | `accept`, `disabled`, `kind`, `maxBytes`, `multiple`, `title` | `onPick` | `kind = file`, `maxBytes = 8388608`, `multiple = false` |
| `Picker` | `picker` | `disabled`, `options`, `placeholder`, `title`, `value` | `onChange` | — |
| `Pressable` | `pressable` | `disabled`, `hitSlop` | `onLongPress`, `onPress`, `onPressIn`, `onPressOut`, `onSwipe` | `disabled = false` |
| `Radio` | `radio` | `color`, `disabled`, `label`, `selected`, `value` | `onSelect` | `disabled = false`, `selected = false` |
| `Rating` | `rating` | `color`, `count`, `size`, `value` | `onChange` | `count = 5`, `size = 24` |
| `SearchBar` | `searchbar` | `placeholder`, `value` | `onBlur`, `onChange`, `onFocus`, `onSubmit` | — |
| `SegmentedControl` | `segmented` | `disabled`, `segments`, `selectedIndex` | `onChange` | `disabled = false`, `selectedIndex = 1` |
| `Slider` | `slider` | `continuous`, `disabled`, `maximum`, `minimum`, `step`, `thumbColor`, `trackColor`, `value` | `onChange`, `onCommit` | `continuous = true`, `disabled = false`, `maximum = 1`, `minimum = 0` |
| `Stepper` | `stepper` | `disabled`, `maximum`, `minimum`, `step`, `value` | `onChange` | `disabled = false`, `step = 1` |
| `Switch` | `switch` | `disabled`, `offColor`, `onColor`, `thumbColor`, `value` | `onChange` | `disabled = false`, `value = false` |
| `TextArea` | `textarea` | `editable`, `maxLength`, `placeholder`, `rows`, `value` | `onBlur`, `onChange`, `onFocus` | `editable = true`, `rows = 3` |
| `TextInput` | `textinput` | `autoCapitalize`, `autoCorrect`, `editable`, `keyboard`, `maxLength`, `placeholder`, `placeholderColor`, `returnKey`, `secure`, `value` | `onBlur`, `onChange`, `onFocus`, `onSubmit` | `autoCapitalize = sentences`, `autoCorrect = true`, `editable = true`, `keyboard = default`, `returnKey = done`, `secure = false` |
| `TimePicker` | `timepicker` | `disabled`, `display`, `value` | `onChange` | `display = compact` |

### Place

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Location` | `location` | `accuracy`, `watch` | `onChange`, `onError` | `accuracy = fine`, `watch = false` |
| `Map` | `map` | `center`, `interactive`, `markers`, `zoom` | `onLayout`, `onMarkerPress`, `onPress`, `onRegionChange` | `interactive = true`, `zoom = 14` |

### Collections

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Carousel` | Lua | `autoplay`, `autoplayInterval`, `bounces`, `data`, `empty`, `horizontal`, `index`, `indicator`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `loop`, `peek`, `recycle`, `renderItem`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onIndexChange`, `onLayout`, `onScroll`, `onScrollEnd`, `onSelect` | `autoplay = false`, `autoplayInterval = 4000`, `horizontal = true`, `index = 1`, `indicator = true`, `loop = false`, `recycle = true`, `showsIndicator = false`, `spacing = 0` |
| `Grid` | Lua | `bounces`, `columns`, `data`, `empty`, `endThreshold`, `footer`, `footerExtent`, `header`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `minColumnWidth`, `recycle`, `refreshing`, `renderItem`, `rowExtent`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `columns = 2`, `recycle = true`, `scrollEnabled = true`, `spacing = 8` |
| `List` | Lua | `bounces`, `data`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `footerExtent`, `header`, `headerExtent`, `horizontal`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `keyboardDismissMode`, `paging`, `recycle`, `refreshing`, `renderItem`, `scrollEnabled`, `separator`, `separatorExtent`, `showsIndicator`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `bounces = true`, `horizontal = false`, `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `windowMargin = 2` |
| `SectionList` | Lua | `bounces`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `header`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `recycle`, `refreshing`, `renderFooter`, `renderHeader`, `renderItem`, `scrollEnabled`, `sectionFooterExtent`, `sections`, `separator`, `separatorExtent`, `showsIndicator`, `stickyHeaders`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `stickyHeaders = true`, `windowMargin = 2` |

### Containers

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Accordion` | Lua | `expanded`, `multiple`, `sections` | `onChange` | `multiple = false` |
| `Drawer` | Lua | `content`, `open`, `side`, `width` | `onClose` | `open = false`, `side = left`, `width = 280` |
| `NavigationStack` | Lua | `actions`, `backTitle`, `barStyle`, `hidesBar`, `index`, `screens`, `title` | `onBack`, `onIndexChange`, `onPop` | `hidesBar = false`, `index = 1` |
| `RadioGroup` | Lua | `disabled`, `options`, `orientation`, `value` | `onChange` | `orientation = vertical` |
| `TabBar` | Lua | `badgeCounts`, `position`, `selectedIndex`, `tabs` | `onChange` | `position = bottom`, `selectedIndex = 1` |
| `Table` | Lua | `columns`, `rowExtent`, `rows`, `sortBy`, `sortOrder`, `striped` | `onRowPress`, `onSelect`, `onSort` | `rowExtent = 44`, `sortOrder = ascending`, `striped = false` |

### Adapting

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `SplitView` | Lua | `collapseAt`, `content`, `showing`, `sidebar`, `sidebarWidth` | `onShowingChange` | `collapseAt = medium`, `sidebarWidth = 320` |

### Presence

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Presence` | Lua | `delay`, `duration`, `easing`, `transition`, `visible` | — | `transition = fade`, `visible = false` |

### Presentation

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `ActionSheet` | Lua | `actions`, `cancelLabel`, `message`, `title`, `visible` | `onAction`, `onDismiss` | `cancelLabel = Cancel`, `visible = false` |
| `Alert` | Lua | `actions`, `message`, `title`, `visible` | `onAction`, `onDismiss` | `visible = false` |
| `Menu` | Lua | `items`, `visible` | `onDismiss`, `onSelect` | `visible = false` |
| `Modal` | Lua | `dismissible`, `transparent`, `visible` | `onDismiss` | `dismissible = true`, `transparent = false`, `visible = false` |
| `Sheet` | Lua | `detents`, `dismissible`, `grabber`, `selectedDetent`, `visible` | `onDismiss` | `detents = { … }`, `dismissible = true`, `grabber = true`, `visible = false` |
| `Toast` | Lua | `action`, `duration`, `message`, `position`, `visible` | `onAction`, `onDismiss` | `duration = 3000`, `position = bottom`, `visible = false` |

### Feedback

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `ActivityIndicator` | `activity` | `animating`, `color`, `size` | — | `animating = true`, `size = medium` |
| `Avatar` | Lua | `badge`, `initials`, `shape`, `size`, `source` | — | `shape = circle`, `size = 40` |
| `Badge` | Lua | `color`, `dot`, `max`, `textColor`, `value` | — | `dot = false`, `max = 99` |
| `Card` | `card` | `elevation`, `outlined`, `padded` | `onPress` | `elevation = sm`, `outlined = false`, `padded = true` |
| `Chip` | Lua | `color`, `disabled`, `label`, `selected` | `onPress`, `onRemove` | `disabled = false`, `selected = false` |
| `ProgressBar` | `progress` | `color`, `indeterminate`, `thickness`, `trackColor`, `value` | — | `indeterminate = false`, `thickness = 4` |
| `Skeleton` | Lua | `lines`, `shape` | — | `lines = 1`, `shape = rect` |
| `Tooltip` | `tooltip` | `text`, `visible` | — | — |

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

## A chip that can be taken away

A `Chip` is a label in a pill: one of a set that can be chosen, and, when it is given somewhere to report it, one somebody is building that can be taken back out.

```lua
gui.Chip {
    label = flavour,
    onRemove = function() self:setState({ kept = without(self.state.kept, flavour) }) end,
}
```

The mark that removes it is drawn from the engine's own icon set, so it is the same shape everywhere, and what a finger has to land on is a full target even though the mark is small.

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

A renderer declares what it can do, and a component that needs something it has no answer for fails loudly rather than rendering nothing.

```lua
local player = gui.headless()
runtime.renderer:require("video", "the player screen")
```

The capability names are listed in [bridge.md](bridge.md).
