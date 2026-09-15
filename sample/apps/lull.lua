local gui = require("gui")

--- An audiobook application, where the covers do all of the work.
---
--- A shelf of covers is the whole interface: there is no row to read, only a picture to recognise, and
--- what a reader is actually doing is scanning for one they already know. So the shelves are wide, the
--- covers are large, and everything around them is dark enough to stay out of the way.
local LOOK = gui.theme.define({
    name = "lull",
    radii = { sm = 6, md = 10, lg = 16, pill = 999 },
    spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 32 },
    light = {
        colors = {
            primary = "#f2b544", onPrimary = "#221803", background = "#12131a", surface = "#1b1d26",
            elevated = "#23262f", text = "#f4f4f6", textMuted = "#9a9db0", border = "#2e3240",
            separator = "#ffffff12", success = "#57c785", warning = "#f2b544", danger = "#ef6b5f",
        },
    },
    dark = {
        colors = {
            primary = "#f2b544", onPrimary = "#221803", background = "#0c0d12", surface = "#15171e",
            elevated = "#1c1f27", text = "#f4f4f6", textMuted = "#8b8fa3", border = "#262a35",
            separator = "#ffffff12", success = "#57c785", warning = "#f2b544", danger = "#ef6b5f",
        },
    },
})

local BOOKS = {
    {
        key = "tide",
        title = "The Turning Tide",
        author = "Helena Vasques",
        narrator = "Read by Ana Sartori",
        cover = "book-tide.png",
        minutes = 742,
        rating = 4.7,
        through = 0.38,
        blurb = "A harbour town votes on whether to sell its own water, and two sisters end up on opposite sides of the question.",
        chapters = {
            { key = "1", name = "The vote", minutes = 41 },
            { key = "2", name = "What the tide left", minutes = 55 },
            { key = "3", name = "A letter from the council", minutes = 38 },
            { key = "4", name = "Low water", minutes = 62 },
            { key = "5", name = "The second meeting", minutes = 47 },
        },
    },
    {
        key = "ember",
        title = "Ember Road",
        author = "Tomás Aguiar",
        narrator = "Read by the author",
        cover = "book-ember.png",
        minutes = 519,
        rating = 4.4,
        through = 0.72,
        blurb = "Eight hundred kilometres of dirt road, one truck, and a driver who will not say where he is going.",
        chapters = {
            { key = "1", name = "Leaving at four", minutes = 33 },
            { key = "2", name = "The first town", minutes = 44 },
            { key = "3", name = "Rain on the flats", minutes = 51 },
            { key = "4", name = "What he was carrying", minutes = 40 },
        },
    },
    {
        key = "north",
        title = "Due North",
        author = "Isabel Krohn",
        narrator = "Read by Peter Hale",
        cover = "book-north.png",
        minutes = 963,
        rating = 4.9,
        through = 0,
        blurb = "The last expedition to map a range nobody had crossed, told from the notebooks that came back without it.",
        chapters = {
            { key = "1", name = "The commission", minutes = 58 },
            { key = "2", name = "Base camp", minutes = 66 },
            { key = "3", name = "The ridge", minutes = 72 },
        },
    },
    {
        key = "glass",
        title = "A House of Glass",
        author = "Renata Póvoa",
        narrator = "Read by Marina Dias",
        cover = "book-glass.png",
        minutes = 604,
        rating = 4.2,
        through = 0.14,
        blurb = "An architect builds the house she has described for thirty years, and discovers she cannot live in it.",
        chapters = {
            { key = "1", name = "The drawing", minutes = 36 },
            { key = "2", name = "Permission", minutes = 49 },
            { key = "3", name = "Moving in", minutes = 53 },
        },
    },
    {
        key = "signal",
        title = "Signal Lost",
        author = "Daniel Okafor",
        narrator = "Read by Grace Bell",
        cover = "book-signal.png",
        minutes = 448,
        rating = 4.6,
        through = 0,
        blurb = "A radio operator on a quiet island hears the same message every night for a year, and nobody else does.",
        chapters = {
            { key = "1", name = "Night one", minutes = 29 },
            { key = "2", name = "The recording", minutes = 43 },
            { key = "3", name = "Somebody else listens", minutes = 47 },
        },
    },
    {
        key = "harbour",
        title = "The Harbour Keeper",
        author = "Marta Nilsen",
        narrator = "Read by Eva Lund",
        cover = "book-harbour.png",
        minutes = 688,
        rating = 4.5,
        through = 0,
        blurb = "Forty years of keeping one light burning, written down the winter the harbour finally closed.",
        chapters = {
            { key = "1", name = "The first winter", minutes = 45 },
            { key = "2", name = "Ships that did not come", minutes = 52 },
            { key = "3", name = "The last boat", minutes = 58 },
        },
    },
}

