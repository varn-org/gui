local gui = require("gui")
local icons = require("gui.style.icons")
local parts = require("parts")

local Words = gui.component({
    name = "TextDemo",
    state = { pressed = 0 },

    render = function(self)
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
                            onPress = function() self:setState({ pressed = self.state.pressed + 1 }) end },
                        { text = " inside it." },
                    },
                },

                gui.Text {
                    text = "The span was pressed " .. self.state.pressed .. " times",
                    style = { fontSize = "caption", color = "textMuted" },
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
    state = { playing = false, position = 0, duration = 0, dragging = nil, said = nil },

    --- Answers a moment as minutes and seconds, which is how a player says where it is.
    clock = function(_, seconds)
        local whole = math.max(0, math.floor(seconds))

        return string.format("%d:%02d", whole // 60, whole % 60)
    end,

    --- Moves the sound to where the scrubber was let go, and follows it again from there.
    seek = function(self, share)
        local seconds = share * self.state.duration

        self:ref("sound"):call("seek", { seconds = seconds })
        self:setState({ position = seconds, dragging = gui.none })
    end,

    render = function(self)
        local at = self.state.dragging or self.state.position

        return gui.View { style = { gap = "sm" },
            gui.Audio {
                ref = self:ref("sound"),
                source = "https://varn-storage.s3.us-east-1.amazonaws.com/stuff/audio-loop-africa.mp3",
                playing = self.state.playing,
                onReady = function(about) self:setState({ duration = about.duration }) end,
                onProgress = function(about)
                    -- What the sound says about itself is ignored while a finger is on the scrubber,
                    -- or the bar jumps back to where the sound still is between two reports.
                    if self.state.dragging == nil then
                        self:setState({ position = about.position, duration = about.duration })
                    end
                end,
                onEnd = function() self:setState({ playing = false, position = 0 }) end,
                onError = function(problem)
                    self:setState({ playing = false, said = problem.message or "the sound would not play" })
                end,
            },

            self.state.said ~= nil and gui.Text {
                text = self.state.said,
                style = { fontSize = "caption", color = "danger" },
            } or false,

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
                    self:setState({ dragging = share * self.state.duration })
                end,
                onCommit = function(share) self:seek(share) end,
            },
        }
    end,
})

local MODES = { "cover", "contain", "stretch", "center" }

--- The looks a picture is given, in the order a reader reads them in.
local LOOKS = { "mono", "noir", "sepia", "vivid", "fade", "cool", "warm", "negative" }

local Pictures = gui.component({
    name = "ImagesDemo",
    state = { look = "mono" },

    --- One picture under each look, which is what choosing between them is done by looking at.
    Looks = function(self)
        local row = {}

        for _, name in ipairs(LOOKS) do
            row[#row + 1] = gui.Pressable {
                key = name,
                accessibilityLabel = name,
                style = { width = 76, gap = "xs" },
                onPress = function() self:setState({ look = name }) end,
                gui.Image {
                    source = "scene.png",
                    resizeMode = "cover",
                    filter = gui.filter.looks[name],
                    style = {
                        height = 64,
                        radius = "sm",
                        background = "surface",
                        border = self.state.look == name and 2 or 0,
                        borderColor = "primary",
                    },
                },
                gui.Text {
                    text = name,
                    style = {
                        fontSize = "caption",
                        textAlign = "center",
                        color = self.state.look == name and "primary" or "textMuted",
                    },
                },
            }
        end

        return row
    end,

    --- Every icon in the set, drawn at the size a row of them reads at.
    ---
    --- A name nobody draws is a shape nobody has ever seen, so the demo takes the whole set rather than
    --- a chosen few: an icon that draws nothing fails here rather than in somebody's application.
    Icons = function(self)
        local drawn = {}
        local names = icons.names()

        for index = 1, #names do
            drawn[index] = gui.View {
                key = names[index],
                style = { width = 64, align = "center", gap = "xs" },
                gui.Icon { name = names[index], size = 24, color = "text" },
                gui.Text {
                    text = names[index],
                    numberOfLines = 1,
                    style = { fontSize = "caption", color = "textMuted" },
                },
            }
        end

        return drawn
    end,

    render = function(self)
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
                title = "A look over a picture",
                summary = "Amounts of grey, sepia, hue and saturation, worked out once and drawn by all three",
                gui.Image {
                    source = "scene.png",
                    resizeMode = "cover",
                    filter = gui.filter.looks[self.state.look],
                    style = { height = 160, radius = "md", background = "surface" },
                },
                gui.ScrollView {
                    horizontal = true,
                    showsIndicator = false,
                    style = { height = 96 },
                    contentStyle = { direction = "row", gap = "sm" },
                    table.unpack(self:Looks()),
                },
            },

            parts.Block {
                title = "Resize modes",
                summary = "One wide picture in four square frames, so each way of filling one shows",
                gui.View { style = { direction = "row", gap = "sm" }, table.unpack(modes) },
            },

            parts.Block {
                title = "Avatars",
                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.Avatar { initials = "PC", size = 44 },
                    gui.Avatar { initials = "AL", size = 44, shape = "rounded" },
                    gui.Avatar { source = "https://picsum.photos/id/1027/200/200", size = 44 },
                },
            },

            parts.Block {
                title = "Every icon the engine draws",
                summary = "One set of shapes, drawn from the same runs of points on every platform",
                gui.View { style = { direction = "row", wrap = true, gap = "md" }, table.unpack(self:Icons()) },
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
