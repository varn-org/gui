local gui = require("gui")
local marks = require("gui.marks")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 6 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function refused(build, needle)
    local ok, problem = pcall(build)

    assert(not ok, "the editor should have refused " .. needle)
    assert(tostring(problem):find(needle, 1, true) ~= nil, "it said " .. tostring(problem))
end

--- The document every case below starts from, which is runs of text carrying marks.
local OPENING = {
    { text = "A rich editor is ", marks = {} },
    { text = "one box", marks = { bold = true } },
    { text = " a reader types into.", marks = {} },
}

-- The document crosses as runs, which is what the tree holds and what every platform edits.
do
    local _, renderer = start(gui.RichEditor { value = OPENING, onChange = function() end })
    local editor = renderer:find("richeditor")

    assert(#editor.props.value == 3, "the document crosses as it was written, got " .. #editor.props.value)
    assert(editor.props.value[2].marks.bold == true, "and every run carries its own marks")
end

-- An editor is measured as the words in it, so one holding a paragraph is as tall as the paragraph.
do
    local _, renderer = start(gui.View { style = { width = 300 },
        gui.RichEditor { value = { { text = "one", marks = {} } }, onChange = function() end },
    })

    local short = renderer:find("richeditor").frame.height

    local _, taller = start(gui.View { style = { width = 300 },
        gui.RichEditor {
            value = { { text = string.rep("a long line of words ", 20), marks = {} } },
            onChange = function() end,
        },
    })

    assert(taller:find("richeditor").frame.height > short,
        "an editor is as tall as what is in it, " .. taller:find("richeditor").frame.height
            .. " against " .. short)
end

-- An editor refuses a document it cannot draw, where it was written.
do
    refused(function() return gui.RichEditor {} end, "needs a value")
    refused(function() return gui.RichEditor { value = "plain" } end, "list of { text, marks } runs")
    refused(function() return gui.RichEditor { value = { { text = 3 } } } end, "carries text")
    refused(function() return gui.RichEditor { value = { { text = "a", marks = { huge = true } } } } end,
        "a mark nothing draws")
end

-- What a toolbar asks for reaches the editor, by name and with what it was asked with.
do
    local Screen = gui.component({
        name = "Writing",
        state = { document = OPENING, marks = {} },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.RichToolbar {
                    editor = self:ref("editor"),
                    marks = self.state.marks,
                    onLink = function() self:setState({ asked = true }) end,
                },

                gui.RichEditor {
                    ref = self:ref("editor"),
                    value = self.state.document,
                    onChange = function(runs) self:setState({ document = runs }) end,
                    onSelectionChange = function(where) self:setState({ marks = where.marks or {} }) end,
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})
    local editor = renderer:find("richeditor")
    local tools = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" and node.props.accessibilityLabel ~= nil then
            tools[node.props.accessibilityLabel] = node
        end
    end

    assert(tools.Bold ~= nil and tools.Copy ~= nil and tools.Paste ~= nil, "the toolbar draws its tools")

    runtime:dispatch(tools.Bold.id, "onPress", nil)
    runtime:commit()

    assert(#renderer.calls == 1, "pressing a mark asks the editor once")
    assert(renderer.calls[1].id == editor.id, "and it asks the editor rather than anything else")
    assert(renderer.calls[1].method == "toggleMark" and renderer.calls[1].arguments.mark == "bold",
        "with the mark it stands for")

    runtime:dispatch(tools.Copy.id, "onPress", nil)
    runtime:commit()

    assert(renderer.calls[2].method == "copy", "and a clipboard tool asks for the clipboard")

    -- Where a link points is something a reader has to be asked for, so the toolbar reports it rather
    -- than inventing an address of its own.
    runtime:dispatch(tools.Link.id, "onPress", nil)
    runtime:commit()

    assert(#renderer.calls == 2, "the link tool asks the editor for nothing on its own")
    assert(runtime.root.instance.state.asked == true, "and tells the screen a link was asked for")
end

-- The toolbar shows what is on at the caret, which is what the editor reported.
do
    local Screen = gui.component({
        name = "Marking",
        state = { marks = {} },

        render = function(self)
            return gui.View { style = { grow = 1 },
                gui.RichToolbar { editor = self:ref("editor"), marks = self.state.marks },

                gui.RichEditor {
                    ref = self:ref("editor"),
                    value = OPENING,
                    onChange = function() end,
                    onSelectionChange = function(where) self:setState({ marks = where.marks or {} }) end,
                },
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    local function lit()
        for _, node in pairs(renderer.nodes) do
            if node.props.accessibilityLabel == "Bold" then
                return node.props.style.background
            end
        end
    end

    local plain = lit()

    runtime:dispatch(renderer:find("richeditor").id, "onSelectionChange",
        { start = 17, ["end"] = 24, marks = { bold = true } })
    runtime:commit()

    assert(lit() ~= plain, "a mark that is on at the caret is drawn as on, it stayed " .. tostring(lit()))
end

-- A caller may draw only the tools they want, in the order they want them.
do
    local _, renderer = start(gui.View { style = { grow = 1 },
        gui.RichToolbar { editor = gui.ref(), tools = { "bold", "link" } },
    })

    local found = 0

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" then
            found = found + 1
        end
    end

    assert(found == 2, "a toolbar draws the tools it was named, drew " .. found)

    refused(function() return gui.RichToolbar { editor = gui.ref(), tools = { "sideways" } } end, "sideways")
    refused(function() return gui.RichToolbar {} end, "needs the editor")
end

-- Every tool a finger lands on is at least as large as the guidelines allow.
do
    local _, renderer = start(gui.View { style = { grow = 1, width = 390 },
        gui.RichToolbar { editor = gui.ref() },
    })

    for _, node in pairs(renderer.nodes) do
        if node.type == "pressable" and node.frame ~= nil then
            assert(node.frame.width >= 44 and node.frame.height >= 44,
                tostring(node.props.accessibilityLabel) .. " is " .. node.frame.width
                    .. " by " .. node.frame.height)
        end
    end
end

-- A mark is turned into the style that draws it, which is how a document reaches RichText.
do
    assert(marks.style({ bold = true }).fontWeight == "700", "bold is drawn heavy")
    assert(marks.style({ italic = true }).fontStyle == "italic", "italic is drawn slanted")
    assert(marks.style({ code = true }).fontFamily == "monospace", "code is drawn in a monospace")
    assert(marks.style({ underline = true }).textDecoration == "underline", "underline is drawn under")
    assert(marks.style({ strikethrough = true }).textDecoration == "line-through", "and a strike through")

    local linked = marks.style({ link = "https://example.com" })

    assert(linked.color == "primary", "a link takes the look's own colour rather than a blue nobody chose")

    assert(next(marks.style({})) == nil, "a run carrying no marks is drawn with no style of its own")
    assert(next(marks.style(nil)) == nil, "and neither is one carrying none at all")

    local spans = marks.spans(OPENING)

    assert(#spans == 3, "a document is drawn as one span per run, got " .. #spans)
    assert(spans[2].style.fontWeight == "700", "and each span is drawn with what its run was marked")
    assert(spans[1].text == OPENING[1].text, "carrying the words it was written with")

    for _, name in ipairs(marks.names) do
        assert(marks.has(name), name .. " is a mark and is not known as one")
    end

    assert(not marks.has("huge"), "and a name nothing draws is not a mark")
end

print("gui.writing ok")
