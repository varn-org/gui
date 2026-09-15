local gui = require("gui")
local parts = require("parts")

--- A field over several lines, either a fixed number of them or as many as what is written needs.
local Field = gui.component({
    name = "WritingField",
    state = { body = "" },

    render = function(self)
        local lines = select(2, self.state.body:gsub("\n", "")) + 1

        return gui.View {
            style = { gap = "sm" },

            gui.TextArea {
                value = self.state.body,
                placeholder = self.props.placeholder,
                rows = self.props.rows,
                grows = self.props.grows,
                onChange = function(value) self:setState({ body = value }) end,
                style = self.props.grows and { maxHeight = 260 } or nil,
            },

            gui.Text {
                text = #self.state.body .. " characters over " .. lines
                    .. (lines == 1 and " line" or " lines"),
                style = { fontSize = "footnote", color = "textMuted" },
            },
        }
    end,
})

--- The document the editor opens with, which is runs of text carrying marks.
local OPENING = {
    { text = "A rich editor is ", marks = {} },
    { text = "one box", marks = { bold = true } },
    { text = " a reader types into, with a ", marks = {} },
    { text = "toolbar", marks = { italic = true } },
    { text = " over it.", marks = {} },
}

--- An editor over styled text, which is where the words are rather than a field beside a preview.
---
--- What is selected, marked and copied is the text itself, in place, drawn as it will be read. The
--- toolbar asks the editor for a mark and shows which ones are on at the caret, and the editor reports
--- the document after every change so the screen can keep it.
local Editor = gui.component({
    name = "WritingEditor",
    state = { document = OPENING, marks = {}, where = { start = 0, ["end"] = 0 }, linking = false, url = "" },

    --- Answers what is written, which is what a screen keeps rather than the marks under it.
    written = function(self)
        local parts_ = {}

        for index = 1, #self.state.document do
            parts_[index] = self.state.document[index].text
        end

        return table.concat(parts_)
    end,

    --- Answers how many runs carry a mark, which is what says the document is more than plain text.
    marked = function(self)
        local total = 0

        for index = 1, #self.state.document do
            if next(self.state.document[index].marks or {}) ~= nil then
                total = total + 1
            end
        end

        return total
    end,

    link = function(self)
        self:ref("editor"):call("setLink", { url = self.state.url })
        self:setState({ linking = false, url = "" })
    end,

    render = function(self)
        local selected = self.state.where["end"] > self.state.where.start

        return gui.View {
            style = { gap = "sm" },

            gui.RichToolbar {
                editor = self:ref("editor"),
                marks = self.state.marks,
                onLink = function() self:setState({ linking = not self.state.linking }) end,
            },

            self.state.linking and gui.View { style = { direction = "row", gap = "sm", align = "center" },
                gui.TextInput {
                    value = self.state.url,
                    placeholder = "https://example.com",
                    keyboard = "url",
                    autoCapitalize = "none",
                    style = { grow = 1 },
                    onChange = function(value) self:setState({ url = value }) end,
                },
                gui.Button { title = "Link", disabled = not selected, onPress = function() self:link() end },
            } or false,

            gui.RichEditor {
                ref = self:ref("editor"),
                value = self.state.document,
                placeholder = "Write something, select it, and mark it",
                style = { minHeight = 140 },
                onChange = function(runs) self:setState({ document = runs }) end,
                onSelectionChange = function(where)
                    self:setState({ marks = where.marks or {}, where = where })
                end,
            },

            gui.Text {
                text = #self:written() .. " characters over " .. self:marked() .. " marked runs, "
                    .. (selected and "with a selection" or "with the caret at " .. self.state.where.start),
                style = { fontSize = "footnote", color = "textMuted" },
            },

            gui.View { style = { direction = "row", gap = "sm" },
                gui.Button {
                    title = "Select all",
                    variant = "outlined",
                    style = { grow = 1 },
                    onPress = function() self:ref("editor"):call("selectAll") end,
                },
                gui.Button {
                    title = "Clear the link",
                    variant = "outlined",
                    disabled = not selected,
                    style = { grow = 1 },
                    onPress = function() self:ref("editor"):call("clearLink") end,
                },
            },

            parts.Block {
                title = "What it is drawn as",
                summary = "The same runs a reader is typing into, drawn by RichText rather than edited",
                gui.RichText { spans = gui.marks.spans(self.state.document) },
            },
        }
    end,
})

local Writing = gui.component({
    name = "Writing",

    render = function()
        return parts.Page {
            parts.Block {
                title = "Several lines, a fixed number of them",
                summary = "It shows three and scrolls inside itself, whatever is written into it",
                Field { rows = 3, placeholder = "Three lines, and it scrolls" },
            },

            parts.Block {
                title = "As tall as what is in it",
                summary = "The height is a measurement of the text, so it changes on every keystroke",
                Field { grows = true, placeholder = "Type, and press return, and watch it grow" },
            },

            parts.Block {
                title = "An editor over styled text",
                summary = "One box, with the marks applied where the words are rather than in a second field",
                Editor {},
            },
        }
    end,
})

return {
    {
        key = "writing",
        title = "Writing",
        summary = "Several lines, a box as tall as what is in it, and an editor over styled text",
        render = function() return Writing {} end,
    },
}
