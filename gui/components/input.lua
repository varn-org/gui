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
---
--- It belongs only to the controls the engine gives a size to. A control the platform sizes is one the
--- platform has already decorated, and painting a box behind it is a second background around the one it
--- draws for itself — a dark rectangle behind the date's own grey pill, wider than it and out of line.
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
    props = { "title", "variant", "size", "disabled" },
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

--- A box that answers a finger, by the gesture the finger actually made.
---
--- A swipe is not a press. Every platform tells them apart by how far the finger travelled, and a box
--- that took either as a press opened whatever it was for when a reader meant to scroll past it.
--- `onSwipe` carries the direction it went, which is what an item does something different for.
M.Pressable = support.host("pressable", {
    props = { "disabled", "hitSlop" },
    events = { "onPress", "onLongPress", "onPressIn", "onPressOut", "onSwipe" },
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
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 44 },
    props = { "value", "disabled", "label", "indeterminate", "color" },
    events = { "onChange" },
    defaults = { value = false, disabled = false, indeterminate = false },
})

M.Radio = support.host("radio", {
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 44 },
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

local DISPLAYS = { "compact", "wheel" }

--- A date, either as the compact field or as the wheel people expect to turn on a phone.
M.DatePicker = support.host("datepicker", {
    natural = { size = function(props)
        if props.display == "wheel" then
            return natural.variant("wheel")
        end

        return natural.platform
    end },
    props = { "value", "minimum", "maximum", "display", "disabled" },
    events = { "onChange" },
    defaults = { display = "compact" },
    validate = function(spec)
        if not support.oneOf(spec.display, DISPLAYS) then
            return support.expected("display", spec.display, DISPLAYS)
        end
    end,
})

M.TimePicker = support.host("timepicker", {
    natural = { size = function(props)
        if props.display == "wheel" then
            return natural.variant("wheel")
        end

        return natural.platform
    end },
    props = { "value", "display", "disabled" },
    events = { "onChange" },
    defaults = { display = "compact" },
    validate = function(spec)
        if not support.oneOf(spec.display, DISPLAYS) then
            return support.expected("display", spec.display, DISPLAYS)
        end
    end,
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

--- What a file is worth reading, since what is chosen crosses the bridge as text.
---
--- A photograph read whole is several megabytes of it, and a reader picking a video would ask for a
--- string no device should be asked to build. Anything larger arrives named and measured but unread.
local MAX_BYTES = 8 * 1024 * 1024

local KINDS = { "file", "image" }

--- Opens the chooser the platform ships and reports what came back, one file at a time.
---
--- A file carries `name`, `size`, `type` and `bytes`, the last of them base64 and absent when the file is
--- larger than `maxBytes`. Each is reported as soon as it has been read rather than the whole set at the
--- end, since the bytes of several photographs in one message are decoded and written in a single turn of
--- the loop and nothing moves until the last of them lands.
---
--- Nothing is written anywhere: where a chosen file belongs is the application's to decide, and
--- `fs.writeFile` with `crypto.base64Decode` is what puts it there.
M.FilePicker = support.host("filepicker", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "title", "kind", "accept", "multiple", "maxBytes", "disabled" },
    events = { "onPick" },
    defaults = { kind = "file", multiple = false, maxBytes = MAX_BYTES },
    validate = function(spec)
        if not support.oneOf(spec.kind, KINDS) then
            return support.expected("kind", spec.kind, KINDS)
        end

        if spec.accept ~= nil and type(spec.accept) ~= "table" then
            return "accept is a list of types, like { \"image/png\", \"pdf\" }"
        end
    end,
})

return M
