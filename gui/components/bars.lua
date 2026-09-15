local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local element = require("gui.element")
local environment = require("gui.environment")
local feedback = require("gui.components.feedback")
local icons = require("gui.style.icons")
local input = require("gui.components.input")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local drawn = require("gui.controls.drawn")
local parts = require("gui.controls.parts")

local M = {}

local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable


--- How far what floats over a screen sits from the corner it floats in.
local FLOATING = 16

--- Answers what is wrong with one thing standing in a navigation bar, or nothing when it can be drawn.
local function wrongItem(entry, side, index)
    local where = side .. " item " .. index

    if element.isElement(entry) then
        return nil
    end

    if type(entry) ~= "table" then
        return where .. " is an element or a { label, icon, image, onPress } entry, got a " .. type(entry)
    end

    if entry.label == nil and entry.icon == nil and entry.image == nil then
        return where .. " shows nothing, so it carries a label, an icon or an image"
    end

    if entry.icon ~= nil and not icons.has(entry.icon) then
        return where .. " names an icon the set does not know, " .. tostring(entry.icon)
    end

    if entry.onPress ~= nil and type(entry.onPress) ~= "function" then
        return where .. " is answered with a function, got a " .. type(entry.onPress)
    end

    return nil
end

--- Answers what is wrong with one side of a bar, or nothing when every item on it can be drawn.
local function wrongSide(given, side)
    if given == nil then
        return nil
    end

    if type(given) ~= "table" or element.isElement(given) then
        return side .. " is a list of bar items, each an element or a { label, icon, image } entry"
    end

    for index = 1, #given do
        local wrong = wrongItem(given[index], side, index)

        if wrong ~= nil then
            return wrong
        end
    end

    return nil
end

--- How large a picture standing in a bar is drawn, which is the room a bar has for one.
local AVATAR = 30

