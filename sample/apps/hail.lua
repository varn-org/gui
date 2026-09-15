local gui = require("gui")

--- A ride-hailing application, from the map through to a car on its way.
---
--- The map is drawn rather than fetched. A tile server is a dependency, a key and a licence, and what
--- one of these screens actually needs is a plausible city under a route: blocks, the streets between
--- them, a park, water, and the two ends of the journey. All of that is a canvas, which every renderer
--- already draws, so the application carries no network at all.
local LOOK = gui.theme.define({
    name = "hail",
    radii = { sm = 6, md = 10, lg = 14, pill = 999 },
    spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 32 },
    light = {
        colors = {
            primary = "#000000", onPrimary = "#ffffff", background = "#ffffff", surface = "#f3f3f3",
            elevated = "#ffffff", text = "#000000", textMuted = "#6b6b6b", border = "#e2e2e2",
            separator = "#0000001a", success = "#1f8a4c", warning = "#d99100", danger = "#d93025",
        },
    },
    dark = {
        colors = {
            primary = "#ffffff", onPrimary = "#000000", background = "#0b0b0b", surface = "#1a1a1a",
            elevated = "#242424", text = "#ffffff", textMuted = "#9e9e9e", border = "#2e2e2e",
            separator = "#ffffff1a", success = "#4cc47c", warning = "#e8b33d", danger = "#ef6b5f",
        },
    },
})

--- The city the map draws, as the blocks a street grid leaves between it.
---
--- A grid alone reads as graph paper, so the blocks are set in from the streets, a park and a river cut
--- across it, and the route runs along the streets rather than straight between its two ends.
local BLOCK = "#e4e1db"
local STREET = "#fbfaf8"
local PARK = "#d5e6cf"
local WATER = "#c3d9e8"
local ROUTE = "#111111"

local function box(x, y, width, height, color)
    return {
        op = "fill",
        color = color,
        path = { { x, y }, { x + width, y }, { x + width, y + height }, { x, y + height } },
    }
end

