local gui = require("gui")

--- A food delivery application, from the address at the top through to a bag with a total in it.
---
--- What makes one of these read as the real thing is the density rather than the colour: a row carries
--- the picture, the name, the rating, the kind of food, how far it is, how long it takes and what
--- delivery costs, all inside seventy-two points, and a reader takes all seven in without reading any of
--- them. Everything here is drawn by the library and the pictures come from `tools/draw-scenes.py`.
local LOOK = gui.theme.define({
    name = "plate",
    radii = { sm = 6, md = 10, lg = 16, pill = 999 },
    spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 32 },
    light = {
        colors = {
            primary = "#ea1d2c", onPrimary = "#ffffff", background = "#ffffff", surface = "#f7f7f7",
            elevated = "#ffffff", text = "#3f3e3e", textMuted = "#717171", border = "#e6e6e6",
            separator = "#00000012", success = "#50a773", warning = "#f4a629", danger = "#ea1d2c",
        },
    },
    dark = {
        colors = {
            primary = "#ff5763", onPrimary = "#31060a", background = "#141414", surface = "#1f1f1f",
            elevated = "#262626", text = "#f2f2f2", textMuted = "#a3a3a3", border = "#333333",
            separator = "#ffffff14", success = "#6fc294", warning = "#f6bb5c", danger = "#ff5763",
        },
    },
})

local CATEGORIES = {
    { key = "burger", name = "Burgers", picture = "dish-burger.png" },
    { key = "pizza", name = "Pizza", picture = "dish-pizza.png" },
    { key = "sushi", name = "Japanese", picture = "dish-sushi.png" },
    { key = "salad", name = "Healthy", picture = "dish-salad.png" },
    { key = "noodles", name = "Asian", picture = "dish-noodles.png" },
    { key = "dessert", name = "Sweets", picture = "dish-dessert.png" },
}

local OFFERS = {
    { key = "two", title = "Two for one", place = "Grill House", cut = "50% off", picture = "dish-burger.png" },
    { key = "free", title = "Free delivery", place = "Verde Bowl", cut = "Free", picture = "dish-salad.png" },
    { key = "night", title = "After nine", place = "Forno Vivo", cut = "30% off", picture = "dish-pizza.png" },
}

