package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

--- Prints every demo the gallery carries, so nothing that judges the gallery keeps a list of its own.
---
--- Each line is the demo, the title its row is drawn under, and what to press to reach the screens
--- inside it. A browser has no environment to be told which demo to open and is walked by pressing the
--- rows a reader presses, and a whole application has screens a reader only reaches by going into it, so
--- the demo says what opens each of them rather than a tool holding a list of its own.
local catalogue = require("catalogue")

for index = 1, #catalogue.groups do
    local group = catalogue.groups[index]

    for position = 1, #group.data do
        local item = group.data[position]
        local walk = {}

        for at = 1, #(item.screens or {}) do
            walk[at] = item.screens[at].as .. "=" .. item.screens[at].press
        end

        walk = table.concat(walk, "\t")

        print(group.key .. "/" .. item.key .. "\t" .. item.title .. (walk ~= "" and "\t" .. walk or ""))
    end
end
