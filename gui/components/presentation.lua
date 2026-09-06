local component = require("gui.component")
local content = require("gui.components.content")
local input = require("gui.components.input")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

local View = structure.View
local Divider = structure.Divider
local Text = content.Text
local Pressable = input.Pressable

local ROW = 52

--- The whole surface, which is what anything shown over a screen is placed against.
local COVER = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0 }

local function cover(style)
    local box = {}

    for key, value in pairs(COVER) do
        box[key] = value
    end

    for key, value in pairs(style or {}) do
        box[key] = value
    end

    return box
end

--- The dark ground behind what is shown over the screen, which dismisses it when it is pressed.
local function scrim(onDismiss, dismissible)
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
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

        local ground = "background"

        if self.props.transparent then
            ground = nil
        end

        return View { style = cover(self.props.style),
            scrim(self.props.onDismiss, self.props.dismissible),
            View { key = "content", style = cover({ background = ground }), table.unpack(self.children) },
        }
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
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

        local panel = {
            position = "absolute",
            left = 0,
            right = 0,
            bottom = 0,
            height = self:height(),
            background = "background",
            radius = "lg",
            overflow = "hidden",
        }

        local children = {}

        if self.props.grabber then
            children[#children + 1] = View { key = "grabber", style = { align = "center", paddingVertical = "sm" },
                View { style = { width = 36, height = 5, radius = "pill", background = "separator" } },
            }
        end

        for index = 1, #self.children do
            children[#children + 1] = self.children[index]
        end

        return View { style = cover(self.props.style),
            scrim(self.props.onDismiss, self.props.dismissible),
            View { key = "panel", style = panel, table.unpack(children) },
        }
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
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

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

        return View { style = cover(self.props.style),
            scrim(self.props.onDismiss, true),
            View {
                key = "card",
                style = { position = "absolute", left = "12%", right = "12%", top = "34%",
                    background = "background", radius = "lg", overflow = "hidden" },
                table.unpack(card),
            },
        }
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
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

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

        return View { style = cover(self.props.style),
            scrim(self.props.onDismiss, true),

            View { key = "choices", style = { position = "absolute", left = "4%", right = "4%", bottom = 90,
                background = "background", radius = "lg", overflow = "hidden" }, table.unpack(card) },

            Pressable {
                key = "cancel",
                style = { position = "absolute", left = "4%", right = "4%", bottom = 24, height = ROW,
                    justify = "center", align = "center", background = "background", radius = "lg" },
                accessibilityLabel = self.props.cancelLabel,
                onPress = self.props.onDismiss,
                Text {
                    text = self.props.cancelLabel,
                    style = { fontSize = "headline", fontWeight = "600", color = "primary" },
                },
            },
        }
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
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

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

        return View { style = cover(self.props.style),
            scrim(self.props.onDismiss, true),
            View {
                key = "items",
                style = { position = "absolute", left = "20%", right = "20%", top = "30%",
                    background = "background", radius = "md", overflow = "hidden" },
                table.unpack(rows),
            },
        }
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

        require("async").spawn(function()
            require("async").sleep(self.props.duration):await()
            self.waiting = false

            if not self.gone and self.props.visible then
                self.props.onDismiss()
            end
        end)
    end,

    render = function(self)
        if not self.props.visible then
            return View { style = { width = 0, height = 0 } }
        end

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

        return View { style = bar, table.unpack(children) }
    end,
}))

return M
