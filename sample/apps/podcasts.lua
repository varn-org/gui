local gui = require("gui")

--- A podcast player: shows to browse, a search that answers as it is typed, favourites, and a player.
---
--- Four destinations behind a tab bar, each holding its own screen, all reading one piece of state.
--- What is playing is not a screen — it is a field, so the bar at the bottom follows you between tabs
--- the way it does in every player worth using.
local SHOWS = {
    {
        key = "signal",
        title = "Signal and Noise",
        author = "Mara Devlin",
        art = "https://picsum.photos/id/1039/400/400",
        episodes = {
            { key = "s1", title = "The first mile", minutes = 42, note = "Where a system starts, and why." },
            { key = "s2", title = "What broke", minutes = 38, note = "Three outages and what they had in common." },
            { key = "s3", title = "Small teams", minutes = 51, note = "What changes when nobody can hide." },
        },
    },
    {
        key = "long",
        title = "The Long Way",
        author = "Ines Okonkwo",
        art = "https://picsum.photos/id/1043/400/400",
        episodes = {
            { key = "l1", title = "Crossing the pass", minutes = 63, note = "Four days on foot." },
            { key = "l2", title = "The map is wrong", minutes = 47, note = "What to do when it is." },
        },
    },
    {
        key = "kitchen",
        title = "Kitchen Table",
        author = "Bo Halvorsen",
        art = "https://picsum.photos/id/1080/400/400",
        episodes = {
            { key = "k1", title = "Bread, badly", minutes = 29, note = "Every mistake, in order." },
            { key = "k2", title = "One pan", minutes = 34, note = "Dinner, and nothing to wash up." },
        },
    },
}

local TABS = {
    { key = "home", label = "Home" },
    { key = "search", label = "Search" },
    { key = "saved", label = "Saved" },
}

--- Answers every episode with the show it belongs to, which is what a search and a list both read.
local function everything()
    local found = {}

    for _, show in ipairs(SHOWS) do
        for _, episode in ipairs(show.episodes) do
            found[#found + 1] = {
                key = show.key .. "/" .. episode.key,
                show = show,
                episode = episode,
            }
        end
    end

    return found
end

