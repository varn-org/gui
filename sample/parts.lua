local gui = require("gui")

local M = {}

--- Answers a list holding only what was actually given.
---
--- A nil in the array part of a table cuts the list short at that point, so a conditional child is
--- appended rather than written in place.
function M.some(values)
    local kept = {}

    for index = 1, values.n or #values do
        if values[index] ~= nil and values[index] ~= false then
            kept[#kept + 1] = values[index]
        end
    end

    return kept
end

--- A titled block with room around it, which is what every demo is made of.
---
--- Each one stacks rather than crowding a row, so nothing is squeezed to the point of being cut off.
function M.Block(spec)
    local children = { }

    for index = 1, #spec do
        children[index] = spec[index]
    end

    return gui.View {
        key = spec.title,
        style = { gap = "sm" },
        gui.Text {
            text = spec.title,
            style = { fontSize = "caption", fontWeight = "700", color = "textMuted", textTransform = "uppercase" },
        },
        gui.View { style = { gap = "sm" }, table.unpack(children) },
    }
end

--- A label above its control, which is what a control that fills the width wants.
function M.Field(label, control)
    return gui.View {
        key = label,
        style = { gap = "xs" },
        gui.Text { text = label, style = { fontSize = "footnote", color = "textMuted" } },
        control,
    }
end

--- A label beside its control, which is what a control the size of itself wants.
---
--- A switch is 51 across however wide the screen is, so putting its label on a line of its own leaves a
--- band of empty space that reads as a mistake.
function M.Row(label, control)
    return gui.View {
        key = label,
        style = { direction = "row", align = "center", justify = "space-between", gap = "md", minHeight = 44 },
        gui.Text { text = label, numberOfLines = 1, style = { grow = 1, color = "text" } },
        control,
    }
end

--- A demo's own page: everything scrolls, with room at the edges and between the blocks.
function M.Page(children)
    return gui.ScrollView {
        style = { grow = 1 },
        contentStyle = { gap = "lg", padding = "md" },
        table.unpack(children),
    }
end

--- A box that shows what a piece of layout is doing, in a colour and with a label inside it.
function M.Swatch(text, style)
    local box = { justify = "center", align = "center", background = "primary", radius = "sm", padding = "sm" }

    for key, value in pairs(style or {}) do
        box[key] = value
    end

    return gui.View {
        style = box,
        gui.Text { text = text, style = { color = "onPrimary", fontWeight = "600" } },
    }
end

return M
