# 🎨 Styling

A style is a table. A node takes one, or a list of them, and the result is resolved into concrete values before it crosses the bridge — so no renderer carries a theme of its own and three of them cannot disagree about what a spacing step means.

```lua
gui.Text {
    text = "Ready",
    style = { color = "text", fontSize = "title", fontWeight = "700" },
}
```

## Composition

A list of styles is flattened left to right, and a `false` entry is skipped, which is how a conditional style is written without an `if`.

```lua
gui.View { style = { base, selected and highlight, { padding = "md" } } }
```

A style table that never changes is resolved once and cached by identity, so a static style costs nothing to re-render.

## The theme

The theme carries colors, typography, spacing, radii, shadows and breakpoints. A style names a token and the engine resolves it.

```lua
local theme = gui.theme.create({
    colors = { primary = "#3b6cff", surface = "#ffffff", text = "#101114" },
    spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 40 },
    radii = { sm = 4, md = 8, lg = 16, full = 9999 },
})
```

`gui.theme.dark()` answers the dark counterpart. Swapping the theme at runtime re-resolves the whole tree, which is what a light and dark switch is:

```lua
runtime:setTheme(gui.theme.dark())
```

The fields that take a token are the spacing family (`padding`, `margin`, `gap`), the radius family, `fontSize`, and every colour field (`color`, `background`, `borderColor`, `tint`, `placeholderColor`). Anything else is taken as written.

## Colors

Hex in three, four, six or eight digits, `rgb`, `rgba`, `hsl`, `hsla`, and the named colours the theme carries.

```lua
gui.color.parse("#3b6cff")
gui.color.lighten("#3b6cff", 0.2)
gui.color.darken("primary", 0.2)
gui.color.readable("#3b6cff")
```

`readable` answers the foreground that reads against a background, which is what a component picking its own text colour needs.

## Typography

`fontFamily`, `fontSize`, `fontWeight`, `fontStyle`, `lineHeight`, `letterSpacing`, `textAlign`, `textDecoration` and `textTransform`.

A custom family resolves to a font the manifest registered, which is described in [assets.md](assets.md).

## Appearance

`background`, `borderColor`, `border`, `radius` and the four corner radii, `opacity`, `shadow` and `overflow`.

```lua
gui.View {
    style = {
        background = "surface",
        radius = "lg",
        border = 1,
        borderColor = "#00000014",
        shadow = { offsetY = 2, radius = 8, color = "#00000022" },
    },
}
```

## Transforms

A transform moves what is drawn rather than what is measured, so a node keeps the frame the layout engine gave it however it is scaled or rotated.

```lua
gui.View { style = { transform = { translateX = 4, rotate = 45, scale = 1.2 } } }
```

The fields are `translateX`, `translateY`, `scale`, `scaleX`, `scaleY`, `rotate` in degrees, `skewX` and `skewY`. `scale` sets both axes unless one is given on its own. A field nobody knows what to do with is refused rather than ignored.

## Responsive values

Any value may be keyed by breakpoint, resolved against the current width.

```lua
gui.Text { text = "Title", style = { fontSize = { compact = 20, expanded = 28 } } }
```

## Reference and tests

`gui/style/` carries the resolver, the theme and the colour helpers, and `gui/tests/style_test.lua` and `gui/tests/environment_test.lua` prove that a token never reaches a renderer unresolved and that a new theme reaches every node that was already there.
