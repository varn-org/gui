local M = {}

--- The marks a run of text may carry, which is what every editor on every platform offers.
---
--- A mark is semantic rather than a style: a renderer draws `bold` with the platform's own bold face and
--- `code` with the platform's own monospace, the way a label drawn in the system's font is the system's
--- font rather than a family the tree named. A `link` carries where it points as well as being a mark.
M.names = { "bold", "italic", "underline", "strikethrough", "code", "link" }

local KNOWN = {}

for index = 1, #M.names do
    KNOWN[M.names[index]] = true
end

--- Answers whether a name is a mark, which is what a document is checked against.
function M.has(name)
    return KNOWN[name] == true
end

--- Answers the style one set of marks is drawn with, which is how a document reaches `RichText`.
---
--- What a reader edits is marks and what the framework draws is styles, so the two meet here rather than
--- in every screen that shows what was written. A link takes the look's own colour rather than a blue
--- nobody chose, since a colour a control carries is resolved by the engine like any other.
function M.style(marks)
    local held = {}

    if marks == nil then
        return held
    end

    if marks.bold then
        held.fontWeight = "700"
    end

    if marks.italic then
        held.fontStyle = "italic"
    end

    if marks.code then
        held.fontFamily = "monospace"
    end

    if marks.underline then
        held.textDecoration = "underline"
    end

    if marks.strikethrough then
        held.textDecoration = "line-through"
    end

    if type(marks.link) == "string" then
        held.color = "primary"
        held.textDecoration = "underline"
    end

    return held
end

--- Answers the spans a document is drawn as, which is what `RichText` takes.
function M.spans(document)
    local spans = {}

    for index = 1, #(document or {}) do
        local run = document[index]

        spans[index] = { text = run.text or "", style = M.style(run.marks) }
    end

    return spans
end

return M
