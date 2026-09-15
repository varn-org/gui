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

A style carries only fields something honours, and anything else is refused where it is written, naming it. So is a value the field cannot carry: a size, a padding, a gap, a corner or a border below nothing, and a `grow` or `shrink` that is not a number. A margin and the four offsets may go below nothing, since that is how a box is pulled outside the one that holds it. A misspelling is otherwise carried across the bridge to three renderers that each ignore it, so a caller who wrote `colr` is shown a box with no colour and told nothing at all — the props of a node are held to what a component declares, and a style is the other half of the same promise.

## The theme

The theme carries colors, typography, spacing, radii, shadows and breakpoints. A style names a token and the engine resolves it.

```lua
local theme = gui.theme.create({
    colors = { primary = "#3b6cff", surface = "#ffffff", text = "#101114" },
    spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 40 },
    radii = { sm = 4, md = 8, lg = 16, full = 9999 },
})
```

`gui.theme.dark()` answers the dark counterpart of the defaults, and a theme given to a runtime pins the application to it.

## A look

A look is one design with an appearance on each side of it, which is what an application actually chooses. Written as two themes an application either repeats itself or drifts, and choosing one of them outright is an application that stops following the device the moment it has a look of its own.

```lua
local ocean = gui.theme.define({
    name = "ocean",
    spacing = { md = 20 },
    radii = { sm = 8, md = 14 },
    typography = { family = "Inter" },
    light = { colors = { primary = "#00668b", background = "#f2fbff" } },
    dark = { colors = { primary = "#7fd0ff", background = "#04121a" } },
})

gui.start(app, renderer, { theme = ocean })
```

`gui.theme.looks` carries the designs people already recognise — `nuxt`, `bootstrap` and `blossom` — each the palette, the corners and the spacing that design is known for. They are looks like any other, so one of them with a field changed is a starting point rather than a wall.

Everything written outside `light` and `dark` belongs to both, since a design is one thing and the two sides are two views of it: the spacing, the corners, the face and the sizes are shared, and only the colours differ. `gui.theme.builtin` is the one the framework carries, and it is a look like any other.

An application put in a look still follows the device: which side of it a reader is shown is theirs, and the look is the application's.

Any screen may change it, without being handed the runtime:

```lua
local wearing = gui.theming:read(self)

gui.Text { text = "Wearing " .. wearing.name }
gui.Button { title = "Ocean", onPress = function() wearing.use(ocean) end }
```

Reading it draws the component again when the look changes, so a chooser shows which one is on without holding a copy of the answer. A runtime may also be told directly, which is what an application deciding for itself does:

```lua
runtime:setTheme(ocean)
```

## One branch in a look of its own

An application wears one look and that is nearly always the whole of it. Some screens hold something with colours of its own: a page serving two brands, a product drawn in a customer's palette, a gallery showing five applications one at a time. `gui.Look` puts everything under it in another look and leaves the rest of the application in its own.

```lua
gui.Look { value = ocean, style = { grow = 1 },
    gui.View { style = { background = "primary" } },
}
```

What is under it is resolved against that look rather than the application's — every colour, every spacing step, every corner. It still follows the device between light and dark, since a look carries both sides of itself.

The control theme is untouched, because a look and a control theme are two things: what is under a `Look` is built out of the same parts as everything around it and coloured differently. `gui.Controls` is the other half and does the same for the parts. Either may be written inside the other.

`use` still belongs to the application, so a chooser under a `Look` changes what the application is drawn in and what is under the `Look` stays in the one it was given.

The five applications in the gallery are each one of these: five palettes in one tree, none of them the gallery's own. See [the sample](sample.md).

## What the platform paints

A page, a window and an activity each draw something of their own around what the tree draws, and none of it is a node: the ground behind the surface, the colour a browser writes the captions of its own controls in, what a selection and a caret are drawn in, and the accent on a control the platform owns. A dark application on a white page is what leaving it out looks like.

The engine sends every renderer the ground of the look in use — the background, the text colour, the primary colour, the face and which appearance it is — and each paints its own: the browser writes them into the page and the scheme it resolves its own colours against, iOS paints the window and its tint, and Android the window behind the surface. A page carries no colours of its own, so an application is what decides them.

The fields that take a token are the spacing family (`padding`, `margin`, `gap`), the radius family, `fontSize`, and the colour fields (`color`, `background`, `borderColor`). Anything else is taken as written.

A colour a control carries rather than a box — a picture's `tint`, a placeholder's colour, a switch's track — is a prop rather than a style field, and it takes a theme name in exactly the same way.

## Colors

Hex in three, four, six or eight digits, `rgb`, `rgba`, `hsl`, `hsla`, and the named colours the theme carries.

```lua
gui.color.parse("#3b6cff")
gui.color.lighten("#3b6cff", 0.2)
gui.color.darken("primary", 0.2)
gui.color.readable("#3b6cff")
```

`readable` answers the foreground that reads against a background, which is what a component picking its own text colour needs.

A colour short of a channel is refused where it is written, naming what was written: `rgb(255, 0)` read as far as it goes is a channel missing arriving inside the arithmetic that renders it, which is a screen gone naming a line of the framework rather than the colour an application wrote.

## Typography

`fontFamily`, `fontSize`, `fontWeight`, `fontStyle`, `lineHeight`, `letterSpacing`, `textAlign` and `textDecoration`. `lineHeight` is a multiple of the size on every platform — a sixteen point size at 1.5 is a twenty-four point line — and a style that names neither a family nor a line takes the theme's, so a string is measured in the face and the line it is drawn in. The colours in the palette are the classic families at the ten tones each is published in, so a style may name `indigo400` or `red` as well as a role like `primary`. There is no `textTransform`: changing the case of a string is one call in Lua, and a field that changed it would have to be applied where the text is drawn and again where it is measured, in each of three renderers.

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

The fields are `translateX`, `translateY`, `scale`, `scaleX`, `scaleY` and `rotate` in degrees. `scale` sets both axes unless one is given on its own. A field nobody knows what to do with is refused rather than ignored. There is no skew: Android's view system has none, so it could only ever have worked on two platforms out of three.

## Responsive values

Any value may be keyed by breakpoint, resolved against the current width.

```lua
gui.Text { text = "Title", style = { fontSize = { compact = 20, expanded = 28 } } }
```

## What the surface is like

`gui.environment` is what a component reads to find out what it is being drawn on, and the only thing in the library that carries a platform's name.

```lua
local surface = gui.environment:read(self)

if surface.breakpoint ~= "compact" then
    return self:Split()
end
```

It carries `platform`, `appearance`, `scale`, `width`, `height`, `breakpoint` and `insets`. Reading it makes a component one the engine renders again when any of them changes, which is what a rotation is. How much room there is — the breakpoint — is what tells a tablet from a phone: the platform's name is for the chrome and for nothing else, and a component that reads it to decide a colour or a size is doing it wrong.

A value of your own flows down the same way, without being threaded through every component between:

```lua
local Money = gui.context("EUR")

Money.Provider { value = "USD", ... }        -- anywhere above
local currency = Money:read(self)            -- anywhere below
```

Only the components that read it are rendered again when it changes, rather than the whole tree under the provider.

## Reference and tests

`gui/style/` carries the resolver, the theme and the colour helpers, and `gui/tests/style_test.lua` and `gui/tests/environment_test.lua` prove that a token never reaches a renderer unresolved and that a new theme reaches every node that was already there.
