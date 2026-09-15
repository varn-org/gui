local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local environment = require("gui.environment")
local presence = require("gui.components.presence")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local drawn = require("gui.controls.drawn")
local parts = require("gui.controls.parts")

local M = {}

local View = structure.View
local Portal = structure.Portal
local Divider = structure.Divider
local Text = content.Text
local Pressable = require("gui.components.pressable")
local Presence = presence.Presence

local ROW = 52

local cover = support.cover

--- The dark ground behind what is shown over the screen, which dismisses it when it is pressed.
local function scrim(onDismiss, dismissible, theme)
    local ground = cover({ background = parts.paint(theme, "overlay", "scrim", {}) })

    if not dismissible or onDismiss == nil then
        return View { key = "scrim", style = ground }
    end

    return Pressable {
        key = "scrim",
        style = ground,
        accessibilityLabel = "Dismiss",
        onPress = onDismiss,
    }
end

--- The chrome every panel shown over a screen carries, which is what a design changes about all of them.
---
--- What a panel is placed at is the component's own and what it is made of is the design's, so the two
--- are written into one table here: what is shown over a screen is given a style rather than a list of
--- them, since it is what a moving node carries rather than what a caller wrote.
local function panelled(theme, placed, corners)
    local look = {
        background = parts.paint(theme, "overlay", "panel", {}),
        radius = corners or theme:metric("overlay", "radius"),
        shadow = theme:metric("overlay", "elevation"),
        overflow = "hidden",
    }

    for key, value in pairs(placed or {}) do
        look[key] = value
    end

    return look
end

--- Travels a panel the whole of its own size, which is how a panel anchored to an edge leaves.
---
--- The distance belongs to the renderer, since only it knows what the panel turned out to be. Written
--- as a fixed number here it would be a guess at a size the layout works out.
local function edge(axis)
    local travel = { [axis] = "100%" }

    return { enter = { transform = travel }, exit = { transform = travel } }
end

local fromBottom = edge("translateY")
M.fromLeft = { enter = { transform = { translateX = "-100%" } },
    exit = { transform = { translateX = "-100%" } } }
M.fromRight = edge("translateX")

