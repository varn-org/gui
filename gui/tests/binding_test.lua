local gui = require("gui")

local function start(description, options)
    local renderer = gui.headless()
    local app = gui.start(description, renderer, options or { size = { width = 320, height = 640 } })
    return app, renderer
end

-- A ref points at the node it was given to, and reaches it imperatively.
do
    local field = gui.ref()
    local app, renderer = start(gui.TextInput { ref = field, placeholder = "name" })

    assert(field:get() ~= nil, "a mounted ref must point at its node")
    assert(field:get().type == "textinput", "the ref must name the node it was placed on")
    assert(field:get().id == renderer:find("textinput").id, "the ref must carry the id the renderer knows")

    field:call("focus", {})
    assert(#renderer.calls == 1, "an imperative call must reach the renderer")
    assert(renderer.calls[1].method == "focus", "the call must carry the method")
    assert(app ~= nil)
end

-- A ref that points at nothing refuses a call rather than failing somewhere deeper.
do
    local empty = gui.ref()
    local ok, message = pcall(empty.call, empty, "focus", {})

    assert(not ok, "a call through an empty ref must be refused")
    assert(tostring(message):find("focus"), "the message must name the method")
end

-- A value provided high in the tree is read far below without being threaded through.
do
    local Locale = gui.context("en")
    local seen = nil

    local Deep = gui.component(function(self)
        seen = Locale:read(self)
        return gui.Text { text = seen }
    end)

    local Middle = gui.component(function()
        return gui.View { Deep {} }
    end)

    start(Locale.Provider { value = "pt", Middle {} })
    assert(seen == "pt", "the provided value must reach the component below, got " .. tostring(seen))
end

-- Without a provider the default is what a read answers.
do
    local Locale = gui.context("en")
    local seen = nil

    local Deep = gui.component(function(self)
        seen = Locale:read(self)
        return gui.Text { text = seen }
    end)

    start(gui.View { Deep {} })
    assert(seen == "en", "the default must answer when nothing provided one")
end

-- The nearest provider wins over one further up.
do
    local Locale = gui.context("en")
    local seen = nil

    local Deep = gui.component(function(self)
        seen = Locale:read(self)
        return gui.Text { text = seen }
    end)

    start(Locale.Provider { value = "pt", Locale.Provider { value = "fr", Deep {} } })
    assert(seen == "fr", "the nearest provider must win, got " .. tostring(seen))
end

-- A theme name resolves to a concrete value before the layout or a renderer sees it.
do
    local theme = gui.theme.create()
    local _, renderer = start(
        gui.View { style = { padding = "md", background = "primary", radius = "lg" } },
        { size = { width = 320, height = 640 }, theme = theme }
    )

    local frame = renderer:find("view").frame
    assert(frame ~= nil, "the node must have been laid out")

    local resolved = gui.resolveStyle({ padding = "md", background = "primary" }, theme, "compact")
    assert(resolved.padding == theme.spacing.md, "a spacing name must become a number")
    assert(resolved.background == theme.colors.primary, "a colour name must become a colour")
end

-- A list of styles is flattened left to right, so a later one overrides an earlier one.
do
    local theme = gui.theme.create()
    local base = { padding = 4, background = "#ffffff" }
    local accent = { background = "#ff0000" }

    local resolved = gui.resolveStyle({ base, accent }, theme, "compact")
    assert(resolved.padding == 4, "an untouched value must survive")
    assert(resolved.background == "#ff0000", "the later style must win")
end

-- A false entry in a style list is skipped, which is what a conditional style is.
do
    local theme = gui.theme.create()
    local resolved = gui.resolveStyle({ { padding = 4 }, false, { margin = 2 } }, theme, "compact")

    assert(resolved.padding == 4 and resolved.margin == 2, "a false entry must be skipped")
end

-- A value keyed by breakpoint resolves against the width the surface has.
do
    local theme = gui.theme.create()

    local compact = gui.resolveStyle({ padding = { compact = 8, expanded = 32 } }, theme, "compact")
    local expanded = gui.resolveStyle({ padding = { compact = 8, expanded = 32 } }, theme, "expanded")

    assert(compact.padding == 8, "a phone must take the compact value")
    assert(expanded.padding == 32, "a desktop must take the expanded value")
end

-- Swapping the theme re-resolves every style, which is what a light and dark switch is.
do
    local light = gui.theme.create()
    local dark = gui.theme.dark()

    local app, renderer = start(
        gui.View { style = { background = "background" } },
        { size = { width = 320, height = 640 }, theme = light }
    )

    local before = #renderer.batches
    app:setTheme(dark)
    app:commit()

    assert(#renderer.batches > before, "swapping the theme must reach the renderer")
    assert(app.theme.colors.background == dark.colors.background, "the runtime must hold the new theme")
end

print("gui.binding ok")
