local gui = require("gui")
local catalogue = require("catalogue")

--- The proportions the chrome is built from, which are the ones the platforms themselves use.
local ROW = 60
local HEADER = 34

local function opening()
    local asked = os.getenv("VARN_GUI_DEMO")

    if asked == nil then
        return nil
    end

    local group, item = asked:match("^([^/]+)/(.+)$")

    if group == nil or catalogue.find(group, item) == nil then
        return nil
    end

    return { group = group, item = item }
end

local Gallery = gui.component({
    name = "Gallery",
    state = { open = opening() },

    current = function(self)
        if self.state.open == nil then
            return nil
        end

        return catalogue.find(self.state.open.group, self.state.open.item)
    end,

    close = function(self)
        self:setState({ open = gui.none })
    end,

    --- A row of the index, which opens what it names.
    Row = function(self, group, item)
        return gui.Pressable {
            style = { grow = 1, direction = "row", align = "center", paddingLeft = "md", background = "background" },
            accessibilityLabel = item.title,
            onPress = function() self:setState({ open = { group = group.key, item = item.key } }) end,

            gui.View { style = { grow = 1, gap = 2, paddingRight = "sm" },
                gui.Text {
                    text = item.title,
                    numberOfLines = 1,
                    style = { fontSize = "body", color = "text" },
                },
                gui.Text {
                    text = item.summary,
                    numberOfLines = 1,
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            gui.Icon { name = "chevron-right", size = 16, color = "textMuted", style = { marginRight = "md" } },
        }
    end,

    Index = function(self)
        local insets = gui.environment:read(self).insets

        return gui.SectionList {
            style = { grow = 1, background = "surface" },
            sections = catalogue.groups,
            itemExtent = ROW,
            headerExtent = HEADER,
            stickyHeaders = true,
            separator = gui.Divider { color = "separator" },
            keyExtractor = function(item) return item.key end,

            -- The index scrolls under whatever the system draws over the bottom of the glass, and stops
            -- above it, so the last row is one a finger can reach rather than one under the indicator.
            footer = gui.Spacer { size = insets.bottom },
            footerExtent = insets.bottom,

            renderHeader = function(section)
                return gui.View {
                    style = { grow = 1, justify = "end", paddingHorizontal = "md", paddingBottom = "xs",
                        background = "surface" },
                    gui.Text {
                        text = section.title:upper(),
                        style = { fontSize = "caption", fontWeight = "600", color = "textMuted" },
                    },
                }
            end,

            renderItem = function(item, _, section)
                return self:Row(section, item)
            end,
        }
    end,

    Sidebar = function(self)
        return gui.View { style = { grow = 1, background = "surface" }, self:Index() }
    end,

    Body = function(self, demo)
        if demo == nil then
            return gui.View {
                style = { grow = 1, background = "background", justify = "center", align = "center" },
                gui.Text { text = "Pick something on the left", style = { color = "textMuted" } },
            }
        end

        return gui.View { style = { grow = 1, background = "background" }, demo.render() }
    end,

    --- The pane's stack, which is a waiting screen with whatever was opened pushed onto it.
    Screens = function(self, demo)
        local screens = {
            { key = "empty", title = "Gallery", content = self:Body(nil) },
        }

        if demo ~= nil then
            screens[2] = { key = demo.key, title = demo.title, content = self:Body(demo) }
        end

        return screens
    end,

    --- The index beside what it opened, or one at a time where there is no room for both.
    ---
    --- One tree, whichever there is room for. Rendering a split when it fits and a stack when it does not
    --- is two different trees, and a turn of the phone crosses between them: everything under either is
    --- taken down and built again, so a reader loses whatever they had put into it.
    render = function(self)
        local demo = self:current()
        local together = gui.environment:read(self).breakpoint ~= "compact"

        -- The application owns the whole of the glass. The bar takes the strip the status bar is drawn
        -- over into itself, so it is one bar running to the top rather than a painted band with a bar
        -- under it, and what scrolls ends above the home indicator rather than under it. Only the sides
        -- are kept clear here, which is what a phone held sideways needs.
        return gui.SafeArea {
            edges = { "left", "right" },
            style = { grow = 1, background = "surface" },

            gui.SplitView {
                sidebarWidth = 340,
                showing = demo ~= nil,

                sidebar = gui.NavigationStack {
                    style = { grow = 1 },
                    screens = { { key = "index", title = "Varn GUI", content = self:Sidebar() } },
                },

                -- A demo is pushed onto the pane rather than swapped into it, so closing one pops a
                -- stack: the screen that is leaving keeps its own bar while it travels out, and the one
                -- underneath never carries a way back it has no use for.
                content = gui.NavigationStack {
                    style = { grow = 1 },
                    backTitle = "Varn GUI",

                    -- A whole application draws its own bar, so a second one over it is two bars and a
                    -- title that is not the screen's.
                    hidesBar = demo ~= nil and demo.chrome == false,

                    index = demo ~= nil and 2 or 1,
                    onIndexChange = function() self:close() end,

                    screens = self:Screens(demo),
                },
            },
        }
    end,
})

return {
    root = Gallery {},
    Gallery = Gallery,
    catalogue = catalogue,
}
