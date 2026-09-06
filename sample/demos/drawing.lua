local gui = require("gui")
local parts = require("parts")

--- Answers the commands that draw a chart, which is what a canvas is given rather than a picture.
local function chart(values, width, height)
    local commands = {}
    local step = width / #values

    for index = 1, #values do
        local bar = values[index] * height
        local left = (index - 1) * step + 4

        commands[#commands + 1] = {
            op = "fill",
            color = "#3b6cff",
            path = {
                { left, height - bar },
                { left + step - 8, height - bar },
                { left + step - 8, height },
                { left, height },
            },
        }
    end

    return commands
end

local Drawing = gui.component({
    name = "CanvasDemo",
    state = { values = { 0.2, 0.5, 0.35, 0.8, 0.6, 0.95, 0.4 } },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Shapes",
                gui.Canvas {
                    style = { height = 160, background = "surface", radius = "md" },
                    commands = {
                        { op = "fill", color = "#3b82f6", path = { { 16, 16 }, { 96, 16 }, { 96, 96 }, { 16, 96 } } },
                        { op = "stroke", color = "#16a34a", width = 4, path = { { 120, 96 }, { 160, 24 }, { 200, 96 } } },
                        { op = "text", text = "drawn in Lua", x = 220, y = 60, color = "#111114", size = 16 },
                    },
                },
            },

            parts.Block {
                title = "A chart from data",
                gui.Canvas {
                    style = { height = 160, background = "surface", radius = "md" },
                    commands = chart(self.state.values, 320, 140),
                },
                gui.Button {
                    title = "Shuffle",
                    variant = "tinted",
                    onPress = function()
                        local next = {}
                        for index = 1, 7 do next[index] = math.random() end
                        self:setState({ values = next })
                    end,
                },
            },
        }
    end,
})

return {
    { key = "canvas", title = "Canvas", summary = "Paths, strokes, text and a chart", render = function() return Drawing {} end },
}
