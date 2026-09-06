local natural = require("gui.layout.natural")
local support = require("gui.components.support")

local M = {}

local KEYBOARDS = { "default", "number", "decimal", "email", "phone", "url", "search" }
local RETURNS = { "done", "go", "next", "search", "send" }
local VARIANTS = { "filled", "tinted", "outlined", "plain", "destructive" }

--- The look a control that takes typing or opens a chooser has, which is the same one for all of them.
---
--- A field with no look of its own draws as bare text sitting on the page, so a reader cannot tell what
--- can be typed into and what cannot. It is written in theme names, so it follows the reader's
--- appearance and a caller who wants something else still overrides it a field at a time.
local FIELD = {
    background = "surface",
    color = "text",
    fontSize = "body",
    radius = "md",
    paddingHorizontal = "sm",
}

--- The look each variant of a button has, which is what the variant means.
---
--- A renderer draws a plain button and the style paints it, so the four variants are four variants
--- everywhere rather than whatever each platform's own button happens to look like.
local VARIANT = {
    filled = { background = "primary", color = "onPrimary" },
    tinted = { background = "surface", color = "primary" },
    outlined = { color = "primary", border = 1, borderColor = "primary" },
    plain = { color = "primary" },
    destructive = { background = "danger", color = "onPrimary" },
}

local function button(spec)
    local look = {}

    for key, value in pairs(VARIANT[spec.variant] or VARIANT.filled) do
        look[key] = value
    end

    look.fontSize = "headline"
    look.fontWeight = "600"
    look.radius = 12
    look.textAlign = "center"

    if spec.disabled then
        look.opacity = 0.4
    end

    return look
end

M.Button = support.host("button", {
    natural = { text = "title", padding = { horizontal = 20, vertical = 12 }, minHeight = 44 },
    style = button,
    props = { "title", "variant", "size", "disabled", "icon" },
    events = { "onPress", "onLongPress" },
    defaults = { variant = "filled", size = "medium", disabled = false },
    validate = function(spec)
        if not support.oneOf(spec.variant, VARIANTS) then
            return support.expected("variant", spec.variant, VARIANTS)
        end

        if spec.title == nil and #spec == 0 then
            return "needs a title or children to show"
        end
    end,
})

M.Pressable = support.host("pressable", {
    props = { "disabled", "hitSlop" },
    events = { "onPress", "onLongPress", "onPressIn", "onPressOut" },
    defaults = { disabled = false },
})

M.TextInput = support.host("textinput", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = {
        "value", "placeholder", "placeholderColor", "secure", "keyboard", "returnKey",
        "autoCapitalize", "autoCorrect", "editable", "maxLength",
    },
    events = { "onChange", "onSubmit", "onFocus", "onBlur" },
    defaults = {
        secure = false,
        keyboard = "default",
        returnKey = "done",
        autoCapitalize = "sentences",
        autoCorrect = true,
        editable = true,
    },
    validate = function(spec)
        if not support.oneOf(spec.keyboard, KEYBOARDS) then
            return support.expected("keyboard", spec.keyboard, KEYBOARDS)
        end

        if not support.oneOf(spec.returnKey, RETURNS) then
            return support.expected("returnKey", spec.returnKey, RETURNS)
        end
    end,
})

M.TextArea = support.host("textarea", {
    natural = { size = function(props) return { height = 22 * (props.rows or 3) + 16 } end },
    style = FIELD,
    props = { "value", "placeholder", "editable", "maxLength", "rows" },
    events = { "onChange", "onFocus", "onBlur" },
    defaults = { editable = true, rows = 3 },
})

M.Switch = support.host("switch", {
    natural = { size = natural.platform },
    props = { "value", "disabled", "onColor", "offColor", "thumbColor" },
    events = { "onChange" },
    defaults = { value = false, disabled = false },
})

M.Checkbox = support.host("checkbox", {
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 24 },
    props = { "value", "disabled", "label", "indeterminate", "color" },
    events = { "onChange" },
    defaults = { value = false, disabled = false, indeterminate = false },
})

M.Radio = support.host("radio", {
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 24 },
    props = { "value", "selected", "disabled", "label", "color" },
    events = { "onSelect" },
    defaults = { selected = false, disabled = false },
    validate = function(spec)
        if spec.value == nil then
            return "needs a value that identifies it inside its group"
        end
    end,
})

M.Slider = support.host("slider", {
    natural = { size = natural.platform },
    props = { "value", "minimum", "maximum", "step", "disabled", "trackColor", "thumbColor", "continuous" },
    events = { "onChange", "onCommit" },
    defaults = { minimum = 0, maximum = 1, disabled = false, continuous = true },
    validate = function(spec)
        if spec.minimum ~= nil and spec.maximum ~= nil and spec.minimum >= spec.maximum then
            return "the minimum must be below the maximum"
        end
    end,
})

M.Stepper = support.host("stepper", {
    natural = { size = natural.platform },
    props = { "value", "minimum", "maximum", "step", "disabled" },
    events = { "onChange" },
    defaults = { step = 1, disabled = false },
})

M.SegmentedControl = support.host("segmented", {
    natural = { size = natural.platform },
    props = { "segments", "selectedIndex", "disabled" },
    events = { "onChange" },
    defaults = { selectedIndex = 1, disabled = false },
    validate = function(spec)
        if type(spec.segments) ~= "table" or #spec.segments == 0 then
            return "needs a segments list with at least one entry"
        end
    end,
})

M.Picker = support.host("picker", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "options", "value", "placeholder", "disabled", "title" },
    events = { "onChange" },
    validate = function(spec)
        if type(spec.options) ~= "table" then
            return "options must be a list of { value, label } entries"
        end
    end,
})

M.DatePicker = support.host("datepicker", {
    natural = { size = natural.platform },
    style = FIELD,
    props = { "value", "minimum", "maximum", "mode", "disabled" },
    events = { "onChange" },
    defaults = { mode = "date" },
    validate = function(spec)
        local choices = { "date", "datetime" }
        if not support.oneOf(spec.mode, choices) then
            return support.expected("mode", spec.mode, choices)
        end
    end,
})

M.TimePicker = support.host("timepicker", {
    natural = { size = natural.platform },
    style = FIELD,
    props = { "value", "disabled" },
    events = { "onChange" },
})

M.SearchBar = support.host("searchbar", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "value", "placeholder" },
    events = { "onChange", "onSubmit", "onFocus", "onBlur" },
})

M.Rating = support.host("rating", {
    natural = { size = function(props) return { width = props.size * props.count, height = props.size } end },
    style = function(spec) return { fontSize = spec.size, color = spec.color or "warning" } end,
    props = { "value", "count", "color", "size" },
    events = { "onChange" },
    defaults = { count = 5, size = 24 },
})

M.ColorPicker = support.host("colorpicker", {
    natural = { size = natural.platform },
    props = { "value", "disabled" },
    events = { "onChange" },
})

M.FilePicker = support.host("filepicker", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "title" },
    events = {},
})

return M
