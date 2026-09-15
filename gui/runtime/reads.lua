local M = {}

--- What the engine reads out of a node's props, by name and by the type that carries it.
---
--- Held together here rather than spread through the passes that read them, since the question a reader
--- asks is what the engine reads rather than where it happens to read it.

M.edges = {
    top = "paddingTop",
    right = "paddingRight",
    bottom = "paddingBottom",
    left = "paddingLeft",
}

--- The fields that say how a box arranges its children, rather than how large the box itself is.
M.arranging = {
    "direction", "justify", "align", "wrap", "gap", "rowGap", "columnGap",
    "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
    "paddingHorizontal", "paddingVertical",
}

--- The props that carry styles of their own inside them, which are resolved along with the node's.
M.nested = { spans = true }

--- The props that carry a colour inside each of their entries, which is resolved the same way.
M.painted = { commands = true }

--- The props that name a file in the application's bundle, by the type that reads them as one.
---
--- A prop name means what its type says it means: a placeholder is a picture on an image and the words
--- shown in an empty field on a field, so which props name a file is decided per type and never by name
--- alone.
M.assets = {
    image = { source = true, placeholder = true },
    video = { poster = true },
}

--- The events a box carries to be told when the reader can see it, which the engine works out itself.
M.seeing = { onEnterView = true, onExitView = true }

--- The types that take the keyboard, which are told to report focus whether a screen asked or not.
---
--- The engine lifts a focused field clear of the keyboard itself, and it knows which field that is only
--- because the field said it had taken focus. A renderer binds an event when a handler for it crosses,
--- so a screen that had no use for `onFocus` sent none, nothing was bound, nothing was reported, and the
--- keyboard came up over the field the reader had just pressed. What the engine needs is not the
--- screen's to declare.
M.focusing = {
    textinput = true,
    textarea = true,
    searchbar = true,
}

--- The props that name a picture used at its own pixels, by the type that reads one that way.
---
--- A nine-slice is cut at four numbers of pixels, and those numbers point at the picture the caller
--- named. Handing a renderer an `@2x` variant instead would cut a picture twice the size at the same
--- four numbers, so the corners would come out half the width they were drawn at.
M.pixels = {
    nineslice = { source = true },
}

--- The props that carry a picture per state rather than one picture, by the type that reads them.
---
--- A frame drawn from artwork is how a button is drawn from artwork, and a button is a different picture
--- while a finger is on it. Each of them is a name in the bundle like any other, resolved at the picture's
--- own pixels for the same reason the one source is.
M.pixelSets = {
    nineslice = { sources = true },
}

--- The props that name something a platform's own player opens, which is a file or an address.
---
--- A picture is fetched by the engine because a phone hands an `https://` string to its image view and
--- quietly draws nothing. A player is the other way round: every one of the three streams an address
--- itself, and downloading a film into memory to hand it over as bytes is a page that draws nothing while
--- a browser refuses the request outright.
M.streamed = {
    video = { source = true },
    audio = { source = true },
}

--- The prop that says how what a node draws is coloured, which is resolved into one colour matrix.
---
--- A filter is written as amounts — how grey, how sepia, how saturated — and reaches a renderer as the
--- matrix they come to, since the browser has one filter primitive, iOS a `CIColorMatrix` and Android a
--- `ColorMatrixColorFilter`. The arithmetic is done once here rather than three times, so one filter is
--- one picture on all three, and a filter that changes nothing is dropped rather than sent.
M.filtered = "filter"

--- The props that carry a colour rather than a style, which are resolved the way a style's colours are.
---
--- A control tinted through a prop is tinted with a theme name like everything else, and a renderer
--- reads a colour rather than parsing one, so these arrive as the same hex a style carries.
M.tints = {
    color = true, textColor = true, tint = true, placeholderColor = true, linkColor = true,
    onColor = true, offColor = true, thumbColor = true, trackColor = true,
}

--- The props that carry a run of colours rather than one, which are resolved the same way.
M.palettes = { colors = true }

return M
