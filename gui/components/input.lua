local drawn = require("gui.controls.drawn")
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

--- Answers what is wrong with the step a control was given, or nothing when it is a distance.
---
--- Nought is a control that cannot be moved at all, and the platform's own stepper raises rather than
--- answers when it is handed one, which takes the application with it.
local function wrongStep(spec)
    if spec.step == nil then
        return nil
    end

    if type(spec.step) ~= "number" or spec.step <= 0 then
        return "step is how far one press moves it, which is greater than zero"
    end

    return nil
end

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

M.Button = support.component("Button", {
    platform = "button",
    natural = { text = "title", padding = { horizontal = 20, vertical = 12 }, minHeight = 44 },
    style = button,
    props = { "title", "variant", "size", "disabled" },
    events = { "onPress", "onLongPress", "onHoverIn", "onHoverOut" },
    defaults = { variant = "filled", size = "medium", disabled = false },
    validate = function(spec)
        if not support.oneOf(spec.variant, VARIANTS) then
            return support.expected("variant", spec.variant, VARIANTS)
        end

        if spec.title == nil and #spec == 0 then
            return "needs a title or children to show"
        end
    end,
}, drawn.button)

M.Pressable = require("gui.components.pressable")

--- A button that floats over a screen rather than sitting in it, which Material calls a floating action.
---
--- Apple's system has no such control, so `cupertino` draws a round filled button rather than refusing:
--- an application built around one would otherwise have a hole in it under that design.
M.FloatingActionButton = support.component("FloatingActionButton", {
    props = { "icon", "label", "size", "disabled" },
    events = { "onPress" },
    defaults = { size = "medium", disabled = false },
    validate = function(spec)
        if spec.icon == nil and spec.label == nil then
            return "needs an icon or a label"
        end

        if not support.oneOf(spec.size, { "small", "medium", "large" }) then
            return support.expected("size", spec.size, { "small", "medium", "large" })
        end
    end,
}, drawn.action)

M.TextInput = support.host("textinput", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = {
        "value", "placeholder", "placeholderColor", "secure", "keyboard", "returnKey",
        "autoCapitalize", "autoCorrect", "editable", "maxLength", "autoFocus",
    },
    events = { "onChange", "onSubmit", "onFocus", "onBlur", "onSelectionChange", "onKeyDown", "onKeyUp" },
    actions = { "focus", "blur" },
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

--- A field with the chrome a design draws around it, holding the platform's own editing inside.
---
--- `TextInput` is the editing itself and nothing else, which is what a screen that draws its own box
--- around one wants. This is the box: the container and its fill, the outline and what focus does to it,
--- the label and where the design puts it, the helper line, the error state, and the parts at either end.
---
--- The editing stays the platform's whatever a design draws, since a caret, selection handles, a system
--- keyboard, autocorrect, dictation and every input method for a language that needs one belong to it.
M.TextField = support.component("TextField", {
    props = {
        "value", "placeholder", "secure", "keyboard", "returnKey", "autoCapitalize", "autoCorrect",
        "editable", "maxLength", "autoFocus", "label", "helper", "invalid", "leading", "trailing",
        "multiline", "rows", "grows", "searching",
    },
    events = { "onChange", "onSubmit", "onFocus", "onBlur", "onSelectionChange", "onKeyDown", "onKeyUp" },
    defaults = { editable = true, invalid = false, multiline = false, searching = false },
}, drawn.field)

--- A field over several lines, either a fixed number of them or as many as what is written needs.
---
--- `rows` is how many lines it shows and scrolls inside. `grows` instead makes the box as tall as what
--- is in it, which is what a composer and a note are, and the height is then a measurement of the text
--- rather than a number — so it changes on every keystroke and is answered by the engine's own measuring
--- rather than by a renderer. A field that grows never scrolls inside itself, since there is nothing
--- below the last line to scroll to.
M.TextArea = support.host("textarea", {
    natural = {
        size = function(props)
            return not props.grows and { height = 22 * props.rows + 16 } or nil
        end,
        text = function(props)
            return props.grows and (props.value ~= "" and props.value or props.placeholder or " ") or nil
        end,
        padding = { horizontal = 12, vertical = 8 },
    },
    style = FIELD,
    props = { "value", "placeholder", "editable", "maxLength", "rows", "grows", "autoFocus" },
    events = { "onChange", "onFocus", "onBlur", "onSelectionChange", "onKeyDown", "onKeyUp" },
    actions = { "focus", "blur" },
    defaults = { editable = true, rows = 3, grows = false },
})

--- A switch, drawn by the platform or by the engine as the control theme in force says.
---
--- Which of the two it is, is never the screen's to decide: a tree written once is the platform's own
--- control under `native` and a drawn one under any other control theme, with nothing about it changed.
M.Switch = support.component("Switch", {
    platform = "switch",
    natural = { size = natural.platform },
    props = { "value", "disabled", "onColor", "offColor", "thumbColor" },
    events = { "onChange" },
    defaults = { value = false, disabled = false },
}, drawn.switch)

M.Checkbox = support.component("Checkbox", {
    platform = "checkbox",
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 44 },
    props = { "value", "disabled", "label", "indeterminate", "color" },
    events = { "onChange" },
    defaults = { value = false, disabled = false, indeterminate = false },
}, drawn.checkbox)

