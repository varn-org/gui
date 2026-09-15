local async = require("async")
local gui = require("gui")

--- A listening application, built as a path rather than as a set of tabs.
---
--- Browsing goes categories, then the groups inside one, then the shows in a group, then a show, and a
--- show names the category and the group it belongs to as things a reader may press. Pressing one opens
--- it as though it had been reached from the list, so the way in has no end and the stack goes as deep
--- as somebody keeps pressing. That is the point of it: a stack is easy to get right two screens deep,
--- and what it costs in state, in memory and in the time a pop takes only shows at twenty.
local CATEGORIES = {
    {
        key = "society",
        title = "Society",
        blurb = "Conversations, and the people in them",
        tint = { "#6C5CE7", "#A29BFE" },
        groups = {
            { key = "interviews", title = "Interviews", blurb = "One person, at length" },
            { key = "history", title = "History", blurb = "What happened, and to whom" },
        },
    },
    {
        key = "making",
        title = "Making things",
        blurb = "Building, breaking and fixing",
        tint = { "#00B894", "#55EFC4" },
        groups = {
            { key = "software", title = "Software", blurb = "Systems and the people who keep them up" },
            { key = "craft", title = "By hand", blurb = "Wood, bread, cloth and clay" },
        },
    },
    {
        key = "outside",
        title = "Outside",
        blurb = "Where the pavement stops",
        tint = { "#0984E3", "#74B9FF" },
        groups = {
            { key = "walking", title = "On foot", blurb = "Long days and where they end" },
            { key = "water", title = "Water", blurb = "Rivers, coasts and crossings" },
        },
    },
}

local SHOWS = {
    {
        key = "signal",
        title = "Signal and Noise",
        author = "Mara Devlin",
        art = "show-signal.png",
        category = "making",
        group = "software",
        about = "What keeps a system standing, told by the people who were on call when it did not.",
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
        art = "show-long.png",
        category = "outside",
        group = "walking",
        about = "Four days, one map and the places it turned out to be wrong about.",
        episodes = {
            { key = "l1", title = "Crossing the pass", minutes = 63, note = "Four days on foot." },
            { key = "l2", title = "The map is wrong", minutes = 47, note = "What to do when it is." },
        },
    },
    {
        key = "kitchen",
        title = "Kitchen Table",
        author = "Bo Halvorsen",
        art = "show-kitchen.png",
        category = "making",
        group = "craft",
        about = "Everything that can go wrong with bread, in the order it usually goes wrong.",
        episodes = {
            { key = "k1", title = "Bread, badly", minutes = 29, note = "Every mistake, in order." },
            { key = "k2", title = "One pan", minutes = 34, note = "Dinner, and nothing to wash up." },
        },
    },
    {
        key = "hours",
        title = "The Hours",
        author = "Petra Lindqvist",
        art = "show-hours.png",
        category = "society",
        group = "interviews",
        about = "One person, one afternoon, and whatever they came to say.",
        episodes = {
            { key = "h1", title = "The archivist", minutes = 55, note = "Forty years of other people's letters." },
            { key = "h2", title = "The ferryman", minutes = 44, note = "The same crossing, twice a day." },
        },
    },
    {
        key = "tide",
        title = "Tideline",
        author = "Ruth Abara",
        art = "show-tide.png",
        category = "outside",
        group = "water",
        about = "Coasts, the people who work them, and what the water takes back.",
        episodes = {
            { key = "t1", title = "Spring tide", minutes = 36, note = "The highest water of the year." },
            { key = "t2", title = "The crossing", minutes = 58, note = "Eleven miles, and the hour it has to be." },
        },
    },
    {
        key = "before",
        title = "Before This",
        author = "Yusuf Demir",
        art = "show-before.png",
        category = "society",
        group = "history",
        about = "What stood here before, and what it was for.",
        episodes = {
            { key = "b1", title = "The old road", minutes = 47, note = "Who built it, and who paid." },
            { key = "b2", title = "Under the square", minutes = 39, note = "Three streets that are no longer there." },
        },
    },
}

