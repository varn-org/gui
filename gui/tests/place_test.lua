local gui = require("gui")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function fails(build, needle)
    local ok, message = pcall(build)

    assert(not ok, "the call should have been refused")
    assert(tostring(message):find(needle, 1, true),
        "expected a message about " .. needle .. ", got " .. tostring(message))
end

local LONDON = { latitude = 51.5074, longitude = -0.1278 }

-- A map is told where to look, and what it is told has to be somewhere on the world.
do
    fails(function() return gui.Map {} end, "center")
    fails(function() return gui.Map { center = { latitude = 91, longitude = 0 } } end, "center")
    fails(function() return gui.Map { center = LONDON, zoom = 42 } end, "zoom")
    fails(function()
        return gui.Map { center = LONDON, markers = { { latitude = 0, longitude = 0 } } }
    end, "key")
    fails(function()
        return gui.Map { center = LONDON, markers = { { key = "a", latitude = 200, longitude = 0 } } }
    end, "world")

    local _, renderer = start(gui.Map { center = LONDON })
    local map = renderer:find("map")

    assert(map.props.zoom == 14, "a map looks at a street rather than the whole world by default")
    assert(map.props.interactive == true, "and a reader may move it")
end

-- What a map reports is what the tree drew it from next, which is the whole of how one is written.
do
    local Screen = gui.component({
        name = "Screen",
        state = { center = LONDON, zoom = 12, said = "" },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Map {
                    center = self.state.center,
                    zoom = self.state.zoom,
                    markers = { { key = "home", latitude = 51.5, longitude = -0.12, title = "Home" } },
                    style = { height = 300 },
                    onRegionChange = function(region)
                        self:setState({ center = region.center, zoom = region.zoom })
                    end,
                    onMarkerPress = function(marker) self:setState({ said = marker.key }) end,
                    onPress = function(at)
                        self:setState({ said = string.format("%.1f", at.latitude) })
                    end,
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})
    local map = renderer:find("map")

    runtime:dispatch(map.id, "onRegionChange", { center = { latitude = 40, longitude = -70 }, zoom = 9 })
    runtime:commit()

    local moved = renderer.nodes[map.id]

    assert(moved.props.center.latitude == 40, "a map that was dragged is drawn where it ended up")
    assert(moved.props.zoom == 9, "at the zoom it ended at")

    runtime:dispatch(map.id, "onMarkerPress", { key = "home" })
    runtime:commit()
    assert(runtime.root.instance.state.said == "home", "a mark reports which one was pressed")

    runtime:dispatch(map.id, "onPress", { latitude = 12.34, longitude = 1 })
    runtime:commit()
    assert(runtime.root.instance.state.said == "12.3", "and a press reports where on the world it landed")
end

-- A fix is asked for by putting one on screen, and stopped by taking it off again.
do
    fails(function() return gui.Location { accuracy = "perfect" } end, "accuracy")

    local Screen = gui.component({
        name = "Screen",
        state = { asking = false, watching = false, fix = nil, problem = nil },

        render = function(self)
            return gui.View { style = { grow = 1 },
                self.state.asking and gui.Location {
                    watch = self.state.watching,
                    onChange = function(at) self:setState({ fix = at, problem = gui.none }) end,
                    onError = function(problem) self:setState({ problem = problem.message }) end,
                } or false,
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    assert(#renderer:findAll("location") == 0, "nothing asks the device where it is until a screen does")

    runtime.root.instance:setState({ asking = true })
    runtime:commit()

    local asking = renderer:find("location")

    assert(asking.props.watch == false, "a screen that asked once does not follow the device")
    assert(asking.props.accuracy == "fine", "and it asks for the accuracy a map needs")
    assert(asking.frame.height == 0, "asking is not something a reader sees")

    runtime:dispatch(asking.id, "onChange", { latitude = 10, longitude = 20, accuracy = 5 })
    runtime:commit()
    assert(runtime.root.instance.state.fix.latitude == 10, "a fix reaches the screen that asked for it")

    runtime:dispatch(asking.id, "onError", { message = "no" })
    runtime:commit()
    assert(runtime.root.instance.state.problem == "no", "and so does a refusal")

    runtime.root.instance:setState({ asking = false })
    runtime:commit()
    assert(#renderer:findAll("location") == 0, "a screen that stopped asking takes the receiver with it")
end

print("gui.place ok")
