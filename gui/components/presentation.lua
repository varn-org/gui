local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local environment = require("gui.environment")
local input = require("gui.components.input")
local presence = require("gui.components.presence")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable
local Presence = presence.Presence

local ROW = 52

local cover = support.cover

--- The dark ground behind what is shown over the screen, which dismisses it when it is pressed.
function M.scrim(onDismiss, dismissible)
    if not dismissible or onDismiss == nil then
        return View { key = "scrim", style = cover({ background = "overlay" }) }
    end

    return Pressable {
        key = "scrim",
        style = cover({ background = "overlay" }),
        accessibilityLabel = "Dismiss",
        onPress = onDismiss,
    }
end

--- Travels a panel the whole of its own size, which is how a panel anchored to an edge leaves.
---
--- The distance belongs to the renderer, since only it knows what the panel turned out to be. Written
--- as a fixed number here it would be a guess at a size the layout works out.
local function edge(axis)
    local travel = { [axis] = "100%" }

    return { enter = { transform = travel }, exit = { transform = travel } }
end

M.fromBottom = edge("translateY")
M.fromLeft = { enter = { transform = { translateX = "-100%" } },
    exit = { transform = { translateX = "-100%" } } }
M.fromRight = edge("translateX")

--- Everything shown over a screen: a ground that fades and a panel that arrives its own way.
---
--- They are two different moves. A ground covers the screen and has nowhere to travel to, so it fades
--- where it is, and a panel travels, which is what a reader reads as the thing arriving. Animated as one
--- node the ground goes with the panel, so dismissing a sheet dragged the darkness down with it and
--- uncovered the screen from the top while the panel was still on its way out.
---
--- The panel is the node that moves rather than a sheet of glass with the panel somewhere inside it, so
--- travelling the whole of its own size means its own size and not the screen's.
function M.over(shown, onDismiss, transition, panel, children)
    return Presence {
        visible = shown,
        transition = "fade",

        M.scrim(onDismiss, true),

        Presence {
            key = "panel",
            visible = shown,
            transition = transition,
            style = panel,
            table.unpack(children),
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
    events = { "onDismiss" },
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
        local room = chrome.panel(environment:read(self).breakpoint)

        if room.centred then
            return over(self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
                M.fromBottom, {
                    position = "absolute", left = "50%", marginLeft = -room.width / 2,
                    top = "8%", bottom = "8%", width = room.width, maxHeight = room.height,
                    background = ground, radius = "lg", overflow = "hidden", shadow = "lg",
                }, self.children)
        end

        return over(self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
            M.fromBottom, cover({ background = ground }), self.children)
    end,
}))

--- A panel that rises from the bottom and stops at the height it was told to.
M.Sheet = support.component("Sheet", {
    props = { "visible", "detents", "selectedDetent", "dismissible", "grabber" },
    events = { "onDismiss" },
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
                background = "elevated", shadow = "lg", radius = "lg", overflow = "hidden",
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

        return over(self.props.visible, self.props.dismissible and self.props.onDismiss or nil,
            M.fromBottom, panel, children)
    end,
}))

--- A question in the middle of the screen, with the answers under it.
M.Alert = support.component("Alert", {
    props = { "visible", "title", "message", "actions" },
    events = { "onAction", "onDismiss" },
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

        return over(self.props.visible, self.props.onDismiss, "scale", {
            position = "absolute", left = "12%", right = "12%", top = "34%",
            background = "elevated", radius = "lg", overflow = "hidden", shadow = "lg",
        }, card)
    end,
}))

--- The same question asked from the bottom of the screen, which is where a phone asks it.
M.ActionSheet = support.component("ActionSheet", {
    props = { "visible", "title", "message", "actions", "cancelLabel" },
    events = { "onAction", "onDismiss" },
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
        return over(self.props.visible, self.props.onDismiss, M.fromBottom, {
            position = "absolute", left = "4%", right = "4%", bottom = 24, gap = "sm",
        }, {
            View {
                key = "choices",
                style = { background = "elevated", radius = "lg", overflow = "hidden", shadow = "lg" },
                table.unpack(card),
            },

            Pressable {
                key = "cancel",
                style = { height = ROW, justify = "center", align = "center", background = "elevated",
                    radius = "lg", shadow = "lg" },
                accessibilityLabel = self.props.cancelLabel,
                onPress = self.props.onDismiss,
                Text {
                    text = self.props.cancelLabel,
                    style = { fontSize = "headline", fontWeight = "600", color = "primary" },
                },
            },
        })
    end,
}))

--- A list of choices shown where it was opened from.
M.Menu = support.component("Menu", {
    props = { "items", "visible" },
    events = { "onSelect", "onDismiss" },
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

        return over(self.props.visible, self.props.onDismiss, "scale", {
            position = "absolute", left = "20%", right = "20%", top = "30%",
            background = "elevated", radius = "md", overflow = "hidden", shadow = "md",
        }, rows)
    end,
}))

--- A line at the edge of the screen that says what happened and goes away on its own.
M.Toast = support.component("Toast", {
    props = { "visible", "message", "duration", "position", "action" },
    events = { "onDismiss", "onAction" },
    defaults = { visible = false, duration = 3000, position = "bottom" },
    validate = function(spec)
        local choices = { "top", "bottom" }
        if not support.oneOf(spec.position, choices) then
            return support.expected("position", spec.position, choices)
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

        return Presence {
            visible = self.props.visible,
            transition = self.props.position == "top" and "slideDown" or "slideUp",
            style = bar,
            table.unpack(children),
        }
    end,
}))

return M