local function clock(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local Podcasts = gui.component({
    name = "Podcasts",
    state = {
        tab = 1,
        query = "",
        saved = {},
        playing = nil,
        position = 0,
        running = false,
        open = false,
    },

    onUnmount = function(self)
        self.gone = true
    end,

    onUpdate = function(self)
        self:tick()
    end,

    --- Advances what is playing a second at a time, for as long as it is playing.
    ---
    --- A timer is armed only while something is running, so a player sitting idle holds nothing open
    --- and a screen that is never opened costs nothing at all.
    tick = function(self)
        if self.ticking or not self.state.running or self.state.playing == nil then
            return
        end

        self.ticking = true

        require("async").spawn(function()
            require("async").sleep(1000):await()
            self.ticking = false

            if self.gone or not self.state.running then
                return
            end

            local length = self:current().episode.minutes * 60

            if self.state.position + 1 >= length then
                self:setState({ position = 0, running = false })
                return
            end

            self:setState({ position = self.state.position + 1 })
        end)
    end,

    current = function(self)
        for _, entry in ipairs(everything()) do
            if entry.key == self.state.playing then
                return entry
            end
        end

        return nil
    end,

    play = function(self, key)
        if self.state.playing == key then
            self:setState({ running = not self.state.running })
            return
        end

        self:setState({ playing = key, position = 0, running = true })
        self:tick()
    end,

    save = function(self, key)
        local saved = {}

        for held, value in pairs(self.state.saved) do
            saved[held] = value
        end

        saved[key] = not saved[key] or nil
        self:setState({ saved = saved })
    end,

    matching = function(self)
        local query = self.state.query:lower()

        if query == "" then
            return {}
        end

        local found = {}

        for _, entry in ipairs(everything()) do
            local haystack = (entry.episode.title .. " " .. entry.show.title .. " " .. entry.show.author):lower()

            if haystack:find(query, 1, true) ~= nil then
                found[#found + 1] = entry
            end
        end

        return found
    end,

    savedEntries = function(self)
        local found = {}

        for _, entry in ipairs(everything()) do
            if self.state.saved[entry.key] then
                found[#found + 1] = entry
            end
        end

        return found
    end,

    --- One episode as a row, which every one of the three lists is built out of.
    Row = function(self, entry)
        return gui.View {
            style = { grow = 1, direction = "row", align = "center", gap = "md", paddingHorizontal = "md" },

            gui.Image {
                source = entry.show.art,
                resizeMode = "cover",
                style = { width = 56, height = 56, radius = "sm", background = "surface" },
            },

            gui.Pressable {
                style = { grow = 1, gap = 2, minHeight = 44, justify = "center" },
                accessibilityLabel = entry.episode.title,
                onPress = function() self:play(entry.key) end,
                gui.Text { text = entry.episode.title, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = entry.show.title .. " · " .. entry.episode.minutes .. " min",
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Pressable {
                style = { minWidth = 44, minHeight = 44, justify = "center", align = "center" },
                accessibilityLabel = self.state.saved[entry.key] and "Remove" or "Save",
                onPress = function() self:save(entry.key) end,
                gui.Text {
                    text = self.state.saved[entry.key] and "★" or "☆",
                    style = { fontSize = "title", color = self.state.saved[entry.key] and "warning" or "textMuted" },
                },
            },
        }
    end,

    List = function(self, entries, empty, header, headerExtent)
        if #entries == 0 then
            return gui.View { style = { grow = 1, justify = "center", align = "center" },
                gui.Text { text = empty, style = { color = "textMuted" } },
            }
        end

        return gui.List {
            style = { grow = 1 },
            data = entries,
            itemExtent = 76,
            header = header,
            headerExtent = headerExtent,
            keyExtractor = function(entry) return entry.key end,
            separator = gui.Divider {},
            renderItem = function(entry) return self:Row(entry) end,
        }
    end,

    --- The whole page is the list of episodes, and everything above them is its header.
    ---
    --- A list inside a scrolling view has to be given a height, since what holds it can grow without
    --- end, and a height written into a screen is a screen that stops short on a taller device and
    --- spills on a smaller one.
    Home = function(self)
        local header = gui.View {
            style = { gap = "md", paddingVertical = "md" },

            gui.Text {
                text = "Shows",
                style = { fontSize = "heading", fontWeight = "700", paddingHorizontal = "md" },
            },

            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 168 },
                contentStyle = { direction = "row", gap = "md", paddingHorizontal = "md" },
                table.unpack(self:Covers()),
            },

            gui.Text {
                text = "Latest",
                style = { fontSize = "title", fontWeight = "700", paddingHorizontal = "md" },
            },
        }

        return self:List(everything(), "Nothing yet", header, 300)
    end,

    Covers = function(self)
        local covers = {}

        for _, show in ipairs(SHOWS) do
            covers[#covers + 1] = gui.Pressable {
                key = show.key,
                style = { width = 132, gap = "xs" },
                accessibilityLabel = show.title,
                onPress = function() self:play(show.key .. "/" .. show.episodes[1].key) end,

                gui.Image {
                    source = show.art,
                    resizeMode = "cover",
                    style = { width = 132, height = 116, radius = "md", background = "surface" },
                },
                gui.Text { text = show.title, numberOfLines = 1, style = { fontWeight = "600" } },
            }
        end

        return covers
    end,

    Search = function(self)
        return gui.View { style = { grow = 1 },
            gui.View { style = { padding = "md" },
                gui.SearchBar {
                    placeholder = "Shows, episodes, people",
                    value = self.state.query,
                    onChange = function(value) self:setState({ query = value }) end,
                },
            },

            self:List(self:matching(), self.state.query == "" and "Type to search" or "Nothing matches that"),
        }
    end,

    Saved = function(self)
        return self:List(self:savedEntries(), "Star something to keep it here")
    end,

    --- The bar that follows you between tabs, which is what tells you something is playing at all.
    Playing = function(self)
        local entry = self:current()

        if entry == nil then
            return false
        end

        return gui.Pressable {
            style = { direction = "row", align = "center", gap = "md", height = 60,
                paddingHorizontal = "md", background = "elevated" },
            accessibilityLabel = "Now playing",
            onPress = function() self:setState({ open = true }) end,

            gui.Image {
                source = entry.show.art,
                resizeMode = "cover",
                style = { width = 40, height = 40, radius = "sm", background = "surface" },
            },

            gui.View { style = { grow = 1, gap = 1 },
                gui.Text { text = entry.episode.title, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = clock(self.state.position),
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Pressable {
                style = { minWidth = 44, minHeight = 44, justify = "center", align = "center" },
                accessibilityLabel = self.state.running and "Pause" or "Play",
                onPress = function() self:setState({ running = not self.state.running }) end,
                gui.Text { text = self.state.running and "❚❚" or "▶", style = { fontSize = "title" } },
            },
        }
    end,

    Player = function(self)
        local entry = self:current()

        if entry == nil then
            return gui.View { style = { width = 0, height = 0 } }
        end

        local length = entry.episode.minutes * 60

        return gui.Sheet {
            visible = self.state.open,
            selectedDetent = "large",
            onDismiss = function() self:setState({ open = false }) end,

            gui.View { style = { grow = 1, padding = "lg", gap = "lg", align = "center" },
                gui.Image {
                    source = entry.show.art,
                    resizeMode = "cover",
                    style = { width = 260, height = 260, radius = "lg", background = "surface" },
                },

                gui.View { style = { gap = "xs", align = "center" },
                    gui.Text {
                        text = entry.episode.title,
                        numberOfLines = 2,
                        style = { fontSize = "title", fontWeight = "700", textAlign = "center" },
                    },
                    gui.Text { text = entry.show.author, style = { color = "textMuted" } },
                },

                gui.View { style = { alignSelf = "stretch", gap = "xs" },
                    gui.Slider {
                        value = self.state.position / length,
                        onChange = function(value) self:setState({ position = value * length }) end,
                    },
                    gui.View { style = { direction = "row", justify = "space-between" },
                        gui.Text {
                            text = clock(self.state.position),
                            style = { fontSize = "caption", color = "textMuted" },
                        },
                        gui.Text {
                            text = "-" .. clock(length - self.state.position),
                            style = { fontSize = "caption", color = "textMuted" },
                        },
                    },
                },

                gui.View { style = { direction = "row", align = "center", gap = "xl" },
                    gui.Pressable {
                        style = { minWidth = 44, minHeight = 44, justify = "center", align = "center" },
                        accessibilityLabel = "Back fifteen seconds",
                        onPress = function() self:setState({ position = math.max(0, self.state.position - 15) }) end,
                        gui.Text { text = "↺", style = { fontSize = "heading" } },
                    },

                    gui.Pressable {
                        style = { width = 68, height = 68, radius = "pill", background = "primary",
                            justify = "center", align = "center" },
                        accessibilityLabel = self.state.running and "Pause" or "Play",
                        onPress = function() self:setState({ running = not self.state.running }) end,
                        gui.Text {
                            text = self.state.running and "❚❚" or "▶",
                            style = { fontSize = "title", color = "onPrimary" },
                        },
                    },

                    gui.Pressable {
                        style = { minWidth = 44, minHeight = 44, justify = "center", align = "center" },
                        accessibilityLabel = "On fifteen seconds",
                        onPress = function()
                            self:setState({ position = math.min(length, self.state.position + 15) })
                        end,
                        gui.Text { text = "↻", style = { fontSize = "heading" } },
                    },
                },
            },
        }
    end,

    render = function(self)
        local screens = { self.Home, self.Search, self.Saved }

        return gui.View { style = { grow = 1, background = "background" },
            gui.View { style = { grow = 1 }, screens[self.state.tab](self) },

            self:Playing(),

            gui.TabBar {
                tabs = TABS,
                selectedIndex = self.state.tab,
                badgeCounts = { saved = #self:savedEntries() },
                onChange = function(index) self:setState({ tab = index }) end,
            },

            self:Player(),
        }
    end,
})

return Podcasts
