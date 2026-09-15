local M = {}

--- The box every icon is drawn in, which everything below is written in and scaled out of.
local BOX = 24

--- How thick a drawn line is at the size the box is written in.
local WEIGHT = 2

--- Answers the points of a circle, which is drawn as a ring of segments rather than an arc.
---
--- Every renderer draws a run of straight lines, which is the one shape all three already agree on, so
--- a curve is written as enough of them that nobody can tell at the size an icon is drawn.
local function ring(x, y, radius, from, to)
    local first = from or 0
    local last = to or 360
    local steps = math.max(8, math.floor((last - first) / 18))
    local points = {}

    for index = 0, steps do
        local angle = math.rad(first + (last - first) * index / steps)
        points[#points + 1] = { x + radius * math.cos(angle), y + radius * math.sin(angle) }
    end

    return points
end

local function line(...)
    return { ... }
end

--- What each icon is made of, as runs of points in a 24 by 24 box.
---
--- The engine owns the set so the same name draws the same thing on every platform. A phone that
--- carries thousands of symbols of its own carries them under names no other platform has, which is
--- how an icon came to be a picture on one and an empty box on the other two.
local SHAPES = {
    ["chevron-left"] = { stroke = { line({ 15, 5 }, { 8, 12 }, { 15, 19 }) } },
    ["chevron-right"] = { stroke = { line({ 9, 5 }, { 16, 12 }, { 9, 19 }) } },
    ["chevron-up"] = { stroke = { line({ 5, 15 }, { 12, 8 }, { 19, 15 }) } },
    ["chevron-down"] = { stroke = { line({ 5, 9 }, { 12, 16 }, { 19, 9 }) } },

    ["arrow-left"] = { stroke = { line({ 20, 12 }, { 4, 12 }), line({ 10, 6 }, { 4, 12 }, { 10, 18 }) } },
    ["arrow-right"] = { stroke = { line({ 4, 12 }, { 20, 12 }), line({ 14, 6 }, { 20, 12 }, { 14, 18 }) } },
    ["arrow-up"] = { stroke = { line({ 12, 20 }, { 12, 4 }), line({ 6, 10 }, { 12, 4 }, { 18, 10 }) } },
    ["arrow-down"] = { stroke = { line({ 12, 4 }, { 12, 20 }), line({ 6, 14 }, { 12, 20 }, { 18, 14 }) } },

    ["close"] = { stroke = { line({ 6, 6 }, { 18, 18 }), line({ 18, 6 }, { 6, 18 }) } },
    ["check"] = { stroke = { line({ 5, 13 }, { 10, 18 }, { 19, 6 }) } },
    ["plus"] = { stroke = { line({ 12, 5 }, { 12, 19 }), line({ 5, 12 }, { 19, 12 }) } },
    ["minus"] = { stroke = { line({ 5, 12 }, { 19, 12 }) } },

    ["menu"] = { stroke = { line({ 4, 7 }, { 20, 7 }), line({ 4, 12 }, { 20, 12 }), line({ 4, 17 }, { 20, 17 }) } },
    ["more"] = { fill = { ring(6, 12, 1.6), ring(12, 12, 1.6), ring(18, 12, 1.6) } },

    ["search"] = { stroke = { ring(11, 11, 6), line({ 15.5, 15.5 }, { 20, 20 }) } },
    ["home"] = { stroke = { line({ 4, 11 }, { 12, 4 }, { 20, 11 }), line({ 6, 11 }, { 6, 20 }, { 18, 20 }, { 18, 11 }) } },
    ["user"] = { stroke = { ring(12, 8, 4), line({ 4, 20 }, { 6, 15 }, { 18, 15 }, { 20, 20 }) } },
    ["settings"] = { stroke = { ring(12, 12, 3.5), ring(12, 12, 8) } },

    ["heart"] = {
        fill = {
            line(
                { 12, 20 }, { 4, 12 }, { 4, 8 }, { 6, 5 }, { 9.5, 5 }, { 12, 8 },
                { 14.5, 5 }, { 18, 5 }, { 20, 8 }, { 20, 12 }
            ),
        },
    },

    ["sun"] = {
        stroke = {
            ring(12, 12, 4.5),
            line({ 12, 2 }, { 12, 4.5 }), line({ 12, 19.5 }, { 12, 22 }),
            line({ 2, 12 }, { 4.5, 12 }), line({ 19.5, 12 }, { 22, 12 }),
            line({ 5, 5 }, { 6.8, 6.8 }), line({ 17.2, 17.2 }, { 19, 19 }),
            line({ 19, 5 }, { 17.2, 6.8 }), line({ 6.8, 17.2 }, { 5, 19 }),
        },
    },

    ["cloud"] = {
        stroke = {
            line(
                { 7, 18 }, { 5, 17 }, { 4, 15 }, { 4.5, 12.5 }, { 6.5, 11 }, { 8, 11 },
                { 8.5, 8.5 }, { 10.5, 6.5 }, { 13.5, 6.5 }, { 15.5, 8.5 }, { 16, 11 },
                { 18, 11.5 }, { 20, 13.5 }, { 20, 16 }, { 18.5, 17.6 }, { 17, 18 }, { 7, 18 }
            ),
        },
    },

    ["rain"] = {
        stroke = {
            line(
                { 7, 15 }, { 5, 14 }, { 4, 12 }, { 4.5, 9.5 }, { 6.5, 8 }, { 8, 8 },
                { 8.5, 5.5 }, { 10.5, 3.5 }, { 13.5, 3.5 }, { 15.5, 5.5 }, { 16, 8 },
                { 18, 8.5 }, { 20, 10.5 }, { 20, 13 }, { 18.5, 14.6 }, { 17, 15 }, { 7, 15 }
            ),
            line({ 8.5, 18 }, { 7.5, 21 }),
            line({ 13, 18 }, { 12, 21 }),
            line({ 17.5, 18 }, { 16.5, 21 }),
        },
    },

    ["moon"] = {
        fill = {
            line(
                { 20, 15 }, { 17.5, 16.5 }, { 14.5, 16.5 }, { 11.5, 15 }, { 9.5, 12 }, { 9.5, 8.5 },
                { 11, 5 }, { 8, 6 }, { 5.5, 8.5 }, { 4.5, 12 }, { 5.5, 16 }, { 8.5, 19 },
                { 12.5, 20 }, { 16.5, 19 }, { 19, 17 }
            ),
        },
    },

    ["star"] = {
        fill = {
            line(
                { 12, 3 }, { 14.8, 9.2 }, { 21.5, 10 }, { 16.5, 14.5 }, { 17.9, 21 },
                { 12, 17.7 }, { 6.1, 21 }, { 7.5, 14.5 }, { 2.5, 10 }, { 9.2, 9.2 }
            ),
        },
    },

    ["trash"] = {
        stroke = {
            line({ 4, 7 }, { 20, 7 }),
            line({ 9, 7 }, { 9, 4 }, { 15, 4 }, { 15, 7 }),
            line({ 6, 7 }, { 7, 20 }, { 17, 20 }, { 18, 7 }),
        },
    },

    ["share"] = {
        stroke = {
            line({ 12, 4 }, { 12, 15 }),
            line({ 8, 8 }, { 12, 4 }, { 16, 8 }),
            line({ 5, 13 }, { 5, 20 }, { 19, 20 }, { 19, 13 }),
        },
    },

    ["play"] = { fill = { line({ 7, 4 }, { 20, 12 }, { 7, 20 }) } },
    ["pause"] = { fill = { line({ 7, 4 }, { 11, 4 }, { 11, 20 }, { 7, 20 }), line({ 13, 4 }, { 17, 4 }, { 17, 20 }, { 13, 20 }) } },

    ["calendar"] = {
        stroke = {
            line({ 4, 6 }, { 20, 6 }, { 20, 20 }, { 4, 20 }, { 4, 6 }),
            line({ 4, 10 }, { 20, 10 }),
            line({ 8, 4 }, { 8, 7 }),
            line({ 16, 4 }, { 16, 7 }),
        },
    },

    ["clock"] = { stroke = { ring(12, 12, 8), line({ 12, 7 }, { 12, 12 }, { 16, 14 }) } },
    ["bell"] = {
        stroke = {
            line({ 6, 17 }, { 6, 10 }, { 8, 6 }, { 16, 6 }, { 18, 10 }, { 18, 17 }, { 6, 17 }),
            line({ 10, 20 }, { 14, 20 }),
        },
    },

    ["mail"] = { stroke = { line({ 3, 6 }, { 21, 6 }, { 21, 18 }, { 3, 18 }, { 3, 6 }), line({ 3, 6 }, { 12, 13 }, { 21, 6 }) } },
    ["lock"] = {
        stroke = {
            line({ 5, 11 }, { 19, 11 }, { 19, 20 }, { 5, 20 }, { 5, 11 }),
            line({ 8, 11 }, { 8, 8 }, { 12, 5 }, { 16, 8 }, { 16, 11 }),
        },
    },

    ["download"] = { stroke = { line({ 12, 4 }, { 12, 15 }), line({ 8, 11 }, { 12, 15 }, { 16, 11 }), line({ 5, 19 }, { 19, 19 }) } },
    ["upload"] = { stroke = { line({ 12, 15 }, { 12, 4 }), line({ 8, 8 }, { 12, 4 }, { 16, 8 }), line({ 5, 19 }, { 19, 19 }) } },

    ["info"] = { stroke = { ring(12, 12, 8), line({ 12, 11 }, { 12, 16 }) }, fill = { ring(12, 8, 1) } },
    ["warning"] = { stroke = { line({ 12, 4 }, { 21, 20 }, { 3, 20 }, { 12, 4 }), line({ 12, 10 }, { 12, 15 }) }, fill = { ring(12, 18, 1) } },

    ["camera"] = {
        stroke = {
            line({ 3, 8 }, { 8, 8 }, { 10, 5 }, { 14, 5 }, { 16, 8 }, { 21, 8 }, { 21, 20 }, { 3, 20 }, { 3, 8 }),
            ring(12, 13, 4),
        },
    },

    ["image"] = {
        stroke = { line({ 3, 5 }, { 21, 5 }, { 21, 19 }, { 3, 19 }, { 3, 5 }), line({ 3, 16 }, { 9, 10 }, { 14, 15 }, { 17, 12 }, { 21, 16 }) },
        fill = { ring(8, 9, 1.4) },
    },

    ["send"] = { fill = { line({ 3, 12 }, { 21, 4 }, { 13, 21 }, { 11, 13 }) } },
    ["message"] = {
        stroke = { line({ 4, 5 }, { 20, 5 }, { 20, 16 }, { 12, 16 }, { 7, 20 }, { 7, 16 }, { 4, 16 }, { 4, 5 }) },
    },
    ["bookmark"] = { stroke = { line({ 6, 4 }, { 18, 4 }, { 18, 20 }, { 12, 15 }, { 6, 20 }, { 6, 4 }) } },
    ["pin"] = {
        stroke = { line({ 12, 21 }, { 6, 12 }, { 6, 9 }), ring(12, 9, 6, 180, 360), line({ 18, 9 }, { 18, 12 }, { 12, 21 }) },
        fill = { ring(12, 9, 2.2) },
    },
    ["compass"] = { stroke = { ring(12, 12, 8), line({ 15, 9 }, { 10, 10 }, { 9, 15 }, { 14, 14 }, { 15, 9 }) } },
    ["more-vertical"] = { fill = { ring(12, 6, 1.6), ring(12, 12, 1.6), ring(12, 18, 1.6) } },

    ["bold"] = {
        stroke = {
            line({ 8, 4 }, { 8, 20 }),
            line({ 8, 4 }, { 13, 4 }),
            ring(13, 7.5, 3.5, -90, 90),
            line({ 13, 11 }, { 8, 11 }),
            line({ 8, 12 }, { 14, 12 }),
            ring(14, 16, 4, -90, 90),
            line({ 14, 20 }, { 8, 20 }),
        },
    },

    ["italic"] = {
        stroke = { line({ 10, 4 }, { 18, 4 }), line({ 15, 4 }, { 9, 20 }), line({ 6, 20 }, { 14, 20 }) },
    },

    ["underline"] = {
        stroke = {
            line({ 7, 4 }, { 7, 11 }),
            ring(12, 11, 5, 0, 180),
            line({ 17, 4 }, { 17, 11 }),
            line({ 5, 20 }, { 19, 20 }),
        },
    },

    ["strikethrough"] = {
        stroke = {
            ring(12, 8, 4, -170, 30),
            ring(12, 16, 4, -20, 190),
            line({ 4, 12 }, { 20, 12 }),
        },
    },

    ["code"] = { stroke = { line({ 9, 6 }, { 4, 12 }, { 9, 18 }), line({ 15, 6 }, { 20, 12 }, { 15, 18 }) } },

    ["link"] = {
        stroke = {
            line({ 9.5, 14.5 }, { 14.5, 9.5 }),
            ring(7.5, 16.5, 4, 45, 315),
            ring(16.5, 7.5, 4, -135, 135),
        },
    },

    ["copy"] = {
        stroke = {
            line({ 9, 3 }, { 21, 3 }, { 21, 15 }, { 9, 15 }, { 9, 3 }),
            line({ 3, 9 }, { 3, 21 }, { 15, 21 }, { 15, 15 }),
        },
    },

    ["scissors"] = {
        stroke = { ring(7, 18, 2.5), ring(17, 18, 2.5), line({ 6, 3 }, { 16, 15.5 }), line({ 18, 3 }, { 8, 15.5 }) },
    },

    ["clipboard"] = {
        stroke = {
            line({ 9, 5 }, { 6, 5 }, { 6, 21 }, { 18, 21 }, { 18, 5 }, { 15, 5 }),
            line({ 9, 3 }, { 15, 3 }, { 15, 7 }, { 9, 7 }, { 9, 3 }),
        },
    },

    ["bag"] = {
        stroke = {
            line({ 5, 8 }, { 19, 8 }, { 18, 21 }, { 6, 21 }, { 5, 8 }),
            ring(12, 8, 3.6, 180, 360),
        },
    },

    ["cart"] = {
        stroke = {
            line({ 2, 4 }, { 5, 4 }, { 8, 16 }, { 18.5, 16 }, { 21, 7.5 }, { 6, 7.5 }),
            ring(9.5, 19.5, 1.6),
            ring(17.5, 19.5, 1.6),
        },
    },

    ["barcode"] = {
        stroke = {
            line({ 3, 5 }, { 3, 19 }),
            line({ 6, 5 }, { 6, 19 }),
            line({ 9.5, 5 }, { 9.5, 19 }),
            line({ 14, 5 }, { 14, 19 }),
            line({ 17.5, 5 }, { 17.5, 19 }),
            line({ 21, 5 }, { 21, 19 }),
        },
    },

    ["filter"] = { stroke = { line({ 3, 5 }, { 21, 5 }, { 14, 13 }, { 14, 20.5 }, { 10, 18 }, { 10, 13 }, { 3, 5 }) } },

    ["microphone"] = {
        stroke = {
            line({ 12, 3 }, { 14.6, 4.6 }, { 14.6, 10.8 }, { 12, 12.5 }, { 9.4, 10.8 }, { 9.4, 4.6 }, { 12, 3 }),
            ring(12, 11, 5.6, 0, 180),
            line({ 12, 16.6 }, { 12, 21 }),
            line({ 8, 21 }, { 16, 21 }),
        },
    },

    ["paperclip"] = {
        stroke = {
            line({ 17, 6 }, { 17, 16.5 }),
            ring(12.5, 16.5, 4.5, 0, 180),
            line({ 8, 16.5 }, { 8, 5.5 }),
            ring(10.5, 5.5, 2.5, 180, 360),
            line({ 13, 5.5 }, { 13, 15 }),
        },
    },

    ["phone"] = {
        stroke = {
            line(
                { 5, 3 }, { 9, 3 }, { 10.5, 8 }, { 8, 10.5 }, { 13.5, 16 }, { 16, 13.5 }, { 21, 15 },
                { 21, 19 }, { 19, 21 }, { 16, 21 }, { 10, 18 }, { 5, 13 }, { 3, 7 }, { 3, 5 }, { 5, 3 }
            ),
        },
    },

    ["video"] = {
        stroke = {
            line({ 3, 6 }, { 15, 6 }, { 15, 18 }, { 3, 18 }, { 3, 6 }),
            line({ 15, 10 }, { 21, 7 }, { 21, 17 }, { 15, 14 }),
        },
    },

    ["shield"] = { stroke = { line({ 12, 3 }, { 20, 6 }, { 20, 12 }, { 12, 21 }, { 4, 12 }, { 4, 6 }, { 12, 3 }) } },

    ["rewind"] = { fill = { line({ 11, 4 }, { 11, 20 }, { 2, 12 }), line({ 22, 4 }, { 22, 20 }, { 13, 12 }) } },
    ["forward"] = { fill = { line({ 13, 4 }, { 13, 20 }, { 22, 12 }), line({ 2, 4 }, { 2, 20 }, { 11, 12 }) } },

    ["list"] = {
        fill = { ring(5, 6, 1.5), ring(5, 12, 1.5), ring(5, 18, 1.5) },
        stroke = { line({ 10, 6 }, { 20, 6 }), line({ 10, 12 }, { 20, 12 }), line({ 10, 18 }, { 20, 18 }) },
    },

    ["headset"] = {
        stroke = { ring(12, 12, 8.5, 180, 360) },
        fill = {
            line({ 2, 11.5 }, { 6.5, 11.5 }, { 6.5, 20 }, { 2, 20 }),
            line({ 17.5, 11.5 }, { 22, 11.5 }, { 22, 20 }, { 17.5, 20 }),
        },
    },

    ["check-double"] = { stroke = { line({ 2, 13 }, { 6, 17 }, { 13, 7 }), line({ 10, 13 }, { 13, 16 }, { 20.5, 6 }) } },
}

--- Answers every name an icon may be drawn under, which is what a caller may choose from.
function M.names()
    local found = {}

    for name in pairs(SHAPES) do
        found[#found + 1] = name
    end

    table.sort(found)
    return found
end

function M.has(name)
    return SHAPES[name] ~= nil
end

--- Answers the drawing commands for one icon, at the size and in the colour it was asked for.
---
--- The colour arrives already resolved against the theme, since everything that crosses to a renderer
--- does, and the size is what the whole box is scaled to.
function M.commands(name, size, color)
    local shape = SHAPES[name]

    if shape == nil then
        return nil
    end

    local scale = (size or BOX) / BOX
    local commands = {}

    local draw = function(runs, op)
        for index = 1, #runs do
            local scaled = {}

            for at = 1, #runs[index] do
                scaled[at] = { runs[index][at][1] * scale, runs[index][at][2] * scale }
            end

            commands[#commands + 1] = { op = op, path = scaled, color = color, width = WEIGHT * scale }
        end
    end

    if shape.fill ~= nil then
        draw(shape.fill, "fill")
    end

    if shape.stroke ~= nil then
        draw(shape.stroke, "stroke")
    end

    return commands
end

return M
