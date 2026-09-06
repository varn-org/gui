# 🧩 Components

Every component here is a declaration: the props it accepts, the events it reports, and the values it starts with. A prop it does not declare is refused at the call, so a typo is an error where it was written rather than something three renderers quietly ignore.

The table below is generated from those declarations by `gui/tools/reference.lua`, which means a component cannot document a prop it does not accept, and cannot accept one it does not document.

A declaration is also a promise. `gui/tests/promises_test.lua` reads every prop and event listed here, searches the three renderers and the components for it by name, and fails when nothing reads it, so a prop that appears in this page is one something honours rather than one somebody meant to get to later.

## Reading the table

- **Component** is what a caller writes: `gui.Text { ... }`.
- **Node** is what crosses the bridge, which is what a renderer implements. `Lua` means the component builds itself out of the others, so it works everywhere with nothing added to a renderer.
- **Props** are the fields that describe it. Every component also takes `key`, `style`, `ref` and `testID`.
- **Events** are the handlers it reports through. A handler is a Lua function that never leaves this side.
- **Defaults** are the values it takes when a caller says nothing.

## Every component

### Structure

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Divider` | `divider` | `color`, `inset`, `orientation`, `thickness` | — | `orientation = horizontal`, `thickness = 1` |
| `KeyboardAvoiding` | `keyboardavoiding` | `behavior`, `offset` | — | `behavior = padding`, `offset = 0` |
| `SafeArea` | `safearea` | `edges` | — | `edges = { … }` |
| `ScrollView` | `scroll` | `bounces`, `contentInset`, `contentStyle`, `horizontal`, `keyboardDismissMode`, `paging`, `refreshing`, `scrollEnabled`, `showsIndicator` | `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd` | `bounces = true`, `horizontal = false`, `scrollEnabled = true`, `showsIndicator = true` |
| `Spacer` | `spacer` | `size` | — | — |
| `View` | `view` | `opacity`, `overflow`, `pointerEvents`, `transform` | `onLayout`, `onLongPress`, `onPress` | — |

### Content

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Canvas` | `canvas` | `commands` | `onLayout` | — |
| `Icon` | `icon` | `color`, `family`, `name`, `size` | — | `size = 24` |
| `Image` | `image` | `placeholder`, `resizeMode`, `source`, `tint` | `onLayout` | `resizeMode = cover` |
| `RichText` | `richtext` | `numberOfLines`, `spans` | `onLayout` | — |
| `Text` | `text` | `numberOfLines`, `text` | `onLayout`, `onLongPress`, `onPress` | — |
| `Video` | `video` | `autoplay`, `controls`, `loop`, `muted`, `poster`, `rate`, `resizeMode`, `source`, `volume` | `onEnd` | `autoplay = false`, `controls = true`, `loop = false`, `muted = false`, `resizeMode = contain` |
| `WebView` | `webview` | `html`, `javaScriptEnabled`, `scrollEnabled`, `url` | — | `javaScriptEnabled = true`, `scrollEnabled = true` |

### Input

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Button` | `button` | `disabled`, `icon`, `size`, `title`, `variant` | `onLongPress`, `onPress` | `disabled = false`, `size = medium`, `variant = filled` |
| `Checkbox` | `checkbox` | `color`, `disabled`, `indeterminate`, `label`, `value` | `onChange` | `disabled = false`, `indeterminate = false`, `value = false` |
| `ColorPicker` | `colorpicker` | `disabled`, `value` | `onChange` | — |
| `DatePicker` | `datepicker` | `disabled`, `maximum`, `minimum`, `mode`, `value` | `onChange` | `mode = date` |
| `FilePicker` | `filepicker` | `title` | — | — |
| `Picker` | `picker` | `disabled`, `options`, `placeholder`, `title`, `value` | `onChange` | — |
| `Pressable` | `pressable` | `disabled`, `hitSlop` | `onLongPress`, `onPress`, `onPressIn`, `onPressOut` | `disabled = false` |
| `Radio` | `radio` | `color`, `disabled`, `label`, `selected`, `value` | `onSelect` | `disabled = false`, `selected = false` |
| `Rating` | `rating` | `color`, `count`, `size`, `value` | `onChange` | `count = 5`, `size = 24` |
| `SearchBar` | `searchbar` | `placeholder`, `value` | `onBlur`, `onChange`, `onFocus`, `onSubmit` | — |
| `SegmentedControl` | `segmented` | `disabled`, `segments`, `selectedIndex` | `onChange` | `disabled = false`, `selectedIndex = 1` |
| `Slider` | `slider` | `continuous`, `disabled`, `maximum`, `minimum`, `step`, `thumbColor`, `trackColor`, `value` | `onChange`, `onCommit` | `continuous = true`, `disabled = false`, `maximum = 1`, `minimum = 0` |
| `Stepper` | `stepper` | `disabled`, `maximum`, `minimum`, `step`, `value` | `onChange` | `disabled = false`, `step = 1` |
| `Switch` | `switch` | `disabled`, `offColor`, `onColor`, `thumbColor`, `value` | `onChange` | `disabled = false`, `value = false` |
| `TextArea` | `textarea` | `editable`, `maxLength`, `placeholder`, `rows`, `value` | `onBlur`, `onChange`, `onFocus` | `editable = true`, `rows = 3` |
| `TextInput` | `textinput` | `autoCapitalize`, `autoCorrect`, `editable`, `keyboard`, `maxLength`, `placeholder`, `placeholderColor`, `returnKey`, `secure`, `value` | `onBlur`, `onChange`, `onFocus`, `onSubmit` | `autoCapitalize = sentences`, `autoCorrect = true`, `editable = true`, `keyboard = default`, `returnKey = done`, `secure = false` |
| `TimePicker` | `timepicker` | `disabled`, `value` | `onChange` | — |

### Collections

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Carousel` | Lua | `autoplay`, `autoplayInterval`, `bounces`, `data`, `empty`, `horizontal`, `index`, `indicator`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `loop`, `peek`, `recycle`, `renderItem`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onIndexChange`, `onLayout`, `onScroll`, `onScrollEnd`, `onSelect` | `autoplay = false`, `autoplayInterval = 4000`, `horizontal = true`, `index = 1`, `indicator = true`, `loop = false`, `recycle = true`, `spacing = 0` |
| `Grid` | Lua | `bounces`, `columns`, `data`, `empty`, `endThreshold`, `footer`, `footerExtent`, `header`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `minColumnWidth`, `recycle`, `refreshing`, `renderItem`, `rowExtent`, `scrollEnabled`, `showsIndicator`, `spacing`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `columns = 2`, `recycle = true`, `scrollEnabled = true`, `spacing = 8` |
| `List` | Lua | `bounces`, `contentInset`, `data`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `footerExtent`, `header`, `headerExtent`, `horizontal`, `initialCount`, `inverted`, `itemExtent`, `itemType`, `keyExtractor`, `keyboardDismissMode`, `paging`, `recycle`, `refreshing`, `renderItem`, `scrollEnabled`, `separator`, `separatorExtent`, `showsIndicator`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `bounces = true`, `horizontal = false`, `inverted = false`, `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `windowMargin = 2` |
| `SectionList` | Lua | `bounces`, `empty`, `endThreshold`, `estimatedItemExtent`, `footer`, `header`, `headerExtent`, `initialCount`, `itemExtent`, `itemType`, `keyExtractor`, `recycle`, `refreshing`, `renderFooter`, `renderHeader`, `renderItem`, `scrollEnabled`, `sectionFooterExtent`, `sections`, `separator`, `separatorExtent`, `showsIndicator`, `stickyHeaders`, `windowMargin` | `onEndReached`, `onItemAppear`, `onItemDisappear`, `onLayout`, `onRefresh`, `onScroll`, `onScrollEnd`, `onSelect` | `recycle = true`, `scrollEnabled = true`, `showsIndicator = true`, `stickyHeaders = true`, `windowMargin = 2` |