--- Answers the whole map as one list of drawings, at the size the box it fills turned out to be.
local function city(width, height, route)
    local commands = { box(0, 0, width, height, STREET) }
    local step = 74
    local road = 13

    -- A block fills its whole cell up to the next street, so what is left between them is the street
    -- and nothing else. Leaving a gap on both sides draws an L in the ground colour inside every cell,
    -- which reads as damage rather than as a city.
    local function cells(each)
        local down = -1

        while down * step < height + step do
            local across = -1

            while across * step < width + step do
                each(across * step, down * step)
                across = across + 1
            end

            down = down + 1
        end
    end

    -- A block is split where a lane runs through it, which is what keeps the grid from reading as graph
    -- paper. Which ones are split is worked out from where they are rather than drawn at random, so the
    -- map is the same map every time it is laid out.
    local at = 0

    cells(function(x, y)
        at = at + 1

        local left = x + road
        local top = y + road
        local wide = step - road
        local tall = step - road

        if at % 5 == 0 then
            commands[#commands + 1] = box(left, top, wide, tall * 0.44, BLOCK)
            commands[#commands + 1] = box(left, top + tall * 0.56, wide, tall * 0.44, BLOCK)
            return
        end

        if at % 7 == 0 then
            commands[#commands + 1] = box(left, top, wide * 0.4, tall, BLOCK)
            commands[#commands + 1] = box(left + wide * 0.52, top, wide * 0.48, tall, BLOCK)
            return
        end

        commands[#commands + 1] = box(left, top, wide, tall, BLOCK)
    end)

    -- One avenue crossing the grid, which every city that grew rather than being laid out has.
    commands[#commands + 1] = {
        op = "stroke",
        color = STREET,
        width = road + 5,
        path = { { -20, height * 0.86 }, { width + 20, height * 0.1 } },
    }

    -- A park and a square take whole blocks, since a city does not put one across a street.
    commands[#commands + 1] = box(step + road, step * 2 + road, step * 2 - road, step * 2 - road, PARK)
    commands[#commands + 1] = box(width - step * 2 - road, height - step * 3, step * 2, step * 2 - road, PARK)

    -- A river runs, so it bends rather than turning: the points are close together and never far from
    -- the line they are following, and it crosses the grid without minding it.
    local along = {}
    local waves = 7

    for index = 0, waves do
        local share = index / waves

        along[#along + 1] = {
            -20 + (width + 40) * share,
            height * (0.44 + 0.05 * math.sin(share * 5.2)),
        }
    end

    commands[#commands + 1] = { op = "stroke", color = WATER, width = 30, path = along }

    if route then
        local from = { width * 0.22, height * 0.72 }
        local to = { width * 0.76, height * 0.24 }

        commands[#commands + 1] = {
            op = "stroke",
            color = ROUTE,
            width = 6,
            path = {
                from, { from[1], height * 0.52 }, { width * 0.5, height * 0.52 },
                { width * 0.5, height * 0.3 }, { to[1], height * 0.3 }, to,
            },
        }

        commands[#commands + 1] = { op = "fill", color = ROUTE, path = {
            { from[1] - 7, from[2] - 7 }, { from[1] + 7, from[2] - 7 },
            { from[1] + 7, from[2] + 7 }, { from[1] - 7, from[2] + 7 },
        } }

        commands[#commands + 1] = { op = "fill", color = ROUTE, path = {
            { to[1], to[2] - 12 }, { to[1] + 10, to[2] + 6 }, { to[1] - 10, to[2] + 6 },
        } }
    end

    return commands
end

local Map = gui.component({
    name = "HailMap",
    state = { width = 0, height = 0 },

    render = function(self)
        local width = self.state.width
        local height = self.state.height

        return gui.View {
            style = { { grow = 1, background = BLOCK, overflow = "hidden" }, self.props.style },
            onLayout = function(frame)
                if frame.width ~= width or frame.height ~= height then
                    self:setState({ width = frame.width, height = frame.height })
                end
            end,

            width > 0 and gui.Canvas {
                key = "map",
                style = { position = "absolute", top = 0, left = 0, width = width, height = height },
                commands = city(width, height, self.props.route == true),
            } or false,
        }
    end,
})

local PLACES = {
    { key = "office", icon = "settings", name = "Work", line = "Av. Central, 1500 — floor 8", away = 14 },
    { key = "market", icon = "cart", name = "Mercado do Porto", line = "Rua da Praia, 40", away = 9 },
    { key = "airport", icon = "compass", name = "Airport, terminal 2", line = "Rodovia dos Bandeirantes", away = 38 },
    { key = "home", icon = "home", name = "Home", line = "Rua das Palmeiras, 220", away = 22 },
}

local RIDES = {
    { key = "small", name = "Hail Go", seats = 4, arrives = 3, price = 21.9, picture = "car-small.png",
        blurb = "Everyday cars, the cheapest way across town" },
    { key = "large", name = "Hail Six", seats = 6, arrives = 6, price = 34.5, picture = "car-large.png",
        blurb = "Room for six and their bags" },
    { key = "black", name = "Hail Black", seats = 4, arrives = 8, price = 58, picture = "car-black.png",
        blurb = "Top rated drivers in newer cars" },
}

local function money(amount)
    local written = string.format("R$ %.2f", amount)

    return (written:gsub("%.", ","))
end

local Hail = gui.component({
    name = "Hail",
    state = { screen = "home", going = nil, ride = "small", search = "" },

    chosen = function(self)
        for index = 1, #RIDES do
            if RIDES[index].key == self.state.ride then
                return RIDES[index]
            end
        end

        return RIDES[1]
    end,

    destination = function(self)
        for index = 1, #PLACES do
            if PLACES[index].key == self.state.going then
                return PLACES[index]
            end
        end

        return PLACES[1]
    end,

    PlaceRow = function(self, place, onPress)
        return gui.Pressable {
            key = place.key,
            style = { direction = "row", align = "center", gap = "sm", minHeight = 60,
                paddingHorizontal = "md" },
            accessibilityLabel = place.name,
            onPress = onPress,

            gui.View {
                style = { width = 40, height = 40, radius = 999, background = "surface",
                    align = "center", justify = "center" },
                gui.Icon { name = place.icon, size = 20, color = "text" },
            },

            gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                gui.Text { text = place.name, numberOfLines = 1, style = { fontWeight = "600" } },
                gui.Text {
                    text = place.line,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Text { text = place.away .. " min", style = { fontSize = "footnote", color = "textMuted" } },
        }
    end,

    --- The map with a card raised over the bottom of it, which is what every one of these opens on.
    Home = function(self)
        local insets = gui.environment:read(self).insets
        local rows = {}

        for index = 1, 3 do
            rows[index] = self:PlaceRow(PLACES[index], function()
                self:setState({ screen = "ride", going = PLACES[index].key })
            end)
        end

        return gui.View { style = { grow = 1, background = "background" },
            Map { style = { grow = 1 } },

            gui.Pressable {
                style = { position = "absolute", top = insets.top + 12, left = 16, width = 44, height = 44,
                    radius = 999, background = "elevated", align = "center", justify = "center",
                    shadow = "md" },
                accessibilityLabel = "Menu",
                onPress = function() self:setState({ screen = "saved" }) end,

                gui.Icon { name = "menu", size = 22, color = "text" },
            },

            gui.View {
                style = { position = "absolute", left = 0, right = 0, bottom = 0, background = "elevated",
                    radius = "lg", paddingTop = "md", paddingBottom = insets.bottom + 16, gap = "sm",
                    shadow = "lg" },

                gui.Text {
                    text = "Where to?",
                    style = { fontSize = "title", fontWeight = "700", paddingHorizontal = "md" },
                },

                gui.Pressable {
                    style = { direction = "row", align = "center", gap = "sm", marginHorizontal = "md",
                        height = 48, radius = "md", background = "surface", paddingHorizontal = "sm" },
                    accessibilityLabel = "Enter a destination",
                    onPress = function() self:setState({ screen = "search" }) end,

                    gui.Icon { name = "search", size = 18, color = "textMuted" },
                    gui.Text { text = "Enter a destination", style = { grow = 1, color = "textMuted" } },
                    gui.View {
                        style = { direction = "row", align = "center", gap = 4, paddingLeft = "sm" },
                        gui.Icon { name = "clock", size = 16, color = "text" },
                        gui.Text { text = "Now", style = { fontSize = "footnote", fontWeight = "600" } },
                    },
                },

                gui.Divider { color = "separator" },

                table.unpack(rows),
            },
        }
    end,

    --- Where to, which is the one screen a reader types on.
    Search = function(self)
        local wanted = self.state.search:lower()
        local rows = {}

        for index = 1, #PLACES do
            local place = PLACES[index]

            if wanted == "" or place.name:lower():find(wanted, 1, true) ~= nil then
                rows[#rows + 1] = self:PlaceRow(place, function()
                    self:setState({ screen = "ride", going = place.key, search = "" })
                end)
            end
        end

        return gui.KeyboardAvoiding {
            style = { grow = 1, background = "background" },

            gui.View { style = { padding = "md", gap = "sm" },
                gui.View { style = { direction = "row", align = "center", gap = "sm" },
                    gui.View { style = { width = 10, height = 10, radius = 999, background = "textMuted" } },
                    gui.Text {
                        text = "Rua das Palmeiras, 220",
                        numberOfLines = 1,
                        style = { grow = 1, color = "textMuted" },
                    },
                },

                gui.View { style = { direction = "row", align = "center", gap = "sm" },
                    gui.View { style = { width = 10, height = 10, background = "text" } },
                    gui.TextInput {
                        style = { grow = 1, height = 44, background = "surface", radius = "md" },
                        placeholder = "Where to?",
                        value = self.state.search,
                        autoFocus = true,
                        accessibilityLabel = "Where to",
                        onChange = function(value) self:setState({ search = value }) end,
                    },
                },
            },

            gui.Divider { color = "separator" },

            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { paddingVertical = "xs" },
                keyboardDismissMode = "on-drag",
                table.unpack(rows),
            },
        }
    end,

    --- The route with the cars under it, which is the screen a price is chosen on.
    Ride = function(self)
        local insets = gui.environment:read(self).insets
        local going = self:destination()
        local rows = {}

        for index = 1, #RIDES do
            local ride = RIDES[index]
            local picked = ride.key == self.state.ride

            rows[index] = gui.Pressable {
                key = ride.key,
                style = { direction = "row", align = "center", gap = "sm", minHeight = 76,
                    paddingHorizontal = "sm", marginHorizontal = "sm", radius = "md",
                    background = picked and "surface" or nil,
                    border = picked and 2 or 0,
                    borderColor = picked and "text" or nil },
                accessibilityLabel = ride.name,
                accessibilityState = { selected = picked },
                onPress = function() self:setState({ ride = ride.key }) end,

                gui.Image {
                    source = ride.picture,
                    resizeMode = "contain",
                    style = { width = 64, height = 48 },
                },

                gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                    gui.View { style = { direction = "row", align = "center", gap = 6 },
                        gui.Text { text = ride.name, style = { fontWeight = "700" } },
                        gui.Icon { name = "user", size = 12, color = "textMuted" },
                        gui.Text {
                            text = tostring(ride.seats),
                            style = { fontSize = "caption", color = "textMuted" },
                        },
                    },
                    gui.Text {
                        text = ride.blurb,
                        numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                    gui.Text {
                        text = ride.arrives .. " min away",
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },

                gui.Text { text = money(ride.price), style = { fontWeight = "700" } },
            }
        end

        rows[#rows + 1] = gui.Button {
            key = "book",
            style = { marginHorizontal = "md", marginTop = "sm" },
            title = "Book " .. self:chosen().name,
            onPress = function() self:setState({ screen = "trip" }) end,
        }

        return gui.View { style = { grow = 1, background = "background" },
            Map { style = { grow = 1 }, route = true },

            gui.View {
                style = { position = "absolute", left = 0, right = 0, bottom = 0, background = "elevated",
                    radius = "lg", paddingTop = "sm", paddingBottom = insets.bottom + 16, gap = "xs",
                    shadow = "lg" },

                gui.Text {
                    text = "To " .. going.name,
                    numberOfLines = 1,
                    style = { fontWeight = "700", fontSize = "headline", paddingHorizontal = "md" },
                },
                gui.Text {
                    text = going.away .. " min • " .. going.line,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted", paddingHorizontal = "md",
                        paddingBottom = "xs" },
                },

                table.unpack(rows),
            },
        }
    end,

    --- The car on its way, which is who is driving, what they are driving and how to reach them.
    Trip = function(self)
        local insets = gui.environment:read(self).insets
        local ride = self:chosen()

        local actions = {
            { key = "call", icon = "phone", label = "Call" },
            { key = "message", icon = "message", label = "Message" },
            { key = "share", icon = "share", label = "Share trip" },
            { key = "safety", icon = "shield", label = "Safety" },
        }

        local marks = {}

        for index = 1, #actions do
            local action = actions[index]

            marks[index] = gui.Pressable {
                key = action.key,
                style = { grow = 1, align = "center", gap = 6, minHeight = 64, justify = "center" },
                accessibilityLabel = action.label,
                onPress = function() self:setState({ screen = "home", going = gui.none }) end,

                gui.View {
                    style = { width = 44, height = 44, radius = 999, background = "surface",
                        align = "center", justify = "center" },
                    gui.Icon { name = action.icon, size = 20, color = "text" },
                },
                gui.Text {
                    text = action.label,
                    numberOfLines = 1,
                    style = { fontSize = "caption", color = "textMuted" },
                },
            }
        end

        return gui.View { style = { grow = 1, background = "background" },
            Map { style = { grow = 1 }, route = true },

            gui.View {
                style = { position = "absolute", left = 0, right = 0, bottom = 0, background = "elevated",
                    radius = "lg", paddingTop = "md", paddingBottom = insets.bottom + 16, gap = "sm",
                    shadow = "lg" },

                gui.Text {
                    text = ride.arrives .. " min away",
                    style = { fontSize = "title", fontWeight = "700", paddingHorizontal = "md" },
                },

                gui.View {
                    style = { direction = "row", align = "center", gap = "sm", paddingHorizontal = "md" },

                    gui.Avatar { source = "face-three.png", size = 56 },

                    gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                        gui.Text { text = "Marcos", style = { fontWeight = "700", fontSize = "headline" } },
                        gui.View { style = { direction = "row", align = "center", gap = 4 },
                            gui.Icon { name = "star", size = 12, color = "warning" },
                            gui.Text { text = "4,92", style = { fontSize = "footnote", color = "textMuted" } },
                            gui.Text {
                                text = "• 2.418 trips",
                                style = { fontSize = "footnote", color = "textMuted" },
                            },
                        },
                    },

                    gui.View { style = { align = "end", gap = 2 },
                        gui.Text { text = "Grey Onix", numberOfLines = 1, style = { fontWeight = "600" } },
                        gui.View {
                            style = { background = "text", radius = "sm", paddingHorizontal = 8,
                                paddingVertical = 2 },
                            gui.Text {
                                text = "RTQ 4D18",
                                numberOfLines = 1,
                                style = { color = "onPrimary", fontSize = "caption", fontWeight = "700",
                                    letterSpacing = 0.5 },
                            },
                        },
                    },
                },

                gui.Divider { color = "separator" },

                gui.View { style = { direction = "row" }, table.unpack(marks) },

                gui.Button {
                    style = { marginHorizontal = "md" },
                    variant = "tinted",
                    title = "Cancel the ride",
                    onPress = function() self:setState({ screen = "home", going = gui.none }) end,
                },
            },
        }
    end,

    --- The places a rider keeps, which is the one screen behind the menu.
    Saved = function(self)
        local rows = {}

        for index = 1, #PLACES do
            rows[index] = self:PlaceRow(PLACES[index], function()
                self:setState({ screen = "ride", going = PLACES[index].key })
            end)
        end

        return gui.ScrollView {
            style = { grow = 1, background = "background" },
            contentStyle = { paddingVertical = "sm" },
            table.unpack(rows),
        }
    end,

    screens = function(self)
        local screens = {
            { key = "home", title = "Hail", content = self:Home(), hidesBar = true },
        }

        if self.state.screen == "search" then
            screens[2] = { key = "search", title = "Where to?", content = self:Search() }
            return screens
        end

        if self.state.screen == "saved" then
            screens[2] = { key = "saved", title = "Saved places", content = self:Saved() }
            return screens
        end

        if self.state.screen == "ride" or self.state.screen == "trip" then
            screens[2] = { key = "ride", title = "Choose a ride", content = self:Ride() }

            if self.state.screen == "trip" then
                screens[3] = { key = "trip", title = "On the way", content = self:Trip() }
            end
        end

        return screens
    end,

    back = function(self)
        if self.state.screen == "trip" then
            self:setState({ screen = "ride" })
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

return Hail
