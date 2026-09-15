local gui = require("gui")

--- A weather application: the hour a reader is in, the day ahead of them, and the week after that.
---
--- Almost all of it is one screen that scrolls, which is what makes it worth replicating: the shape is a
--- hero nobody scrolls past, a strip that runs sideways under it, and a column of days. The ground is
--- painted from the sky rather than from the theme, so the screen reads as the weather it is showing
--- while everything drawn on it still follows the look the application is in.
local PLACES = {
    {
        key = "lisbon",
        name = "Lisbon",
        summary = "Clear",
        now = 24,
        high = 27,
        low = 17,
        sky = "clear",
        hours = { 24, 26, 27, 27, 25, 23, 21, 20, 19, 18, 18, 17 },
        days = {
            { key = "mon", name = "Monday", sky = "clear", high = 27, low = 17 },
            { key = "tue", name = "Tuesday", sky = "clear", high = 28, low = 18 },
            { key = "wed", name = "Wednesday", sky = "cloud", high = 25, low = 18 },
            { key = "thu", name = "Thursday", sky = "rain", high = 21, low = 16 },
            { key = "fri", name = "Friday", sky = "cloud", high = 23, low = 16 },
            { key = "sat", name = "Saturday", sky = "clear", high = 26, low = 17 },
            { key = "sun", name = "Sunday", sky = "clear", high = 27, low = 18 },
        },
    },
    {
        key = "reykjavik",
        name = "Reykjavík",
        summary = "Rain",
        now = 6,
        high = 8,
        low = 3,
        sky = "rain",
        hours = { 6, 6, 7, 8, 8, 7, 6, 5, 4, 4, 3, 3 },
        days = {
            { key = "mon", name = "Monday", sky = "rain", high = 8, low = 3 },
            { key = "tue", name = "Tuesday", sky = "rain", high = 7, low = 3 },
            { key = "wed", name = "Wednesday", sky = "cloud", high = 9, low = 4 },
            { key = "thu", name = "Thursday", sky = "cloud", high = 10, low = 5 },
            { key = "fri", name = "Friday", sky = "rain", high = 8, low = 4 },
            { key = "sat", name = "Saturday", sky = "rain", high = 7, low = 3 },
            { key = "sun", name = "Sunday", sky = "cloud", high = 9, low = 4 },
        },
    },
    {
        key = "kyoto",
        name = "Kyoto",
        summary = "Cloudy",
        now = 18,
        high = 22,
        low = 14,
        sky = "cloud",
        hours = { 18, 19, 21, 22, 22, 21, 19, 18, 17, 16, 15, 14 },
        days = {
            { key = "mon", name = "Monday", sky = "cloud", high = 22, low = 14 },
            { key = "tue", name = "Tuesday", sky = "rain", high = 19, low = 14 },
            { key = "wed", name = "Wednesday", sky = "cloud", high = 21, low = 15 },
            { key = "thu", name = "Thursday", sky = "clear", high = 24, low = 15 },
            { key = "fri", name = "Friday", sky = "clear", high = 25, low = 16 },
            { key = "sat", name = "Saturday", sky = "cloud", high = 23, low = 16 },
            { key = "sun", name = "Sunday", sky = "rain", high = 20, low = 15 },
        },
    },
}

--- What the sky is drawn as, which is a run of colours rather than a picture of a cloud.
local SKIES = {
    clear = { colors = { "#3f7fd8", "#89bff0" }, icon = "sun", word = "Clear" },
    cloud = { colors = { "#4a5b72", "#8494aa" }, icon = "cloud", word = "Cloudy" },
    rain = { colors = { "#2f3d52", "#5c6f86" }, icon = "rain", word = "Rain" },
}

local function degrees(value)
    return tostring(math.floor(value + 0.5)) .. "°"
end

--- Answers the hour of the day each reading belongs to, counted from now.
local function hour(index)
    return tostring((index - 1) * 2 % 24) .. "h"
end

