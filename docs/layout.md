# 📐 Layout

Layout is computed in Lua and the renderers are given finished frames. A row of three cards is measured once and lands in the same place on a phone, a browser and a tablet, because the same code decided where it goes.

## Flexbox

The model is flexbox, with the fields a caller expects.

| Field | Values |
|---|---|
| `direction` | `row`, `column`, `row-reverse`, `column-reverse` |
| `justify` | `start`, `center`, `end`, `space-between`, `space-around`, `space-evenly` |
| `align`, `alignSelf` | `start`, `center`, `end`, `stretch` |
| `wrap` | `nowrap`, `wrap`, `wrap-reverse` |
| `grow`, `shrink` | a number |
| `basis` | a number, a percentage, or `auto` |
| `gap`, `rowGap`, `columnGap` | a number or a spacing token |

```lua
gui.View {
    style = { direction = "row", justify = "space-between", align = "center", gap = "md" },
    gui.Text { text = "Title" },
    gui.Switch { value = dark, onChange = toggle },
}
```

## Size

`width` and `height` take a number, a percentage as a string, or nothing. `minWidth`, `maxWidth`, `minHeight` and `maxHeight` bound what a node takes.

A node with no size asks its content. A label asks the renderer what its string measures, an image takes its natural size, and a box with neither content nor size is zero.

## The box model

`margin`, `padding` and `border` apply per side, with the shorthands.

| Written | Means |
|---|---|
| `padding = 8` | every side |
| `paddingHorizontal`, `paddingVertical` | one axis |
| `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft` | one side |

The same four shapes exist for `margin`. `border` is a width, and `borderColor` is what it is drawn in.

## Absolute positioning

`position = "absolute"` takes a node out of flow and places it against its nearest positioned ancestor with `top`, `right`, `bottom` and `left`. Giving both edges of an axis stretches the node between them.

```lua
gui.View {
    style = { grow = 1 },
    gui.View { style = { position = "absolute", right = 16, bottom = 16, width = 56, height = 56 } },
}
```

## Text measurement

Only the platform knows what its font engine does with a string, so the engine asks and caches the answer against every input: the text, the size, the family, the weight and the width bound. Registering a font drops the cache, since the same string in a different face is a different size.

## Safe areas and the keyboard

Both are layout inputs rather than a platform check.

`SafeArea` turns the insets the platform reports into padding, on the edges it was told to avoid:

```lua
gui.SafeArea { edges = { "top", "bottom" }, style = { grow = 1 }, content }
```

`KeyboardAvoiding` leaves room for the keyboard while it is up, and takes it back when it goes:

```lua
gui.KeyboardAvoiding { offset = 0, style = { grow = 1, justify = "end" }, form }
```

A device with no notch reports zero insets and the same tree reads correctly, which is the point.

## Hearing about a frame

`onLayout` reports the frame a node was given, after the commit that gave it. It is what a component reads when it needs a measurement the tree already has, such as a list learning how tall its viewport is.

```lua
gui.View { onLayout = function(frame) print(frame.width, frame.height) end }
```

## Responsive values

Any style value may be a table keyed by breakpoint, resolved against the current width, so one tree serves a phone and a tablet.

```lua
gui.View { style = { padding = { compact = 12, medium = 20, expanded = 32 } } }
```

The breakpoints come from the theme, so a project may name its own.

## Reference and tests

`gui/layout/flex.lua` is the engine, and `gui/tests/layout_test.lua` is a table of trees and the frames they must produce, so a change that moves a pixel is caught here rather than discovered on a device.
