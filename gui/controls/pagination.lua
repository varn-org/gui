local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")
local theme = require("gui.controls.theme")

local View = structure.View
local Text = content.Text

--- A row of numbered pages with a way forward and back, which every table on a wide screen needs.
---
--- Only a window of the numbers is drawn, with a gap standing for what is left out, since a thousand
--- pages is a row nobody can read and a row that does not fit is one that scrolls sideways by accident.
theme.kind("pagination", {
    parts = { "page", "label", "gap" },
    default = {
        metrics = { size = 40, touch = 44, radius = "pill", gap = 4 },
        paint = {
            page = { rest = "background", on = "primary", disabled = "disabledSurface" },
            label = { rest = "text", on = "onPrimary", disabled = "disabledText" },
            gap = { rest = "textMuted" },
        },
        motion = { duration = 150 },
        press = "highlight",
    },
})

--- Answers the pages to draw, with nothing standing where a run of them was left out.
local function window(at, count, shown)
    if count <= shown then
        local all = {}

        for index = 1, count do
            all[index] = index
        end

        return all
    end

    local held = { 1 }
    local from = math.max(2, at - 1)
    local to = math.min(count - 1, at + 1)

    if from > 2 then
        held[#held + 1] = false
    end

    for index = from, to do
        held[#held + 1] = index
    end

    if to < count - 1 then
        held[#held + 1] = false
    end

    held[#held + 1] = count
    return held
end

return component.define({
    name = "DrawnPagination",
    state = { focused = nil },

    render = function(self)
        local props = self.props
        local wearing = props.theme
        local at = props.page or 1
        local count = props.count or 1
        local size = wearing:metric("pagination", "size")
        local touch = wearing:metric("pagination", "touch")

        local function key(name, label, wanted, reachable)
            local about = { disabled = not reachable }

            return Pressable {
                key = name,
                disabled = not reachable,
                accessibilityLabel = label,
                accessibilityRole = "button",
                accessibilityState = { disabled = not reachable },
                focusable = reachable,
                onFocus = function() self:setState({ focused = name }) end,
                onBlur = function() self:setState({ focused = component.none }) end,
                style = {
                    width = math.max(size, touch),
                    height = touch,
                    shrink = 0,
                    align = "center",
                    justify = "center",
                    radius = wearing:metric("pagination", "radius"),
                },
                onPress = function()
                    if props.onChange ~= nil and reachable then
                        props.onChange(wanted)
                    end
                end,
                onKeyDown = function(held)
                    if parts.chooses(held.key) and props.onChange ~= nil and reachable then
                        props.onChange(wanted)
                    end
                end,

                content.Icon {
                    name = name == "back" and "chevron-left" or "chevron-right",
                    size = 20,
                    color = parts.paint(wearing, "pagination", "label", about),
                },
            }
        end

        local pages = { key("back", "Back", at - 1, at > 1) }

        for _, page in ipairs(window(at, count, props.shown or 7)) do
            if page == false then
                pages[#pages + 1] = Text {
                    key = "gap" .. #pages,
                    text = "…",
                    style = {
                        width = size,
                        shrink = 0,
                        textAlign = "center",
                        color = parts.paint(wearing, "pagination", "gap", {}),
                    },
                }
            else
                local on = page == at
                local about = { on = on }

                pages[#pages + 1] = Pressable {
                    key = tostring(page),
                    accessibilityLabel = "Page " .. page,
                    accessibilityRole = "button",
                    accessibilityState = { selected = on },
                    focusable = true,
                    onFocus = function() self:setState({ focused = page }) end,
                    onBlur = function() self:setState({ focused = component.none }) end,
                    transition = parts.motion(wearing, "pagination"),
                    style = {
                        width = math.max(size, touch),
                        height = touch,
                        shrink = 0,
                        align = "center",
                        justify = "center",
                        radius = wearing:metric("pagination", "radius"),
                        background = parts.paint(wearing, "pagination", "page", about),
                    },
                    onPress = function()
                        if props.onChange ~= nil and not on then
                            props.onChange(page)
                        end
                    end,
                    onKeyDown = function(held)
                        local step = parts.steps(held.key, "horizontal")

                        if parts.chooses(held.key) and props.onChange ~= nil then
                            props.onChange(page)
                            return
                        end

                        if type(step) == "number" and props.onChange ~= nil then
                            props.onChange(math.max(1, math.min(count, at + step)))
                        end
                    end,

                    Text {
                        text = tostring(page),
                        style = {
                            color = parts.paint(wearing, "pagination", "label", about),
                            fontWeight = on and "700" or "400",
                        },
                    },
                }
            end
        end

        pages[#pages + 1] = key("on", "Next", at + 1, at < count)

        return View {
            accessibilityRole = "none",
            accessibilityValue = { now = at, least = 1, most = count },
            testID = props.testID,
            style = {
                {
                    direction = "row",
                    align = "center",
                    alignSelf = "start",
                    gap = wearing:metric("pagination", "gap"),
                },
                props.style,
            },

            table.unpack(pages),
        }
    end,
})