local PLACES = {
    {
        key = "grill",
        name = "Grill House",
        picture = "place-grill.png",
        cover = "cover-grill.png",
        cuisine = "Burgers",
        rating = 4.8,
        distance = 1.2,
        fastest = 25,
        slowest = 35,
        fee = 0,
        sections = { "Burgers", "Sides", "Drinks" },
        dishes = {
            { key = "double", section = 1, name = "Double smash", price = 38.9, picture = "dish-burger.png",
                blurb = "Two smashed patties, aged cheese, pickles and the house sauce in a brioche bun." },
            { key = "classic", section = 1, name = "Classic cheese", price = 29.9, picture = "dish-burger.png",
                blurb = "One patty, cheddar, salad and tomato, which is the one everybody orders." },
            { key = "fries", section = 2, name = "Fries with herbs", price = 16.5, picture = "dish-salad.png",
                blurb = "Cut thick, twice fried, salted while hot and finished with rosemary." },
            { key = "shake", section = 3, name = "Malt shake", price = 18, picture = "dish-dessert.png",
                blurb = "Thick enough to stand a spoon in, in vanilla, chocolate or strawberry." },
        },
    },
    {
        key = "forno",
        name = "Forno Vivo",
        picture = "place-pasta.png",
        cover = "cover-pasta.png",
        cuisine = "Pizza",
        rating = 4.6,
        distance = 2.4,
        fastest = 35,
        slowest = 50,
        fee = 6.99,
        sections = { "Pizza", "Pasta", "Drinks" },
        dishes = {
            { key = "margherita", section = 1, name = "Margherita", price = 44, picture = "dish-pizza.png",
                blurb = "San Marzano tomato, mozzarella torn by hand and basil put on as it leaves." },
            { key = "pepperoni", section = 1, name = "Pepperoni", price = 52, picture = "dish-pizza.png",
                blurb = "Cured sausage that curls and crisps at the edges, on a base left to rise overnight." },
            { key = "carbonara", section = 2, name = "Carbonara", price = 48, picture = "dish-noodles.png",
                blurb = "Egg, pecorino, guanciale and pepper, with nothing else in it at all." },
        },
    },
    {
        key = "kaisen",
        name = "Kaisen Bar",
        picture = "place-sushi.png",
        cover = "cover-sushi.png",
        cuisine = "Japanese",
        rating = 4.9,
        distance = 3.1,
        fastest = 40,
        slowest = 55,
        fee = 9.9,
        sections = { "Sets", "Hot", "Drinks" },
        dishes = {
            { key = "set", section = 1, name = "Twenty piece set", price = 89, picture = "dish-sushi.png",
                blurb = "Salmon, tuna, hamachi and shrimp, cut to order and set on rice seasoned that morning." },
            { key = "ramen", section = 2, name = "Shoyu ramen", price = 46, picture = "dish-noodles.png",
                blurb = "A clear broth built over twelve hours, thin noodles, pork belly and a soft egg." },
        },
    },
    {
        key = "verde",
        name = "Verde Bowl",
        picture = "place-green.png",
        cover = "cover-green.png",
        cuisine = "Healthy",
        rating = 4.7,
        distance = 0.8,
        fastest = 20,
        slowest = 30,
        fee = 0,
        sections = { "Bowls", "Juices" },
        dishes = {
            { key = "bowl", section = 1, name = "Green bowl", price = 34, picture = "dish-salad.png",
                blurb = "Quinoa, avocado, cucumber, seeds and a lemon dressing, in a bowl you can lift." },
            { key = "juice", section = 2, name = "Cold pressed", price = 16, picture = "dish-salad.png",
                blurb = "Apple, ginger and mint, pressed rather than blended, so nothing separates." },
        },
    },
    {
        key = "doce",
        name = "Casa Doce",
        picture = "place-sweets.png",
        cover = "cover-sweets.png",
        cuisine = "Sweets",
        rating = 4.5,
        distance = 1.9,
        fastest = 30,
        slowest = 45,
        fee = 4.99,
        sections = { "Cakes", "Ice cream" },
        dishes = {
            { key = "slice", section = 1, name = "Chocolate slice", price = 22, picture = "dish-dessert.png",
                blurb = "Four layers, ganache between each of them, cut thick and served cold." },
            { key = "scoop", section = 2, name = "Two scoops", price = 19, picture = "dish-dessert.png",
                blurb = "Churned the same day, in whatever three the counter has that afternoon." },
        },
    },
    {
        key = "padaria",
        name = "Pão da Esquina",
        picture = "place-bakery.png",
        cover = "cover-bakery.png",
        cuisine = "Bakery",
        rating = 4.4,
        distance = 0.5,
        fastest = 15,
        slowest = 25,
        fee = 0,
        sections = { "Bread", "Coffee" },
        dishes = {
            { key = "loaf", section = 1, name = "Sourdough loaf", price = 24, picture = "dish-burger.png",
                blurb = "Left to prove for a day and baked dark, so the crust is worth the wait." },
            { key = "coffee", section = 2, name = "Coffee and milk", price = 11, picture = "dish-dessert.png",
                blurb = "Pulled short and let down with steamed milk, which is how it is drunk here." },
        },
    },
}

--- Answers a price the way it is written where these applications are used.
local function money(amount)
    local written = string.format("R$ %.2f", amount)

    return (written:gsub("%.", ","))
end

--- Answers a number to one place, written the same way, with whatever unit follows it.
local function decimal(value, unit)
    local written = string.format("%.1f", value)

    return (written:gsub("%.", ",")) .. unit
end

local function find(key)
    for index = 1, #PLACES do
        if PLACES[index].key == key then
            return PLACES[index]
        end
    end

    return nil
end

local function dishOf(place, key)
    for index = 1, #place.dishes do
        if place.dishes[index].key == key then
            return place.dishes[index]
        end
    end

    return nil
end

