local animation = require("gui.style.animation")
local component = require("gui.component")
local structure = require("gui.components.structure")
local support = require("gui.components.support")


local M = {}

local View = structure.View

--- Keeps what it holds on screen while it is arriving and while it is leaving.
---
--- A node removed from the tree is gone the moment the commit lands, so an overlay dismissed by a
--- handler would vanish rather than animate away. This holds its children for as long as the exit
--- takes, hands the renderer the state to animate towards, and only then lets them go.
M.Presence = support.component("Presence", {
    props = { "visible", "transition", "duration", "easing", "delay" },
    defaults = { visible = false, transition = "fade" },
}, component.define({
    name = "Presence",
    state = { shown = false, leaving = false },

    onMount = function(self)
        if self.props.visible then
            self:setState({ shown = true })
        end
    end,

    onUnmount = function(self)
        self.dropped = true
    end,

    --- Answers how the move is timed, which is what both the arrival and the exit are drawn with.
    timing = function(self)
        return animation.transition({
            duration = self.props.duration,
            easing = self.props.easing,
            delay = self.props.delay,
        })
    end,

    onUpdate = function(self)
        if self.props.visible and not self.state.shown then
            self:setState({ shown = true, leaving = false })
            return
        end

        if not self.props.visible and self.state.shown and not self.state.leaving then
            self:setState({ leaving = true })
            self:release()
        end
    end,

    --- Lets the children go once the exit has had the time it was given.
    release = function(self)
        local timing = self:timing()

        self:after(timing.duration + timing.delay, function()
            if self.dropped or self.props.visible then
                return
            end

            self:setState({ shown = false, leaving = false })
        end)
    end,

    render = function(self)
        if not self.state.shown then
            return View { key = "absent", style = { width = 0, height = 0 } }
        end

        local states = animation.states(self.props.transition)
        local moving = self.state.leaving and states.exit or nil

        -- The node this holds is the one that moves, so a caller that gives it the panel's own box gets
        -- the panel animated rather than a screen-sized sheet of glass with the panel somewhere inside
        -- it. That is what lets a panel say it leaves by travelling the whole of its own height.
        return View {
            key = "present",
            style = { self.props.style or support.cover(), moving },
            transition = self:timing(),
            enter = states.enter,
            table.unpack(self.children),
        }
    end,
}))

return M
