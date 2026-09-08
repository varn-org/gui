local support = require("gui.components.support")

local M = {}

local ACCURACY = { "coarse", "fine" }

--- Answers whether a value is a coordinate, which is the one shape every prop here is written in.
local function coordinate(value)
    if type(value) ~= "table" then
        return false
    end

    if type(value.latitude) ~= "number" or type(value.longitude) ~= "number" then
        return false
    end

    return math.abs(value.latitude) <= 90 and math.abs(value.longitude) <= 180
end

--- A map of the world, centred where the caller asked and marked where the caller said.
---
--- The platform draws the map and answers the gestures over it, which is the whole of what it decides.
--- Where it is looking, what is marked on it and what happens when a mark is pressed are the tree's,
--- so a map is written the way a list is: state goes in and an event comes back.
M.Map = support.host("map", {
    natural = { size = { height = 240 } },
    props = { "center", "zoom", "markers", "interactive" },
    events = { "onRegionChange", "onMarkerPress", "onPress", "onLayout" },
    defaults = { zoom = 14, interactive = true },
    validate = function(spec)
        if not coordinate(spec.center) then
            return "center must be a { latitude, longitude } inside the world"
        end

        if type(spec.zoom) ~= "number" or spec.zoom < 1 or spec.zoom > 20 then
            return "zoom must be between 1 and 20, got " .. tostring(spec.zoom)
        end

        for index = 1, #(spec.markers or {}) do
            local marker = spec.markers[index]

            if not coordinate(marker) then
                return "marker " .. index .. " must be a { latitude, longitude } inside the world"
            end

            if type(marker.key) ~= "string" then
                return "marker " .. index .. " must carry a key, since it is what a press reports"
            end
        end
    end,
})

--- Where the device is, reported for as long as this is on screen.
---
--- Asking is mounting one and letting go is unmounting it, so nothing keeps a receiver running behind a
--- screen a reader has left. The permission the platform requires is asked for the first time one is
--- mounted, and a reader who refuses is reported through `onError` rather than left waiting.
M.Location = support.host("location", {
    natural = { size = { width = 0, height = 0 } },
    props = { "watch", "accuracy" },
    events = { "onChange", "onError" },
    defaults = { watch = false, accuracy = "fine" },
    validate = function(spec)
        if not support.oneOf(spec.accuracy, ACCURACY) then
            return support.expected("accuracy", spec.accuracy, ACCURACY)
        end
    end,
})

return M
