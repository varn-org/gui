local gui = require("gui")
local icons = require("gui.style.icons")

--- Answers the canvas an icon is drawn on, which is the only node it produces.
local function drawn(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 320, height = 480 } })

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return renderer:find("canvas")
end

-- Every name the set carries draws something, which is what makes the set a set.
do
    local names = icons.names()

    assert(#names >= 30, "the set must cover what an application needs, has " .. #names)

    for index = 1, #names do
        local commands = icons.commands(names[index], 24, "#000000ff")

        assert(commands ~= nil and #commands > 0, names[index] .. " must draw something")

        for at = 1, #commands do
            local command = commands[at]

            assert(command.op == "fill" or command.op == "stroke",
                names[index] .. " draws with an operation a renderer has, got " .. tostring(command.op))
            assert(#command.path >= 2, names[index] .. " draws a run of at least two points")

            for point = 1, #command.path do
                assert(#command.path[point] == 2, names[index] .. " draws points of two numbers each")
            end
        end
    end
end

-- An icon is the same drawing at any size, scaled rather than redrawn.
do
    local small = icons.commands("check", 12, "#000000ff")
    local large = icons.commands("check", 48, "#000000ff")

    assert(#small == #large, "the same icon is the same number of runs at any size")
    assert(large[1].path[1][1] == small[1].path[1][1] * 4, "and every point scales with the box")
    assert(large[1].width == small[1].width * 4, "and so does how thick its line is")
end

-- A name the set does not carry is refused when it is written, not drawn as an empty box.
do
    local ok, problem = pcall(function()
        return drawn(gui.Icon { name = "not-an-icon" })
    end)

    assert(not ok, "an icon the set does not carry must be refused")
    assert(tostring(problem):find("does not know an icon called", 1, true) ~= nil,
        "and named for it, got " .. tostring(problem))
end

-- An icon reaches a renderer as a drawing, in the colour the theme resolved rather than the name of one.
do
    local canvas = drawn(gui.Icon { name = "star", size = 28, color = "warning" })

    assert(canvas ~= nil, "an icon must reach the renderer as something drawn")
    assert(#canvas.props.commands > 0, "carrying what to draw")
    assert(canvas.props.commands[1].color:find("^#") ~= nil,
        "and a colour a renderer reads rather than one it would have to look up, got "
            .. tostring(canvas.props.commands[1].color))
    assert(canvas.props.style.width == 28, "drawn in the box it was asked for")
end

print("gui.icons ok")