local Plate = gui.component({
    name = "Plate",
    state = {
        screen = "home",
        place = nil,
        dish = nil,
        section = 1,
        quantity = 1,
        bag = {},
        search = "",
    },

    --- Answers what is in the bag as lines, since it is held as a count against a place and a dish.
    lines = function(self)
        local lines = {}

        for _, held in pairs(self.state.bag) do
            lines[#lines + 1] = held
        end

        table.sort(lines, function(one, other) return one.key < other.key end)
        return lines
    end,

    total = function(self)
        local total = 0

        for _, line in ipairs(self:lines()) do
            total = total + line.price * line.count
        end

        return total
    end,

    counted = function(self)
        local count = 0

        for _, line in ipairs(self:lines()) do
            count = count + line.count
        end

        return count
    end,

    add = function(self)
        local place = find(self.state.place)
        local dish = dishOf(place, self.state.dish)
        local key = place.key .. "/" .. dish.key
        local bag = {}

        for held, entry in pairs(self.state.bag) do
            bag[held] = entry
        end

        local before = bag[key]

        bag[key] = {
            key = key,
            name = dish.name,
            place = place.name,
            picture = dish.picture,
            price = dish.price,
            count = (before ~= nil and before.count or 0) + self.state.quantity,
        }

        self:setState({ bag = bag, screen = "bag" })
    end,

    change = function(self, key, count)
        local bag = {}

        for held, entry in pairs(self.state.bag) do
            bag[held] = entry
        end

        if count <= 0 then
            bag[key] = nil
        else
            local entry = bag[key]
            bag[key] = {
                key = entry.key, name = entry.name, place = entry.place,
                picture = entry.picture, price = entry.price, count = count,
            }
        end

        self:setState({ bag = bag })
    end,

    openPlace = function(self, key)
        self:setState({ screen = "place", place = key, section = 1 })
    end,

    openDish = function(self, key)
        self:setState({ screen = "dish", dish = key, quantity = 1 })
    end,

    --- The band across the top, which is the address, the bag and the search in one block of red.
    ---
    --- It runs up under whatever the system draws over the top of the glass rather than starting below
    --- it, which is what makes it read as a header rather than as a red box on a screen.
    Header = function(self)
        local insets = gui.environment:read(self).insets
        local waiting = self:counted()

        return gui.View {
            style = { background = "primary", paddingTop = insets.top + 8, paddingBottom = "sm",
                paddingHorizontal = "md", gap = "sm" },

            gui.View { style = { direction = "row", align = "center", gap = "sm" },
                gui.Pressable {
                    style = { grow = 1, direction = "row", align = "center", gap = 6, minHeight = 44 },
                    accessibilityLabel = "Deliver to Rua das Palmeiras, 220",
                    onPress = function() self:setState({ screen = "address" }) end,

                    gui.Icon { name = "pin", size = 18, color = "onPrimary" },
                    gui.View { style = { shrink = 1 },
                        gui.Text {
                            text = "Deliver to",
                            style = { fontSize = "caption", color = "#ffffffcc" },
                        },
                        gui.Text {
                            text = "Rua das Palmeiras, 220",
                            numberOfLines = 1,
                            style = { fontWeight = "700", color = "onPrimary" },
                        },
                    },
                    gui.Icon { name = "chevron-down", size = 16, color = "onPrimary" },
                },

                gui.Pressable {
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Bag",
                    onPress = function() self:setState({ screen = "bag" }) end,

                    gui.Icon { name = "bag", size = 24, color = "onPrimary" },
                    waiting > 0 and gui.View {
                        key = "count",
                        style = { position = "absolute", top = 4, right = 2 },
                        gui.Badge { value = waiting, color = "#ffffff", textColor = "#ea1d2c" },
                    } or false,
                },
            },

            gui.View {
                style = { direction = "row", align = "center", gap = "xs", background = "elevated",
                    radius = "pill", paddingHorizontal = "sm", height = 40 },

                gui.Icon { name = "search", size = 18, color = "textMuted" },
                gui.TextInput {
                    style = { grow = 1, background = "transparent", paddingHorizontal = 0 },
                    placeholder = "Search for a place or a dish",
                    value = self.state.search,
                    accessibilityLabel = "Search",
                    onChange = function(value) self:setState({ search = value }) end,
                },
            },
        }
    end,

    --- The round marks, which is how every one of these opens: what you feel like rather than who sells it.
    Categories = function(self)
        return gui.ScrollView {
            horizontal = true,
            showsIndicator = false,
            style = { height = 104 },
            contentStyle = { direction = "row", gap = "md", paddingHorizontal = "md", paddingVertical = "sm",
                align = "start" },
            table.unpack((function()
                local marks = {}

                for index = 1, #CATEGORIES do
                    local category = CATEGORIES[index]

                    marks[index] = gui.Pressable {
                        key = category.key,
                        style = { width = 64, align = "center", gap = 6 },
                        accessibilityLabel = category.name,
                        onPress = function() self:setState({ search = category.name }) end,

                        gui.Image {
                            source = category.picture,
                            resizeMode = "cover",
                            style = { width = 56, height = 56, radius = 999, background = "surface" },
                        },
                        gui.Text {
                            text = category.name,
                            numberOfLines = 1,
                            style = { fontSize = "caption", color = "text", textAlign = "center" },
                        },
                    }
                end

                return marks
            end)()),
        }
    end,

    --- The offers, which are wide cards with the size of the discount cut into the corner.
    Offers = function(self)
        return gui.View { style = { gap = "xs" },
            gui.Text {
                text = "Offers for you",
                style = { fontWeight = "700", fontSize = "headline", paddingHorizontal = "md" },
            },

            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 168 },
                contentStyle = { direction = "row", gap = "sm", paddingHorizontal = "md", paddingVertical = "xs" },
                table.unpack((function()
                    local cards = {}

                    for index = 1, #OFFERS do
                        local offer = OFFERS[index]

                        cards[index] = gui.Pressable {
                            key = offer.key,
                            style = { width = 240, radius = "md", background = "elevated", overflow = "hidden",
                                shadow = "sm" },
                            accessibilityLabel = offer.title .. " at " .. offer.place,
                            onPress = function() self:setState({ search = offer.place }) end,

                            gui.Image {
                                source = offer.picture,
                                resizeMode = "cover",
                                style = { height = 104, background = "surface" },
                            },

                            gui.View {
                                style = { position = "absolute", top = 8, left = 8, background = "primary",
                                    radius = "sm", paddingHorizontal = 8, paddingVertical = 3 },
                                gui.Text {
                                    text = offer.cut,
                                    style = { color = "onPrimary", fontSize = "caption", fontWeight = "700" },
                                },
                            },

                            gui.View { style = { padding = "sm", gap = 1 },
                                gui.Text { text = offer.title, numberOfLines = 1, style = { fontWeight = "700" } },
                                gui.Text {
                                    text = offer.place,
                                    numberOfLines = 1,
                                    style = { fontSize = "footnote", color = "textMuted" },
                                },
                            },
                        }
                    end

                    return cards
                end)()),
            },
        }
    end,

    --- One place, as the seven things a reader takes in without reading any of them.
    PlaceRow = function(self, place)
        return gui.Pressable {
            style = { grow = 1, direction = "row", align = "center", gap = "sm", paddingHorizontal = "md" },
            accessibilityLabel = place.name,
            onPress = function() self:openPlace(place.key) end,

            gui.Image {
                source = place.picture,
                resizeMode = "cover",
                style = { width = 56, height = 56, radius = "sm", background = "surface" },
            },

            gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                gui.Text { text = place.name, numberOfLines = 1, style = { fontWeight = "600" } },

                gui.View { style = { direction = "row", align = "center", gap = 4 },
                    gui.Icon { name = "star", size = 12, color = "warning" },
                    gui.Text {
                        text = decimal(place.rating, ""),
                        style = { fontSize = "footnote", color = "warning", fontWeight = "600" },
                    },
                    gui.Text {
                        text = "• " .. place.cuisine .. " • " .. decimal(place.distance, " km"),
                        numberOfLines = 1,
                        style = { shrink = 1, fontSize = "footnote", color = "textMuted" },
                    },
                },

                gui.View { style = { direction = "row", align = "center", gap = 4 },
                    gui.Text {
                        text = place.fastest .. "-" .. place.slowest .. " min •",
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                    gui.Text {
                        text = place.fee == 0 and "Free" or money(place.fee),
                        style = { fontSize = "footnote", fontWeight = "600",
                            color = place.fee == 0 and "success" or "textMuted" },
                    },
                },
            },
        }
    end,

    --- Answers the places a search leaves, which is every one of them when nothing was typed.
    matching = function(self)
        local wanted = self.state.search:lower()

        if wanted == "" then
            return PLACES
        end

        local kept = {}

        for index = 1, #PLACES do
            local place = PLACES[index]

            if place.name:lower():find(wanted, 1, true) ~= nil
                or place.cuisine:lower():find(wanted, 1, true) ~= nil then
                kept[#kept + 1] = place
            end
        end

        return kept
    end,

    Home = function(self)
        local insets = gui.environment:read(self).insets
        local places = self:matching()

        return gui.View { style = { grow = 1, background = "background" },
            self:Header(),

            gui.List {
                style = { grow = 1 },
                data = places,
                itemExtent = 72,
                keyExtractor = function(place) return place.key end,
                separator = gui.Divider { color = "separator", inset = 84 },

                header = gui.View { style = { gap = "sm" },
                    self:Categories(),
                    gui.Divider { color = "separator" },
                    self:Offers(),
                    gui.Text {
                        text = "Places near you",
                        style = { fontWeight = "700", fontSize = "headline", paddingHorizontal = "md",
                            paddingTop = "sm" },
                    },
                },
                headerExtent = 332,

                empty = gui.View { style = { padding = "lg", align = "center", gap = "xs" },
                    gui.Text { text = "Nothing matches that", style = { fontWeight = "600" } },
                    gui.Text {
                        text = "Try the name of a place or a kind of food",
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },

                footer = gui.Spacer { size = insets.bottom + 16 },
                footerExtent = insets.bottom + 16,

                renderItem = function(place) return self:PlaceRow(place) end,
            },
        }
    end,

    --- One place, which is the cover, what it is, and its menu under a row of its own sections.
    Place = function(self)
        local place = find(self.state.place)
        local dishes = {}

        for index = 1, #place.dishes do
            if place.dishes[index].section == self.state.section then
                dishes[#dishes + 1] = place.dishes[index]
            end
        end

        return gui.ScrollView {
            style = { grow = 1, background = "background" },
            contentStyle = { paddingBottom = gui.environment:read(self).insets.bottom + 24 },

            gui.Image {
                source = place.cover,
                resizeMode = "cover",
                style = { height = 150, background = "surface" },
            },

            gui.View { style = { padding = "md", gap = "xs" },
                gui.Text { text = place.name, style = { fontSize = "title", fontWeight = "700" } },

                gui.View { style = { direction = "row", align = "center", gap = 6 },
                    gui.Icon { name = "star", size = 14, color = "warning" },
                    gui.Text {
                        text = decimal(place.rating, ""),
                        style = { color = "warning", fontWeight = "700" },
                    },
                    gui.Text {
                        text = "• " .. place.cuisine .. " • " .. decimal(place.distance, " km"),
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },

                gui.View { style = { direction = "row", align = "center", gap = 6 },
                    gui.Icon { name = "clock", size = 14, color = "textMuted" },
                    gui.Text {
                        text = "Today, " .. place.fastest .. "-" .. place.slowest .. " min •",
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                    gui.Text {
                        text = place.fee == 0 and "Free delivery" or money(place.fee),
                        style = { fontSize = "footnote", fontWeight = "600",
                            color = place.fee == 0 and "success" or "textMuted" },
                    },
                },
            },

            gui.Divider { color = "separator" },

            gui.View { style = { paddingHorizontal = "md", paddingVertical = "sm" },
                gui.SegmentedControl {
                    segments = place.sections,
                    selectedIndex = self.state.section,
                    accessibilityLabel = "Menu sections",
                    onChange = function(index) self:setState({ section = index }) end,
                },
            },

            table.unpack((function()
                local rows = {}

                for index = 1, #dishes do
                    local dish = dishes[index]

                    if index > 1 then
                        rows[#rows + 1] = gui.Divider { key = "rule" .. index, color = "separator", inset = 16 }
                    end

                    rows[#rows + 1] = gui.Pressable {
                        key = dish.key,
                        style = { direction = "row", align = "center", gap = "sm", padding = "md",
                            minHeight = 96 },
                        accessibilityLabel = dish.name,
                        onPress = function() self:openDish(dish.key) end,

                        gui.View { style = { grow = 1, shrink = 1, gap = 4 },
                            gui.Text { text = dish.name, numberOfLines = 1, style = { fontWeight = "600" } },
                            gui.Text {
                                text = dish.blurb,
                                numberOfLines = 2,
                                style = { fontSize = "footnote", color = "textMuted", lineHeight = 1.35 },
                            },
                            gui.Text { text = money(dish.price), style = { fontWeight = "700" } },
                        },

                        gui.Image {
                            source = dish.picture,
                            resizeMode = "cover",
                            style = { width = 72, height = 72, radius = "sm", background = "surface" },
                        },
                    }
                end

                return rows
            end)()),
        }
    end,

    --- One dish, which is a picture, what is in it, how many, and a button carrying the running total.
    Dish = function(self)
        local place = find(self.state.place)
        local dish = dishOf(place, self.state.dish)
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "background" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", paddingBottom = "lg" },

                gui.Image {
                    source = dish.picture,
                    resizeMode = "cover",
                    style = { height = 240, background = "surface" },
                },

                gui.View { style = { paddingHorizontal = "md", gap = "xs" },
                    gui.Text { text = dish.name, style = { fontSize = "title", fontWeight = "700" } },
                    gui.Text {
                        text = dish.blurb,
                        style = { color = "textMuted", lineHeight = 1.45 },
                    },
                    gui.Text { text = money(dish.price), style = { fontSize = "headline", fontWeight = "700" } },
                },

                gui.Divider { color = "separator" },

                gui.View { style = { paddingHorizontal = "md", gap = "xs" },
                    gui.Text { text = "Anything to say to the kitchen", style = { fontWeight = "600" } },
                    gui.TextArea {
                        rows = 3,
                        placeholder = "No onion, cut in half, leave it at the door",
                        accessibilityLabel = "Anything to say to the kitchen",
                    },
                },
            },

            gui.View {
                style = { direction = "row", align = "center", gap = "sm", padding = "md",
                    paddingBottom = insets.bottom + 16, background = "elevated", shadow = "md" },

                gui.Stepper {
                    value = self.state.quantity,
                    minimum = 1,
                    maximum = 20,
                    accessibilityLabel = "How many",
                    onChange = function(value) self:setState({ quantity = value }) end,
                },

                gui.Button {
                    style = { grow = 1 },
                    title = "Add " .. money(dish.price * self.state.quantity),
                    onPress = function() self:add() end,
                },
            },
        }
    end,

    Bag = function(self)
        local lines = self:lines()
        local insets = gui.environment:read(self).insets

        if #lines == 0 then
            return gui.View {
                style = { grow = 1, background = "background", justify = "center", align = "center",
                    gap = "sm", padding = "lg" },

                gui.Icon { name = "bag", size = 44, color = "textMuted" },
                gui.Text { text = "Your bag is empty", style = { fontSize = "headline", fontWeight = "700" } },
                gui.Text {
                    text = "Pick a place and add something to it",
                    style = { fontSize = "footnote", color = "textMuted", textAlign = "center" },
                },
                gui.Button {
                    title = "Find somewhere",
                    variant = "tinted",
                    style = { marginTop = "sm" },
                    onPress = function() self:setState({ screen = "home" }) end,
                },
            }
        end

        return gui.View { style = { grow = 1, background = "background" },
            gui.List {
                style = { grow = 1 },
                data = lines,
                itemExtent = 88,
                keyExtractor = function(line) return line.key end,
                separator = gui.Divider { color = "separator" },

                renderItem = function(line)
                    return gui.View {
                        style = { grow = 1, direction = "row", align = "center", gap = "sm",
                            paddingHorizontal = "md" },

                        gui.Image {
                            source = line.picture,
                            resizeMode = "cover",
                            style = { width = 56, height = 56, radius = "sm", background = "surface" },
                        },

                        gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                            gui.Text { text = line.name, numberOfLines = 1, style = { fontWeight = "600" } },
                            gui.Text {
                                text = line.place,
                                numberOfLines = 1,
                                style = { fontSize = "footnote", color = "textMuted" },
                            },
                            gui.Text { text = money(line.price * line.count), style = { fontWeight = "700" } },
                        },

                        gui.Stepper {
                            value = line.count,
                            minimum = 0,
                            maximum = 20,
                            accessibilityLabel = "How many " .. line.name,
                            onChange = function(value) self:change(line.key, value) end,
                        },
                    }
                end,
            },

            gui.View {
                style = { padding = "md", paddingBottom = insets.bottom + 16, gap = "sm",
                    background = "elevated", shadow = "md" },

                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text { text = "Items", style = { color = "textMuted" } },
                    gui.Text { text = money(self:total()), style = { color = "textMuted" } },
                },
                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text { text = "Delivery", style = { color = "textMuted" } },
                    gui.Text { text = "Free", style = { color = "success", fontWeight = "600" } },
                },
                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text { text = "Total", style = { fontWeight = "700", fontSize = "headline" } },
                    gui.Text { text = money(self:total()), style = { fontWeight = "700", fontSize = "headline" } },
                },

                gui.Button {
                    title = "Place the order",
                    onPress = function() self:setState({ screen = "ordered" }) end,
                },
            },
        }
    end,

    Address = function(self)
        local SAVED = {
            { key = "home", icon = "home", name = "Home", line = "Rua das Palmeiras, 220 — apt 42" },
            { key = "work", icon = "settings", name = "Work", line = "Av. Central, 1500 — floor 8" },
            { key = "gym", icon = "pin", name = "Gym", line = "Rua do Parque, 77" },
        }

        local rows = {}

        for index = 1, #SAVED do
            local saved = SAVED[index]

            rows[index] = gui.Pressable {
                key = saved.key,
                style = { direction = "row", align = "center", gap = "sm", paddingHorizontal = "md",
                    minHeight = 64 },
                accessibilityLabel = saved.name,
                onPress = function() self:setState({ screen = "home" }) end,

                gui.View {
                    style = { width = 40, height = 40, radius = 999, background = "surface",
                        align = "center", justify = "center" },
                    gui.Icon { name = saved.icon, size = 20, color = "primary" },
                },
                gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                    gui.Text { text = saved.name, style = { fontWeight = "600" } },
                    gui.Text {
                        text = saved.line,
                        numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },
                gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
            }
        end

        return gui.ScrollView {
            style = { grow = 1, background = "background" },
            contentStyle = { paddingVertical = "sm" },
            table.unpack(rows),
        }
    end,

    Ordered = function(self)
        return gui.View {
            style = { grow = 1, background = "background", justify = "center", align = "center",
                gap = "sm", padding = "lg" },

            gui.View {
                style = { width = 88, height = 88, radius = 999, background = "primary",
                    align = "center", justify = "center" },
                gui.Icon { name = "check", size = 44, color = "onPrimary" },
            },
            gui.Text { text = "Order placed", style = { fontSize = "title", fontWeight = "700" } },
            gui.Text {
                text = "It is with the kitchen now and arrives in about 30 minutes",
                style = { color = "textMuted", textAlign = "center" },
            },
            gui.Button {
                title = "Back to the start",
                variant = "tinted",
                style = { marginTop = "sm" },
                onPress = function() self:setState({ screen = "home", bag = {}, search = "" }) end,
            },
        }
    end,

    screens = function(self)
        local screens = {
            { key = "home", title = "Plate", content = self:Home(), hidesBar = true },
        }

        if self.state.screen == "address" then
            screens[2] = { key = "address", title = "Where it goes", content = self:Address() }
            return screens
        end

        if self.state.screen == "ordered" then
            screens[2] = { key = "ordered", title = "Order placed", content = self:Ordered() }
            return screens
        end

        if self.state.screen == "bag" then
            screens[2] = { key = "bag", title = "Your bag", content = self:Bag() }
            return screens
        end

        if self.state.screen == "place" or self.state.screen == "dish" then
            screens[2] = {
                key = "place",
                title = find(self.state.place).name,
                content = self:Place(),
            }

            if self.state.screen == "dish" then
                screens[3] = {
                    key = "dish",
                    title = dishOf(find(self.state.place), self.state.dish).name,
                    content = self:Dish(),
                }
            end
        end

        return screens
    end,

    back = function(self)
        if self.state.screen == "dish" then
            self:setState({ screen = "place" })
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

return Plate
