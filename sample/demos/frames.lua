local gui = require("gui")
local parts = require("parts")

--- How many points one pixel of a border is drawn at.
---
--- One, and the same one for every picture on the screen. The artwork is authored at the weight it reads
--- at, so a panel and the buttons on it are the same material at the same weight — a button drawn at
--- twice the weight of the panel around it has a chamfer whose staircase is twice the size of every step
--- beside it, and the two read as different things badly matched.
local SCALE = 1

--- Where the bar across the titled window sits, read off the picture itself.
---
--- The bar runs from row eleven to row forty-two and the top is cut at forty-six, so the title is put
--- inside the bar and the content below the cut. Both are multiplied by the scale the border is drawn
--- at, since that is what one row of the picture comes out as.
local BAR = { into = 14 * SCALE, under = 50 * SCALE }

--- The artwork this screen is built out of, and where each picture is cut.
---
--- A cut is written in the pixels of the picture itself, so these four numbers and the file they point at
--- belong together. The window is cut deeper along its top than its other three edges, since the bar
--- across it is part of the corner pieces and must not be stretched down the way the sides are.
local PLATE = { top = 30, right = 26, bottom = 30, left = 26 }

local ART = {
    window = { source = "window.png", slice = 28 },
    titled = { source = "window-titled.png", slice = { top = 46, right = 28, bottom = 28, left = 28 } },
    stone = { source = "button-stone.png", slice = PLATE },
    green = {
        source = "button-green.png",
        slice = PLATE,

        -- A frame carries artwork per state, and a state with none of its own is drawn with the plain
        -- picture: the stone button below names neither and presses with the same face throughout.
        sources = { pressed = "button-pressed.png", disabled = "button-off.png" },
    },
}

--- A button drawn from artwork, which goes down when it is held and comes back when it is let go.
---
--- Which picture each state is drawn with is the frame's rather than the screen's, so nothing here holds
--- a state field to swap one. What is left of the press is the nudge downwards, which is a transform.
local Plate = gui.component({
    name = "FramePlate",
    state = { held = false },

    render = function(self)
        local art = self.props.tone == "green" and ART.green or ART.stone
        local ink = "#2a2230"

        return gui.NineSlice {
            source = art.source,
            sources = art.sources,
            slice = art.slice,
            sliceScale = SCALE,
            disabled = self.props.disabled,
            style = {
                paddingHorizontal = 30 * SCALE,
                paddingVertical = 16 * SCALE,
                justify = "center",
                align = "center",
                grow = self.props.grow and 1 or nil,
                shrink = 0,
                transform = { translateY = self.state.held and 2 or 0 },
            },
            transition = { duration = 90 },
            onPressIn = function() self:setState({ held = true }) end,
            onPressOut = function() self:setState({ held = false }) end,
            onPress = function() self.props.onPress() end,
            gui.Text {
                text = self.props.title,
                style = { fontSize = "headline", fontWeight = "700", color = ink },
            },
        }
    end,
})

--- A window drawn from artwork, with a bar across its top when it was given a title.
local Window = gui.component({
    name = "FrameWindow",

    render = function(self)
        local art = self.props.title ~= nil and ART.titled or ART.window
        local children = {}

        for index = 1, #self.children do
            children[index] = self.children[index]
        end

        -- The padding clears the border the frame draws, which is the cut times the scale it is drawn
        -- at. Anything less puts the content on top of the ornament, and how far it intrudes is then a
        -- property of the artwork rather than of the screen.
        local border = 28 * SCALE

        return gui.NineSlice {
            source = art.source,
            slice = art.slice,
            sliceScale = SCALE,
            style = {
                padding = border,
                paddingTop = self.props.title ~= nil and BAR.into or border,
                gap = "md",
            },

            self.props.title ~= nil and gui.Text {
                key = "title",
                text = self.props.title,
                style = {
                    fontSize = "headline", fontWeight = "700", color = "#e8c66a",
                    textAlign = "center", marginBottom = BAR.under - BAR.into - 23,
                },
            } or false,

            gui.View { key = "content", style = { gap = "md" }, table.unpack(children) },
        }
    end,
})

local Frames = gui.component({
    name = "Frames",
    state = { said = "Nothing has been pressed yet", name = "" },

    say = function(self, what)
        self:setState({ said = what })
    end,

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "A dialogue",
                summary = "One picture of ninety-six pixels, drawn at whatever width the screen is",

                Window {
                    gui.Text {
                        text = "New version of the application found.\nWould you like to update now?",
                        style = { fontSize = "body", color = "#d8d2ea", textAlign = "center" },
                    },
                    gui.View {
                        style = { direction = "row", gap = "md", justify = "center", marginTop = "sm" },
                        Plate {
                            title = "Later",
                            grow = true,
                            onPress = function() self:say("Left for later") end,
                        },
                        Plate {
                            title = "Update",
                            tone = "green",
                            grow = true,
                            onPress = function() self:say("The update was taken") end,
                        },
                    },
                },
            },

            parts.Block {
                title = "A titled window",
                summary = "Cut deeper along its top, so the bar is part of the corners and never stretches",

                Window {
                    title = "Language",
                    gui.View {
                        style = { direction = "row", wrap = true, gap = "sm", justify = "center" },
                        Plate { title = "English", onPress = function() self:say("English") end },
                        Plate { title = "Português", onPress = function() self:say("Português") end },
                        Plate { title = "Español", onPress = function() self:say("Español") end },
                    },
                },
            },

            parts.Block {
                title = "A panel holding a control",
                summary = "A frame is a box, so anything goes inside it",

                Window {
                    title = "Username",
                    gui.TextInput {
                        value = self.state.name,
                        placeholder = "Username",
                        onChange = function(value) self:setState({ name = value }) end,
                        style = {
                            background = "#1b1728", color = "#e8e4f4", radius = "sm",
                            padding = "sm", height = 48,
                        },
                    },
                    gui.Text {
                        text = "You can change your name at any time.",
                        style = { fontSize = "footnote", color = "#9b93b8", textAlign = "center" },
                    },
                    Plate {
                        title = "Ok",
                        tone = "green",
                        onPress = function()
                            self:say(self.state.name ~= "" and "Saved as " .. self.state.name or "Nothing was typed")
                        end,
                    },
                },
            },

            parts.Block {
                title = "Artwork per state",
                summary = "A frame draws one picture while a finger is on it and another when it is off",

                Window {
                    gui.View {
                        style = { direction = "row", gap = "md", justify = "center" },
                        Plate {
                            title = "Hold me",
                            tone = "green",
                            grow = true,
                            onPress = function() self:say("Held and let go") end,
                        },
                        Plate {
                            title = "Not now",
                            tone = "green",
                            disabled = true,
                            grow = true,
                            onPress = function() self:say("This cannot happen") end,
                        },
                    },
                },
            },

            parts.Block {
                title = "What was pressed",
                gui.Text { text = self.state.said },
            },
        }
    end,
})

return {
    {
        key = "nineslice",
        title = "Frames from artwork",
        summary = "A picture cut into nine, so one file draws a panel of any size",
        render = function() return Frames {} end,
    },
}