local SPEEDS = { 0.75, 1, 1.25, 1.5, 2 }
local SLEEPS = { "Off", "15 min", "30 min", "End of chapter" }

local function find(key)
    for index = 1, #BOOKS do
        if BOOKS[index].key == key then
            return BOOKS[index]
        end
    end

    return nil
end

--- Answers a run of minutes the way a player writes one, which is hours and minutes rather than a count.
local function span(minutes)
    local whole = math.floor(minutes)

    if whole < 60 then
        return whole .. " min"
    end

    return math.floor(whole / 60) .. " h " .. (whole % 60) .. " min"
end

--- Answers a position in a book as a clock, which is what a scrubber is written under.
local function clock(minutes)
    local whole = math.floor(minutes)

    return string.format("%d:%02d:%02d", math.floor(whole / 60), whole % 60, 0)
end

--- Answers the books of one shelf, since a shelf is a question about the list rather than a list.
local function shelf(which)
    local kept = {}

    for index = 1, #BOOKS do
        local book = BOOKS[index]
        local wanted = which == "continue" and book.through > 0
            or which == "new" and book.through == 0
            or which == "top" and book.rating >= 4.5

        if wanted then
            kept[#kept + 1] = book
        end
    end

    return kept
end

local Lull = gui.component({
    name = "Lull",
    state = {
        screen = "home",
        looking = nil,
        playing = nil,
        at = 0,
        running = false,
        speed = 2,
        sleep = 1,
        search = "",
    },

    open = function(self, key)
        self:setState({ screen = "book", looking = key })
    end,

    play = function(self, key)
        local book = find(key)

        self:setState({
            screen = "player",
            playing = key,
            at = book.minutes * book.through,
            running = true,
        })
    end,

    current = function(self)
        return find(self.state.playing) or BOOKS[1]
    end,

    --- One cover with its title and author under it, which is the whole of a shelf.
    Cover = function(self, book, width)
        return gui.Pressable {
            key = book.key,
            style = { width = width, gap = 6 },
            accessibilityLabel = book.title,
            onPress = function() self:open(book.key) end,

            gui.View { style = { radius = "md", overflow = "hidden" },
                gui.Image {
                    source = book.cover,
                    resizeMode = "cover",
                    style = { width = width, height = width, background = "surface" },
                },

                book.through > 0 and gui.View {
                    key = "through",
                    style = { position = "absolute", left = 0, right = 0, bottom = 0, height = 4,
                        background = "#00000066" },
                    gui.View {
                        style = { width = string.format("%.0f%%", book.through * 100), height = 4,
                            background = "primary" },
                    },
                } or false,
            },

            gui.Text { text = book.title, numberOfLines = 1, style = { fontWeight = "600", fontSize = "footnote" } },
            gui.Text {
                text = book.author,
                numberOfLines = 1,
                style = { fontSize = "caption", color = "textMuted" },
            },
        }
    end,

    Shelf = function(self, title, which)
        local books = shelf(which)
        local covers = {}

        for index = 1, #books do
            covers[index] = self:Cover(books[index], 132)
        end

        if #covers == 0 then
            return false
        end

        return gui.View { key = which, style = { gap = "xs" },
            gui.Text {
                text = title,
                style = { fontSize = "headline", fontWeight = "700", paddingHorizontal = "md" },
            },

            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 194 },
                contentStyle = { direction = "row", gap = "sm", paddingHorizontal = "md" },
                table.unpack(covers),
            },
        }
    end,

    --- The strip at the bottom saying what is playing, which every one of these carries on every screen.
    Playing = function(self)
        if self.state.playing == nil then
            return false
        end

        local book = self:current()
        local insets = gui.environment:read(self).insets

        return gui.Pressable {
            key = "playing",
            style = { position = "absolute", left = 8, right = 8, bottom = insets.bottom + 8,
                direction = "row", align = "center", gap = "sm", height = 62, radius = "md",
                background = "elevated", paddingHorizontal = "sm", shadow = "lg" },
            accessibilityLabel = "Now playing, " .. book.title,
            onPress = function() self:setState({ screen = "player" }) end,

            gui.Image {
                source = book.cover,
                resizeMode = "cover",
                style = { width = 44, height = 44, radius = "sm", background = "surface" },
            },

            gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                gui.Text { text = book.title, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = clock(self.state.at) .. " of " .. clock(book.minutes),
                    style = { fontSize = "caption", color = "textMuted" },
                },
            },

            gui.Pressable {
                style = { width = 44, height = 44, align = "center", justify = "center" },
                accessibilityLabel = self.state.running and "Pause" or "Play",
                onPress = function() self:setState({ running = not self.state.running }) end,
                gui.Icon { name = self.state.running and "pause" or "play", size = 22, color = "primary" },
            },
        }
    end,

    Home = function(self)
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "background" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", paddingTop = insets.top + 8,
                    paddingBottom = insets.bottom + 96 },

                gui.View { style = { direction = "row", align = "center", gap = "sm",
                    paddingHorizontal = "md" },
                    gui.Text {
                        text = "Lull",
                        style = { grow = 1, fontSize = "title", fontWeight = "700" },
                    },
                    gui.Pressable {
                        style = { width = 44, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Search",
                        onPress = function() self:setState({ screen = "search" }) end,
                        gui.Icon { name = "search", size = 22, color = "text" },
                    },
                    gui.Pressable {
                        style = { width = 44, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Library",
                        onPress = function() self:setState({ screen = "library" }) end,
                        gui.Icon { name = "list", size = 22, color = "text" },
                    },
                },

                self:Shelf("Continue listening", "continue"),
                self:Shelf("New this month", "new"),
                self:Shelf("Highest rated", "top"),
            },

            self:Playing(),
        }
    end,

    --- One book, which is the cover, who reads it, how long it runs and what is in it.
    Book = function(self)
        local book = find(self.state.looking)
        local insets = gui.environment:read(self).insets
        local rows = {}

        for index = 1, #book.chapters do
            local chapter = book.chapters[index]

            rows[index] = gui.Pressable {
                key = chapter.key,
                style = { direction = "row", align = "center", gap = "sm", minHeight = 56,
                    paddingHorizontal = "md" },
                accessibilityLabel = chapter.name,
                onPress = function() self:play(book.key) end,

                gui.Text {
                    text = tostring(index),
                    style = { width = 24, color = "textMuted", textAlign = "center" },
                },
                gui.View { style = { grow = 1, shrink = 1 },
                    gui.Text { text = chapter.name, numberOfLines = 1 },
                },
                gui.Text {
                    text = chapter.minutes .. " min",
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            }
        end

        return gui.View { style = { grow = 1, background = "background" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", paddingBottom = insets.bottom + 96 },

                gui.View { style = { align = "center", gap = "sm", paddingTop = "md",
                    paddingHorizontal = "md" },

                    gui.Image {
                        source = book.cover,
                        resizeMode = "cover",
                        style = { width = 200, height = 200, radius = "md", background = "surface",
                            shadow = "lg" },
                    },

                    gui.Text {
                        text = book.title,
                        style = { fontSize = "title", fontWeight = "700", textAlign = "center" },
                    },
                    gui.Text { text = book.author, style = { color = "textMuted" } },
                    gui.Text {
                        text = book.narrator .. " • " .. span(book.minutes),
                        style = { fontSize = "footnote", color = "textMuted" },
                    },

                    gui.View { style = { direction = "row", align = "center", gap = 4 },
                        gui.Rating { value = book.rating, size = 15, color = "primary" },
                        gui.Text {
                            text = string.format("%.1f", book.rating),
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },

                    gui.View { style = { direction = "row", gap = "sm", paddingTop = "xs",
                        alignSelf = "stretch" },
                        gui.Button {
                            style = { grow = 1 },
                            title = book.through > 0 and "Continue" or "Start listening",
                            onPress = function() self:play(book.key) end,
                        },
                        gui.Button {
                            variant = "tinted",
                            title = "Save",
                            onPress = function() self:setState({ screen = "library" }) end,
                        },
                    },
                },

                gui.Text {
                    text = book.blurb,
                    style = { color = "textMuted", lineHeight = 1.5, paddingHorizontal = "md" },
                },

                gui.View { style = { gap = 2 },
                    gui.Text {
                        text = #book.chapters .. " chapters",
                        style = { fontWeight = "700", fontSize = "headline", paddingHorizontal = "md",
                            paddingBottom = "xs" },
                    },
                    table.unpack(rows),
                },
            },

            self:Playing(),
        }
    end,

    --- The player, which is the cover, the scrubber and the transport row under it.
    Player = function(self)
        local book = self:current()
        local insets = gui.environment:read(self).insets
        local left = math.max(0, book.minutes - self.state.at)

        local sleeps = {}

        for index = 1, #SLEEPS do
            sleeps[index] = { value = index, label = SLEEPS[index] }
        end

        return gui.View {
            style = { grow = 1, background = "background", paddingTop = insets.top + 8,
                paddingBottom = insets.bottom + 16, paddingHorizontal = "md", gap = "md" },

            gui.View { style = { direction = "row", align = "center" },
                gui.Pressable {
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Close the player",
                    onPress = function() self:setState({ screen = "book", looking = book.key }) end,
                    gui.Icon { name = "chevron-down", size = 24, color = "text" },
                },
                gui.Text {
                    text = "Now playing",
                    style = { grow = 1, textAlign = "center", fontSize = "footnote", color = "textMuted" },
                },
                gui.Pressable {
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Chapters",
                    onPress = function() self:setState({ screen = "book", looking = book.key }) end,
                    gui.Icon { name = "list", size = 22, color = "text" },
                },
            },

            gui.View { style = { grow = 1, align = "center", justify = "center" },
                gui.Image {
                    source = book.cover,
                    resizeMode = "cover",
                    style = { width = 260, height = 260, radius = "lg", background = "surface",
                        shadow = "lg" },
                },
            },

            gui.View { style = { gap = 2, align = "center" },
                gui.Text {
                    text = book.title,
                    numberOfLines = 1,
                    style = { fontSize = "headline", fontWeight = "700" },
                },
                gui.Text { text = book.author, style = { fontSize = "footnote", color = "textMuted" } },
            },

            gui.View { style = { gap = 2 },
                gui.Slider {
                    minimum = 0,
                    maximum = book.minutes,
                    value = self.state.at,
                    accessibilityLabel = "How far through",
                    onChange = function(value) self:setState({ at = value }) end,
                },
                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text {
                        text = clock(self.state.at),
                        style = { fontSize = "caption", color = "textMuted" },
                    },
                    gui.Text {
                        text = "-" .. clock(left),
                        style = { fontSize = "caption", color = "textMuted" },
                    },
                },
            },

            gui.View { style = { direction = "row", align = "center", justify = "space-between" },
                gui.Pressable {
                    style = { width = 56, height = 56, align = "center", justify = "center", gap = 1 },
                    accessibilityLabel = "Back fifteen seconds",
                    onPress = function() self:setState({ at = math.max(0, self.state.at - 0.25) }) end,
                    gui.Icon { name = "rewind", size = 22, color = "text" },
                    gui.Text { text = "15", style = { fontSize = 10, color = "textMuted" } },
                },

                gui.Pressable {
                    style = { width = 56, height = 56, align = "center", justify = "center" },
                    accessibilityLabel = "Previous chapter",
                    onPress = function() self:setState({ at = 0 }) end,
                    gui.Icon { name = "chevron-left", size = 24, color = "text" },
                },

                gui.Pressable {
                    style = { width = 72, height = 72, radius = 999, background = "primary",
                        align = "center", justify = "center" },
                    accessibilityLabel = self.state.running and "Pause" or "Play",
                    onPress = function() self:setState({ running = not self.state.running }) end,
                    gui.Icon {
                        name = self.state.running and "pause" or "play",
                        size = 30,
                        color = "onPrimary",
                    },
                },

                gui.Pressable {
                    style = { width = 56, height = 56, align = "center", justify = "center" },
                    accessibilityLabel = "Next chapter",
                    onPress = function()
                        self:setState({ at = math.min(book.minutes, self.state.at + 40) })
                    end,
                    gui.Icon { name = "chevron-right", size = 24, color = "text" },
                },

                gui.Pressable {
                    style = { width = 56, height = 56, align = "center", justify = "center", gap = 1 },
                    accessibilityLabel = "On thirty seconds",
                    onPress = function()
                        self:setState({ at = math.min(book.minutes, self.state.at + 0.5) })
                    end,
                    gui.Icon { name = "forward", size = 22, color = "text" },
                    gui.Text { text = "30", style = { fontSize = 10, color = "textMuted" } },
                },
            },

            gui.View { style = { direction = "row", align = "center", justify = "space-between",
                gap = "sm" },

                gui.Pressable {
                    style = { direction = "row", align = "center", gap = 6, minHeight = 44,
                        paddingHorizontal = "sm", radius = "pill", background = "surface" },
                    accessibilityLabel = "Speed",
                    onPress = function()
                        self:setState({ speed = self.state.speed % #SPEEDS + 1 })
                    end,
                    gui.Text {
                        text = string.format("%gx", SPEEDS[self.state.speed]),
                        style = { fontWeight = "600" },
                    },
                },

                gui.Pressable {
                    style = { direction = "row", align = "center", gap = 6, minHeight = 44,
                        paddingHorizontal = "sm", radius = "pill", background = "surface" },
                    accessibilityLabel = "Sleep timer",
                    onPress = function()
                        self:setState({ sleep = self.state.sleep % #SLEEPS + 1 })
                    end,
                    gui.Icon { name = "moon", size = 16, color = "text" },
                    gui.Text { text = SLEEPS[self.state.sleep], style = { fontWeight = "600" } },
                },

                gui.Pressable {
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Download",
                    onPress = function() self:setState({ screen = "library" }) end,
                    gui.Icon { name = "download", size = 20, color = "text" },
                },
            },
        }
    end,

    --- Everything a reader keeps, as the list a shelf is not.
    Library = function(self)
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "background" },
            gui.List {
                style = { grow = 1 },
                data = BOOKS,
                itemExtent = 88,
                keyExtractor = function(book) return book.key end,
                separator = gui.Divider { color = "separator", inset = 88 },
                footer = gui.Spacer { size = insets.bottom + 96 },
                footerExtent = insets.bottom + 96,

                renderItem = function(book)
                    return gui.Pressable {
                        style = { grow = 1, direction = "row", align = "center", gap = "sm",
                            paddingHorizontal = "md" },
                        accessibilityLabel = book.title,
                        onPress = function() self:open(book.key) end,

                        gui.Image {
                            source = book.cover,
                            resizeMode = "cover",
                            style = { width = 56, height = 56, radius = "sm", background = "surface" },
                        },

                        gui.View { style = { grow = 1, shrink = 1, gap = 3 },
                            gui.Text { text = book.title, numberOfLines = 1, style = { fontWeight = "600" } },
                            gui.Text {
                                text = book.author,
                                numberOfLines = 1,
                                style = { fontSize = "footnote", color = "textMuted" },
                            },
                            book.through > 0 and gui.ProgressBar {
                                key = "through",
                                value = book.through,
                                thickness = 3,
                            } or gui.Text {
                                key = "length",
                                text = span(book.minutes),
                                style = { fontSize = "caption", color = "textMuted" },
                            },
                        },

                        gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
                    }
                end,
            },

            self:Playing(),
        }
    end,

    --- What a search left, which is the one screen here with a field on it.
    Search = function(self)
        local wanted = self.state.search:lower()
        local kept = {}

        for index = 1, #BOOKS do
            local book = BOOKS[index]

            if wanted == "" or book.title:lower():find(wanted, 1, true) ~= nil
                or book.author:lower():find(wanted, 1, true) ~= nil then
                kept[#kept + 1] = book
            end
        end

        local covers = {}

        for index = 1, #kept do
            covers[index] = self:Cover(kept[index], nil)
        end

        return gui.KeyboardAvoiding { style = { grow = 1, background = "background" },
            gui.View { style = { padding = "md" },
                gui.View {
                    style = { direction = "row", align = "center", gap = "xs", height = 44,
                        radius = "pill", background = "surface", paddingHorizontal = "sm" },
                    gui.Icon { name = "search", size = 18, color = "textMuted" },
                    gui.TextInput {
                        style = { grow = 1, background = "transparent", paddingHorizontal = 0 },
                        placeholder = "A title or an author",
                        value = self.state.search,
                        autoFocus = true,
                        accessibilityLabel = "Search",
                        onChange = function(value) self:setState({ search = value }) end,
                    },
                },
            },

            gui.Grid {
                style = { grow = 1 },
                data = kept,
                columns = 3,
                spacing = 12,
                rowExtent = 166,
                keyExtractor = function(book) return book.key end,

                empty = gui.View { style = { padding = "lg", align = "center" },
                    gui.Text { text = "Nothing matches that", style = { color = "textMuted" } },
                },

                renderItem = function(book) return self:Cover(book, nil) end,
            },
        }
    end,

    screens = function(self)
        local screens = {
            { key = "home", title = "Lull", content = self:Home(), hidesBar = true },
        }

        if self.state.screen == "search" then
            screens[2] = { key = "search", title = "Search", content = self:Search() }
            return screens
        end

        if self.state.screen == "library" then
            screens[2] = { key = "library", title = "Your library", content = self:Library() }
            return screens
        end

        if self.state.screen == "book" or self.state.screen == "player" then
            screens[2] = { key = "book", title = find(self.state.looking).title, content = self:Book() }

            if self.state.screen == "player" then
                screens[3] = {
                    key = "player",
                    title = "Now playing",
                    content = self:Player(),
                    hidesBar = true,
                    transition = "slideUp",
                }
            end
        end

        return screens
    end,

    back = function(self)
        if self.state.screen == "player" then
            self:setState({ screen = "book" })
            return
        end

        self:setState({ screen = "home" })
    end,

    render = function(self)
        local screens = self:screens()

        return gui.Look {
            value = LOOK,
            style = { grow = 1 },

            gui.NavigationStack {
                style = { grow = 1 },
                screens = screens,
                index = #screens,
                backTitle = "Back",
                onPop = function() self:back() end,
            },
        }
    end,
})

return Lull
