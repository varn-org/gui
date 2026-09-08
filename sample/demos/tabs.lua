local gui = require("gui")

--- The four screens every one of these switches between, so what a tab does is seen rather than described.
local SCREENS = {
    { key = "home", label = "Home", icon = "home", title = "Home",
      body = "What a reader lands on. Each tab here is a screen of its own rather than a label that changes colour." },
    { key = "search", label = "Search", icon = "search", title = "Search",
      body = "The second screen. Switching tabs keeps whatever each one was left holding." },
    { key = "saved", label = "Saved", icon = "heart", title = "Saved",
      body = "The third. A badge on a tab says how much is waiting behind it." },
    { key = "you", label = "You", icon = "user", title = "You",
      body = "And the fourth, which is where an account usually lives." },
}

--- One screen, with somewhere to type so that what a tab kept is visible when it is come back to.
---
--- It also says every moment it was told about, which is what a screen hears when it is built, shown,
--- hidden and taken down. Switching tabs shows the difference between being built and being seen.
local Screen = gui.component({
    name = "TabScreen",
    state = { note = "", heard = {} },

    heardOf = function(self, moment)
        local heard = {}

        for index = 1, #self.state.heard do
            heard[index] = self.state.heard[index]
        end

        heard[#heard + 1] = moment
        self:setState({ heard = heard })
    end,

    onMount = function(self) self:heardOf("built") end,
    onAppear = function(self) self:heardOf("shown") end,
    onDisappear = function(self) self:heardOf("hidden") end,

    render = function(self)
        local screen = self.props.screen

        return gui.ScrollView { style = { grow = 1, background = "surface" },
            contentStyle = { padding = "md", gap = "sm" },

            gui.Text { text = screen.title, style = { fontSize = "title", fontWeight = "700" } },
            gui.Text { text = screen.body, style = { color = "textMuted" } },

            gui.TextInput {
                value = self.state.note,
                placeholder = "Type here, then come back",
                onChange = function(value) self:setState({ note = value }) end,
            },

            gui.Text {
                text = "This screen has heard: " .. table.concat(self.state.heard, ", "),
                style = { fontSize = "footnote", color = "primary" },
            },
        }
    end,
})

--- Every screen at once, with the chosen one showing, so each of them keeps what was put into it.
local function screens(chosen)
    local held = {}

    for index = 1, #SCREENS do
        held[index] = gui.View {
            key = SCREENS[index].key,
            style = index == chosen and { grow = 1 }
                or { position = "absolute", top = 0, right = 0, bottom = 0, left = 0, opacity = 0 },
            pointerEvents = index == chosen and "auto" or "none",

            -- Every tab is kept and one is shown, which nothing under it can work out for itself.
            gui.Showing { value = index == chosen, Screen { screen = SCREENS[index] } },
        }
    end

    return gui.View { style = { grow = 1 }, table.unpack(held) }
end

local Standard = gui.component({
    name = "StandardTabs",
    state = { tab = 1 },

    render = function(self)
        return gui.View { style = { grow = 1 },
            screens(self.state.tab),

            gui.TabBar {
                tabs = SCREENS,
                selectedIndex = self.state.tab,
                badgeCounts = { saved = 3 },
                onChange = function(index) self:setState({ tab = index }) end,
            },
        }
    end,
})

--- A bar that floats over the screen as a pill rather than sitting on its edge.
local Floating = gui.component({
    name = "FloatingTabs",
    state = { tab = 1 },

    Tab = function(self, index)
        local screen = SCREENS[index]
        local chosen = index == self.state.tab

        return gui.Pressable {
            key = screen.key,
            style = { grow = 1, basis = 0, height = 44, radius = "pill", align = "center", justify = "center",
                direction = "row", gap = "xs", background = chosen and "primary" or nil },
            accessibilityLabel = screen.label,
            onPress = function() self:setState({ tab = index }) end,

            gui.Icon { name = screen.icon, size = 18, color = chosen and "onPrimary" or "textMuted" },
            chosen and gui.Text {
                text = screen.label,
                style = { fontSize = "footnote", fontWeight = "600", color = "onPrimary" },
            } or false,
        }
    end,

    render = function(self)
        local tabs = {}

        for index = 1, #SCREENS do
            tabs[index] = self:Tab(index)
        end

        return gui.View { style = { grow = 1 },
            screens(self.state.tab),

            gui.View {
                style = { position = "absolute", left = "6%", right = "6%", bottom = 20, height = 56,
                    direction = "row", align = "center", padding = 6, gap = 4,
                    radius = "pill", background = "elevated", shadow = "lg" },
                table.unpack(tabs),
            },
        }
    end,
})

--- Two tabs, a round picture raised above the bar, two more — and the picture is one a reader chose.
local Cover = gui.component({
    name = "CoverTabs",
    state = { tab = 1, cover = nil, problem = nil },

    keep = function(self, file)
        -- A picture too large to read is reported where the reader asked for it, since silence there is
        -- a control that looks broken.
        if file.bytes == nil then
            self:setState({ problem = file.name .. " is too large to keep" })
            return
        end

        self:setState({ problem = gui.none })

        self:after(0, function()
            local crypto = require("crypto")
            local fs = require("fs")
            local path = gui.storage.directory("cover") .. "/" .. file.name

            fs.writeFile(path, crypto.base64Decode(file.bytes)):await()
            self:setState({ cover = path })
        end)
    end,

    Tab = function(self, index)
        local screen = SCREENS[index]
        local chosen = index == self.state.tab

        return gui.Pressable {
            key = screen.key,
            style = { grow = 1, basis = 0, height = 56, align = "center", justify = "center", gap = 2 },
            accessibilityLabel = screen.label,
            onPress = function() self:setState({ tab = index }) end,

            gui.Icon { name = screen.icon, size = 20, color = chosen and "primary" or "textMuted" },
            gui.Text {
                text = screen.label,
                style = { fontSize = "caption", fontWeight = "600", color = chosen and "primary" or "textMuted" },
            },
        }
    end,

    --- The round picture the bar is built around, raised above it and pressed to change.
    Cover = function(self)
        return gui.View {
            key = "cover",
            style = { position = "absolute", left = "50%", marginLeft = -34, top = -26, width = 68, height = 68 },

            gui.FilePicker {
                kind = "image",
                title = self.state.cover == nil and "Pick" or "",
                accept = { "image/*" },
                maxBytes = 24 * 1024 * 1024,
                onPick = function(file) self:keep(file) end,
                style = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0,
                    radius = "pill", background = "primary", color = "onPrimary", fontSize = "caption" },
            },

            self.state.cover ~= nil and gui.Image {
                key = "picture",
                source = self.state.cover,
                resizeMode = "cover",
                style = { position = "absolute", top = 4, right = 4, bottom = 4, left = 4, radius = "pill" },
                pointerEvents = "none",
            } or false,
        }
    end,

    render = function(self)
        return gui.View { style = { grow = 1 },
            screens(self.state.tab),

            gui.View { style = { height = 56, direction = "row", background = "background" },
                gui.Divider { key = "edge", style = { position = "absolute", top = 0, left = 0, right = 0 } },

                self:Tab(1),
                self:Tab(2),
                gui.View { key = "gap", style = { width = 84 } },
                self:Tab(3),
                self:Tab(4),

                self:Cover(),

                self.state.problem ~= nil and gui.Text {
                    key = "problem",
                    text = self.state.problem,
                    style = { position = "absolute", left = 0, right = 0, top = -28, textAlign = "center",
                        fontSize = "caption", color = "danger" },
                } or false,
            },
        }
    end,
})

