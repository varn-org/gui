local gui = require("gui")

--- A marketplace application, which is the densest of the five and deliberately so.
---
--- Nothing on one of these screens is given room. A search bar, a row of categories, a carousel, a band
--- of the day's deals and a two-across grid all fit above the fold, and the price block alone carries
--- four separate facts: what it costs, what it cost, the instalments and whether delivery is free. That
--- crowding is the product rather than a fault in it, so the copy keeps it.
local LOOK = gui.theme.define({
    name = "bazaar",
    radii = { sm = 4, md = 6, lg = 10, pill = 999 },
    spacing = { xs = 4, sm = 8, md = 12, lg = 20, xl = 28 },
    typography = { lineHeight = 1.3 },
    light = {
        colors = {
            primary = "#3483fa", onPrimary = "#ffffff", background = "#ebebeb", surface = "#ffffff",
            elevated = "#ffffff", text = "#333333", textMuted = "#767676", border = "#e0e0e0",
            separator = "#00000012", success = "#00a650", warning = "#fff159", danger = "#f23d4f",
        },
    },
    dark = {
        colors = {
            primary = "#63a3ff", onPrimary = "#05244f", background = "#101114", surface = "#1a1c20",
            elevated = "#22252a", text = "#ededed", textMuted = "#9a9a9a", border = "#2e3138",
            separator = "#ffffff12", success = "#3ecb82", warning = "#ffe14d", danger = "#ff6b79",
        },
    },
})

--- The band across the top, which is the one part of this that is not blue.
local YELLOW = "#fff159"

--- What a second button is filled with, since a card and a page are both already white here.
---
--- A tinted button takes the look's surface, which is what a card is, so one standing on a card had
--- nothing to stand out against at all. What a marketplace fills a second button with is a wash of the
--- same blue as the first.
local TINT = "#e3edfd"

local CATEGORIES = {
    { key = "phones", name = "Phones", icon = "phone" },
    { key = "sound", name = "Sound", icon = "headset" },
    { key = "photo", name = "Photo", icon = "camera" },
    { key = "games", name = "Games", icon = "play" },
    { key = "home", name = "Home", icon = "home" },
    { key = "sport", name = "Sport", icon = "compass" },
}

local GOODS = {
    {
        key = "phone",
        name = "Smartphone Aurora 12 256 GB 8 GB RAM, unlocked, dual chip",
        price = 2799,
        was = 3899,
        picture = "good-phone.png",
        pictures = { "good-phone.png", "good-watch.png", "good-headset.png" },
        seller = "AuroraStore",
        sold = 1284,
        stock = 12,
        rating = 4.7,
        reviews = 3921,
        blurb = "A 6.7 inch screen, three cameras and a battery that lasts a day and a half.",
    },
    {
        key = "headset",
        name = "Wireless over-ear headphones with active noise cancelling",
        price = 649,
        was = 999,
        picture = "good-headset.png",
        pictures = { "good-headset.png", "good-phone.png" },
        seller = "SomLivre",
        sold = 842,
        stock = 5,
        rating = 4.6,
        reviews = 1140,
        blurb = "Thirty hours on a charge, and folds flat into the case it comes with.",
    },
    {
        key = "watch",
        name = "Smart watch with heart rate, GPS and five day battery",
        price = 899,
        was = 1299,
        picture = "good-watch.png",
        pictures = { "good-watch.png", "good-phone.png" },
        seller = "AuroraStore",
        sold = 2310,
        stock = 40,
        rating = 4.4,
        reviews = 5602,
        blurb = "Reads your pulse every second and tells you when you have been sitting too long.",
    },
    {
        key = "camera",
        name = "Mirrorless camera with 24 MP sensor and 18-55 lens",
        price = 4290,
        was = 5199,
        picture = "good-camera.png",
        pictures = { "good-camera.png", "good-console.png" },
        seller = "FotoPonto",
        sold = 318,
        stock = 3,
        rating = 4.9,
        reviews = 402,
        blurb = "Small enough to carry every day, with a sensor that does not mind a dark room.",
    },
    {
        key = "console",
        name = "Game console with wireless controller and two games",
        price = 3499,
        was = 3999,
        picture = "good-console.png",
        pictures = { "good-console.png", "good-headset.png" },
        seller = "PlayMais",
        sold = 967,
        stock = 8,
        rating = 4.8,
        reviews = 2280,
        blurb = "Loads in seconds and comes with the two everybody buys it for anyway.",
    },
    {
        key = "shoe",
        name = "Running shoes with cushioned sole, sizes 38 to 45",
        price = 429,
        was = 649,
        picture = "good-shoe.png",
        pictures = { "good-shoe.png", "good-watch.png" },
        seller = "PasseLivre",
        sold = 5120,
        stock = 60,
        rating = 4.3,
        reviews = 8814,
        blurb = "Light, wide at the toe, and the sole holds up past six hundred kilometres.",
    },
}

