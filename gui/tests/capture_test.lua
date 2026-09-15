local gui = require("gui")

local function start(description)
    local renderer = gui.headless()
    local asked = {}

    renderer.invoke = function(_, id, method, arguments)
        asked[#asked + 1] = { id = id, method = method, arguments = arguments }
        return true
    end

    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer, asked
end

local function find(renderer, type)
    for _, node in pairs(renderer.nodes) do
        if node.type == type then
            return node
        end
    end

    return nil
end

--- Answers the pressable carrying a name, which is what a finger would land on.
local function pressable(renderer, label)
    for _, node in pairs(renderer.nodes) do
        if node.props.accessibilityLabel == label then
            return node
        end
    end

    error("nothing on screen is named " .. label, 2)
end

-- A camera is a node like any other, with what it is looking at and how it is drawn on it.
do
    local _, renderer = start(gui.Camera {
        facing = "front",
        zoom = 2,
        torch = true,
        filter = gui.filter.looks.mono,
        style = { height = 200 },
    })

    local camera = find(renderer, "camera")

    assert(camera ~= nil, "a camera reaches the renderer as a node of its own")
    assert(camera.props.facing == "front", "which way it is looking is what it was told")
    assert(camera.props.zoom == 2, "and so is how far in it is")
    assert(camera.props.torch == true, "and whether the light is on")
    assert(type(camera.props.filter) == "table" and #camera.props.filter == 20,
        "a look over a preview is the same matrix a picture is drawn through")
end

-- A camera is asked to capture through a ref, which is what the imperative half of the bridge is for.
do
    local Screen = gui.component({
        name = "CaptureScreen",
        state = { recording = false },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Camera { ref = self:ref("camera"), style = { height = 200 } },

                gui.Pressable {
                    accessibilityLabel = "Take",
                    onPress = function() self:ref("camera"):call("capturePhoto") end,
                    gui.Text { text = "take" },
                },

                gui.Pressable {
                    accessibilityLabel = "Record",
                    onPress = function()
                        self:ref("camera"):call(self.state.recording and "stopRecording" or "startRecording")
                        self:setState({ recording = not self.state.recording })
                    end,
                    gui.Text { text = "record" },
                },
            }
        end,
    })

    local runtime, renderer, asked = start(Screen {})
    local camera = find(renderer, "camera")

    runtime:dispatch(pressable(renderer, "Take").id, "onPress", nil)

    assert(#asked == 1 and asked[1].method == "capturePhoto",
        "pressing what takes a picture asks the camera for one")
    assert(asked[1].id == camera.id, "and asks the camera rather than anything else")

    runtime:dispatch(pressable(renderer, "Record").id, "onPress", nil)
    runtime:commit()
    runtime:dispatch(pressable(renderer, "Record").id, "onPress", nil)

    assert(asked[2].method == "startRecording" and asked[3].method == "stopRecording",
        "and recording starts and stops through the same handle")
end

-- The handle a component holds under a name is one handle rather than a new one on every render.
do
    local held = {}

    local Screen = gui.component({
        name = "HoldingScreen",
        state = { count = 0 },

        render = function(self)
            held[#held + 1] = self:ref("camera")

            return gui.View { style = { grow = 1 },
                gui.Camera { ref = self:ref("camera"), style = { height = 100 } },

                gui.Pressable {
                    accessibilityLabel = "Again",
                    onPress = function() self:setState({ count = self.state.count + 1 }) end,
                    gui.Text { text = "again" },
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    runtime:dispatch(pressable(renderer, "Again").id, "onPress", nil)
    runtime:commit()

    assert(#held > 1, "the screen was drawn more than once")
    assert(held[1] == held[#held], "and it held one handle throughout rather than a new one each time")
    assert(held[1]:get() ~= nil, "which points at the node it was written on")
end

-- A component cannot take a name every component already answers, since the engine would call the wrong one.
do
    local ok, problem = pcall(gui.component, {
        name = "Shadowing",
        ref = function() return nil end,
        render = function() return gui.Text { text = "x" } end,
    })

    assert(not ok, "a method shadowing one every component answers is refused")
    assert(tostring(problem):find("already answers", 1, true) ~= nil,
        "and says why, it said " .. tostring(problem))
end

-- A recorder has nothing to draw and is told whether it should be running.
do
    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.Recorder { recording = true },
    })

    local recorder = find(renderer, "recorder")

    assert(recorder ~= nil, "a recorder reaches the renderer as a node of its own")
    assert(recorder.props.recording == true, "and carries whether it should be running")
    assert(recorder.frame.height == 0, "while taking no room at all")
end

-- A camera is written the way it is drawn, so what it cannot be is refused where it was written.
do
    local ok, problem = pcall(function() return gui.Camera { facing = "sideways" } end)

    assert(not ok and tostring(problem):find("facing", 1, true) ~= nil,
        "a camera that looks nowhere is refused, said " .. tostring(problem))

    ok, problem = pcall(function() return gui.Camera { zoom = 0.5 } end)

    assert(not ok and tostring(problem):find("zoom", 1, true) ~= nil,
        "and so is one zoomed further out than it can go, said " .. tostring(problem))
end

-- A file is kept by asking the platform, which answers whenever the reader is done with it.
do
    local async = require("async")
    local asked = {}

    host.gui_files = function(request)
        asked[#asked + 1] = request
    end

    async.run(function()
        local kept = gui.files.save("/somewhere/photo.jpg", { title = "From the camera" })

        assert(#asked == 1, "asking to keep a file reaches the host once")
        assert(asked[1].action == "save" and asked[1].path == "/somewhere/photo.jpg",
            "and carries what to keep and what to do with it")

        gui.files.answered({ ticket = asked[1].ticket, path = "/kept/photo.jpg" })

        assert(kept:await().path == "/kept/photo.jpg", "and answers where it ended up")

        local shared = gui.files.share("/somewhere/film.mp4")

        assert(asked[2].action == "share", "sharing is the same handle asked for differently")

        gui.files.answered({ ticket = asked[2].ticket, problem = "the reader said no" })

        local answer = shared:await()

        assert(answer.problem == "the reader said no",
            "and a refusal is answered as one rather than as silence, said " .. tostring(answer.problem))

        -- A reply for something nobody is waiting on is life rather than a mistake: a sheet a reader
        -- left open outlives the screen that opened it.
        gui.files.answered({ ticket = 9999, path = "/nowhere" })

        print("gui.capture ok")
    end)
end
