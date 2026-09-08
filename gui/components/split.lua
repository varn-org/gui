local animation = require("gui.style.animation")
local component = require("gui.component")
local environment = require("gui.environment")
local structure = require("gui.components.structure")
local support = require("gui.components.support")
local visibility = require("gui.visibility")

local M = {}

local View = structure.View
local Divider = structure.Divider

--- Where a pane sits when there is no room for it, which is exactly where it was and out of sight.
local HELD = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0, opacity = 0 }

--- A list beside what it opens, or one at a time when there is not room for both.
---
--- A tablet, a phone turned sideways, a window sharing a screen with another and a folding phone that
--- has just been opened are all one thing: a width that changed. This reads the room it has rather than
--- what device it is on, so none of those is a case anybody writes code for.
M.SplitView = support.component("SplitView", {
    props = { "sidebar", "content", "sidebarWidth", "showing", "collapseAt" },
    events = { "onShowingChange" },
    defaults = { sidebarWidth = 320, collapseAt = "medium" },
    validate = function(spec)
        if spec.sidebar == nil then
            return "needs a sidebar to put beside what it opens"
        end

        local choices = { "medium", "expanded" }
        if not support.oneOf(spec.collapseAt, choices) then
            return support.expected("collapseAt", spec.collapseAt, choices)
        end
    end,
}, component.define({
    name = "SplitView",

    --- Answers whether there is room for both at once, which is the only question this component asks.
    together = function(self)
        local breakpoint = environment:read(self).breakpoint

        if self.props.collapseAt == "expanded" then
            return breakpoint == "expanded"
        end

        return breakpoint ~= "compact"
    end,

    onMount = function(self)
        self.both = self:together()
    end,

    --- Says when the room changed, so a caller knows whether what it opened is a screen or a panel.
    ---
    --- A phone turned sideways and a window given half a desktop are the same event, and a caller that
    --- keeps its own idea of what is open has no other way to hear about it.
    onUpdate = function(self)
        local both = self:together()

        if both == self.both then
            return
        end

        self.both = both

        if type(self.props.onShowingChange) == "function" then
            self.props.onShowingChange(both)
        end
    end,

    --- Both panes, in one shape, whichever of them there is room for.
    ---
    --- Rendering one tree with room for both and another with room for one is two different trees, and a
    --- turn of the phone crosses between them: every component under it is taken down and built again, so
    --- a reader loses what they had typed for having held the device sideways. The panes keep their place
    --- and their keys here and only how they are laid out changes, so the instances live through it.
    render = function(self)
        local sidebar = self.props.sidebar
        local content = self.props.content
        local together = self:together()
        local showing = content ~= nil and self.props.showing ~= false

        return View {
            style = { { grow = 1, direction = "row" }, self.props.style },

            View {
                key = "sidebar",
                style = together and { width = self.props.sidebarWidth }
                    or (showing and HELD or { grow = 1 }),
                pointerEvents = (together or not showing) and "auto" or "none",
                visibility.Showing { value = together or not showing, sidebar },
            },

            together and Divider { key = "rule", orientation = "vertical" } or false,

            View {
                key = "content",
                style = together and { grow = 1 } or (showing and { grow = 1 } or HELD),
                pointerEvents = (together or showing) and "auto" or "none",
                transition = { duration = "fast" },
                enter = animation.states("slideLeft").enter,
                visibility.Showing { value = together or showing, content or false },
            },
        }
    end,
}))

return M
