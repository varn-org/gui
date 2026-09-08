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

--- A player drawn by the tree over a sound the platform carries.
---
--- Nothing about a play button, a scrubber or a time is the platform's to decide, so the component
--- carries the sound and says where it has got to, and everything a reader sees is here.
local Player = gui.component({
    name = "AudioPlayer",
    state = { playing = false, position = 0, duration = 0, seeking = nil },

    --- Answers a moment as minutes and seconds, which is how a player says where it is.
    clock = function(_, seconds)
        local whole = math.max(0, math.floor(seconds))

        return string.format("%d:%02d", whole // 60, whole % 60)
    end,

    render = function(self)
        local at = self.state.seeking or self.state.position

        return gui.View { style = { gap = "sm" },
            gui.Audio {
                source = "https://varn-storage.s3.us-east-1.amazonaws.com/stuff/audio-loop-africa.mp3",
                playing = self.state.playing,
                position = self.state.seeking,
                onReady = function(about) self:setState({ duration = about.duration }) end,
                onProgress = function(about)
                    if self.state.seeking == nil then
                        self:setState({ position = about.position, duration = about.duration })
                    end
                end,
                onEnd = function() self:setState({ playing = false, position = 0 }) end,
            },

            gui.View { style = { direction = "row", align = "center", gap = "md" },
                gui.Button {
                    title = self.state.playing and "Pause" or "Play",
                    variant = "tinted",
                    onPress = function() self:setState({ playing = not self.state.playing }) end,
                },

                gui.Text { text = self:clock(at), style = { fontSize = "footnote", color = "textMuted" } },
                gui.View { style = { grow = 1 } },
                gui.Text {
                    text = self:clock(self.state.duration),
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Slider {
                value = self.state.duration > 0 and at / self.state.duration or 0,
                onChange = function(share)
                    self:setState({ seeking = share * self.state.duration })
                end,
                onCommit = function(share)
                    self:setState({ position = share * self.state.duration, seeking = gui.none })
                end,
            },
        }
    end,
})

local MODES = { "cover", "contain", "stretch", "center" }

local Pictures = gui.component({
    name = "ImagesDemo",

    render = function()
        local modes = {}

        for _, mode in ipairs(MODES) do
            modes[#modes + 1] = gui.View {
                key = mode,
                style = { grow = 1, basis = 0, gap = "xs" },
                gui.Image {
                    source = "scene.png",
                    resizeMode = mode,
                    style = { height = 72, radius = "sm", background = "surface" },
                },
                gui.Text { text = mode, style = { fontSize = "caption", color = "textMuted", textAlign = "center" } },
            }
        end

        return parts.Page {
            parts.Block {
                title = "From the bundle",
                summary = "Named by the screen, found by the runtime at the density it is drawn at",
                gui.Image { source = "scene.png", style = { height = 120, radius = "md" }, resizeMode = "contain" },
            },

            parts.Block {
                title = "From somewhere else",
                summary = "Fetched once by the engine and handed to the renderer as a file it can open",
                gui.View { style = { direction = "row", gap = "sm" },
                    gui.Image {
                        source = "https://picsum.photos/id/1015/600/400",
                        placeholder = "logo.png",
                        resizeMode = "cover",
                        style = { grow = 1, basis = 0, height = 120, radius = "md", background = "surface" },
                    },
                    gui.Image {
                        source = "https://picsum.photos/id/1025/600/400",
                        placeholder = "logo.png",
                        resizeMode = "cover",
                        style = { grow = 1, basis = 0, height = 120, radius = "md", background = "surface" },
                    },
                },
            },

            parts.Block {
                title = "One that is not there",
                summary = "The placeholder stays rather than an empty box",
                gui.Image {
                    source = "https://picsum.photos/this/is/not/a/picture",
                    placeholder = "logo.png",
                    resizeMode = "contain",
                    style = { height = 90, radius = "md", background = "surface" },
                },
            },

            parts.Block {
                title = "Resize modes",
                summary = "One wide picture in four square frames, so each way of filling one shows",
                gui.View { style = { direction = "row", gap = "sm" }, table.unpack(modes) },
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
    state = { ended = false },

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Video",
                summary = "The platform's own player, with its controls and its poster",
                gui.Video {
                    source = "https://varn-storage.s3.us-east-1.amazonaws.com/stuff/big-buck-bunny-1080p-30sec.mp4",
                    poster = "logo.png",
                    controls = true,
                    muted = true,
                    loop = false,
                    resizeMode = "contain",
                    onEnd = function() self:setState({ ended = true }) end,
                    style = { height = 200, radius = "md", background = "surface" },
                },
                gui.Text {
                    text = self.state.ended and "It reached the end" or "Press play",
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            parts.Block {
                title = "Sound",
                summary = "The platform carries it and the tree draws the player",
                Player {},
            },

            parts.Block {
                title = "A page",
                summary = "Loaded by the platform's own web view",
                gui.WebView {
                    url = "https://paulox.dev",
                    style = { height = 420, radius = "md", background = "surface" },
                },
            },

            parts.Block {
                title = "Markup of its own",
                gui.WebView {
                    html = "<h2 style='font: 600 18px system-ui; padding: 12px'>Drawn by the platform</h2>",
                    style = { height = 120, radius = "md", background = "surface" },
                },
            },
        }
    end,
})

return {
    { key = "text", title = "Text", summary = "Sizes, weights, wrapping and spans", render = function() return Words {} end },
    { key = "images", title = "Images and icons", summary = "Bundled images, icons and avatars", render = function() return Pictures {} end },
    { key = "media", title = "Video, sound and web", summary = "A player the platform draws, and one the tree draws",
      render = function() return Media {} end },
}
