package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

--- Prints every demo the gallery carries, so nothing that judges the gallery keeps a list of its own.
local catalogue = require("catalogue")

for index = 1, #catalogue.groups do
    local group = catalogue.groups[index]

    for position = 1, #group.data do
        print(group.key .. "/" .. group.data[position].key)
    end
end