M.Radio = support.component("Radio", {
    platform = "radio",
    natural = { text = "label", padding = { horizontal = 28, vertical = 2 }, minHeight = 44 },
    props = { "value", "selected", "disabled", "label", "color" },
    events = { "onSelect" },
    defaults = { selected = false, disabled = false },
    validate = function(spec)
        if spec.value == nil then
            return "needs a value that identifies it inside its group"
        end
    end,
}, drawn.radio)

M.Slider = support.component("Slider", {
    platform = "slider",
    natural = { size = natural.platformHeight },
    props = { "value", "minimum", "maximum", "step", "disabled", "trackColor", "thumbColor", "continuous" },
    events = { "onChange", "onCommit" },
    defaults = { minimum = 0, maximum = 1, disabled = false, continuous = true },
    validate = function(spec)
        if spec.minimum >= spec.maximum then
            return "the minimum must be below the maximum"
        end

        return wrongStep(spec)
    end,
}, drawn.slider)

--- A slider with two thumbs, which is a span rather than a value.
---
--- It carries no platform node because neither phone draws one: a `UISlider` holds one value and the
--- Android range slider belongs to a library this renderer does not depend on. A control that cannot be
--- handed to the platform names none.
M.RangeSlider = support.component("RangeSlider", {
    props = { "range", "minimum", "maximum", "step", "disabled" },
    events = { "onChange", "onCommit" },
    defaults = { minimum = 0, maximum = 1, disabled = false },
    validate = function(spec)
        if spec.minimum >= spec.maximum then
            return "the minimum must be below the maximum"
        end

        if type(spec.range) ~= "table" or #spec.range ~= 2 then
            return "a range is the two values it runs between"
        end

        if spec.range[1] > spec.range[2] then
            return "the lower end of a range comes first"
        end

        return wrongStep(spec)
    end,
}, drawn.range)

M.Stepper = support.component("Stepper", {
    platform = "stepper",
    natural = { size = natural.platform },
    props = { "value", "minimum", "maximum", "step", "disabled" },
    events = { "onChange" },
    defaults = { step = 1, disabled = false },
    validate = function(spec)
        if spec.minimum ~= nil and spec.maximum ~= nil and spec.minimum >= spec.maximum then
            return "the minimum must be below the maximum"
        end

        return wrongStep(spec)
    end,
}, drawn.stepper)

M.SegmentedControl = support.component("SegmentedControl", {
    platform = "segmented",
    natural = { size = natural.platformHeight },
    props = { "segments", "selectedIndex", "disabled" },
    events = { "onChange" },
    defaults = { selectedIndex = 1, disabled = false },
    validate = function(spec)
        if type(spec.segments) ~= "table" or #spec.segments == 0 then
            return "needs a segments list with at least one entry"
        end
    end,
}, drawn.segmented)

M.Picker = support.component("Picker", {
    platform = "picker",
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "options", "value", "placeholder", "disabled", "title" },
    events = { "onChange" },
    validate = function(spec)
        if type(spec.options) ~= "table" then
            return "options must be a list of { value, label } entries"
        end
    end,
}, drawn.select)

--- A date, drawn as the control the platform has for choosing one.
M.DatePicker = support.component("DatePicker", {
    platform = "datepicker",
    natural = { size = natural.platform },
    props = { "value", "minimum", "maximum", "disabled" },
    events = { "onChange" },
    validate = function(spec)
        if spec.minimum ~= nil and spec.maximum ~= nil and spec.minimum >= spec.maximum then
            return "the minimum must be below the maximum"
        end
    end,
}, drawn.calendar)

M.TimePicker = support.component("TimePicker", {
    platform = "timepicker",
    natural = { size = natural.platform },
    props = { "value", "disabled" },
    events = { "onChange" },
}, drawn.clock)

M.SearchBar = support.host("searchbar", {
    natural = { size = { height = 44 } },
    style = FIELD,
    props = { "value", "placeholder", "autoFocus" },
    events = { "onChange", "onSubmit", "onFocus", "onBlur", "onSelectionChange", "onKeyDown", "onKeyUp" },
    actions = { "focus", "blur" },
})

--- How many marks a rating may carry, since each of them is a drawing a renderer builds.
local STARS = 100

M.Rating = support.component("Rating", {
    platform = "rating",
    natural = { size = function(props) return { width = props.size * props.count, height = props.size } end },
    style = function(spec) return { fontSize = spec.size, color = spec.color or "warning" } end,
    props = { "value", "count", "color", "size" },
    events = { "onChange" },
    defaults = { count = 5, size = 24 },
    validate = function(spec)
        if type(spec.count) ~= "number" or spec.count < 1 or spec.count % 1 ~= 0 or spec.count > STARS then
            return "count is a whole number of marks, at least one and at most " .. STARS
        end

        if type(spec.size) ~= "number" or spec.size <= 0 then
            return "size is how large one mark is drawn, in points, greater than zero"
        end
    end,
}, drawn.rating)

M.ColorPicker = support.component("ColorPicker", {
    platform = "colorpicker",
    natural = { size = natural.platform },
    props = { "value", "disabled" },
    events = { "onChange" },
}, drawn.swatches)

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
