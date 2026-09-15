local M = {}

--- The proportions each system draws its own chrome at.
---
--- These are the one place a platform name is read. A bar is 44 tall on iOS and 56 on Android, a back
--- button carries the previous screen's title on one and nothing but an arrow on the other, and a title
--- sits in the middle of one and against the leading edge of the other. Getting any of them wrong is
--- what makes an application read as something ported rather than something written for the device.
--- `large` is the row a big title is drawn in, under the bar's own row and above the rule the bar draws.
--- A large title belongs to the bar rather than to the screen: drawn inside the content it is a heading
--- with the bar's own rule cut across the top of it, and it cannot collapse as the reader scrolls.
--- `collapse` is how far the content moves before the big title gives way to the small one.
local BARS = {
    ios = {
        height = 44,
        title = { size = "headline", weight = "600", align = "center" },
        large = { height = 52, size = "display", weight = "700", align = "left" },
        collapse = 24,
        back = { symbol = "chevron-left", labelled = true, size = "title" },
        push = "slideLeft",
    },
    android = {
        height = 56,
        title = { size = "title", weight = "500", align = "left" },
        large = { height = 72, size = "display", weight = "500", align = "left" },
        collapse = 32,
        back = { symbol = "arrow-left", labelled = false, size = "title" },
        push = "fade",
    },
    web = {
        height = 48,
        title = { size = "headline", weight = "600", align = "left" },
        large = { height = 56, size = "display", weight = "700", align = "left" },
        collapse = 24,
        back = { symbol = "arrow-left", labelled = true, size = "headline" },
        push = "fade",
    },
}

--- How much taller a bar is on a large screen, which iOS draws and the other two do not.
local TALLER = { ios = 6 }

--- Answers how the platform draws a navigation bar, which is the only thing the chrome asks it.
---
--- A tablet is not a large phone: iOS draws a bar fifty points tall where a phone has forty-four, and a
--- screen that keeps the phone's proportions on a large one reads as an application that was stretched.
function M.bar(platform, breakpoint)
    local look = BARS[platform] or BARS.web

    if breakpoint == nil or breakpoint == "compact" or TALLER[platform] == nil then
        return look
    end

    local large = {}

    for key, value in pairs(look) do
        large[key] = value
    end

    large.height = look.height + TALLER[platform]
    return large
end

--- The room a screen keeps at its edges, which is wider on a large screen than on a phone.
local MARGINS = { compact = 16, medium = 20, expanded = 20 }

function M.margin(breakpoint)
    return MARGINS[breakpoint] or MARGINS.compact
end

--- How wide a run of text may be before it stops being comfortable to read.
---
--- A line the width of a tablet is a line a reader loses their place in, which is why the platform caps
--- one rather than letting it run to the edges. Text is capped and everything else fills the room.
M.readable = 672

--- How something shown over a screen is presented, which is not the same on a large screen.
---
--- A phone shows a sheet from the bottom edge and a modal over the whole screen. A tablet centres both
--- in a panel of its own, which is what the system does with a form sheet rather than covering a
--- thirteen inch screen with one field and a button.
local PANELS = {
    compact = { centred = false },
    medium = { centred = true, width = 540, height = 620 },
    expanded = { centred = true, width = 540, height = 620 },
}

function M.panel(breakpoint)
    return PANELS[breakpoint] or PANELS.compact
end

--- How wide the list beside what it opens is, which the platform settles rather than each screen.
M.sidebar = 320

--- The height of a row in a list, which each system sets rather than each screen.
local ROWS = { ios = 44, android = 56, web = 48 }

function M.row(platform)
    return ROWS[platform] or ROWS.web
end

--- The smallest a thing a finger has to land on may be, which Apple sets at forty-four points.
M.touch = 44

return M
