--- Every family the library is built out of, in the order the reference reads them.
---
--- One list, read by the library, by the reference page and by the check that every declared prop is
--- honoured. Three copies meant two of them fell behind: `Presence` and `SplitView` were exported,
--- documented nowhere, and had not one prop checked, which is how an event nothing fires survived.
return {
    { title = "Structure", module = "gui.components.structure" },
    { title = "Content", module = "gui.components.content" },
    { title = "Input", module = "gui.components.input" },
    { title = "Place", module = "gui.components.place" },
    { title = "Collections", module = "gui.components.collections" },
    { title = "Containers", module = "gui.components.containers" },
    { title = "Adapting", module = "gui.components.split" },
    { title = "Presence", module = "gui.components.presence" },
    { title = "Presentation", module = "gui.components.presentation" },
    { title = "Feedback", module = "gui.components.feedback" },
}
