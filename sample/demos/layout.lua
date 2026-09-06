local gui = require("gui")
local parts = require("parts")

local Flow = gui.component({
    name = "FlowDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "A row that shares its space",
                gui.View { style = { direction = "row", gap = "sm", height = 56 },
                    parts.Swatch("grow 1", { grow = 1 }),
                    parts.Swatch("grow 2", { grow = 2, background = "success" }),
                },
            },

            parts.Block {
                title = "A column",
                gui.View { style = { gap = "sm" },
                    parts.Swatch("first", { height = 44 }),
                    parts.Swatch("second", { height = 44, background = "success" }),
                },
            },

            parts.Block {
                title = "Spread apart",
                gui.View { style = { direction = "row", justify = "space-between", align = "center" },
                    gui.Text { text = "Left" },
                    gui.Text { text = "Middle" },
                    gui.Text { text = "Right" },
                },
            },

            parts.Block {
                title = "Wrapping onto a second line",
                gui.View { style = { direction = "row", wrap = true, gap = "sm" },
                    parts.Swatch("one", { width = 96, height = 48 }),
                    parts.Swatch("two", { width = 96, height = 48 }),
                    parts.Swatch("three", { width = 96, height = 48 }),
                    parts.Swatch("four", { width = 96, height = 48 }),
                },
            },
        }
    end,
})

local Placing = gui.component({
    name = "PlacingDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "Pinned to an edge",
                gui.View { style = { height = 140, background = "surface", radius = "md" },
                    gui.View {
                        style = { position = "absolute", right = 12, bottom = 12, width = 72, height = 32,
                            background = "danger", radius = "pill", justify = "center", align = "center" },
                        gui.Text { text = "here", style = { color = "onPrimary", fontWeight = "600" } },
                    },
                },
            },

            parts.Block {
                title = "Stretched between both edges",
                gui.View { style = { height = 100, background = "surface", radius = "md" },
                    gui.View {
                        style = { position = "absolute", left = 12, right = 12, top = 12, height = 36,
                            background = "primary", radius = "sm" },
                    },
                },
            },

            parts.Block {
                title = "A spacer and a divider",
                gui.View { style = { direction = "row", align = "center" },
                    gui.Text { text = "Before" },
                    gui.Spacer { style = { grow = 1 } },
                    gui.Text { text = "After" },
                },
                gui.Divider {},
                gui.Text { text = "Below the rule", style = { color = "textMuted" } },
            },
        }
    end,
})

local Avoiding = gui.component({
    name = "AvoidingDemo",
    state = { note = "" },

    render = function(self)
        return gui.KeyboardAvoiding {
            style = { grow = 1 },
            gui.View { style = { grow = 1, padding = "md", gap = "md", justify = "end" },
                gui.Text {
                    text = "The field below stays clear of the keyboard, and this screen sits inside the safe area, both without asking what platform it is on.",
                },
                gui.TextInput {
                    value = self.state.note,
                    placeholder = "Type here",
                    onChange = function(value) self:setState({ note = value }) end,
                },
            },
        }
    end,
})

local Scrolling = gui.component({
    name = "ScrollingDemo",

    render = function()
        local blocks = {}

        for index = 1, 12 do
            blocks[index] = parts.Swatch("block " .. index, {
                height = 72,
                background = index % 2 == 0 and "primary" or "success",
            })
        end

        return gui.View { style = { grow = 1, gap = "md", padding = "md" },
            gui.Text { text = "Along the horizontal", style = { fontWeight = "600" } },
            gui.ScrollView {
                horizontal = true,
                style = { height = 96 },
                contentStyle = { direction = "row", gap = "sm" },
                parts.Swatch("one", { width = 140 }),
                parts.Swatch("two", { width = 140, background = "success" }),
                parts.Swatch("three", { width = 140 }),
                parts.Swatch("four", { width = 140, background = "success" }),
            },

            gui.Text { text = "And the vertical", style = { fontWeight = "600" } },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "sm" },
                table.unpack(blocks),
            },
        }
    end,
})

return {
    { key = "flow", title = "Rows, columns and wrapping", summary = "How space is shared along an axis", render = function() return Flow {} end },
    { key = "placing", title = "Placing and spacing", summary = "Absolute edges, a spacer, a divider", render = function() return Placing {} end },
    { key = "avoiding", title = "Safe area and keyboard", summary = "Both are layout, not a platform check", render = function() return Avoiding {} end },
    { key = "scrolling", title = "Scrolling", summary = "Along either axis", render = function() return Scrolling {} end },
}