--- The edges of the surface a panel reaches, which are the ones the system draws its own things over.
---
--- A panel is placed against the edges it names: one anchored to the bottom touches three of them and a
--- drawer touches its own side and both ends. What it does not touch has a screen behind it rather than
--- the system, so insetting there would be a gap inside the panel with nothing in it.
local function touching(panel)
    local edges = {}

    for _, edge in ipairs({ "top", "right", "bottom", "left" }) do
        if panel[edge] == 0 then
            edges[#edges + 1] = edge
        end
    end

    return edges
end

--- The four moments everything shown over a screen reports, which a caller is told both ends of.
local MOMENTS = { "onWillShow", "onShow", "onWillHide", "onHide" }

--- Answers the moments a component was given, which travel to the panel that actually moves.
local function moments(props)
    local told = {}

    for index = 1, #MOMENTS do
        told[MOMENTS[index]] = props[MOMENTS[index]]
    end

    return told
end

--- Everything shown over a screen: a ground that fades and a panel that arrives its own way.
---
--- They are two different moves. A ground covers the screen and has nowhere to travel to, so it fades
--- where it is, and a panel travels, which is what a reader reads as the thing arriving. Animated as one
--- node the ground goes with the panel, so dismissing a sheet dragged the darkness down with it and
--- uncovered the screen from the top while the panel was still on its way out.
---
--- The panel is the node that moves rather than a sheet of glass with the panel somewhere inside it, so
--- travelling the whole of its own size means its own size and not the screen's.
---
--- It is drawn through a portal, so what covers the screen covers the application: a drawer raised from
--- a screen inside a stack darkens the bar above it too. That is also why the panel keeps the system
--- clear of what it holds: standing over the whole surface, it stands under the clock and over the home
--- indicator, which a panel written inside a screen was never close enough to reach.
function M.over(theme, shown, onDismiss, transition, panel, children, told)
    told = told or {}

    return Portal {
        Presence {
            visible = shown,
            transition = "fade",

            scrim(onDismiss, true, theme),

            Presence {
                key = "panel",
                visible = shown,
                transition = transition,
                style = panel,

                onWillShow = told.onWillShow,
                onShow = told.onShow,
                onWillHide = told.onWillHide,
                onHide = told.onHide,

                structure.SafeArea {
                    key = "inside",
                    edges = touching(panel),
                    style = { grow = 1 },
                    table.unpack(children),
                },
            },
        },
    }
end

local over = M.over

--- A row of an alert or an action sheet, drawn in the colour its kind is drawn in.
local function action(entry, onPress)
    local tint = "primary"

    if entry.destructive then
        tint = "danger"
    end

    return Pressable {
        key = tostring(entry.key),
        style = { height = ROW, justify = "center", align = "center" },
        accessibilityLabel = entry.label,
        onPress = function()
            if onPress ~= nil then
                onPress(entry.key)
            end
        end,
        Text { text = entry.label, style = { fontSize = "headline", color = tint } },
    }
end

--- A stack of actions with a rule between them, which is what both asking components are made of.
local function actions(entries, onPress)
    local rows = {}

    for index = 1, #(entries or {}) do
        rows[#rows + 1] = Divider { key = "rule:" .. index }
        rows[#rows + 1] = action(entries[index], onPress)
    end

    return rows
end

--- Everything the screen carries, shown over it until it is dismissed.
M.Modal = support.component("Modal", {
    props = { "visible", "dismissible", "transparent" },
    events = { "onDismiss", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false, dismissible = true, transparent = false },
}, component.define({
    name = "Modal",

    render = function(self)
        local ground = "background"

        if self.props.transparent then
            ground = nil
        end

        -- A tablet centres what is shown over a screen rather than covering the whole of one with it,
        -- which is what the system does with a form sheet.
        local theme = parts.themeOf(self)
        local room = chrome.panel(environment:read(self).breakpoint)

        if room.centred then
            return over(theme, self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
                fromBottom, panelled(theme, {
                    position = "absolute", left = "50%", marginLeft = -room.width / 2,
                    top = "8%", bottom = "8%", width = room.width, maxHeight = room.height,
                }), self.children, moments(self.props))
        end

        return over(theme, self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
            fromBottom, cover({ background = ground }), self.children, moments(self.props))
    end,
}))

--- A panel that rises from the bottom and stops at the height it was told to.
M.Sheet = support.component("Sheet", {
    props = { "visible", "detents", "selectedDetent", "dismissible", "grabber" },
    events = { "onDismiss", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false, detents = { "medium", "large" }, dismissible = true, grabber = true },
}, component.define({
    name = "Sheet",

    --- Answers how much of the screen the sheet takes, which is what a detent names.
    height = function(self)
        local detent = self.props.selectedDetent or self.props.detents[1]

        if detent == "large" then
            return "92%"
        end

        if detent == "small" then
            return "30%"
        end

        return "55%"
    end,

    render = function(self)
        local theme = parts.themeOf(self)
        local room = chrome.panel(environment:read(self).breakpoint)
        local panel = {
            position = "absolute",
            left = 0,
            right = 0,
            bottom = 0,
            height = self:height(),
            background = "elevated",
            shadow = "lg",
            radius = "lg",
            overflow = "hidden",
        }

        -- On a large screen a sheet is a panel in the middle, which is where the system puts one.
        if room.centred then
            panel = {
                position = "absolute", left = "50%", marginLeft = -room.width / 2,
                top = "10%", bottom = "10%", width = room.width, maxHeight = room.height,
                panelled(parts.themeOf(self), nil, parts.themeOf(self):metric("overlay", "sheetRadius")),
            }
        end

        local children = {}

        if self.props.grabber then
            children[#children + 1] = View { key = "grabber", style = { align = "center", paddingVertical = "sm" },
                View { style = { width = 36, height = 5, radius = "pill", background = "separator" } },
            }
        end

        for index = 1, #self.children do
            children[#children + 1] = self.children[index]
        end

        return over(parts.themeOf(self), self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
            fromBottom, panel, children, moments(self.props))
    end,
}))

--- A question in the middle of the screen, with the answers under it.
M.Alert = support.component("Alert", {
    props = { "visible", "title", "message", "actions" },
    events = { "onAction", "onDismiss", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false },
    validate = function(spec)
        if spec.visible and spec.title == nil then
            return "needs a title while it is visible"
        end
    end,
}, component.define({
    name = "Alert",

    render = function(self)
        local head = { Text {
            key = "title",
            text = self.props.title,
            style = { fontSize = "headline", fontWeight = "600", textAlign = "center" },
        } }

        if self.props.message ~= nil then
            head[#head + 1] = Text {
                key = "message",
                text = self.props.message,
                style = { fontSize = "footnote", color = "textMuted", textAlign = "center" },
            }
        end

        local card = {
            View { key = "head", style = { padding = "md", gap = "xs" }, table.unpack(head) },
        }

        for _, row in ipairs(actions(self.props.actions, self.props.onAction)) do
            card[#card + 1] = row
        end

        return over(parts.themeOf(self), self.props.visible, self.props.onDismiss, "scale",
            panelled(parts.themeOf(self), {
                position = "absolute", left = "12%", right = "12%", top = "34%",
            }), card, moments(self.props))
    end,
}))

--- The same question asked from the bottom of the screen, which is where a phone asks it.
M.ActionSheet = support.component("ActionSheet", {
    props = { "visible", "title", "message", "actions", "cancelLabel" },
    events = { "onAction", "onDismiss", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false, cancelLabel = "Cancel" },
}, component.define({
    name = "ActionSheet",

    render = function(self)
        local card = {}

        if self.props.title ~= nil then
            card[#card + 1] = View { key = "head", style = { padding = "md", gap = "xs" },
                Text {
                    text = self.props.title,
                    style = { fontSize = "footnote", color = "textMuted", textAlign = "center" },
                },
            }
        end

        for _, row in ipairs(actions(self.props.actions, self.props.onAction)) do
            card[#card + 1] = row
        end

        -- The choices and the way out are one panel stacked from the bottom edge, so the space between
        -- them is a gap rather than two offsets that have to agree about how tall the other one is.
        return over(parts.themeOf(self), self.props.visible, self.props.onDismiss, fromBottom, {
            position = "absolute", left = "4%", right = "4%", bottom = 24, gap = "sm",
        }, {
            View {
                key = "choices",
                style = panelled(parts.themeOf(self), nil),
                table.unpack(card),
            },

            Pressable {
                key = "cancel",
                style = {
                    panelled(parts.themeOf(self), nil),
                    { height = ROW, justify = "center", align = "center" },
                },
                accessibilityLabel = self.props.cancelLabel,
                onPress = self.props.onDismiss,
                Text {
                    text = self.props.cancelLabel,
                    style = { fontSize = "headline", fontWeight = "600", color = "primary" },
                },
            },
        }, moments(self.props))
    end,
}))

--- A list of choices shown where it was opened from.
M.Menu = support.component("Menu", {
    props = { "items", "visible" },
    events = { "onSelect", "onDismiss", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false },
    validate = function(spec)
        if type(spec.items) ~= "table" then
            return "items must be a list of { key, label, destructive } entries"
        end
    end,
}, component.define({
    name = "Menu",

    render = function(self)
        local rows = {}

        for index = 1, #self.props.items do
            local item = self.props.items[index]
            local tint = "text"

            if item.destructive then
                tint = "danger"
            end

            if index > 1 then
                rows[#rows + 1] = Divider { key = "rule:" .. index }
            end

            rows[#rows + 1] = Pressable {
                key = tostring(item.key),
                style = { height = 44, justify = "center", paddingHorizontal = "md" },
                accessibilityLabel = item.label,
                onPress = function()
                    if self.props.onSelect ~= nil then
                        self.props.onSelect(item.key)
                    end
                end,
                Text { text = item.label, style = { color = tint } },
            }
        end

        return over(parts.themeOf(self), self.props.visible, self.props.onDismiss, "scale",
            panelled(parts.themeOf(self), {
                position = "absolute", left = "20%", right = "20%", top = "30%",
            }), rows, moments(self.props))
    end,
}))

--- A line at the edge of the screen that says what happened and goes away on its own.
M.Toast = support.component("Toast", {
    props = { "visible", "message", "duration", "position", "action" },
    events = { "onDismiss", "onAction", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { visible = false, duration = 3000, position = "bottom" },
    validate = function(spec)
        local choices = { "top", "bottom" }
        if not support.oneOf(spec.position, choices) then
            return support.expected("position", spec.position, choices)
        end

        if type(spec.duration) ~= "number" or spec.duration < 0 then
            return "duration is how long it stays on screen, in milliseconds"
        end
    end,
}, component.define({
    name = "Toast",

    onMount = function(self)
        self:wait()
    end,

    onUpdate = function(self)
        self:wait()
    end,

    onUnmount = function(self)
        self.gone = true
    end,

    --- Dismisses itself once it has been read, which is what a toast does rather than waiting to be told.
    wait = function(self)
        if not self.props.visible or self.waiting or self.props.onDismiss == nil then
            return
        end

        self.waiting = true

        self:after(self.props.duration, function()
            self.waiting = false

            if not self.gone and self.props.visible then
                self.props.onDismiss()
            end
        end)
    end,

    render = function(self)
        local bar = {
            position = "absolute",
            left = "5%",
            right = "5%",
            direction = "row",
            align = "center",
            gap = "md",
            minHeight = 48,
            paddingHorizontal = "md",
            background = "text",
            radius = "md",
        }

        if self.props.position == "top" then
            bar.top = 60
        else
            bar.bottom = 40
        end

        local children = {
            Text {
                key = "message",
                text = self.props.message,
                style = { grow = 1, color = "background" },
            },
        }

        if self.props.action ~= nil then
            children[#children + 1] = Pressable {
                key = "action",
                accessibilityLabel = self.props.action,
                onPress = self.props.onAction,
                Text {
                    text = self.props.action,
                    style = { fontWeight = "600", color = "primary" },
                },
            }
        end

        -- A line at the edge of the screen is over the application like everything else here, and it
        -- darkens nothing: a reader carries on with what they were doing while it says what happened.
        return Portal {
            Presence {
                visible = self.props.visible,
                transition = self.props.position == "top" and "slideDown" or "slideUp",
                style = bar,

                onWillShow = self.props.onWillShow,
                onShow = self.props.onShow,
                onWillHide = self.props.onWillHide,
                onHide = self.props.onHide,

                structure.SafeArea {
                    key = "inside",
                    edges = touching(bar),
                    style = { grow = 1, direction = "row", align = "center", gap = "md" },
                    table.unpack(children),
                },
            },
        }
    end,
}))

--- A message along the bottom edge with one thing that can be done about it.
---
--- A toast says something and goes. A snackbar offers to undo it, which is why it waits to be answered:
--- something a reader has to reach cannot be on a timer they do not control.
M.Snackbar = support.component("Snackbar", {
    props = { "visible", "message", "actions" },
    events = { "onAction", "onDismiss" },
    defaults = { visible = false },
    validate = function(spec)
        if spec.message == nil then
            return "needs a message to show"
        end
    end,
}, drawn.snackbar)

--- A message across the top of the content, which stays until it is answered.
M.Banner = support.component("Banner", {
    props = { "visible", "message", "actions", "icon", "tone" },
    events = { "onAction" },
    defaults = { visible = true, tone = "neutral" },
    validate = function(spec)
        if spec.message == nil then
            return "needs a message to show"
        end

        if not support.oneOf(spec.tone, { "neutral", "danger" }) then
            return support.expected("tone", spec.tone, { "neutral", "danger" })
        end
    end,
}, drawn.banner)

--- A panel anchored to whatever opened it, with an arrow pointing back at it.
---
--- Where the thing that was pressed is, is something only the layout knows, so the anchor is the frame
--- the caller reports from that node's own `onLayout`.
M.Popover = support.component("Popover", {
    props = { "visible", "anchor", "dismissLabel" },
    events = { "onDismiss" },
    defaults = { visible = false },
}, drawn.popover)

return M
