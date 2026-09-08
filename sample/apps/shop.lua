local gui = require("gui")

--- A shop, from the window through to a confirmed order.
---
--- The point of this is not the components it happens to use. It is that a whole application is one
--- tree of state: what is in the bag, what is being looked at and how far through checkout it has got
--- are ordinary fields, and every screen is a function of them.
local PRODUCTS = {
    {
        key = "chair",
        name = "Shell Chair",
        maker = "Kestrel",
        price = 340,
        blurb = "Moulded ply over a steel frame, in three finishes.",
        pictures = {
            "https://picsum.photos/id/1080/800/800",
            "https://picsum.photos/id/1084/800/800",
        },
        sizes = { "Low", "Standard", "Counter" },
        colours = { "Walnut", "Ash", "Charcoal" },
    },
    {
        key = "lamp",
        name = "Arc Lamp",
        maker = "Kestrel",
        price = 185,
        blurb = "A weighted base and a shade you can point anywhere.",
        pictures = { "https://picsum.photos/id/1060/800/800" },
        sizes = { "Table", "Floor" },
        colours = { "Brass", "Black" },
    },
    {
        key = "rug",
        name = "Flatweave Rug",
        maker = "Norden",
        price = 260,
        blurb = "Wool, woven flat, so it lies where you put it.",
        pictures = { "https://picsum.photos/id/1076/800/800" },
        sizes = { "Small", "Medium", "Large" },
        colours = { "Sand", "Slate" },
    },
    {
        key = "table",
        name = "Trestle Table",
        maker = "Norden",
        price = 520,
        blurb = "Two trestles and a top, which comes apart to move.",
        pictures = { "https://picsum.photos/id/1082/800/800" },
        sizes = { "Four", "Six", "Eight" },
        colours = { "Oak", "Painted" },
    },
}

local DELIVERY = {
    { value = "standard", label = "Standard, three days", price = 0 },
    { value = "quick", label = "Next day", price = 12 },
}

local function money(amount)
    return string.format("£%d", amount)
end

local function find(key)
    for index = 1, #PRODUCTS do
        if PRODUCTS[index].key == key then
            return PRODUCTS[index]
        end
    end

    return nil
end

