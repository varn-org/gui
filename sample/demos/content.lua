local gui = require("gui")
local parts = require("parts")

local Words = gui.component({
    name = "TextDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "Sizes and weights",
                gui.Text { text = "A title", style = { fontSize = "title", fontWeight = "700" } },
                gui.Text { text = "A heading", style = { fontSize = "heading", fontWeight = "600" } },
                gui.Text { text = "Body text, which is the size everything else is measured against." },
                gui.Text { text = "A caption", style = { fontSize = "caption", color = "textMuted" } },
            },

            parts.Block {
                title = "Weights",
                gui.Text { text = "Regular", style = { fontSize = "title" } },
                gui.Text { text = "Medium", style = { fontSize = "title", fontWeight = "500" } },
                gui.Text { text = "Semibold", style = { fontSize = "title", fontWeight = "600" } },
                gui.Text { text = "Bold", style = { fontSize = "title", fontWeight = "700" } },
            },

            parts.Block {
                title = "Wrapping and trimming",
                gui.Text {
                    text = "A long line that has more to say than there is room for, so it runs on to a second line rather than being cut short.",
                },
                gui.Text { text = "Held to one line, and trimmed when it does not fit at all", numberOfLines = 1 },
            },

            parts.Block {
                title = "Spans with their own styles",
                gui.RichText {
                    spans = {
                        { text = "A sentence with " },
                        { text = "a tappable span", style = { color = "primary", textDecoration = "underline" },
                            onPress = function() end },
                        { text = " inside it." },
                    },
                },
            },
        }
    end,
})

local Pictures = gui.component({
    name = "ImagesDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "An image from the bundle",
                gui.Image { source = "logo.png", style = { height = 120, radius = "md" }, resizeMode = "contain" },
            },

            parts.Block {
                title = "Resize modes",
                gui.View { style = { direction = "row", gap = "sm" },
                    gui.Image { source = "logo.png", resizeMode = "cover", style = { grow = 1, height = 80, radius = "sm" } },
                    gui.Image { source = "logo.png", resizeMode = "contain", style = { grow = 1, height = 80, radius = "sm" } },
                },
            },

            parts.Block {
                title = "Icons and avatars",
                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.Icon { name = "star", size = 28, color = "warning" },
                    gui.Icon { name = "heart", size = 28, color = "danger" },
                    gui.Avatar { initials = "PC", size = 44 },
                    gui.Avatar { initials = "AL", size = 44, shape = "rounded" },
                },
            },
        }
    end,
})

local Media = gui.component({
    name = "MediaDemo",

    render = function()
        return parts.Page {
            parts.Block {
                title = "Video",
                gui.Video {
                    source = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                    poster = "logo.png",
                    controls = true,
                    muted = true,
                    loop = true,
                    style = { height = 200, radius = "md", background = "surface" },
                },
            },

            parts.Block {
                title = "A web view",
                gui.WebView {
                    html = "<h2 style='font: 600 18px system-ui; padding: 12px'>Drawn by the platform</h2>",
                    style = { height = 160, radius = "md", background = "surface" },
                },
            },
        }
    end,
})

return {
    { key = "text", title = "Text", summary = "Sizes, weights, wrapping and spans", render = function() return Words {} end },
    { key = "images", title = "Images and icons", summary = "Bundled images, icons and avatars", render = function() return Pictures {} end },
    { key = "media", title = "Video and web", summary = "What the platform draws for itself", render = function() return Media {} end },
}
