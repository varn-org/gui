local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

local DAYS = { "M", "T", "W", "T", "F", "S", "S" }
local MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

--- Answers the day of the week a date falls on, counting Monday as the first.
local function weekday(year, month, day)
    return tonumber(os.date("%u", os.time({ year = year, month = month, day = day, hour = 12 })))
end

--- Answers how many days a month has, which is the day before the first of the next one.
local function lengthOf(year, month)
    local after = os.time({ year = month == 12 and year + 1 or year, month = month % 12 + 1, day = 1, hour = 12 })

    return tonumber(os.date("%d", after - 86400))
end

--- Answers a date as the string every part of this reads it as, which is what a caller writes.
local function written(year, month, day)
    return string.format("%04d-%02d-%02d", year, month, day)
end

--- Answers the three numbers a written date carries, or today when it carries none.
local function readDate(value)
    local year, month, day = tostring(value or ""):match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

    if year == nil then
        local now = os.date("*t")
        return now.year, now.month, now.day
    end

    return tonumber(year), tonumber(month), tonumber(day)
end

--- A month drawn as a grid of days, with the months either side a press away.
---
--- A date is written as `YYYY-MM-DD` rather than as a number of seconds, which is what a screen holds,
--- what a form sends and what reads the same in every part of the world.
return component.define({
    name = "DrawnCalendar",
    state = { year = nil, month = nil, focused = nil },

    --- Answers the month being looked at, which is the one holding the value until a reader moves it.
    looking = function(self)
        local year, month = readDate(self.props.value)

        return self.state.year or year, self.state.month or month
    end,

    move = function(self, by)
        local year, month = self:looking()
        local wanted = month + by

        if wanted < 1 then
            self:setState({ year = year - 1, month = 12 })
            return
        end

        if wanted > 12 then
            self:setState({ year = year + 1, month = 1 })
            return
        end

        self:setState({ year = year, month = wanted })
    end,

    render = function(self)
        local props = self.props
        local theme = props.theme
        local year, month = self:looking()
        local chosen = props.value
        local size = theme:metric("calendar", "day")
        local cells = {}

        local first = weekday(year, month, 1)
        local held = lengthOf(year, month)

        for _ = 1, first - 1 do
            cells[#cells + 1] = View { key = "gap" .. #cells, style = { width = size, height = size } }
        end

        for day = 1, held do
            local at = written(year, month, day)
            local on = at == chosen
            local past = props.minimum ~= nil and at < props.minimum
            local ahead = props.maximum ~= nil and at > props.maximum
            local about = { on = on, disabled = past or ahead }

            cells[#cells + 1] = Pressable {
                key = at,
                disabled = about.disabled,
                accessibilityLabel = day .. " " .. MONTHS[month] .. " " .. year,
                accessibilityRole = "button",
                accessibilityState = { selected = on, disabled = about.disabled },
                focusable = not about.disabled,
                transition = parts.motion(theme, "calendar"),
                style = {
                    width = size,
                    height = size,
                    align = "center",
                    justify = "center",
                    radius = theme:metric("calendar", "radius"),
                    background = parts.paint(theme, "calendar", "day", about),
                },
                onPress = function()
                    if props.onChange ~= nil then
                        props.onChange(at)
                    end
                end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) and props.onChange ~= nil then
                        props.onChange(at)
                    end
                end,
                onFocus = function() self:setState({ focused = at }) end,
                onBlur = function() self:setState({ focused = component.none }) end,

                Text {
                    text = tostring(day),
                    style = {
                        color = parts.paint(theme, "calendar", "number", about),
                        fontWeight = on and "700" or "400",
                    },
                },
            }
        end

        local heads = {}

        for index = 1, #DAYS do
            heads[index] = Text {
                key = "day" .. index,
                text = DAYS[index],
                style = {
                    width = size,
                    textAlign = "center",
                    fontSize = "caption",
                    fontWeight = "600",
                    color = parts.paint(theme, "calendar", "weekday", {}),
                },
            }
        end

        local function step(name, by, icon)
            return Pressable {
                key = name,
                accessibilityLabel = name == "back" and "The month before" or "The month after",
                accessibilityRole = "button",
                focusable = true,
                style = { width = 44, height = 44, align = "center", justify = "center" },
                onPress = function() self:move(by) end,
                onKeyDown = function(key)
                    if parts.chooses(key.key) then
                        self:move(by)
                    end
                end,

                content.Icon {
                    name = icon,
                    size = 20,
                    color = parts.paint(theme, "calendar", "number", {}),
                },
            }
        end

        return View {
            accessibilityRole = "none",
            accessibilityLabel = props.accessibilityLabel,
            testID = props.testID,
            style = { { gap = theme:metric("calendar", "gap") }, props.style },

            View {
                key = "head",
                style = { direction = "row", align = "center", justify = "space-between" },

                step("back", -1, "chevron-left"),

                Text {
                    key = "month",
                    text = MONTHS[month] .. " " .. year,
                    style = { fontWeight = "600", color = parts.paint(theme, "calendar", "number", {}) },
                },

                step("on", 1, "chevron-right"),
            },

            View { key = "days", style = { direction = "row" }, table.unpack(heads) },
            View { key = "grid", style = { direction = "row", wrap = true }, table.unpack(cells) },
        }
    end,
})