local Shop = gui.component({
    name = "Shop",
    state = {
        screen = "window",
        looking = nil,
        picture = 1,
        size = nil,
        colour = nil,
        quantity = 1,
        bag = {},
        delivery = "standard",
        name = "",
        address = "",
        placed = false,
    },

    --- Answers what is in the bag as lines, since state is held as a count against a product key.
    lines = function(self)
        local lines = {}

        for index = 1, #PRODUCTS do
            local product = PRODUCTS[index]
            local held = self.state.bag[product.key]

            if held ~= nil and held.count > 0 then
                lines[#lines + 1] = {
                    key = product.key,
                    product = product,
                    count = held.count,
                    size = held.size,
                    colour = held.colour,
                }
            end
        end

        return lines
    end,

    total = function(self)
        local total = 0

        for _, line in ipairs(self:lines()) do
            total = total + line.product.price * line.count
        end

        for _, option in ipairs(DELIVERY) do
            if option.value == self.state.delivery then
                total = total + option.price
            end
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

    open = function(self, key)
        local product = find(key)

        self:setState({
            screen = "product",
            looking = key,
            picture = 1,
            size = product.sizes[1],
            colour = product.colours[1],
            quantity = 1,
        })
    end,

    add = function(self)
        local bag = {}

        for key, held in pairs(self.state.bag) do
            bag[key] = held
        end

        local key = self.state.looking
        local held = bag[key]

        bag[key] = {
            count = (held ~= nil and held.count or 0) + self.state.quantity,
            size = self.state.size,
            colour = self.state.colour,
        }

        self:setState({ bag = bag, screen = "bag" })
    end,

    change = function(self, key, by)
        local bag = {}

        for held, entry in pairs(self.state.bag) do
            bag[held] = entry
        end

        local entry = bag[key]

        if entry == nil then
            return
        end

        local count = entry.count + by

        if count <= 0 then
            bag[key] = nil
        else
            bag[key] = { count = count, size = entry.size, colour = entry.colour }
        end

        self:setState({ bag = bag })
    end,

    Window = function(self)
        return gui.Grid {
            style = { grow = 1, paddingHorizontal = "md", paddingTop = "md" },
            data = PRODUCTS,
            columns = 2,
            spacing = 12,
            rowExtent = 232,
            keyExtractor = function(product) return product.key end,
            renderItem = function(product)
                return gui.Pressable {
                    style = { grow = 1, gap = "xs" },
                    accessibilityLabel = product.name,
                    onPress = function() self:open(product.key) end,

                    gui.Image {
                        source = product.pictures[1],
                        resizeMode = "cover",
                        style = { height = 150, radius = "md", background = "surface" },
                    },
                    gui.Text { text = product.name, numberOfLines = 1, style = { fontWeight = "600" } },
                    gui.Text {
                        text = product.maker,
                        numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                    gui.Text { text = money(product.price), style = { fontWeight = "600" } },
                }
            end,
        }
    end,

    Product = function(self)
        local product = find(self.state.looking)

        return gui.ScrollView {
            style = { grow = 1 },
            contentStyle = { gap = "md", padding = "md" },

            gui.Carousel {
                style = { height = 280 },
                data = product.pictures,
                index = self.state.picture,
                onIndexChange = function(index) self:setState({ picture = index }) end,
                keyExtractor = function(_, index) return index end,
                renderItem = function(picture)
                    return gui.Image {
                        source = picture,
                        resizeMode = "cover",
                        style = { grow = 1, radius = "md", background = "surface" },
                    }
                end,
            },

            gui.View { style = { gap = "xs" },
                gui.Text { text = product.name, style = { fontSize = "heading", fontWeight = "700" } },
                gui.Text { text = product.blurb, style = { color = "textMuted" } },
                gui.Text { text = money(product.price), style = { fontSize = "title", fontWeight = "700" } },
            },

            gui.View { style = { gap = "xs" },
                gui.Text { text = "Size", style = { fontWeight = "600" } },
                gui.SegmentedControl {
                    segments = product.sizes,
                    selectedIndex = self:indexOf(product.sizes, self.state.size),
                    onChange = function(index) self:setState({ size = product.sizes[index] }) end,
                },
            },

            gui.View { style = { gap = "xs" },
                gui.Text { text = "Finish", style = { fontWeight = "600" } },
                gui.RadioGroup {
                    orientation = "horizontal",
                    value = self.state.colour,
                    options = self:optionsOf(product.colours),
                    onChange = function(value) self:setState({ colour = value }) end,
                },
            },

            gui.View { style = { direction = "row", align = "center", justify = "space-between" },
                gui.Text { text = "How many", style = { fontWeight = "600" } },
                gui.Stepper {
                    value = self.state.quantity,
                    minimum = 1,
                    maximum = 9,
                    onChange = function(value) self:setState({ quantity = value }) end,
                },
            },

            gui.Button { title = "Add to bag", onPress = function() self:add() end },
        }
    end,

    Bag = function(self)
        local lines = self:lines()

        if #lines == 0 then
            return gui.View { style = { grow = 1, justify = "center", align = "center", gap = "md" },
                gui.Text { text = "Nothing in the bag yet", style = { color = "textMuted" } },
                gui.Button {
                    title = "Have a look",
                    variant = "tinted",
                    onPress = function() self:setState({ screen = "window" }) end,
                },
            }
        end

        return gui.View { style = { grow = 1 },
            gui.List {
                style = { grow = 1 },
                data = lines,
                itemExtent = 96,
                keyExtractor = function(line) return line.key end,
                separator = gui.Divider {},
                renderItem = function(line)
                    return gui.View {
                        style = { grow = 1, direction = "row", align = "center", gap = "md",
                            paddingHorizontal = "md" },

                        gui.Image {
                            source = line.product.pictures[1],
                            resizeMode = "cover",
                            style = { width = 64, height = 64, radius = "sm", background = "surface" },
                        },

                        gui.View { style = { grow = 1, gap = 2 },
                            gui.Text { text = line.product.name, numberOfLines = 1, style = { fontWeight = "600" } },
                            gui.Text {
                                text = line.size .. " · " .. line.colour,
                                numberOfLines = 1,
                                style = { fontSize = "footnote", color = "textMuted" },
                            },
                            gui.Text { text = money(line.product.price * line.count) },
                        },

                        gui.Stepper {
                            value = line.count,
                            minimum = 0,
                            maximum = 9,
                            onChange = function(value) self:change(line.key, value - line.count) end,
                        },
                    }
                end,
            },

            gui.View { style = { padding = "md", gap = "sm", background = "surface" },
                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text { text = "Total", style = { fontWeight = "600" } },
                    gui.Text { text = money(self:total()), style = { fontWeight = "700" } },
                },
                gui.Button { title = "Checkout", onPress = function() self:setState({ screen = "checkout" }) end },
            },
        }
    end,

    Checkout = function(self)
        return gui.KeyboardAvoiding {
            style = { grow = 1 },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", padding = "md" },
                keyboardDismissMode = "on-drag",

                gui.Text { text = "Where it goes", style = { fontSize = "title", fontWeight = "700" } },

                gui.TextInput {
                    placeholder = "Name",
                    value = self.state.name,
                    returnKey = "next",
                    onChange = function(value) self:setState({ name = value }) end,
                },

                gui.TextArea {
                    placeholder = "Address",
                    rows = 3,
                    value = self.state.address,
                    onChange = function(value) self:setState({ address = value }) end,
                },

                gui.Text { text = "How it gets there", style = { fontWeight = "600" } },
                gui.RadioGroup {
                    value = self.state.delivery,
                    options = DELIVERY,
                    onChange = function(value) self:setState({ delivery = value }) end,
                },

                gui.Divider {},

                gui.View { style = { direction = "row", justify = "space-between" },
                    gui.Text { text = "To pay", style = { fontWeight = "600" } },
                    gui.Text { text = money(self:total()), style = { fontWeight = "700" } },
                },

                gui.Button {
                    title = "Place the order",
                    disabled = self.state.name == "" or self.state.address == "",
                    onPress = function() self:setState({ placed = true }) end,
                },
            },
        }
    end,

    Placed = function(self)
        return gui.View { style = { grow = 1, justify = "center", align = "center", gap = "md", padding = "lg" },
            gui.Text { text = "Ordered", style = { fontSize = "heading", fontWeight = "700" } },
            gui.Text {
                text = "Going to " .. self.state.name,
                style = { color = "textMuted", textAlign = "center" },
            },
            gui.Button {
                title = "Back to the shop",
                variant = "tinted",
                onPress = function()
                    self:setState({ screen = "window", bag = {}, placed = false, name = "", address = "" })
                end,
            },
        }
    end,

    indexOf = function(_, values, wanted)
        for index = 1, #values do
            if values[index] == wanted then
                return index
            end
        end

        return 1
    end,

    optionsOf = function(_, values)
        local options = {}

        for index = 1, #values do
            options[index] = { value = values[index], label = values[index] }
        end

        return options
    end,

    --- The screens of the shop, as the stack the platform pushes them onto.
    screens = function(self)
        local screens = {
            { key = "window", title = "Kestrel", content = self:Window() },
        }

        if self.state.screen == "window" then
            return screens
        end

        if self.state.screen == "product" then
            screens[2] = { key = "product", title = find(self.state.looking).name, content = self:Product() }
            return screens
        end

        screens[2] = { key = "bag", title = "Bag", content = self:Bag() }

        if self.state.screen == "checkout" then
            screens[3] = { key = "checkout", title = "Checkout", content = self:Checkout() }
        end

        return screens
    end,

    back = function(self)
        if self.state.screen == "checkout" then
            self:setState({ screen = "bag" })
            return
        end

        self:setState({ screen = "window" })
    end,

    render = function(self)
        if self.state.placed then
            return self:Placed()
        end

        local screens = self:screens()
        local waiting = self:counted()

        -- The bag sits in the bar rather than over the application, or it is drawn on top of every
        -- menu, sheet and alert that opens under it.
        local bag = gui.Pressable {
            style = { minWidth = 44, minHeight = 44, justify = "center", align = "center" },
            accessibilityLabel = "Bag",
            onPress = function() self:setState({ screen = "bag" }) end,
            gui.Text { text = "Bag", style = { color = "primary" } },
            waiting > 0 and gui.Badge { value = waiting, style = { position = "absolute", top = 2, right = -6 } }
                or false,
        }

        return gui.NavigationStack {
            style = { grow = 1 },
            screens = screens,
            index = #screens,
            actions = bag,
            onPop = function() self:back() end,
        }
    end,
})

return Shop
