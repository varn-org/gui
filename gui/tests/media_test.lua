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

--- A player over a sound, drawn the way the gallery draws one.
local Player = gui.component({
    name = "Player",
    state = { playing = false, position = 0, duration = 0, dragging = nil, ended = 0 },

    seek = function(self, seconds)
        self:ref("sound"):call("seek", { seconds = seconds })
        self:setState({ position = seconds, dragging = gui.none })
    end,

    render = function(self)
        return gui.View { style = { grow = 1 },
            gui.Audio {
                ref = self:ref("sound"),
                source = "https://example.test/loop.mp3",
                playing = self.state.playing,
                loop = self.props.loop,
                onReady = function(about) self:setState({ duration = about.duration }) end,
                onProgress = function(about)
                    if self.state.dragging == nil then
                        self:setState({ position = about.position })
                    end
                end,
                onEnd = function() self:setState({ ended = self.state.ended + 1, playing = false }) end,
            },

            gui.Text { text = string.format("%.0f of %.0f", self.state.position, self.state.duration) },

            gui.Button {
                title = self.state.playing and "Pause" or "Play",
                onPress = function() self:setState({ playing = not self.state.playing }) end,
            },
        }
    end,
})

-- A sound needs somewhere to come from, and nothing else.
do
    fails(function() return gui.Audio {} end, "source")

    local _, renderer = start(gui.Audio { source = "loop.mp3" })
    local sound = renderer:find("audio")

    assert(sound.props.playing == false, "a sound waits to be asked rather than starting on its own")
    assert(sound.props.loop == false, "and it plays once")
    assert(sound.props.volume == 1 and sound.props.rate == 1, "at the volume and speed it was recorded")
end

-- A sound takes no room, since everything a reader sees of it is drawn by the tree.
do
    local _, renderer = start(gui.View { style = { grow = 1 }, gui.Audio { source = "loop.mp3" } })
    local sound = renderer:find("audio")

    assert(sound.frame.height == 0,
        "a sound is heard rather than seen, it stands " .. sound.frame.height .. " tall")
end

-- What the platform reports is what the player draws, and what the reader presses is what it plays.
do
    local runtime, renderer = start(Player {})
    local sound = renderer:find("audio")

    local function label()
        for _, node in pairs(renderer.nodes) do
            if node.type == "text" and node.props.text ~= nil then
                return node.props.text
            end
        end
    end

    runtime:dispatch(sound.id, "onReady", { position = 0, duration = 184 })
    runtime:commit()
    assert(label() == "0 of 184", "a duration is known once the platform has read the file, got " .. label())

    runtime:dispatch(sound.id, "onProgress", { position = 12, duration = 184 })
    runtime:commit()
    assert(label() == "12 of 184", "and the player follows it, got " .. label())

    local button = renderer:find("button")

    runtime:dispatch(button.id, "onPress", nil)
    runtime:commit()
    assert(renderer.nodes[sound.id].props.playing == true, "pressing play asks the platform to play")

    runtime:dispatch(button.id, "onPress", nil)
    runtime:commit()
    assert(renderer.nodes[sound.id].props.playing == false, "and pressing it again asks it to stop")
end

-- A sound that reached its end says so, and stays stopped until it is asked again.
do
    local runtime, renderer = start(Player {})
    local sound = renderer:find("audio")

    runtime:dispatch(renderer:find("button").id, "onPress", nil)
    runtime:commit()

    runtime:dispatch(sound.id, "onEnd", nil)
    runtime:commit()

    assert(runtime.root.instance.state.ended == 1, "the end of a sound is reported once")
    assert(renderer.nodes[sound.id].props.playing == false, "and it is not asked to play again by itself")
end

-- Seeking is asked for rather than described, so the same moment twice is asked for twice.
do
    local runtime, renderer = start(Player {})
    local sound = renderer:find("audio")

    assert(sound.props.position == nil, "a sound carries no position at all, since a seek is an action")
    assert(#renderer.calls == 0, "nothing is sought until a reader drags")

    runtime.root.instance:seek(90)
    runtime:commit()

    assert(#renderer.calls == 1, "letting go of the scrubber seeks once")
    assert(renderer.calls[1].method == "seek" and renderer.calls[1].arguments.seconds == 90,
        "and it carries the moment it was dragged to")

    -- What the sound reports while a finger is down is ignored, and the bar follows it again after.
    runtime.root.instance:setState({ dragging = 30 })
    runtime:dispatch(sound.id, "onProgress", { position = 91, duration = 184 })
    runtime:commit()

    assert(runtime.root.instance.state.position == 90, "a report during a drag does not move the bar")

    runtime.root.instance:seek(90)
    runtime:commit()

    assert(#renderer.calls == 2, "dragging back to the same moment seeks again rather than being silent")

    runtime:dispatch(sound.id, "onProgress", { position = 92, duration = 184 })
    runtime:commit()

    assert(runtime.root.instance.state.position == 92, "and the bar follows the sound once the finger is up")
end

print("gui.media ok")