--- Answers a category by the name it is kept under.
local function categoryOf(key)
    for _, category in ipairs(CATEGORIES) do
        if category.key == key then
            return category
        end
    end

    return nil
end

--- Answers a group inside a category, which is what the second level of the path is.
local function groupOf(category, key)
    for _, group in ipairs((category or {}).groups or {}) do
        if group.key == key then
            return group
        end
    end

    return nil
end

local function showOf(key)
    for _, show in ipairs(SHOWS) do
        if show.key == key then
            return show
        end
    end

    return nil
end

--- Answers the shows in a category, and in one group of it when a group is named.
local function showsIn(category, group)
    local found = {}

    for _, show in ipairs(SHOWS) do
        if show.category == category and (group == nil or show.group == group) then
            found[#found + 1] = show
        end
    end

    return found
end

--- Answers every episode with the show it belongs to, which is what a search reads.
local function everything()
    local found = {}

    for _, show in ipairs(SHOWS) do
        for _, episode in ipairs(show.episodes) do
            found[#found + 1] = { key = show.key .. "/" .. episode.key, show = show, episode = episode }
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
        trail = { { kind = "browse" } },
        query = "",
        saved = {},
        playing = nil,
        position = 0,
        running = false,
        expanded = false,
    },

    onUnmount = function(self)
        self.gone = true
    end,

    onUpdate = function(self)
        self:tick()
    end,

    --- Advances what is playing a second at a time, for as long as it is playing.
    tick = function(self)
        if self.ticking or not self.state.running or self.state.playing == nil then
            return
        end

        self.ticking = true

        async.spawn(function()
            async.sleep(1000):await()
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

    --- Opens a place on top of what is already open, which is what every row here does.
    open = function(self, place)
        local trail = {}

        for index = 1, #self.state.trail do
            trail[index] = self.state.trail[index]
        end

        trail[#trail + 1] = place
        self:setState({ trail = trail })
    end,

    back = function(self)
        if #self.state.trail < 2 then
            return
        end

        local trail = {}

        for index = 1, #self.state.trail - 1 do
            trail[index] = self.state.trail[index]
        end

        self:setState({ trail = trail })
    end,

    --- A row of the same shape wherever a list of things to open appears.
    Row = function(self, options)
        return gui.Pressable {
            key = options.key,
            accessibilityLabel = options.title,
            onPress = options.onPress,
            style = { direction = "row", align = "center", gap = "md",
                paddingHorizontal = "md", paddingVertical = "sm" },

            options.art ~= nil and gui.Image {
                source = options.art,
                resizeMode = "cover",
                style = { width = 56, height = 56, radius = "md" },
            } or gui.Gradient {
                colors = options.tint or { "#636E72", "#B2BEC3" },
                direction = "diagonal",
                style = { width = 56, height = 56, radius = "md" },
            },

            gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                gui.Text { text = options.title, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = options.blurb,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
        }
    end,

    --- The chips a show carries, which reopen the category and the group it sits in.
    ---
    --- Pressing one pushes that screen on top of the show, so a reader can go round the same loop for as
    --- long as they like and the stack grows every time they do.
    Belonging = function(self, show)
        local category = categoryOf(show.category)
        local group = groupOf(category, show.group)

        return gui.View { style = { direction = "row", gap = "sm", paddingHorizontal = "md" },
            gui.Chip {
                key = "category",
                label = category.title,
                onPress = function() self:open({ kind = "category", category = category.key }) end,
            },
            gui.Chip {
                key = "group",
                label = group.title,
                onPress = function()
                    self:open({ kind = "group", category = category.key, group = group.key })
                end,
            },
        }
    end,

    --- The latest episode of each show, across the top, which is what a listening application opens on.
    ---
    --- What is named here is the episode rather than the show, so the path through the categories is
    --- still the only way to reach a show by name — which is what this application exists to put under
    --- strain. Pressing one opens the show it belongs to, where its episodes are.
    Shelf = function(self)
        local covers = {}

        for _, show in ipairs(SHOWS) do
            local episode = show.episodes[1]

            covers[#covers + 1] = gui.Pressable {
                key = show.key,
                accessibilityLabel = episode.title,
                style = { width = 132, gap = "xs" },
                onPress = function() self:open({ kind = "show", show = show.key }) end,

                gui.Image {
                    source = show.art,
                    resizeMode = "cover",
                    style = { width = 132, height = 132, radius = "md", background = "surface" },
                },
                gui.Text {
                    text = episode.title,
                    numberOfLines = 1,
                    style = { fontWeight = "600", fontSize = "footnote" },
                },
                gui.Text {
                    text = episode.minutes .. " min",
                    numberOfLines = 1,
                    style = { fontSize = "caption", color = "textMuted" },
                },
            }
        end

        return gui.ScrollView {
            horizontal = true,
            showsIndicator = false,
            style = { height = 200 },
            contentStyle = { direction = "row", gap = "md", paddingHorizontal = "md" },
            table.unpack(covers),
        }
    end,

    --- The categories as cards two to a row, which is what a browse screen is on every platform.
    ---
    --- A row the height of a list row leaves a screen two thirds empty and reads as a menu rather than
    --- as somewhere to look around, which is what browsing is meant to be.
    Cards = function(self)
        local surface = gui.environment:read(self)
        local cards = {}

        -- A card is half the room between the margins, less the gap between two of them. Grown into
        -- what is left instead, a row holding one card stretches it the width of the screen.
        local across = (surface.width - 32 - 16) / 2

        for _, category in ipairs(CATEGORIES) do
            cards[#cards + 1] = gui.Pressable {
                key = category.key,
                accessibilityLabel = category.title,
                style = { width = across, gap = "xs" },
                onPress = function() self:open({ kind = "category", category = category.key }) end,

                gui.Gradient {
                    colors = category.tint,
                    direction = "diagonal",
                    style = { height = 108, radius = "md", justify = "end", padding = "sm" },

                    gui.Text {
                        text = #category.groups .. " groups",
                        style = { fontSize = "caption", fontWeight = "600", color = "#ffffffcc" },
                    },
                },

                gui.Text { text = category.title, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = category.blurb,
                    numberOfLines = 2,
                    style = { fontSize = "footnote", color = "textMuted", lineHeight = 1.3 },
                },
            }
        end

        return gui.View {
            style = { direction = "row", wrap = true, gap = "md", paddingHorizontal = "md" },
            table.unpack(cards),
        }
    end,

    Browse = function(self)
        local insets = gui.environment:read(self).insets

        return gui.ScrollView {
            style = { grow = 1 },

            -- The list runs under the player and under whatever the system draws over the bottom of the
            -- glass, and stops above both, so the last row is one a finger can reach.
            contentStyle = { paddingVertical = "sm", paddingBottom = insets.bottom + 120 },

            gui.View { style = { paddingHorizontal = "md", paddingBottom = "sm" },
                gui.SearchBar {
                    value = self.state.query,
                    placeholder = "Search every show",
                    onChange = function(value) self:setState({ query = value }) end,
                },
            },

            self.state.query ~= "" and self:Found() or gui.View { style = { gap = "sm" },
                self:Heading("New episodes"),
                self:Shelf(),
                self:Heading("Browse"),
                self:Cards(),
            },
        }
    end,

    --- What the search answers, which is the episodes whose show or title carries what was typed.
    Found = function(self)
        local wanted = self.state.query:lower()
        local rows = {}

        for _, entry in ipairs(everything()) do
            local matches = entry.show.title:lower():find(wanted, 1, true) ~= nil
                or entry.episode.title:lower():find(wanted, 1, true) ~= nil

            if matches then
                rows[#rows + 1] = self:Row({
                    key = entry.key,
                    title = entry.episode.title,
                    blurb = entry.show.title,
                    art = entry.show.art,
                    onPress = function() self:open({ kind = "show", show = entry.show.key }) end,
                })
            end
        end

        if #rows == 0 then
            return gui.View { style = { padding = "xl", align = "center" },
                gui.Text { text = "Nothing answers that", style = { color = "textMuted" } },
            }
        end

        return gui.View { table.unpack(rows) }
    end,

    Category = function(self, place)
        local category = categoryOf(place.category)
        local rows = {}

        for _, group in ipairs(category.groups) do
            rows[#rows + 1] = self:Row({
                key = group.key,
                title = group.title,
                blurb = group.blurb,
                tint = category.tint,
                onPress = function()
                    self:open({ kind = "group", category = category.key, group = group.key })
                end,
            })
        end

        local shows = {}

        for _, show in ipairs(showsIn(category.key)) do
            shows[#shows + 1] = self:Row({
                key = show.key,
                title = show.title,
                blurb = show.author,
                art = show.art,
                onPress = function() self:open({ kind = "show", show = show.key }) end,
            })
        end

        return gui.ScrollView { style = { grow = 1 }, contentStyle = { paddingBottom = "md" },
            gui.Gradient {
                colors = category.tint,
                direction = "diagonal",
                style = { padding = "md", gap = "xs" },
                gui.Text { text = category.title,
                    style = { fontSize = "heading", fontWeight = "700", color = "#ffffff" } },
                gui.Text { text = category.blurb, style = { color = "#ffffffcc" } },
            },

            self:Heading("Inside this"),
            gui.View { table.unpack(rows) },

            self:Heading("Everything here"),
            gui.View { table.unpack(shows) },
        }
    end,

    Group = function(self, place)
        local category = categoryOf(place.category)
        local group = groupOf(category, place.group)
        local rows = {}

        for _, show in ipairs(showsIn(category.key, group.key)) do
            rows[#rows + 1] = self:Row({
                key = show.key,
                title = show.title,
                blurb = show.author,
                art = show.art,
                onPress = function() self:open({ kind = "show", show = show.key }) end,
            })
        end

        return gui.ScrollView { style = { grow = 1 }, contentStyle = { paddingBottom = "md" },
            gui.View { style = { padding = "md", gap = "xs" },
                gui.Text { text = group.title, style = { fontSize = "heading", fontWeight = "700" } },
                gui.Text { text = group.blurb, style = { color = "textMuted" } },
            },

            gui.View { style = { paddingHorizontal = "md", paddingBottom = "sm" },
                gui.Chip {
                    label = category.title,
                    onPress = function() self:open({ kind = "category", category = category.key }) end,
                },
            },

            gui.Divider {},
            gui.View { table.unpack(rows) },
        }
    end,

    Show = function(self, place)
        local show = showOf(place.show)
        local rows = {}

        for _, episode in ipairs(show.episodes) do
            local key = show.key .. "/" .. episode.key
            local playing = self.state.playing == key

            rows[#rows + 1] = gui.Pressable {
                key = episode.key,
                accessibilityLabel = episode.title,
                onPress = function() self:play(key) end,
                style = { direction = "row", align = "center", gap = "md",
                    paddingHorizontal = "md", paddingVertical = "sm" },

                gui.View {
                    style = { width = 36, height = 36, radius = "pill", align = "center", justify = "center",
                        background = playing and "primary" or "surface" },
                    gui.Icon {
                        name = playing and self.state.running and "pause" or "play",
                        size = 16,
                        color = playing and "onPrimary" or "text",
                    },
                },

                gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                    gui.Text { text = episode.title, numberOfLines = 1, style = { fontWeight = "600" } },
                    gui.Text { text = episode.note, numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" } },
                },

                gui.Text { text = episode.minutes .. " min",
                    style = { fontSize = "caption", color = "textMuted" } },
            }
        end

        return gui.ScrollView { style = { grow = 1 }, contentStyle = { paddingBottom = "md" },
            gui.View { style = { direction = "row", gap = "md", padding = "md" },
                gui.Image {
                    source = show.art,
                    resizeMode = "cover",
                    style = { width = 104, height = 104, radius = "lg" },
                },

                gui.View { style = { grow = 1, shrink = 1, gap = "xs", justify = "center" },
                    gui.Text { text = show.title, style = { fontSize = "title", fontWeight = "700" } },
                    gui.Text { text = show.author, style = { color = "textMuted" } },

                    gui.Button {
                        title = self.state.saved[show.key] and "Saved" or "Save",
                        variant = self.state.saved[show.key] and "tinted" or "outlined",
                        size = "small",
                        style = { alignSelf = "start" },
                        onPress = function() self:save(show.key) end,
                    },
                },
            },

            gui.Text { text = show.about,
                style = { paddingHorizontal = "md", paddingBottom = "sm", color = "textMuted" } },

            self:Belonging(show),

            gui.Divider { style = { marginTop = "sm" } },
            gui.View { table.unpack(rows) },
        }
    end,

    Heading = function(self, text)
        return gui.Text {
            text = text:upper(),
            style = { paddingHorizontal = "md", paddingTop = "md", paddingBottom = "xs",
                fontSize = "caption", fontWeight = "700", color = "textMuted", letterSpacing = 0.6 },
        }
    end,

    --- What is playing, drawn over every screen and following the reader down the whole path.
    Player = function(self)
        local entry = self:current()

        if entry == nil then
            return false
        end

        local length = entry.episode.minutes * 60

        local insets = gui.environment:read(self).insets

        return gui.Blur {
            intensity = 0.9,
            tint = "background",
            style = { paddingHorizontal = "md", paddingTop = "sm",
                paddingBottom = 8 + insets.bottom, gap = "xs" },

            gui.View { style = { direction = "row", align = "center", gap = "md" },
                gui.Image {
                    source = entry.show.art,
                    resizeMode = "cover",
                    style = { width = 40, height = 40, radius = "sm" },
                },

                gui.View { style = { grow = 1, shrink = 1 },
                    gui.Text { text = entry.episode.title, numberOfLines = 1,
                        style = { fontWeight = "600", fontSize = "footnote" } },
                    gui.Text { text = clock(self.state.position) .. " of " .. clock(length),
                        style = { fontSize = "caption", color = "textMuted" } },
                },

                gui.Pressable {
                    accessibilityLabel = self.state.running and "Pause" or "Play",
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    onPress = function() self:setState({ running = not self.state.running }) end,
                    gui.Icon { name = self.state.running and "pause" or "play", size = 22, color = "primary" },
                },
            },

            gui.Slider {
                value = length > 0 and self.state.position / length or 0,
                onChange = function(share) self:setState({ position = math.floor(share * length) }) end,
            },
        }
    end,

    --- Answers the screen one place on the trail is drawn as, and the name its way back carries.
    screenOf = function(self, place, index)
        if place.kind == "category" then
            return { key = "category:" .. place.category .. ":" .. index,
                title = categoryOf(place.category).title, content = self:Category(place) }
        end

        if place.kind == "group" then
            local category = categoryOf(place.category)

            return { key = "group:" .. place.group .. ":" .. index,
                title = groupOf(category, place.group).title, content = self:Group(place) }
        end

        if place.kind == "show" then
            return { key = "show:" .. place.show .. ":" .. index,
                title = showOf(place.show).title, content = self:Show(place) }
        end

        return { key = "browse", title = "Listening", content = self:Browse() }
    end,

    render = function(self)
        local screens = {}

        for index = 1, #self.state.trail do
            screens[index] = self:screenOf(self.state.trail[index], index)
        end

        return gui.View { style = { grow = 1, background = "background" },
            gui.NavigationStack {
                style = { grow = 1 },
                screens = screens,
                index = #screens,
                onIndexChange = function() self:back() end,
            },

            self:Player(),
        }
    end,
})

return Podcasts
