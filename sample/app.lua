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
        return gui.SectionList {
            style = { grow = 1, background = "surface" },
            sections = catalogue.groups,
            itemExtent = ROW,
            headerExtent = HEADER,
            stickyHeaders = true,
            separator = gui.Divider { color = "separator" },
            keyExtractor = function(item) return item.key end,

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

    --- The index beside what it opened, or one at a time where there is no room for both.
    ---
    --- One tree, whichever there is room for. Rendering a split when it fits and a stack when it does not
    --- is two different trees, and a turn of the phone crosses between them: everything under either is
    --- taken down and built again, so a reader loses whatever they had put into it.
    render = function(self)
        local demo = self:current()
        local together = gui.environment:read(self).breakpoint ~= "compact"

        return gui.SafeArea {
            style = { grow = 1, background = "surface" },

            -- What the status bar and the home indicator sit over, which is the bar's own colour so the
            -- bar runs all the way up rather than ending in a hard edge below the clock.
            barStyle = { background = "background" },

            gui.SplitView {
                sidebarWidth = 340,
                showing = demo ~= nil,

                sidebar = gui.NavigationStack {
                    style = { grow = 1 },
                    screens = { { key = "index", title = "Varn GUI", content = self:Sidebar() } },
                },

                content = gui.NavigationStack {
                    style = { grow = 1 },

                    -- With the index beside it there is nowhere to go back to, and with it covered there is.
                    onBack = not together and function() self:close() end or nil,
                    backTitle = "Varn GUI",

                    -- A whole application draws its own bar, so a second one over it is two bars and a
                    -- title that is not the screen's.
                    hidesBar = demo ~= nil and demo.chrome == false,

                    screens = {
                        { key = demo ~= nil and demo.key or "empty",
                          title = demo ~= nil and demo.title or "Gallery",
                          content = self:Body(demo) },
                    },
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
