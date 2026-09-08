local gui = require("gui")
local parts = require("parts")

local EASINGS = { "linear", "easeIn", "easeOut", "easeInOut", "spring" }

--- One square that arrives and leaves the way the transition it is labelled with says.
local Move = gui.component({
    name = "MoveDemo",
    state = { shown = false },

    render = function(self)
        return gui.View {
            style = { direction = "row", align = "center", gap = "md", minHeight = 56 },

            gui.View {
                style = { width = 96 },
                gui.Text { text = self.props.name, style = { fontSize = "footnote", color = "textMuted" } },
            },

            gui.View {
                style = { width = 64, height = 44, justify = "center", align = "center" },
                gui.Presence {
                    visible = self.state.shown,
                    transition = self.props.name,
                    duration = self.props.duration,
                    easing = self.props.easing,
                    gui.View {
                        style = { position = "absolute", left = 8, top = 4, width = 48, height = 36,
                            radius = "sm", background = "primary" },
                    },
                },
            },

            gui.Button {
                title = self.state.shown and "Hide" or "Show",
                variant = "tinted",
                size = "small",
                onPress = function() self:setState({ shown = not self.state.shown }) end,
            },
        }
    end,
})

local Transitions = gui.component({
    name = "TransitionsDemo",

    render = function()
        local rows = {}

        for _, name in ipairs(gui.animation.names()) do
            rows[#rows + 1] = Move { key = name, name = name }
        end

        return parts.Page {
            parts.Block {
                title = "Every transition",
                summary = "How something arrives on screen and how it leaves it",
                table.unpack(rows),
            },
        }
    end,
})

--- The same move drawn with each curve, so the difference between them is something a reader can see.
local Easings = gui.component({
    name = "EasingsDemo",
    state = { shown = false },

    render = function(self)
        local rows = {}

        for _, name in ipairs(EASINGS) do
            rows[#rows + 1] = gui.View {
                key = name,
                style = { direction = "row", align = "center", gap = "md", minHeight = 48 },

                gui.View { style = { width = 96 },
                    gui.Text { text = name, style = { fontSize = "footnote", color = "textMuted" } },
                },

                gui.View {
                    style = { grow = 1, height = 36, justify = "center" },
                    gui.View {
                        style = { width = 36, height = 36, radius = "pill", background = "primary",
                            transform = { translateX = self.state.shown and 160 or 0 } },
                        transition = { duration = 600, easing = name },
                    },
                },
            }
        end

        rows[#rows + 1] = gui.Button {
            key = "run",
            title = self.state.shown and "Back" or "Run",
            onPress = function() self:setState({ shown = not self.state.shown }) end,
        }

        return parts.Page {
            parts.Block {
                title = "Every easing",
                summary = "The same distance, covered by each curve",
                table.unpack(rows),
            },
        }
    end,
})

return {
    { key = "transitions", title = "Transitions", summary = "How a thing arrives and leaves",
        render = function() return Transitions {} end },
    { key = "easings", title = "Easings", summary = "The curves a change is drawn with",
        render = function() return Easings {} end },
}
