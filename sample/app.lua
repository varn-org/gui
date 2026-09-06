local gui = require("gui")
local catalogue = require("catalogue")

--- The proportions the chrome is built from, which are the ones the platforms themselves use.
local BAR = 44
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

    --- The bar over a demo: one row the height a platform draws it at, with the way back on the left.
    ---
    --- The title is centred in the bar rather than pushed along by whatever sits beside it, so it reads
    --- the same whether or not there is a way back to draw.
    Bar = function(self, title)
        return gui.View {
            style = { height = BAR, background = "background" },

            gui.View {
                style = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
                    justify = "center", align = "center", paddingHorizontal = 64 },
                gui.Text {
                    text = title,
                    numberOfLines = 1,
                    style = { fontSize = "headline", fontWeight = "600", color = "text", textAlign = "center" },
                },
            },

            gui.Pressable {
                style = { position = "absolute", left = 0, top = 0, bottom = 0,
                    direction = "row", align = "center", paddingHorizontal = "sm", gap = 2 },
                accessibilityLabel = "Back",
                onPress = function() self:close() end,
                gui.Text { text = "‹", style = { fontSize = "title", color = "primary" } },
                gui.Text { text = "Gallery", style = { fontSize = "body", color = "primary" } },
            },
        }
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

            gui.Text { text = "›", style = { fontSize = "title", color = "textMuted", paddingRight = "md" } },
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

    render = function(self)
        local demo = self:current()

        if demo == nil then
            return gui.SafeArea {
                style = { grow = 1, background = "surface" },
                gui.View {
                    style = { paddingHorizontal = "md", paddingTop = "sm", paddingBottom = "xs",
                        background = "surface" },
                    gui.Text {
                        text = "Varn GUI",
                        style = { fontSize = "display", fontWeight = "700", color = "text" },
                    },
                },
                self:Index(),
            }
        end

        return gui.SafeArea {
            style = { grow = 1, background = "background" },
            self:Bar(demo.title),
            gui.Divider { color = "separator" },
            gui.View { style = { grow = 1 }, demo.render() },
        }
    end,
})

return {
    root = Gallery {},
    Gallery = Gallery,
    catalogue = catalogue,
}
