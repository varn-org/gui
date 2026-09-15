local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local input = require("gui.components.input")
local marks = require("gui.marks")
local structure = require("gui.components.structure")
local support = require("gui.components.support")

local M = {}

local Pressable = input.Pressable

--- Answers what is wrong with a document, or nothing when it is runs of marked text.
local function wrongValue(value)
    if type(value) ~= "table" then
        return "value is the document, which is a list of { text, marks } runs, got a " .. type(value)
    end

    for index = 1, #value do
        local run = value[index]

        if type(run) ~= "table" then
            return "run " .. index .. " is a { text, marks } entry, got a " .. type(run)
        end

        if type(run.text) ~= "string" then
            return "run " .. index .. " carries text, which is a string, got a " .. type(run.text)
        end

        if run.marks ~= nil and type(run.marks) ~= "table" then
            return "run " .. index .. " carries marks, which is a table, got a " .. type(run.marks)
        end

        for name in pairs(run.marks or {}) do
            if not marks.has(name) then
                return "run " .. index .. " carries a mark nothing draws, " .. tostring(name)
            end
        end
    end

    return nil
end

--- An editor over styled text, which is one box a reader types into rather than two that mirror.
---
--- What a reader selects, marks and copies is the text itself, in place, drawn as it will be read. A
--- field beside a preview is not an editor: nothing can be selected across a mark, the caret is never
--- where the words are, and what is being written is drawn twice in two different shapes.
---
--- The document is runs of text carrying marks, which is what `RichText` draws and what every platform's
--- own editor holds: an attributed string on iOS, a spanned editable on Android, and a tree of elements
--- in a browser. The marks are semantic, so each platform draws its own bold rather than a weight the
--- tree named, and a link is drawn in `linkColor` so one look reaches all three.
---
--- Nothing about a toolbar is here. Applying a mark, following a link, copying and pasting are all asked
--- for through a ref, and `RichToolbar` is the row of buttons that asks — which means an application may
--- draw its own instead without the editor knowing.
M.RichEditor = support.host("richeditor", {
    natural = {
        text = function(props)
            local parts = {}

            for index = 1, #(props.value or {}) do
                parts[index] = props.value[index].text or ""
            end

            local written = table.concat(parts)

            if written ~= "" then
                return written
            end

            return props.placeholder or " "
        end,
        padding = { horizontal = 12, vertical = 8 },
        minHeight = 96,
    },
    style = {
        background = "surface",
        color = "text",
        fontSize = "body",
        radius = "md",
    },
    props = { "value", "placeholder", "placeholderColor", "linkColor", "editable",
        "autoCapitalize", "autoCorrect", "maxLength", "autoFocus" },
    events = { "onChange", "onSelectionChange", "onFocus", "onBlur" },
    actions = { "focus", "blur", "toggleMark", "setLink", "clearLink", "copy", "cut", "paste", "selectAll" },
    defaults = { editable = true, autoCapitalize = "sentences", autoCorrect = true },
    validate = function(spec)
        if spec.value == nil then
            return "needs a value, which is the document as a list of { text, marks } runs"
        end

        return wrongValue(spec.value)
    end,
})

--- What each button in the toolbar says, in the order every editor puts them in.
local TOOLS = {
    { key = "bold", icon = "bold", label = "Bold", mark = "bold" },
    { key = "italic", icon = "italic", label = "Italic", mark = "italic" },
    { key = "underline", icon = "underline", label = "Underline", mark = "underline" },
    { key = "strikethrough", icon = "strikethrough", label = "Strikethrough", mark = "strikethrough" },
    { key = "code", icon = "code", label = "Code", mark = "code" },
    { key = "link", icon = "link", label = "Link", action = "link" },
    { key = "copy", icon = "copy", label = "Copy", action = "copy" },
    { key = "cut", icon = "scissors", label = "Cut", action = "cut" },
    { key = "paste", icon = "clipboard", label = "Paste", action = "paste" },
}

local NAMED = {}

for index = 1, #TOOLS do
    NAMED[TOOLS[index].key] = TOOLS[index]
end

--- Answers the tools a caller asked for, in the order they were asked for.
local function chosen(names)
    if names == nil then
        return TOOLS
    end

    local wanted = {}

    for index = 1, #names do
        wanted[#wanted + 1] = NAMED[names[index]]
    end

    return wanted
end

--- The row of tools over an editor, which shows what is on at the caret and turns it off again.
---
--- It reaches the editor through the same ref a caller holds, so an application that wants a toolbar of
--- its own writes one and the editor never knows the difference.
M.RichToolbar = support.component("RichToolbar", {
    props = { "editor", "tools", "marks", "disabled" },
    events = { "onLink" },
    validate = function(spec)
        if spec.editor == nil then
            return "needs the editor it drives, which is the ref the editor was given"
        end

        for index = 1, #(spec.tools or {}) do
            if NAMED[spec.tools[index]] == nil then
                return "there is no tool called " .. tostring(spec.tools[index])
            end
        end
    end,
}, component.define({
    name = "RichToolbar",

    --- Asks the editor for what the tool stands for, which is a mark to turn on or off or a clipboard.
    use = function(self, tool)
        if tool.mark ~= nil then
            self.props.editor:call("toggleMark", { mark = tool.mark })
            return
        end

        if tool.action == "link" then
            if self.props.onLink ~= nil then
                self.props.onLink()
            end

            return
        end

        self.props.editor:call(tool.action)
    end,

    render = function(self)
        local on_ = self.props.marks or {}
        local buttons = {}

        for _, tool in ipairs(chosen(self.props.tools)) do
            local on = tool.mark ~= nil and on_[tool.mark] ~= nil and on_[tool.mark] ~= false

            buttons[#buttons + 1] = Pressable {
                key = tool.key,
                disabled = self.props.disabled,
                accessibilityLabel = tool.label,
                onPress = function() self:use(tool) end,
                style = {
                    width = chrome.touch,
                    height = chrome.touch,
                    align = "center",
                    justify = "center",
                    radius = "sm",
                    background = on and "primary" or "surface",
                },

                content.Icon { name = tool.icon, size = 18, color = on and "onPrimary" or "text" },
            }
        end

        -- The tools run along one line and scroll rather than wrapping onto a second, which is what a
        -- toolbar is on every platform: a second row of them takes the editor's room and moves the
        -- words under it every time a tool is added.
        return structure.ScrollView {
            horizontal = true,
            showsIndicator = false,
            style = { { height = chrome.touch }, self.props.style },
            contentStyle = { direction = "row", align = "center", gap = "xs" },
            table.unpack(buttons),
        }
    end,
}))

return M
