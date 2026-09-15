local gui = require("gui")
local parts = require("parts")

--- The looks this gallery offers, each one a design rather than a set of colours.
---
--- A look carries an appearance on each side of it, so the application still follows the device: what is
--- chosen here is the design, and light or dark stays the reader's own.
local LOOKS = {
    {
        key = "varn",
        title = "Varn",
        summary = "What the framework carries",
        look = gui.theme.builtin,
    },
    {
        key = "nuxt",
        title = "Nuxt",
        summary = "That green, on near black",
        look = gui.theme.looks.nuxt,
    },
    {
        key = "bootstrap",
        title = "Bootstrap",
        summary = "The blue, the greys and the corners",
        look = gui.theme.looks.bootstrap,
    },
    {
        key = "blossom",
        title = "Blossom",
        summary = "Pinks, round corners, generous spacing",
        look = gui.theme.looks.blossom,
    },
    {
        key = "ocean",
        title = "Ocean",
        summary = "One written here rather than shipped",
        look = gui.theme.define({
            name = "ocean",
            spacing = { md = 20, lg = 28 },
            radii = { sm = 8, md = 14, lg = 22 },
            light = {
                colors = {
                    primary = "#00668b", onPrimary = "#ffffff", background = "#f2fbff",
                    surface = "#dff2fb", elevated = "#ffffff", text = "#001e2b", textMuted = "#40606f",
                    border = "#a6cddd", separator = "#001e2b1f",
                },
            },
            dark = {
                colors = {
                    primary = "#7fd0ff", onPrimary = "#003549", background = "#04121a",
                    surface = "#0e2029", elevated = "#16303c", text = "#c5e7f7", textMuted = "#8fb2c1",
                    border = "#2b4550", separator = "#c5e7f71f",
                },
            },
        }),
    },
}

--- Answers the look carrying a name, which is what a chooser presses.
local function looked(key)
    for index = 1, #LOOKS do
        if LOOKS[index].key == key then
            return LOOKS[index]
        end
    end

    return LOOKS[1]
end

local Looks = gui.component({
    name = "ThemesDemo",

    --- The row a reader chooses a look from, which is drawn in the look it stands for.
    Choice = function(self, entry, wearing)
        local chosen = wearing.name == entry.look.name
        local colors = entry.look.light.colors

        return gui.Pressable {
            key = entry.key,
            accessibilityLabel = entry.title,
            style = {
                direction = "row", align = "center", gap = "md", padding = "md",
                radius = "md", background = chosen and "surface" or "background",
                border = 1, borderColor = chosen and "primary" or "border",
            },
            onPress = function() wearing.use(entry.look) end,

            gui.View {
                style = {
                    width = 40, height = 40, radius = "pill",
                    background = colors.primary, align = "center", justify = "center",
                },
                gui.Text { text = entry.title:sub(1, 1), style = { color = colors.onPrimary, fontWeight = "700" } },
            },

            gui.View { style = { grow = 1, shrink = 1 },
                gui.Text { text = entry.title, style = { fontWeight = "600" } },
                gui.Text { text = entry.summary, style = { fontSize = "caption", color = "textMuted" } },
            },

            chosen and gui.Icon { name = "check", size = 20, color = "primary" } or false,
        }
    end,

    render = function(self)
        local wearing = gui.theming:read(self)
        local surface = gui.environment:read(self)
        local rows = {}

        for index = 1, #LOOKS do
            rows[#rows + 1] = self:Choice(LOOKS[index], wearing)
        end

        return parts.Page {
            parts.Block {
                title = "The look",
                summary = "One design, chosen once, and every screen of the application is drawn in it",
                gui.View { style = { gap = "sm" }, table.unpack(rows) },
            },

            parts.Block {
                title = "And the side of it",
                summary = "A look carries light and dark, so choosing one never stops the application"
                    .. " following the device",
                gui.Text {
                    text = "This device is set to " .. surface.appearance .. ", and the "
                        .. looked(wearing.name).title .. " look is drawn in its " .. surface.appearance .. " side.",
                    style = { color = "textMuted" },
                },
            },

            parts.Block {
                title = "What it reaches",
                summary = "Colours, spacing, corners, the face and what the platform paints around the tree",
                gui.View { style = { direction = "row", gap = "sm", wrap = true },
                    gui.Button { title = "A button" },
                    gui.Button { title = "Tinted", variant = "tinted" },
                    gui.Button { title = "Outlined", variant = "outlined" },
                },
                gui.View { style = { direction = "row", gap = "sm", align = "center" },
                    gui.Chip { label = "A chip", selected = true },
                    gui.Switch { value = true },
                    gui.ProgressBar { value = 0.6, style = { grow = 1 } },
                },
                gui.View { style = { padding = "md", radius = "md", background = "surface" },
                    gui.Text { text = "A surface, at the corner and the spacing this look carries." },
                },
            },

            parts.Block {
                title = "One branch in a look of its own",
                summary = "An application wears one look, and a screen holding something with colours of"
                    .. " its own puts that branch in another",
                gui.View { style = { direction = "row", gap = "sm" }, table.unpack(self:Beside()) },
            },
        }
    end,

    --- Three of the looks drawn at once, each in its own, beside whatever the application is wearing.
    ---
    --- A chooser that shows a design by naming it is asking a reader to imagine it. Everything under a
    --- `Look` is resolved against the one it names, so a reader sees three of them at the same time and
    --- the page around them stays in the application's own.
    Beside = function(self)
        local shown = {}

        for index = 2, 4 do
            local entry = LOOKS[index]

            shown[#shown + 1] = gui.Look {
                key = entry.key,
                value = entry.look,
                style = { grow = 1, basis = 0 },

                gui.View {
                    style = { gap = "xs", padding = "sm", radius = "md", background = "surface",
                        border = 1, borderColor = "border" },

                    gui.Text {
                        text = entry.title,
                        numberOfLines = 1,
                        style = { fontWeight = "700", fontSize = "footnote", color = "text" },
                    },
                    gui.View { style = { height = 8, radius = "pill", background = "primary" } },
                    gui.View { style = { height = 8, radius = "pill", background = "border" } },
                },
            }
        end

        return shown
    end,
})

return {
    {
        key = "looks",
        title = "Looks",
        summary = "Choosing the design the whole application is drawn in",
        render = function() return Looks {} end,
    },
}
