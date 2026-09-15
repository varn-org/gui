local theme = require("gui.controls.theme")

--- The controls the platform draws, which is what an application that names no control theme is given.
---
--- A reader already knows how the control their own system draws behaves, down to how long a press has
--- to be held and what a drag across it does, and none of that is worth imitating where the real one is
--- there to be used. Everything drawn by the engine is a choice made against this one.
local platform = {}

for _, control in ipairs(theme.kinds()) do
    -- A kind no platform draws is left to the entry it brought, since handing it to a platform that has
    -- none of it is a control that draws nothing where it was written.
    if not theme.alwaysDrawn(control) then
        platform[control] = theme.platform
    end
end

--- A field is the one control the platform does not draw, because no platform draws one.
---
--- What a system owns is the editing — the caret, the selection handles, the keyboard, autocorrect and
--- every input method — and that is a node inside the field rather than the field itself. The box around
--- it, the label and the helper line are drawn by the engine under every control theme, and this is the
--- plainest of them.
platform.field = {
    metrics = {
        height = 44, radius = "md", border = 0, focusBorder = 0, paddingHorizontal = 8,
        labelSize = "footnote", helperSize = "footnote", gap = 4, label = "above",
    },
    paint = {
        container = { rest = "surface", disabled = "disabledSurface" },
        label = { rest = "textMuted", invalid = "danger", disabled = "disabledText" },
        text = { rest = "text", disabled = "disabledText" },
        helper = { rest = "textMuted", invalid = "danger", disabled = "disabledText" },
        indicator = { rest = "surface", focused = "primary", invalid = "danger", disabled = "disabledOutline" },
    },
    motion = { duration = 120 },
    press = "none",
}

return theme.define({ name = "native", controls = platform })
