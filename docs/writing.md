# ✍️ Writing

A field holds a string. An editor holds a document: runs of text that each carry marks, edited where the words are rather than in a second box beside a preview.

`gui.RichEditor` is that editor, `gui.RichToolbar` is the row of tools over it, `gui.marks` is what a mark means, and `gui.RichText` draws a document that is no longer being edited.

## One box, not two

What a reader selects, marks and copies is the text itself, in place, drawn as it will be read. A plain field with a preview beside it is not an editor: nothing can be selected across a mark, the caret is never where the words are, and what is being written is drawn twice in two different shapes.

The platform already holds a document this way — an attributed string on iOS, a spanned editable on Android, a tree of elements in a browser — so the editor is the platform's own control with the marks turned into spans going in and read back out of them coming out.

## The marks

| Mark | What it is |
|---|---|
| `bold` | The platform's own bold face |
| `italic` | The platform's own italic |
| `underline` | A line under the run |
| `strikethrough` | A line through the run |
| `code` | The platform's own monospace |
| `link` | Where the run points, which is a string rather than `true` |

A mark is semantic rather than a style. A renderer draws `bold` with the face the platform draws its own bold with, the way a label drawn in the system's font is the system's font rather than a family the tree named. The one exception is what a link is coloured in, which is the look's and reaches all three renderers as `linkColor`.

## The document

```lua
local document = {
    { text = "A rich editor is ", marks = {} },
    { text = "one box", marks = { bold = true } },
    { text = " a reader types into.", marks = {} },
}
```

That is what `value` takes, what `onChange` reports back, and what `gui.marks.spans` turns into the spans `gui.RichText` draws.

## An editor with a toolbar

```lua
local Editor = gui.component({
    name = "Editor",
    state = { document = {}, marks = {} },

    render = function(self)
        return gui.View { style = { gap = "sm" },
            gui.RichToolbar {
                editor = self:ref("editor"),
                marks = self.state.marks,
                onLink = function() self:setState({ linking = true }) end,
            },

            gui.RichEditor {
                ref = self:ref("editor"),
                value = self.state.document,
                placeholder = "Write something",
                onChange = function(runs) self:setState({ document = runs }) end,
                onSelectionChange = function(where) self:setState({ marks = where.marks }) end,
            },
        }
    end,
})
```

`onSelectionChange` carries `{ start, end, marks }`: where the caret is, counted in characters, and which marks are on there. That is what the toolbar draws itself from, so a reader sees `Bold` lit while the caret is inside something bold.

## What a toolbar asks for

The toolbar owns none of the editing. Every tool is an action asked of the editor through its ref, so an application that wants a toolbar of its own writes one and the editor never knows the difference.

| Action | What it does |
|---|---|
| `toggleMark { mark }` | Turns a mark on or off over what is selected |
| `setLink { url }` | Points what is selected at an address |
| `clearLink` | Takes the address off it |
| `copy`, `cut`, `paste` | The system's own clipboard |
| `selectAll` | Selects the whole document |
| `focus`, `blur` | Takes the keyboard, or gives it up |

`tools` names which of them the toolbar draws, in the order it draws them: `tools = { "bold", "italic", "link" }`. Naming none draws all of them.

`onLink` is the one tool the toolbar cannot do by itself, since where a link points is something a reader has to be asked for. It reports that the reader wants one and the screen decides how to ask.

## Pasting

Copying and cutting work everywhere. Pasting is the platform's to allow: a phone hands over what is on its clipboard, and a browser refuses to let a page read one without being allowed to. Where it is refused the editor reports the refusal through `onSelectionChange` rather than leaving a button that does nothing.

## Drawing a document that is not being edited

```lua
gui.RichText { spans = gui.marks.spans(document) }
```

`gui.marks` carries `names`, `has(name)` and `style(marks)` beside `spans(document)`, so a screen that draws its own runs turns a mark into a style the same way the editor does.

## What this is not

The editor holds a document and the marks over it. It is not a word processor: there are no paragraphs, no lists, no headings and no tables, and adding them means owning a layout engine for text rather than using the platform's own. What is here is the shape every editor in a message, a note or a comment field actually has, and the line is drawn deliberately rather than left to be discovered.

## Reference and tests

The declarations are in [components.md](components.md). The suite is `gui/tests/writing_test.lua`, the browser drives one in `renderers/web/tests/browser.test.js`, and the gallery draws one under **Writing / Writing**.
