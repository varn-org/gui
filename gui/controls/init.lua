local theme = require("gui.controls.theme")

--- The control themes the library ships, and the way to write another.
---
--- A look says what a control is coloured in. A control theme says what it is built out of: the sizes it
--- is drawn at, which colour role each of its parts takes in each of its states, how it moves between
--- them, and what a finger does to it. The two are separate, so the same design in two looks is two
--- different-looking applications and one set of controls.
---
--- `native` hands every control to the platform, which is what an application that names none is drawn
--- with. The other three are drawn by the engine out of boxes, text and paths, so a renderer that can
--- build those can host the whole library.
local M = {
    define = theme.define,
    extend = theme.extend,
    isTheme = theme.isTheme,
    platform = theme.platform,
    kind = theme.kind,
    kinds = theme.kinds,
    partsOf = theme.partsOf,
    parts = require("gui.controls.parts"),

    native = require("gui.controls.native"),
    material2 = require("gui.controls.material2"),
    material3 = require("gui.controls.material3"),
    cupertino = require("gui.controls.cupertino"),
}

return M
