local context = require("gui.context")

--- What the surface a tree is drawn on is like, which the runtime provides above everything else.
---
--- The chrome of an application has to look like the system it is running on — a back button is a
--- chevron and a title on one and an arrow on the other — and that is the one thing a tree cannot work
--- out for itself. Everything else stays free of it: layout, styling and behaviour are the same
--- wherever they run, and a component that reads this to decide a colour or a size is doing it wrong.
return context.create({
    platform = "web",
    appearance = "light",
    scale = 1,
    width = 0,
    height = 0,
    breakpoint = "compact",
    insets = { top = 0, right = 0, bottom = 0, left = 0 },
})