### Containers

| Component | Node | Props | Events | Defaults |
|---|---|---|---|---|
| `Accordion` | Lua | `expanded`, `multiple`, `sections` | `onChange` | `multiple = false` |
| `Drawer` | Lua | `content`, `open`, `side`, `width` | `onClose` | `open = false`, `side = left`, `width = 280` |
| `NavigationStack` | Lua | `backTitle`, `barStyle`, `hidesBar`, `index`, `screens`, `title` | `onIndexChange`, `onPop` | `hidesBar = false`, `index = 1` |
| `RadioGroup` | Lua | `disabled`, `options`, `orientation`, `value` | `onChange` | `orientation = vertical` |
| `TabBar` | Lua | `badgeCounts`, `position`, `selectedIndex`, `tabs` | `onChange` | `position = bottom`, `selectedIndex = 1` |
| `Table` | Lua | `columns`, `rowExtent`, `rows`, `sortBy`, `sortOrder`, `striped` | `onRowPress`, `onSelect`, `onSort` | `rowExtent = 44`, `sortOrder = ascending`, `striped = false` |

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
| `Avatar` | `avatar` | `badge`, `initials`, `shape`, `size`, `source` | — | `shape = circle`, `size = 40` |
| `Badge` | `badge` | `color`, `dot`, `max`, `textColor`, `value` | — | `dot = false`, `max = 99` |
| `Card` | `card` | `elevation`, `outlined`, `padded` | `onPress` | `elevation = sm`, `outlined = false`, `padded = true` |
| `Chip` | `chip` | `color`, `disabled`, `icon`, `label`, `selected` | `onPress` | `disabled = false`, `selected = false` |
| `ProgressBar` | `progress` | `color`, `indeterminate`, `thickness`, `trackColor`, `value` | — | `indeterminate = false`, `thickness = 4` |
| `RefreshControl` | `refresh` | `refreshing`, `tint`, `title` | `onRefresh` | `refreshing = false` |
| `Skeleton` | `skeleton` | `lines`, `shape` | — | `lines = 1`, `shape = rect` |
| `Tooltip` | `tooltip` | `text`, `visible` | — | — |

## What is not in the table

`style` is documented in [styling.md](styling.md), the layout fields in [layout.md](layout.md), and the fields shared by every collection in [lists.md](lists.md).

Three components take a value that is itself a tree rather than a plain value: `List.renderItem`, `SectionList.renderHeader` and `Grid.renderItem`. Those are functions that answer an element, which is why a cell may hold anything a component can build.

## Examples

Every component appears in the sample application, under `sample/demos/`. Its first screen is an index of what there is to see, grouped by the kind of thing it is — inputs, content, drawing, lists, layout, feedback, presentation and two real screens — and each entry opens a demo of its own. Run it with `python3 run.py sample` and open it in whichever host you have to hand. `gui/tests/sample_test.lua` renders every demo and fails naming the one that broke, and refuses a component that appears in none of them.

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

## Capabilities

A renderer declares what it can do, and a component that needs something it has no answer for fails loudly rather than rendering nothing.

```lua
local player = gui.headless()
runtime.renderer:require("video", "the player screen")
```

The capability names are listed in [bridge.md](bridge.md).
