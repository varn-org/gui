local gui = require("gui")
local filters = require("gui.style.filter")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 320, height = 640 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function near(actual, expected, what)
    assert(math.abs(actual - expected) < 1e-6,
        what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

--- Answers what a matrix makes of a colour, which is what a filter is for.
local function through(matrix, r, g, b)
    local out = {}

    for row = 0, 2 do
        out[row + 1] = matrix[row * 5 + 1] * r + matrix[row * 5 + 2] * g + matrix[row * 5 + 3] * b
            + matrix[row * 5 + 5]
    end

    return out[1], out[2], out[3]
end

-- A filter that names nothing changes nothing, and one that names the neutral amount does not either.
do
    assert(filters.transparent(filters.matrix({})), "a filter of nothing is the matrix that does nothing")
    assert(filters.transparent(filters.matrix({ saturate = 1, brightness = 1, grayscale = 0 })),
        "and so is one written out in the amounts that change nothing")
    assert(not filters.transparent(filters.matrix({ grayscale = 1 })), "a filter that does something is not")
end

-- Grey is the brightness the eye reads, which is what makes a picture in black and white readable.
do
    local matrix = filters.matrix({ grayscale = 1 })
    local r, g, b = through(matrix, 1, 0, 0)

    near(r, 0.2126, "red through grey")
    near(g, 0.2126, "and every channel is the same grey")
    near(b, 0.2126, "on all three")

    r, g, b = through(filters.matrix({ grayscale = 1 }), 0, 1, 0)
    near(r, 0.7152, "green is most of what the eye reads as brightness")

    -- Half way is half way, since an amount mixes what was there with what it becomes.
    r = through(filters.matrix({ grayscale = 0.5 }), 1, 0, 0)
    near(r, (1 + 0.2126) / 2, "half grey is half way between the colour and its grey")
end

-- Inverting twice is the picture back again, and inverting white is black.
do
    local r, g, b = through(filters.matrix({ invert = 1 }), 1, 1, 1)

    near(r, 0, "white inverted is black")
    near(g, 0, "on every channel")
    near(b, 0, "of it")

    r = through(filters.matrix({ invert = 0.5 }), 1, 0, 0)
    near(r, 0.5, "inverting half way is the middle, whatever it started as")
end

-- What is not saturated at all is grey, and brightness and contrast are what they say.
do
    local r, g, b = through(filters.matrix({ saturate = 0 }), 1, 0, 0)

    near(r, 0.213, "nothing saturated is grey")
    near(g, 0.213, "on every channel")
    near(b, 0.213, "of it")

    r = through(filters.matrix({ brightness = 0.5 }), 1, 1, 1)
    near(r, 0.5, "half the brightness is half the colour")

    r = through(filters.matrix({ contrast = 2 }), 0.5, 0.5, 0.5)
    near(r, 0.5, "contrast turns about the middle, so the middle is where it was")

    r = through(filters.matrix({ contrast = 2 }), 0.75, 0.75, 0.75)
    near(r, 1, "and what was above it is pushed further")
end

-- One filter after another is not the same as the other way round, so the order is the engine's.
do
    local first = filters.matrix({ grayscale = 1, saturate = 2 })
    local r = through(first, 1, 0, 0)

    -- Grey comes first, and saturating a grey leaves it grey.
    near(r, 0.2126, "a colour made grey and then saturated is still grey")
end

-- A caller is told where a filter was written wrong rather than being shown a picture that is not right.
do
    local ok, problem = pcall(filters.matrix, { grayscal = 1 })

    assert(not ok and tostring(problem):find("grayscal", 1, true) ~= nil,
        "a misspelled filter is refused by name, said " .. tostring(problem))

    ok, problem = pcall(filters.matrix, { grayscale = "a lot" })

    assert(not ok and tostring(problem):find("amount", 1, true) ~= nil,
        "and one written as anything but an amount, said " .. tostring(problem))
end

-- A picture is sent the matrix its amounts came to, rather than the amounts themselves.
do
    local _, renderer = start(gui.Image { source = "logo.png", filter = { grayscale = 1 } })
    local picture = renderer:find("image")

    assert(type(picture.props.filter) == "table" and #picture.props.filter == 20,
        "a renderer is sent one matrix of twenty numbers")
    near(picture.props.filter[1], 0.2126, "which is the one the amounts came to")
end

-- A film is drawn through the same matrix a picture is, since a look is one thing.
do
    local _, renderer = start(gui.Video { source = "clip.mp4", filter = gui.filter.looks.noir })
    local film = renderer:find("video")

    assert(type(film.props.filter) == "table" and #film.props.filter == 20,
        "a film carries the matrix its amounts came to")

    local picture = select(2, start(gui.Image { source = "logo.png", filter = gui.filter.looks.noir }))
        :find("image")

    for index = 1, 20 do
        assert(math.abs(film.props.filter[index] - picture.props.filter[index]) < 1e-9,
            "and it is the same one a picture is drawn through")
    end
end

-- A filter that changes nothing is not sent at all, and one taken away is cleared.
do
    local Screen = gui.component({
        name = "FilteredScreen",
        state = { grey = true },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.Pressable {
                    accessibilityLabel = "Toggle",
                    onPress = function() self:setState({ grey = not self.state.grey }) end,
                    gui.Text { text = "toggle" },
                },

                gui.Image {
                    source = "logo.png",
                    filter = self.state.grey and { grayscale = 1 } or { grayscale = 0 },
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    assert(renderer:find("image").props.filter ~= nil, "a picture that is filtered carries one")

    local pressable = renderer:find("pressable")

    runtime:dispatch(pressable.id, "onPress", nil)
    runtime:commit()

    assert(renderer:find("image").props.filter == nil,
        "and one that no longer changes anything carries none, rather than a matrix that does nothing")
end

print("gui.filter ok")
