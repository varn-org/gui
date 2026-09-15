local component = require("gui.component")
local theme = require("gui.controls.theme")
local theming = require("gui.theming")

--- Draws everything under it in another control theme, leaving the rest of the application in its own.
---
--- An application chooses one control theme and that is nearly always the whole of it. This is for the
--- screen that has to show two at once: a chooser that draws what each design looks like before a reader
--- picks one, and the gallery's own page of the four side by side.
---
--- The look is untouched, since a look and a control theme are two things: what is under this is drawn in
--- the same colours as everything around it and built out of different parts.
return component.define({
    name = "Controls",

    render = function(self)
        if not theme.isTheme(self.props.value) then
            error("Controls draws what is under it in a control theme, got a " .. type(self.props.value), 0)
        end

        local wearing = theming:read(self)
        local inside = { controls = self.props.value }

        for key, value in pairs(wearing) do
            if key ~= "controls" then
                inside[key] = value
            end
        end

        return theming.Provider { value = inside, style = self.props.style, table.unpack(self.children) }
    end,
})
