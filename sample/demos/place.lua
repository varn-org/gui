local gui = require("gui")
local parts = require("parts")

--- Places worth looking at, so the map has somewhere to go without a reader typing a coordinate.
local PLACES = {
    { key = "lisbon", title = "Lisbon", latitude = 38.7223, longitude = -9.1393 },
    { key = "london", title = "London", latitude = 51.5074, longitude = -0.1278 },
    { key = "tokyo", title = "Tokyo", latitude = 35.6762, longitude = 139.6503 },
    { key = "recife", title = "Recife", latitude = -8.0476, longitude = -34.8770 },
}

--- Answers a coordinate written the way a person reads one.
local function written(latitude, longitude)
    return string.format("%.4f, %.4f", latitude, longitude)
end

local Maps = gui.component({
    name = "MapDemo",
    state = {
        center = { latitude = PLACES[1].latitude, longitude = PLACES[1].longitude },
        zoom = 12,
        chosen = PLACES[1].key,
        dropped = {},
        said = "Press a mark, or press the map to drop one",
    },

    go = function(self, place)
        self:setState({
            chosen = place.key,
            center = { latitude = place.latitude, longitude = place.longitude },
            zoom = 12,
            said = "Looking at " .. place.title,
        })
    end,

    --- Answers everything on the map, which is the places it knows plus what a reader dropped.
    marks = function(self)
        local marks = {}

        for index = 1, #PLACES do
            marks[index] = PLACES[index]
        end

        for index = 1, #self.state.dropped do
            marks[#marks + 1] = self.state.dropped[index]
        end

        return marks
    end,

    drop = function(self, at)
        local dropped = {}

        for index = 1, #self.state.dropped do
            dropped[index] = self.state.dropped[index]
        end

        dropped[#dropped + 1] = {
            key = "dropped:" .. (#dropped + 1),
            latitude = at.latitude,
            longitude = at.longitude,
            title = "Mark " .. (#dropped + 1),
        }

        self:setState({ dropped = dropped, said = "Dropped a mark at " .. written(at.latitude, at.longitude) })
    end,

    named = function(self, key)
        for index = 1, #PLACES do
            if PLACES[index].key == key then
                return PLACES[index].title
            end
        end

        return key
    end,

    render = function(self)
        local buttons = {}

        for index = 1, #PLACES do
            buttons[index] = gui.Button {
                key = PLACES[index].key,
                title = PLACES[index].title,
                variant = self.state.chosen == PLACES[index].key and "filled" or "tinted",
                size = "small",
                onPress = function() self:go(PLACES[index]) end,
            }
        end

        return parts.Page {
            parts.Block {
                title = "A place on the map",
                gui.Map {
                    accessibilityLabel = "The map, pressed to drop a mark",
                    center = self.state.center,
                    zoom = self.state.zoom,
                    markers = self:marks(),
                    style = { height = 300, radius = "md" },
                    onRegionChange = function(region)
                        self:setState({ center = region.center, zoom = region.zoom })
                    end,
                    onMarkerPress = function(marker)
                        self:setState({ said = "That mark is " .. self:named(marker.key) })
                    end,
                    onPress = function(at) self:drop(at) end,
                },

                gui.Text { text = self.state.said, style = { fontWeight = "600", color = "primary" } },
                gui.Text {
                    text = written(self.state.center.latitude, self.state.center.longitude)
                        .. " at zoom " .. string.format("%.1f", self.state.zoom),
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },

            parts.Block {
                title = "Somewhere else",
                gui.View { style = { direction = "row", gap = "sm", wrap = "wrap" }, table.unpack(buttons) },
            },

            parts.Block {
                title = "A map that is only a picture",
                gui.Map {
                    center = { latitude = PLACES[2].latitude, longitude = PLACES[2].longitude },
                    zoom = 15,
                    interactive = false,
                    markers = { { key = "office", latitude = PLACES[2].latitude,
                        longitude = PLACES[2].longitude, title = "Here" } },
                    style = { height = 180, radius = "md" },
                },
                gui.Text {
                    text = "A map that may not be moved is what an address on a page is.",
                    style = { fontSize = "footnote", color = "textMuted" },
                },
            },
        }
    end,
})

local Where = gui.component({
    name = "LocationDemo",
    state = { asking = false, watching = false, fix = nil, problem = nil },

    render = function(self)
        local fix = self.state.fix

        return parts.Page {
            parts.Block {
                title = "Where this device is",

                self.state.asking and gui.Location {
                    watch = self.state.watching,
                    accuracy = "fine",
                    onChange = function(at) self:setState({ fix = at, problem = gui.none }) end,
                    onError = function(problem) self:setState({ problem = problem.message }) end,
                } or false,

                parts.Row("Ask where I am", gui.Switch {
                    value = self.state.asking,
                    onChange = function(on)
                        self:setState({ asking = on, fix = gui.none, problem = gui.none })
                    end,
                }),

                parts.Row("Keep following", gui.Switch {
                    value = self.state.watching,
                    onChange = function(on) self:setState({ watching = on }) end,
                }),

                gui.Text {
                    text = fix ~= nil and written(fix.latitude, fix.longitude)
                        or (self.state.problem or "Nothing asked for yet"),
                    style = { fontWeight = "600", color = self.state.problem ~= nil and "danger" or "primary" },
                },

                fix ~= nil and gui.Text {
                    text = string.format("to within %.0f m", fix.accuracy),
                    style = { fontSize = "footnote", color = "textMuted" },
                } or false,
            },

            fix ~= nil and parts.Block {
                title = "On the map",
                gui.Map {
                    center = { latitude = fix.latitude, longitude = fix.longitude },
                    zoom = 16,
                    markers = { { key = "me", latitude = fix.latitude, longitude = fix.longitude, title = "You" } },
                    style = { height = 260, radius = "md" },
                },
            } or false,

            parts.Block {
                title = "How it works",
                gui.Text {
                    text = "Asking is mounting a Location and letting go is unmounting it, so nothing keeps"
                        .. " a receiver running behind a screen you have left. The permission is the"
                        .. " platform's own, and a refusal is reported rather than left waiting.",
                    style = { color = "textMuted" },
                },
            },
        }
    end,
})

return {
    { key = "map", title = "Maps", summary = "A place, marks on it, and what a press reports",
      render = function() return Maps {} end },
    { key = "location", title = "Location", summary = "Where the device is, once or as it moves",
      render = function() return Where {} end },
}
