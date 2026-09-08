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

-- A ref that points at nothing answers no rather than failing somewhere deeper.
--
-- A ref is held across time — a timer that scrolls a list, a handler that focuses a field once an
-- answer comes back — and by then the screen may have gone. That is life rather than a mistake, so the
-- call answers whether there was anything to call, and raising instead left a screen that had been left
-- reporting a failure from inside the bridge.
do
    local empty = gui.ref()
    local ok, answered = pcall(empty.call, empty, "focus", {})

    assert(ok, "a call through an empty ref is not a failure: " .. tostring(answered))
    assert(answered == false, "and it answers that there was nothing to call")
    assert(empty:get() == nil, "which is what a caller who wants to look first reads")
end

-- A ref points at nothing once what it pointed at has gone.
do
    local held = gui.ref()

    local Screen = gui.component({
        name = "Screen",
        state = { shown = true },
        render = function(self)
            if not self.state.shown then
                return gui.Text { text = "gone" }
            end

            return gui.TextInput { ref = held, value = "", onChange = function() end }
        end,
    })

    local renderer = gui.headless()
    local app = gui.start(Screen {}, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 4 do
        if not app:needsCommit() then
            break
        end

        app:commit()
    end

    assert(held:get() ~= nil, "a ref points at the node it was given to")

    app.root.instance:setState({ shown = false })
    app:commit()

    assert(held:get() == nil, "and at nothing once that node has gone")
    assert(held:call("focus", {}) == false, "so a call through it answers no rather than reaching a dead id")

    app:stop()
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
    assert(resolved.background == gui.color.toHex(theme.colors.primary),
        "a colour name must become the hex every renderer draws with")
end

-- Every colour reaches a renderer as eight digit hex, whatever shape it was written in.
--
-- The iOS and Android parsers read nothing that does not start with a hash, so the theme's `overlay`,
-- written as an `rgba` call, drew as nothing at all: the scrim behind every overlay was invisible and an
-- alert read as the page it was covering. A renderer reads a colour rather than parsing one.
do
    local theme = gui.theme.create()

    local written = {
        { given = "overlay", expected = "#00000066" },
        { given = "rgba(0, 0, 0, 0.4)", expected = "#00000066" },
        { given = "#fff", expected = "#ffffffff" },
        { given = "#3b82f6", expected = "#3b82f6ff" },
        { given = "hsl(0, 100%, 50%)", expected = "#ff0000ff" },
        { given = "red", expected = "#ff0000ff" },
    }

    for index = 1, #written do
        local entry = written[index]
        local resolved = gui.resolveStyle({ background = entry.given }, theme, "compact")

        assert(resolved.background == entry.expected,
            entry.given .. " must resolve to " .. entry.expected .. ", got " .. tostring(resolved.background))
    end

    -- A colour carried as a prop rather than a style is resolved the same way.
    local _, renderer = start(
        gui.Switch { value = true, onColor = "primary", thumbColor = "rgb(255, 255, 255)" },
        { size = { width = 320, height = 640 }, theme = theme }
    )

    local control = renderer:find("switch")
    assert(control.props.onColor == gui.color.toHex(theme.colors.primary),
        "a tint named by the theme must reach a renderer as hex, got " .. tostring(control.props.onColor))
    assert(control.props.thumbColor == "#ffffffff",
        "a tint written as a call must reach a renderer as hex, got " .. tostring(control.props.thumbColor))

    -- A shadow carries a colour of its own, which is the one an overlay is separated from the page by.
    local shadow = gui.resolveStyle({ shadow = "md" }, theme, "compact").shadow
    assert(shadow.color:match("^#%x%x%x%x%x%x%x%x$") ~= nil,
        "a shadow's colour must reach a renderer as hex, got " .. tostring(shadow.color))
end

-- A list of styles is flattened left to right, so a later one overrides an earlier one.
do
    local theme = gui.theme.create()
    local base = { padding = 4, background = "#ffffff" }
    local accent = { background = "#ff0000" }

    local resolved = gui.resolveStyle({ base, accent }, theme, "compact")
    assert(resolved.padding == 4, "an untouched value must survive")
    assert(resolved.background == "#ff0000ff", "the later style must win")
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


-- A file picker opens the chooser the platform ships and reports what came back.
--
-- It declared a title and nothing else: no kind, no event, nothing a chosen file could ever be reported
-- through, so the component could not work whatever the renderers did. Two of the three drew a control
-- that was not a chooser at all.
do
    local picked = {}

    local _, renderer = start(gui.FilePicker {
        title = "Choose a file",
        kind = "image",
        accept = { "image/png" },
        multiple = true,
        onPick = function(file) picked[#picked + 1] = file end,
    })

    local chooser = renderer:find("filepicker")

    assert(chooser ~= nil, "a file picker must reach the renderer")
    assert(chooser.props.kind == "image", "the kind of chooser to open crosses to the renderer")
    assert(chooser.props.accept[1] == "image/png", "and what it may offer")
    assert(chooser.props.multiple == true, "and whether it takes more than one")
    assert(chooser.props.maxBytes > 0, "and how much of a file is worth reading")

    -- What a platform reports is the same four fields wherever it is reported from, one file at a time.
    chooser.props.onPick({ name = "a.png", size = 12, type = "image/png", bytes = "AAAA" })
    chooser.props.onPick({ name = "huge.mov", size = 900000000, type = "video/quicktime" })

    assert(#picked == 2, "everything chosen must reach the tree, reached " .. #picked)
    assert(picked[1].bytes == "AAAA", "a file within the cap arrives read")
    assert(picked[2].bytes == nil, "and one over it arrives named and measured but unread")
end

-- A kind the platform has no chooser for is refused where it was written.
do
    local ok, problem = pcall(function()
        return start(gui.FilePicker { kind = "folder" })
    end)

    assert(not ok, "a kind that is not one must be refused")
    assert(tostring(problem):find("kind", 1, true) ~= nil, "and named for it, got " .. tostring(problem))
end

-- What a picker answers is enough to write the file down and show it, which is the whole point of one.
--
-- A picker that reports a name and a size and nothing a screen can do anything with is a chooser with
-- no chooser behind it. This is the round trip: choose, decode, write, read back, and hand the path to
-- an image, all of it through the same calls a screen would make.

-- An application that was never told where it may write says so, rather than answering nothing.
do
    local storage = require("gui.host.storage")

    storage.use(os.getenv("VARN_TEST_DIR") .. "/files")

    local ok, problem = pcall(storage.directory, "wherever")

    assert(ok, "a host that has said where may be asked")
    assert(problem ~= nil and problem:sub(1, 1) == "/", "and it answers a place, answered " .. tostring(problem))

    local refused, named = pcall(storage.directory, "a/path")

    assert(not refused, "a directory is named rather than pathed")
    assert(tostring(named):find("named, not pathed", 1, true) ~= nil,
        "and it says so, said " .. tostring(named))
end

do
    local async = require("async")
    local crypto = require("crypto")
    local fs = require("fs")

    local storage = require("gui.host.storage")

    storage.use(os.getenv("VARN_TEST_DIR") .. "/files")

    async.run(function()
        local folder = storage.directory("picked")
        local original = "the bytes of a picture"
        local reported = {
            name = "photo.png",
            size = #original,
            type = "image/png",
            bytes = crypto.base64Encode(original),
        }

        local path = folder .. "/" .. reported.name

        fs.writeFile(path, crypto.base64Decode(reported.bytes)):await()

        assert(fs.exists(path), "what a picker reported must be writable where the engine can read it")
        assert(fs.readFile(path):await() == original,
            "and what is read back is what was chosen, byte for byte")

        -- A path the engine can read is a source an image takes as it is, rather than a name it looks
        -- up in the bundle.
        local renderer = gui.headless()
        local runtime = gui.start(gui.Image {
            source = path,
            resizeMode = "cover",
            style = { width = 80, height = 80 },
        }, renderer, { size = { width = 320, height = 480 } })

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        local picture = renderer:find("image")

        assert(picture ~= nil, "a picked picture must reach the renderer")
        assert(picture.props.source == path,
            "as the file it was written to rather than a name in the bundle, is "
                .. tostring(picture.props.source))
        assert(picture.frame.width == 80 and picture.frame.height == 80,
            "in the box the screen gave it")

        runtime:stop()

        -- Where an application writes is a place the host gave it, never one worked out from where the
        -- process happens to have been started. A relative path is written into the working directory,
        -- which is writable on a desktop and is not on a phone, so this passed everywhere but the device
        -- it was written for.
        assert(path:sub(1, 1) == "/", "a picked file is written somewhere absolute, was written to " .. path)

        fs.removeRecursive(folder):await()
        print("gui.binding ok")
    end)
end