--- One thing standing in a navigation bar, which is a word, a glyph, a picture or an element of its own.
---
--- Every platform offers a bar as items rather than as a view to fill: a title, a glyph, a picture or
--- something of the caller's, on either side, each with an action of its own. Built by hand a screen at
--- a time they come out at a different size, a different tint and a different touch target on each
--- screen, and half of them are smaller than a finger.
local function BarItem(entry, index)
    if element.isElement(entry) then
        return entry
    end

    local tint = entry.color or "primary"
    local inside = {}

    if entry.icon ~= nil then
        inside[#inside + 1] = content.Icon { key = "icon", name = entry.icon, size = entry.size or 22, color = tint }
    end

    if entry.image ~= nil then
        inside[#inside + 1] = content.Image {
            key = "image",
            source = entry.image,
            resizeMode = "cover",
            style = { width = entry.size or AVATAR, height = entry.size or AVATAR, radius = "pill" },
        }
    end

    if entry.label ~= nil then
        inside[#inside + 1] = Text {
            key = "label",
            text = entry.label,
            numberOfLines = 1,
            style = { color = tint, fontSize = "headline", fontWeight = entry.prominent and "600" or "400" },
        }
    end

    if entry.badge ~= nil then
        inside[#inside + 1] = feedback.Badge {
            key = "badge",
            value = entry.badge,
            style = { position = "absolute", top = 2, right = -6 },
        }
    end

    -- A word in a bar keeps the margin the platform keeps at the edge of a screen, and a glyph keeps
    -- less of one, which is what puts a back chevron against the edge and a title beside it.
    local box = {
        minWidth = chrome.touch,
        minHeight = chrome.touch,
        direction = "row",
        align = "center",
        justify = "center",
        gap = "xs",
        paddingHorizontal = entry.label ~= nil and "sm" or "xs",
    }

    if entry.disabled then
        box.opacity = 0.4
    end

    return Pressable {
        key = tostring(entry.key or entry.label or entry.icon or index),
        disabled = entry.disabled,
        accessibilityLabel = entry.accessibilityLabel or entry.label or entry.icon,
        onPress = entry.onPress,
        style = box,
        table.unpack(inside),
    }
end

--- Answers the elements one side of a bar holds, which is a list of items in the order they were written.
local function side(given)
    local built = {}

    for index = 1, #(given or {}) do
        built[#built + 1] = BarItem(given[index], index)
    end

    return built
end

--- The bar a screen is read under, drawn the way the system this is running on draws its own.
---
--- The bar owns the whole of the top of the screen. It takes the strip the status bar is drawn over into
--- itself, so what a reader sees is one bar running to the top of the glass rather than a painted band
--- with a bar under it, and what it holds is centred in the part below that strip rather than in the
--- whole of it. A safe area that has already taken the top inset leaves nothing for the bar to add, so
--- the same bar is correct on a screen drawn inside one and on a screen drawn edge to edge.
---
--- A centred title is centred on the bar, and that only holds when the two sides claim the same width —
--- centring it in whatever they happen to leave over puts it wherever the way back is long. The trailing
--- side is there with nothing in it for that reason. A title too long to fit between them shortens what
--- leads first, since the name of where a reader came from is worth less than the name of where they are.
---
--- A large title belongs to the bar as well. Drawn inside the screen it is a heading with the bar's own
--- rule cut across the top of it and no way to give way to the small title as the reader scrolls. The
--- bar draws it, collapses it against `scrolled`, and shows its rule only once it has collapsed.
M.AppBar = support.component("AppBar", {
    props = { "title", "subtitle", "titleView", "leading", "trailing", "largeTitle", "scrolled",
        "underStatusBar", "rule" },
    defaults = { largeTitle = false, scrolled = 0, underStatusBar = true, rule = true },
    style = function() return {} end,
    validate = function(spec)
        if spec.title ~= nil and type(spec.title) ~= "string" then
            return "title is a string, got a " .. type(spec.title)
        end

        if spec.titleView ~= nil and not element.isElement(spec.titleView) then
            return "titleView is an element drawn in the middle of the bar, got a " .. type(spec.titleView)
        end

        if type(spec.scrolled) ~= "number" or spec.scrolled ~= spec.scrolled then
            return "scrolled is how far the content under the bar has moved, in points"
        end

        return wrongSide(spec.leading, "leading") or wrongSide(spec.trailing, "trailing")
    end,
}, component.define({
    name = "AppBar",
    reads = { "surface" },

    --- Answers how much of the large title is still showing, which is what a reader has scrolled away.
    remaining = function(self, look)
        if not self.props.largeTitle then
            return 0
        end

        local left = look.large.height - math.max(0, self.props.scrolled)

        return math.max(0, math.min(look.large.height, left))
    end,

    --- The middle of the bar, which is the title the caller wrote or an element of their own.
    Middle = function(self, look, showing)
        if self.props.titleView ~= nil then
            return self.props.titleView
        end

        local titles = {
            key = "titles",
            style = { justify = "center" },
        }

        titles[#titles + 1] = Text {
            key = "title",
            text = self.props.title or "",
            numberOfLines = 1,
            style = { fontSize = look.title.size, fontWeight = look.title.weight,
                textAlign = look.title.align, opacity = showing },
            transition = self.props.largeTitle and { duration = "fast" } or nil,
        }

        if self.props.subtitle ~= nil then
            titles[#titles + 1] = Text {
                key = "subtitle",
                text = self.props.subtitle,
                numberOfLines = 1,
                style = { fontSize = "caption", color = "textMuted", textAlign = look.title.align,
                    opacity = showing },
            }
        end

        return View(titles)
    end,

    --- The big title, as much of it as the reader has not scrolled away.
    Large = function(self, look, left)
        return View {
            key = "large",
            style = { height = left, overflow = "hidden", justify = "end", paddingHorizontal = "md",
                opacity = left / look.large.height },

            Text {
                text = self.props.title or "",
                numberOfLines = 1,
                style = { fontSize = look.large.size, fontWeight = look.large.weight,
                    textAlign = look.large.align },
            },
        }
    end,

    render = function(self)
        local surface = environment:read(self)
        local look = chrome.bar(surface.platform, surface.breakpoint)
        local centred = look.title.align == "center"

        local sides = centred and { grow = 1, basis = 0, shrink = 1 } or { shrink = 1 }
        local middle = centred and { shrink = 1 } or { grow = 1, shrink = 1 }

        local left = self:remaining(look)
        local showing = 1

        if self.props.largeTitle then
            showing = 1 - left / look.large.height
        end

        local above = 0

        if self.props.underStatusBar then
            above = surface.insets.top
        end

        local bar = {
            style = { { background = "background", paddingTop = above }, self.props.style },

            View {
                key = "row",
                style = { height = look.height, direction = "row", align = "center",
                    paddingHorizontal = "sm", gap = "sm" },

                View {
                    key = "leading",
                    style = { { direction = "row", align = "center" }, sides },
                    table.unpack(side(self.props.leading)),
                },

                View { key = "middle", style = { { justify = "center" }, middle }, self:Middle(look, showing) },

                View {
                    key = "trailing",
                    style = { { direction = "row", align = "center", justify = "end", gap = "xs" }, sides },
                    table.unpack(side(self.props.trailing)),
                },
            },
        }

        if left > 0 then
            bar[#bar + 1] = self:Large(look, left)
        end

        -- The rule belongs to the bar, and a big title standing under it is what the bar is showing, so
        -- the rule waits until the title has collapsed rather than being drawn across the top of it.
        if self.props.rule and left <= 0 then
            bar[#bar + 1] = Divider { key = "rule" }
        end

        return View(bar)
    end,
}))

--- The shape a screen is built into: a bar, the screen itself, a bar along the bottom and what floats
--- over all of it.
---
--- Every application draws the same arrangement, and one written by hand each time is one that puts the
--- floating action under the bottom bar on the screen somebody forgot about. The bottom bar keeps clear
--- of whatever the system draws below it, so a screen drawn edge to edge does not end under the home
--- indicator and one drawn inside a safe area is not inset twice.
M.Scaffold = support.component("Scaffold", {
    props = { "bar", "bottom", "floating" },
}, component.define({
    name = "Scaffold",
    reads = { "surface" },

    render = function(self)
        local insets = environment:read(self).insets
        local body = { key = "body", style = { grow = 1 } }

        for index = 1, #self.children do
            body[#body + 1] = self.children[index]
        end

        local under = false

        if self.props.bottom ~= nil then
            under = View { key = "bottom", style = { paddingBottom = insets.bottom }, self.props.bottom }
        end

        return View {
            style = { { grow = 1, background = "background" }, self.props.style },

            self.props.bar or false,

            View {
                key = "over",
                style = { grow = 1 },

                View(body),

                -- What floats stands over the screen rather than in it, so it is placed against the
                -- box the screen fills rather than pushed around by what the screen happens to hold.
                self.props.floating ~= nil and View {
                    key = "floating",
                    style = { position = "absolute", right = FLOATING, bottom = FLOATING + insets.bottom },
                    self.props.floating,
                } or false,
            },

            under,
        }
    end,
}))

--- Answers what a tab says is waiting behind it, which is nothing at all when nothing is.
local function waiting(counts, tab, index)
    local count = (counts or {})[tab.key] or (counts or {})[index]

    if count == nil or count == 0 then
        return false
    end

    return feedback.Badge {
        key = "badge",
        value = count,
        -- A badge hangs off the top corner of the icon it counts, which is where a phone puts one.
        -- Hung off the label instead it sat on the word rather than beside it, and placed at a share of
        -- the tab's width it moved with the number of tabs.
        style = { position = "absolute", top = -8, right = -14 },
    }
end

--- A row of destinations, one of which is chosen, sitting at the edge the platform puts one at.
---
--- A bar along the bottom keeps clear of what the system draws below it, so a screen drawn edge to edge
--- does not put its destinations under the home indicator.
M.TabBar = support.component("TabBar", {
    props = { "tabs", "selectedIndex", "position", "badgeCounts" },
    events = { "onChange" },
    defaults = { selectedIndex = 1, position = "bottom" },
    validate = function(spec)
        if type(spec.tabs) ~= "table" or #spec.tabs == 0 then
            return "needs a tabs list with at least one entry"
        end

        for index = 1, #spec.tabs do
            if spec.tabs[index].icon ~= nil and not icons.has(spec.tabs[index].icon) then
                return "the icon set does not know an icon called " .. tostring(spec.tabs[index].icon)
            end
        end

        local choices = { "top", "bottom" }
        if not support.oneOf(spec.position, choices) then
            return support.expected("position", spec.position, choices)
        end
    end,
}, component.define({
    name = "TabBar",
    state = { focused = nil },

    render = function(self)
        local theme = parts.themeOf(self)
        local tabs = self.props.tabs
        local children = {}
        local indicator = theme:metric("tabbar", "indicator")

        for index = 1, #tabs do
            local tab = tabs[index]
            local chosen = index == self.props.selectedIndex
            local about = { on = chosen }
            local count = waiting(self.props.badgeCounts, tab, index)
            local marked = tab.icon ~= nil and tab.icon or false

            local glyph = marked ~= false and View {
                key = "icon",
                transition = parts.motion(theme, "tabbar"),
                style = {
                    align = "center",
                    justify = "center",
                    width = indicator > 0 and theme:metric("tabbar", "indicatorWidth") or nil,
                    height = indicator > 0 and indicator or nil,
                    radius = theme:metric("tabbar", "radius"),
                    background = indicator > 0 and parts.paint(theme, "tabbar", "indicator", about) or nil,
                },

                content.Icon {
                    key = "glyph",
                    name = tab.icon,
                    size = 22,
                    color = parts.paint(theme, "tabbar", "icon", about),
                },
                count,
            } or false

            children[#children + 1] = Pressable {
                key = tostring(tab.key or index),
                accessibilityLabel = tab.label,
                accessibilityRole = "tab",
                accessibilityState = { selected = chosen },
                focusable = true,
                style = {
                    grow = 1,
                    basis = 0,
                    align = "center",
                    justify = "center",
                    gap = theme:metric("tabbar", "gap"),
                    height = theme:metric("tabbar", "height"),
                },
                onPress = function()
                    if self.props.onChange ~= nil then
                        self.props.onChange(index)
                    end
                end,
                onKeyDown = function(key)
                    local step = parts.steps(key.key, "horizontal")

                    if self.props.onChange == nil then
                        return
                    end

                    if parts.chooses(key.key) then
                        self.props.onChange(index)
                        return
                    end

                    if type(step) == "number" then
                        self.props.onChange(math.max(1, math.min(#tabs, index + step)))
                    end
                end,
                onFocus = function() self:setState({ focused = index }) end,
                onBlur = function() self:setState({ focused = component.none }) end,

                glyph,

                View {
                    key = "label",
                    style = { align = "center", justify = "center" },

                    Text {
                        text = tab.label,
                        numberOfLines = 1,
                        style = {
                            fontSize = "caption",
                            fontWeight = chosen and "600" or "500",
                            color = parts.paint(theme, "tabbar", "label", about),
                            textAlign = "center",
                        },
                    },

                    marked == false and count or false,
                },
            }
        end

        local bar = View {
            key = "bar",
            style = {
                direction = "row",
                background = parts.paint(theme, "tabbar", "container", {}),
            },

            table.unpack(children),
        }

        local rows = { bar }

        if theme:metric("tabbar", "rule") > 0 then
            local edge = Divider {}

            rows = self.props.position == "top" and { bar, edge } or { edge, bar }
        end

        return View { accessibilityRole = "none", style = self.props.style, table.unpack(rows) }
    end,
}))

--- The tab bar of a wide screen, which is a column against the leading edge rather than a row along the
--- bottom.
---
--- It takes the same `tabs` a bar takes, so a screen that changes shape with the room it has changes one
--- prop rather than holding two trees.
M.NavigationRail = support.component("NavigationRail", {
    props = { "tabs", "selectedIndex", "header" },
    events = { "onChange" },
    defaults = { selectedIndex = 1 },
    validate = function(spec)
        if type(spec.tabs) ~= "table" or #spec.tabs == 0 then
            return "needs a tabs list with at least one entry"
        end
    end,
}, drawn.rail)

return M
