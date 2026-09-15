local component = require("gui.component")
local element = require("gui.element")
local parts = require("gui.controls.parts")
local support = require("gui.components.support")
local theme = require("gui.controls.theme")

local M = {}

--- Builds the component a control is, which is the one the control theme names or the one it was declared
--- with, or the platform's own node where the theme says the platform draws it.
---
--- The control theme is read here and nowhere else, and the drawing is handed the theme it draws with.
--- Read in both, both owe a render when the theme changes, and the drawing is then rendered against a
--- theme that no longer draws it at all.
local function chooses(control, platform, drawing)
    local host = platform ~= nil and element.define(platform) or nil

    return component.define({
        name = "Control:" .. control,

        render = function(self)
            local wearing = parts.themeOf(self)

            if wearing:isPlatform(control) then
                if host == nil then
                    error("the " .. wearing.name .. " controls hand a " .. control
                        .. " to the platform, and no platform draws one", 0)
                end

                return host(self.props)
            end

            local given = { theme = wearing }

            for key, value in pairs(self.props) do
                given[key] = value
            end

            for index = 1, #self.children do
                given[index] = self.children[index]
            end

            return (wearing:drawing(control) or drawing)(given)
        end,
    })
end

--- Declares a control, which is a component the control theme decides the drawing of.
---
--- A control somebody writes is a control in every sense: it registers its kind, so a control theme may
--- carry an entry for it and replace how it is drawn, its props are checked and it is in the reference,
--- and a control theme that hands it to the platform reaches the node named by `platform`.
---
--- `parts` names what it is painted in, `drawn` is how it is drawn where a control theme says nothing
--- about it, and `platform` names the host node a theme that hands it to the platform reaches.
---
--- A control brings its own default because a kind registered later would otherwise leave every control
--- theme already written incomplete, including the four the library ships. Adding a control breaks
--- nothing and shaping it stays a theme's to do.
function M.control(name, declaration, drawing)
    if type(drawing) ~= "function" then
        error("a control is drawn by a component, which is what gui.component() answers", 2)
    end

    local kind = declaration.control or name:lower()

    theme.kind(kind, { parts = declaration.parts, default = declaration.drawn })

    local held = {}

    for key, value in pairs(declaration) do
        if key ~= "parts" and key ~= "control" and key ~= "drawn" then
            held[key] = value
        end
    end

    return support.component(name, held, chooses(kind, declaration.platform, drawing))
end

M.chooses = chooses

return M
