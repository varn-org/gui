--- Every demo the gallery carries, in the groups the first screen lists them under.
---
--- A group is a category and an item is one demo inside it, so the first screen is a list of what
--- there is to see rather than a row of tabs nothing fits into.
local GROUPS = {
    { key = "inputs", title = "Inputs", module = "demos.inputs" },
    { key = "content", title = "Content", module = "demos.content" },
    { key = "drawing", title = "Drawing", module = "demos.drawing" },
    { key = "lists", title = "Lists", module = "demos.lists" },
    { key = "layout", title = "Layout", module = "demos.layout" },
    { key = "feedback", title = "Feedback", module = "demos.feedback" },
    { key = "presentation", title = "Presentation", module = "demos.presentation" },
    { key = "screens", title = "Real screens", module = "demos.screens" },
}

local M = { groups = {} }

for index = 1, #GROUPS do
    local group = GROUPS[index]
    local items = require(group.module)

    for position = 1, #items do
        items[position].group = group.title
    end

    M.groups[index] = { key = group.key, title = group.title, data = items }
end

--- Answers one demo by the group and item it belongs to, which is what the first screen opens.
function M.find(group, item)
    for index = 1, #M.groups do
        if M.groups[index].key == group then
            local items = M.groups[index].data

            for position = 1, #items do
                if items[position].key == item then
                    return items[position]
                end
            end
        end
    end

    return nil
end

--- Answers how many demos there are, which the tests read to prove nothing was dropped.
function M.count()
    local total = 0

    for index = 1, #M.groups do
        total = total + #M.groups[index].data
    end

    return total
end

return M
