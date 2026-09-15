--- The faces the framework itself ships, registered before the first layout on every platform.
---
--- The same tree is drawn in the same face everywhere rather than in whatever each platform calls its
--- system font, which is what makes a screenshot from one comparable with a screenshot from another.
--- A project that wants its own names them in its manifest, and a style names a family either way.
return {
    { family = "Roboto", file = "Roboto-Regular.ttf", weight = "400" },
    { family = "Roboto", file = "Roboto-Medium.ttf", weight = "500" },
    { family = "Roboto", file = "Roboto-Bold.ttf", weight = "700" },
}