local Weather = gui.component({
    name = "WeatherApp",
    state = { place = "lisbon", chosen = nil },

    place = function(self)
        for _, place in ipairs(PLACES) do
            if place.key == self.state.place then
                return place
            end
        end

        return PLACES[1]
    end,

    --- The number nobody scrolls past, on the sky it is happening under.
    ---
    --- The sky runs to the top of the glass and keeps the clock clear of the name of the place, which is
    --- what the inset says rather than a number guessed at for one phone.
    Hero = function(self, place)
        local sky = SKIES[place.sky]
        local insets = gui.environment:read(self).insets

        return gui.Gradient {
            colors = sky.colors,
            direction = "down",
            style = { paddingTop = insets.top + 16, paddingBottom = 32, align = "center", gap = "xs" },

            gui.Text { text = place.name, style = { fontSize = "title", color = "#ffffff" } },
            gui.Text {
                text = degrees(place.now),
                style = { fontSize = 76, fontWeight = "200", color = "#ffffff" },
            },
            gui.Text { text = sky.word, style = { color = "#ffffffcc" } },
            gui.Text {
                text = "H " .. degrees(place.high) .. "   L " .. degrees(place.low),
                style = { color = "#ffffffcc", fontSize = "footnote" },
            },
        }
    end,

    --- The next hours, running sideways the way every weather application shows them.
    Hours = function(self, place)
        local cells = {}

        for index, reading in ipairs(place.hours) do
            cells[#cells + 1] = gui.View {
                key = "hour:" .. index,
                style = { width = 56, align = "center", gap = "xs", paddingVertical = "sm" },
                gui.Text { text = hour(index), style = { fontSize = "caption", color = "textMuted" } },
                gui.Icon { name = SKIES[place.sky].icon, size = 18, color = "text" },
                gui.Text { text = degrees(reading), style = { fontWeight = "600" } },
            }
        end

        return gui.View {
            style = { background = "elevated", radius = "lg", overflow = "hidden" },
            gui.ScrollView {
                horizontal = true,
                showsIndicator = false,
                style = { height = 96 },
                contentStyle = { direction = "row", paddingHorizontal = "sm" },
                table.unpack(cells),
            },
        }
    end,

    --- The week, as a row a day, with the range each one covers drawn between its two numbers.
    Days = function(self, place)
        local coldest, warmest = 99, -99

        for _, day in ipairs(place.days) do
            coldest = math.min(coldest, day.low)
            warmest = math.max(warmest, day.high)
        end

        local rows = {}

        for index, day in ipairs(place.days) do
            local from = (day.low - coldest) / math.max(1, warmest - coldest)
            local span = (day.high - day.low) / math.max(1, warmest - coldest)

            rows[#rows + 1] = gui.View {
                key = day.key,
                style = { direction = "row", align = "center", gap = "md", paddingVertical = "sm" },

                gui.Text { text = day.name:sub(1, 3), style = { width = 44, color = "textMuted" } },
                gui.Icon { name = SKIES[day.sky].icon, size = 18, color = "text" },
                gui.Text { text = degrees(day.low), style = { width = 40, textAlign = "right", color = "textMuted" } },

                gui.View {
                    style = { grow = 1, height = 4, radius = "pill", background = "surface" },
                    gui.View {
                        style = {
                            position = "absolute", top = 0, bottom = 0, radius = "pill",
                            left = tostring(math.floor(from * 100)) .. "%",
                            width = tostring(math.max(8, math.floor(span * 100))) .. "%",
                            background = "primary",
                        },
                    },
                },

                gui.Text { text = degrees(day.high), style = { width = 40, textAlign = "right", fontWeight = "600" } },

            }
        end

        return gui.View {
            style = { background = "elevated", radius = "lg", padding = "md" },
            table.unpack(rows),
        }
    end,

    --- The places this knows, which is what a reader swaps between.
    Places = function(self)
        local chips = {}

        for _, place in ipairs(PLACES) do
            chips[#chips + 1] = gui.Chip {
                key = place.key,
                label = place.name,
                selected = place.key == self.state.place,
                onPress = function() self:setState({ place = place.key }) end,
            }
        end

        return gui.ScrollView {
            horizontal = true,
            showsIndicator = false,
            style = { height = 44 },
            contentStyle = { direction = "row", gap = "sm", align = "center", paddingHorizontal = "md" },
            table.unpack(chips),
        }
    end,

    render = function(self)
        local place = self:place()

        -- A screen of cards stands on the surface and the cards are what is raised off it, which is the
        -- only arrangement that reads in both appearances: a card the colour of the ground is no card.
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "surface" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { gap = "md", paddingBottom = 32 + insets.bottom },

                self:Hero(place),
                self:Places(),

                gui.View { style = { paddingHorizontal = "md", gap = "md" },
                    self:Hours(place),
                    self:Days(place),

                    gui.View { style = { direction = "row", gap = "md" },
                        gui.View {
                            style = { grow = 1, basis = 0, background = "elevated", radius = "lg",
                                padding = "md", gap = "xs" },
                            gui.Text { text = "FEELS LIKE", style = { fontSize = "caption", color = "textMuted" } },
                            gui.Text { text = degrees(place.now - 1), style = { fontSize = "heading" } },
                        },
                        gui.View {
                            style = { grow = 1, basis = 0, background = "elevated", radius = "lg",
                                padding = "md", gap = "xs" },
                            gui.Text { text = "RANGE", style = { fontSize = "caption", color = "textMuted" } },
                            gui.Text {
                                text = degrees(place.low) .. " – " .. degrees(place.high),
                                style = { fontSize = "heading" },
                            },
                        },
                    },
                },
            },
        }
    end,
})

return Weather