local function money(amount)
    local whole = string.format("%d", math.floor(amount))
    local marked = whole:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")

    return "R$ " .. marked
end

local function off(good)
    return math.floor((good.was - good.price) / good.was * 100 + 0.5) .. "% OFF"
end

local function find(key)
    for index = 1, #GOODS do
        if GOODS[index].key == key then
            return GOODS[index]
        end
    end

    return nil
end

local Bazaar = gui.component({
    name = "Bazaar",
    state = { screen = "home", looking = nil, picture = 1, search = "", basket = {}, filter = 1 },

    lines = function(self)
        local lines = {}

        for _, held in pairs(self.state.basket) do
            lines[#lines + 1] = held
        end

        table.sort(lines, function(one, other) return one.key < other.key end)
        return lines
    end,

    total = function(self)
        local total = 0

        for _, line in ipairs(self:lines()) do
            total = total + line.good.price * line.count
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

    add = function(self, andBuy)
        local good = find(self.state.looking)
        local basket = {}

        for key, entry in pairs(self.state.basket) do
            basket[key] = entry
        end

        local before = basket[good.key]

        basket[good.key] = { key = good.key, good = good, count = (before ~= nil and before.count or 0) + 1 }

        self:setState({ basket = basket, screen = andBuy and "basket" or self.state.screen })
    end,

    change = function(self, key, count)
        local basket = {}

        for held, entry in pairs(self.state.basket) do
            basket[held] = entry
        end

        if count <= 0 then
            basket[key] = nil
        else
            basket[key] = { key = key, good = basket[key].good, count = count }
        end

        self:setState({ basket = basket })
    end,

    open = function(self, key)
        self:setState({ screen = "product", looking = key, picture = 1 })
    end,

    --- The yellow band, which is the search, the barcode mark and the basket.
    Header = function(self, backable)
        local insets = gui.environment:read(self).insets
        local waiting = self:counted()

        return gui.View {
            style = { background = YELLOW, paddingTop = insets.top + 8, paddingBottom = "sm",
                paddingHorizontal = "sm", gap = "xs" },

            gui.View { style = { direction = "row", align = "center", gap = "xs" },
                backable and gui.Pressable {
                    key = "back",
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Back",
                    onPress = function() self:setState({ screen = "home" }) end,
                    gui.Icon { name = "arrow-left", size = 22, color = "#333333" },
                } or false,

                gui.Pressable {
                    style = { grow = 1, direction = "row", align = "center", gap = "xs", height = 44,
                        radius = "sm", background = "#ffffff", paddingHorizontal = "sm" },
                    accessibilityLabel = "Search",
                    onPress = function() self:setState({ screen = "results" }) end,

                    gui.Icon { name = "search", size = 18, color = "#767676" },
                    gui.Text {
                        text = self.state.search ~= "" and self.state.search or "Search on Bazaar",
                        numberOfLines = 1,
                        style = { grow = 1, color = self.state.search ~= "" and "#333333" or "#767676" },
                    },
                    gui.Icon { name = "barcode", size = 18, color = "#767676" },
                },

                gui.Pressable {
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    accessibilityLabel = "Basket",
                    onPress = function() self:setState({ screen = "basket" }) end,

                    gui.Icon { name = "cart", size = 22, color = "#333333" },
                    waiting > 0 and gui.View {
                        key = "count",
                        style = { position = "absolute", top = 2, right = 0 },
                        gui.Badge { value = waiting, color = "#3483fa", textColor = "#ffffff" },
                    } or false,
                },
            },

            gui.View { style = { direction = "row", align = "center", gap = 4, paddingHorizontal = 4 },
                gui.Icon { name = "pin", size = 14, color = "#333333" },
                gui.Text {
                    text = "Deliver to Rua das Palmeiras, 220",
                    numberOfLines = 1,
                    style = { grow = 1, fontSize = "caption", color = "#333333" },
                },
                gui.Icon { name = "chevron-right", size = 12, color = "#333333" },
            },
        }
    end,

    Categories = function(self)
        local marks = {}

        for index = 1, #CATEGORIES do
            local category = CATEGORIES[index]

            marks[index] = gui.Pressable {
                key = category.key,
                style = { width = 64, align = "center", gap = 4, minHeight = 76, justify = "center" },
                accessibilityLabel = category.name,
                onPress = function() self:setState({ screen = "results", search = category.name }) end,

                gui.View {
                    style = { width = 48, height = 48, radius = 999, background = "surface",
                        align = "center", justify = "center" },
                    gui.Icon { name = category.icon, size = 22, color = "primary" },
                },
                gui.Text {
                    text = category.name,
                    numberOfLines = 1,
                    style = { fontSize = "caption", color = "text", textAlign = "center" },
                },
            }
        end

        return gui.ScrollView {
            horizontal = true,
            showsIndicator = false,
            style = { height = 92, background = "surface" },
            contentStyle = { direction = "row", gap = "xs", paddingHorizontal = "sm", align = "center" },
            table.unpack(marks),
        }
    end,

    --- The carousel, which is the only part of one of these screens with room around it.
    Offers = function(self)
        return gui.Carousel {
            style = { height = 150, background = "surface" },
            data = GOODS,
            itemExtent = 320,
            keyExtractor = function(good) return good.key end,
            indicator = true,
            loop = true,
            renderItem = function(good)
                return gui.Pressable {
                    style = { grow = 1, direction = "row", align = "center", gap = "sm", padding = "sm" },
                    accessibilityLabel = good.name,
                    onPress = function() self:open(good.key) end,

                    gui.Image {
                        source = good.picture,
                        resizeMode = "contain",
                        style = { width = 110, height = 110 },
                    },

                    gui.View { style = { grow = 1, shrink = 1, gap = 4 },
                        gui.View {
                            style = { background = "success", radius = "sm", alignSelf = "start",
                                paddingHorizontal = 6, paddingVertical = 2 },
                            gui.Text {
                                text = off(good),
                                style = { color = "#ffffff", fontSize = "caption", fontWeight = "700" },
                            },
                        },
                        gui.Text { text = good.name, numberOfLines = 2, style = { fontSize = "footnote" } },
                        gui.Text { text = money(good.price), style = { fontSize = "headline", fontWeight = "600" } },
                    },
                }
            end,
        }
    end,

    --- One card of the deals row, which is the shape the whole of one of these applications is built from.
    Card = function(self, good, width)
        return gui.Pressable {
            key = good.key,
            style = { width = width, background = "surface", radius = "sm", padding = "sm", gap = 4 },
            accessibilityLabel = good.name,
            onPress = function() self:open(good.key) end,

            gui.Image {
                source = good.picture,
                resizeMode = "contain",
                style = { height = 120 },
            },

            gui.View { style = { direction = "row", align = "center", gap = 4 },
                gui.Text {
                    text = money(good.was),
                    style = { fontSize = "caption", color = "textMuted", textDecoration = "line-through" },
                },
                gui.Text {
                    text = off(good),
                    style = { fontSize = "caption", color = "success", fontWeight = "700" },
                },
            },

            gui.Text { text = money(good.price), style = { fontSize = "headline", fontWeight = "600" } },
            gui.Text {
                text = "12x " .. money(good.price / 12) .. " no interest",
                numberOfLines = 1,
                style = { fontSize = "caption", color = "success" },
            },
            gui.Text { text = good.name, numberOfLines = 2, style = { fontSize = "footnote", color = "textMuted" } },
        }
    end,

    Deals = function(self)
        local cards = {}

        for index = 1, #GOODS do
            cards[index] = self:Card(GOODS[index], 150)
        end

        return gui.View { style = { background = "surface", paddingVertical = "sm", gap = "xs" },
            gui.View {
                style = { direction = "row", align = "center", justify = "space-between",
                    paddingHorizontal = "sm" },
                gui.Text { text = "Deals of the day", style = { fontWeight = "700", fontSize = "headline" } },
                gui.Text { text = "See all", style = { color = "primary", fontSize = "footnote" } },
            },

            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 288 },
                contentStyle = { direction = "row", gap = "xs", paddingHorizontal = "sm" },
                table.unpack(cards),
            },
        }
    end,

    Home = function(self)
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "background" },
            self:Header(false),

            gui.Grid {
                style = { grow = 1 },
                data = GOODS,
                columns = 2,
                spacing = 8,
                rowExtent = 268,
                keyExtractor = function(good) return good.key end,

                header = gui.View { style = { gap = "xs" },
                    self:Categories(),
                    self:Offers(),
                    self:Deals(),
                    gui.Text {
                        text = "Because you looked at phones",
                        style = { fontWeight = "700", fontSize = "headline", paddingHorizontal = "sm",
                            paddingTop = "xs" },
                    },
                },
                headerExtent = 592,

                footer = gui.Spacer { size = insets.bottom + 16 },
                footerExtent = insets.bottom + 16,

                renderItem = function(good) return self:Card(good, nil) end,
            },
        }
    end,

    --- The product, which is the picture carousel over four separate facts about the price.
    Product = function(self)
        local good = find(self.state.looking)
        local insets = gui.environment:read(self).insets
        return gui.View { style = { grow = 1, background = "background" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "xs", paddingBottom = "md" },

                gui.View { style = { background = "surface", paddingVertical = "sm" },
                    gui.Carousel {
                        style = { height = 300 },
                        data = good.pictures,
                        keyExtractor = function(_, index) return tostring(index) end,
                        index = self.state.picture,
                        onIndexChange = function(index) self:setState({ picture = index }) end,
                        renderItem = function(picture)
                            return gui.Image {
                                source = picture,
                                resizeMode = "contain",
                                style = { grow = 1 },
                            }
                        end,
                    },

                },

                gui.View { style = { background = "surface", padding = "sm", gap = "xs" },
                    gui.Text {
                        text = "New • " .. good.sold .. " sold",
                        style = { fontSize = "caption", color = "textMuted" },
                    },
                    gui.Text { text = good.name, style = { fontSize = "headline", lineHeight = 1.3 } },

                    gui.View { style = { direction = "row", align = "center", gap = 4 },
                        gui.Text {
                            text = string.format("%.1f", good.rating),
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                        gui.Rating { value = good.rating, size = 13, color = "primary" },
                        gui.Text {
                            text = "(" .. good.reviews .. ")",
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },

                    gui.Text {
                        text = money(good.was),
                        style = { fontSize = "footnote", color = "textMuted", textDecoration = "line-through" },
                    },

                    gui.View { style = { direction = "row", align = "center", gap = "xs" },
                        gui.Text { text = money(good.price), style = { fontSize = "title", fontWeight = "400" } },
                        gui.Text { text = off(good), style = { color = "success", fontWeight = "600" } },
                    },

                    gui.Text {
                        text = "in 12x " .. money(good.price / 12) .. " with no interest",
                        style = { color = "success", fontSize = "footnote" },
                    },

                    gui.Divider { color = "separator", inset = 0 },

                    gui.View { style = { direction = "row", align = "center", gap = 6 },
                        gui.Icon { name = "check", size = 16, color = "success" },
                        gui.View { style = { grow = 1, shrink = 1 },
                            gui.Text { text = "Free delivery", style = { color = "success", fontWeight = "600" } },
                            gui.Text {
                                text = "Arrives tomorrow if you buy in the next four hours",
                                style = { fontSize = "footnote", color = "textMuted" },
                            },
                        },
                    },

                    gui.Text {
                        text = "Sold by " .. good.seller,
                        style = { fontSize = "footnote", color = "primary" },
                    },
                    gui.Text {
                        text = good.stock <= 5 and ("Only " .. good.stock .. " left")
                            or (good.stock .. " in stock"),
                        style = { fontSize = "footnote", fontWeight = "600",
                            color = good.stock <= 5 and "danger" or "textMuted" },
                    },
                },

                gui.View { style = { background = "surface", padding = "sm", gap = "xs" },
                    gui.Text { text = "What it is", style = { fontWeight = "700", fontSize = "headline" } },
                    gui.Text { text = good.blurb, style = { color = "textMuted", lineHeight = 1.45 } },
                },
            },

            gui.View {
                style = { padding = "sm", paddingBottom = insets.bottom + 12, gap = "xs",
                    background = "surface", shadow = "md" },

                gui.Button { title = "Buy now", onPress = function() self:add(true) end },
                gui.Button {
                    title = "Add to the basket",
                    variant = "tinted",
                    style = { background = TINT },
                    onPress = function() self:add(false) end,
                },
            },
        }
    end,

    --- What a search left, with the filter row every one of these puts above it.
    Results = function(self)
        local FILTERS = { "Relevance", "Cheapest", "Best rated", "Free delivery" }
        local insets = gui.environment:read(self).insets
        local wanted = self.state.search:lower()
        local kept = {}

        for index = 1, #GOODS do
            if wanted == "" or GOODS[index].name:lower():find(wanted, 1, true) ~= nil then
                kept[#kept + 1] = GOODS[index]
            end
        end

        if self.state.filter == 2 then
            table.sort(kept, function(one, other) return one.price < other.price end)
        end

        if self.state.filter == 3 then
            table.sort(kept, function(one, other) return one.rating > other.rating end)
        end

        local chips = {}

        for index = 1, #FILTERS do
            chips[index] = gui.Chip {
                key = FILTERS[index],
                label = FILTERS[index],
                selected = index == self.state.filter,
                onPress = function() self:setState({ filter = index }) end,
            }
        end

        return gui.View { style = { grow = 1, background = "background" },
            self:Header(true),

            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 56, background = "surface" },
                contentStyle = { direction = "row", gap = "xs", paddingHorizontal = "sm", align = "center" },
                table.unpack(chips),
            },

            gui.List {
                style = { grow = 1 },
                data = kept,
                itemExtent = 148,
                keyExtractor = function(good) return good.key end,
                separator = gui.Divider { color = "separator" },

                empty = gui.View { style = { padding = "lg", align = "center", gap = "xs" },
                    gui.Text { text = "Nothing matches that", style = { fontWeight = "600" } },
                    gui.Text {
                        text = "Try fewer words",
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },

                footer = gui.Spacer { size = insets.bottom + 16 },
                footerExtent = insets.bottom + 16,

                renderItem = function(good)
                    return gui.Pressable {
                        style = { grow = 1, direction = "row", gap = "sm", padding = "sm",
                            background = "surface" },
                        accessibilityLabel = good.name,
                        onPress = function() self:open(good.key) end,

                        gui.Image {
                            source = good.picture,
                            resizeMode = "contain",
                            style = { width = 116, height = 116 },
                        },

                        gui.View { style = { grow = 1, shrink = 1, gap = 3 },
                            gui.Text { text = good.name, numberOfLines = 2, style = { fontSize = "footnote" } },
                            gui.Text {
                                text = money(good.was),
                                style = { fontSize = "caption", color = "textMuted",
                                    textDecoration = "line-through" },
                            },
                            gui.View { style = { direction = "row", align = "center", gap = 4 },
                                gui.Text { text = money(good.price), style = { fontSize = "headline" } },
                                gui.Text {
                                    text = off(good),
                                    style = { fontSize = "caption", color = "success", fontWeight = "700" },
                                },
                            },
                            gui.Text {
                                text = "Free delivery",
                                style = { fontSize = "caption", color = "success", fontWeight = "600" },
                            },
                        },
                    }
                end,
            },
        }
    end,

    Basket = function(self)
        local lines = self:lines()
        local insets = gui.environment:read(self).insets

        if #lines == 0 then
            return gui.View {
                style = { grow = 1, background = "background", justify = "center", align = "center",
                    gap = "sm", padding = "lg" },

                gui.Icon { name = "cart", size = 44, color = "textMuted" },
                gui.Text { text = "The basket is empty", style = { fontSize = "headline", fontWeight = "700" } },
                gui.Button {
                    title = "Have a look",
                    variant = "tinted",
                    style = { background = TINT },
                    onPress = function() self:setState({ screen = "home" }) end,
                },
            }
        end

        return gui.View { style = { grow = 1, background = "background" },
            gui.List {
                style = { grow = 1 },
                data = lines,
                itemExtent = 120,
                keyExtractor = function(line) return line.key end,
                separator = gui.Divider { color = "separator" },

                renderItem = function(line)
                    return gui.View {
                        style = { grow = 1, direction = "row", align = "center", gap = "sm", padding = "sm",
                            background = "surface" },

                        gui.Image {
                            source = line.good.picture,
                            resizeMode = "contain",
                            style = { width = 88, height = 88 },
                        },

                        gui.View { style = { grow = 1, shrink = 1, gap = 4 },
                            gui.Text {
                                text = line.good.name,
                                numberOfLines = 2,
                                style = { fontSize = "footnote" },
                            },
                            gui.Text {
                                text = money(line.good.price * line.count),
                                style = { fontSize = "headline", fontWeight = "600" },
                            },
                            gui.Text {
                                text = "Free delivery",
                                style = { fontSize = "caption", color = "success", fontWeight = "600" },
                            },
                        },

                        gui.Stepper {
                            value = line.count,
                            minimum = 0,
                            maximum = 10,
                            accessibilityLabel = "How many " .. line.good.name,
                            onChange = function(value) self:change(line.key, value) end,
                        },
                    }
                end,
            },

            gui.View {
                style = { padding = "sm", paddingBottom = insets.bottom + 12, gap = "xs",
                    background = "surface", shadow = "md" },

                gui.View { style = { direction = "row", justify = "space-between", align = "center" },
                    gui.Text { text = "Total", style = { fontSize = "headline" } },
                    gui.Text { text = money(self:total()), style = { fontSize = "title", fontWeight = "600" } },
                },
                gui.Button { title = "Continue", onPress = function() self:setState({ screen = "placed" }) end },
            },
        }
    end,

    Placed = function(self)
        return gui.View {
            style = { grow = 1, background = "background", justify = "center", align = "center",
                gap = "sm", padding = "lg" },

            gui.View {
                style = { width = 88, height = 88, radius = 999, background = "success",
                    align = "center", justify = "center" },
                gui.Icon { name = "check", size = 44, color = "#ffffff" },
            },
            gui.Text { text = "Order confirmed", style = { fontSize = "title", fontWeight = "700" } },
            gui.Text {
                text = "It arrives tomorrow and you can follow it from your orders",
                style = { color = "textMuted", textAlign = "center" },
            },
            gui.Button {
                title = "Back to the start",
                variant = "tinted",
                style = { marginTop = "sm", background = TINT },
                onPress = function() self:setState({ screen = "home", basket = {}, search = "" }) end,
            },
        }
    end,

    screens = function(self)
        local screens = {
            { key = "home", title = "Bazaar", content = self:Home(), hidesBar = true },
        }

        if self.state.screen == "results" then
            screens[2] = { key = "results", title = "Results", content = self:Results(), hidesBar = true }
            return screens
        end

        if self.state.screen == "basket" then
            screens[2] = { key = "basket", title = "Your basket", content = self:Basket() }
            return screens
        end

        if self.state.screen == "placed" then
            screens[2] = { key = "placed", title = "Order confirmed", content = self:Placed() }
            return screens
        end

        if self.state.screen == "product" then
            screens[2] = { key = "product", title = "Product", content = self:Product() }
        end

        return screens
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
                onPop = function() self:setState({ screen = "home" }) end,
            },
        }
    end,
})

return Bazaar
