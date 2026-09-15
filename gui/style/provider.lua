local component = require("gui.component")
local environment = require("gui.environment")
local theme = require("gui.style.theme")
local theming = require("gui.theming")

--- Answers the look a caller named, which is a look or one theme pinned to both sides of one.
local function lookOf(value)
    if theme.isLook(value) then
        return value
    end

    if type(value) == "table" and type(value.color) == "function" then
        return { name = "a theme", light = value, dark = value, of = function() return value end }
    end

    error("Look draws what is under it in a look, got a " .. type(value), 0)
end

--- Draws everything under it in another look, leaving the rest of the application in its own.
---
--- An application wears one look and that is nearly always the whole of it. This is for the screen that
--- holds something with colours of its own: a gallery showing five applications, a page serving two
--- brands, a customer's own palette inside a product that has its own.
---
--- The control theme is untouched, since a look and a control theme are two things: what is under this is
--- built out of the same parts as everything around it and coloured differently.
---
--- A look carries both sides of itself, so what is under this still follows the device between light and
--- dark. `use` still belongs to the application, so a chooser under a `Look` changes what the application
--- is drawn in and what is under the `Look` stays in the one it was given.
return component.define({
    name = "Look",

    render = function(self)
        local look = lookOf(self.props.value)
        local wearing = theming:read(self)
        local inside = {
            theme = look:of(environment:read(self).appearance),
            name = look.name,
        }

        for key, value in pairs(wearing) do
            if inside[key] == nil then
                inside[key] = value
            end
        end

        return theming.Provider { value = inside, style = self.props.style, table.unpack(self.children) }
    end,
})