--- A row that answers a swipe with something other than what a press does, which is what a gesture is for.
local Gestures = gui.component({
    name = "GesturesDemo",
    state = { said = "Press a row, or swipe one" },

    Row = function(self, label)
        return gui.Pressable {
            key = label,
            style = { height = 60, direction = "row", align = "center", paddingHorizontal = "md",
                background = "background" },
            accessibilityLabel = label,
            onPress = function() self:setState({ said = label .. " was pressed" }) end,
            onLongPress = function() self:setState({ said = label .. " was held" }) end,
            onSwipe = function(swipe) self:setState({ said = label .. " was swiped " .. swipe.direction }) end,

            gui.Text { text = label, style = { grow = 1 } },
            gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
        }
    end,

    render = function(self)
        return gui.View { style = { grow = 1, background = "surface" },
            gui.View { style = { padding = "md", gap = "xs" },
                gui.Text { text = "Gestures", style = { fontSize = "title", fontWeight = "700" } },
                gui.Text {
                    text = "A swipe is not a press. Each row answers the gesture the finger actually made.",
                    style = { color = "textMuted" },
                },
                gui.Text { text = self.state.said, style = { fontWeight = "600", color = "primary" } },
            },

            gui.Divider {},
            self:Row("The first row"),
            gui.Divider {},
            self:Row("The second row"),
            gui.Divider {},
            self:Row("The third row"),
        }
    end,
})

--- Tabs at the top over pages a reader swipes between, which is what a phone does with a feed.
local Paged = gui.component({
    name = "PagedTabs",
    state = { tab = 1 },

    render = function(self)
        local pages = self.pages

        if pages == nil then
            pages = gui.ref()
            self.pages = pages
        end

        local tabs = {}

        for index = 1, #SCREENS do
            local chosen = index == self.state.tab

            tabs[index] = gui.Pressable {
                key = SCREENS[index].key,
                style = { grow = 1, basis = 0, height = 44, align = "center", justify = "center",
                    border = 0, borderColor = "primary" },
                accessibilityLabel = SCREENS[index].label,
                onPress = function()
                    self:setState({ tab = index })
                    pages:call("scrollToIndex", { index = index, animated = true })
                end,

                gui.Text {
                    text = SCREENS[index].label,
                    style = { fontSize = "footnote", fontWeight = "600",
                        color = chosen and "primary" or "textMuted" },
                },
            }
        end

        return gui.View { style = { grow = 1 },
            gui.View { style = { direction = "row", background = "background" }, table.unpack(tabs) },

            gui.View {
                style = { height = 2 },
                gui.View { style = { position = "absolute", top = 0, bottom = 0,
                    left = (100 / #SCREENS * (self.state.tab - 1)) .. "%",
                    width = (100 / #SCREENS) .. "%", background = "primary" } },
            },

            gui.Divider {},

            gui.Carousel {
                ref = pages,
                style = { grow = 1 },
                data = SCREENS,
                index = self.state.tab,
                keyExtractor = function(screen) return screen.key end,
                onIndexChange = function(index) self:setState({ tab = index }) end,
                renderItem = function(screen) return Screen { screen = screen } end,
            },
        }
    end,
})

return {
    { key = "standard", title = "Tabs", summary = "The bar the platform draws, with icons and a badge",
      chrome = false, render = function() return Standard {} end },
    { key = "floating", title = "A floating bar", summary = "A pill over the screen rather than on its edge",
      chrome = false, render = function() return Floating {} end },
    { key = "cover", title = "Tabs around a cover", summary = "Two, a round picture you choose, two more",
      chrome = false, render = function() return Cover {} end },
    { key = "paged", title = "Tabs over pages", summary = "Swiped between as well as pressed",
      chrome = false, render = function() return Paged {} end },
    { key = "gestures", title = "Gestures", summary = "A press, a hold and a swipe are three things",
      render = function() return Gestures {} end },
}
