local gui = require("gui")
local async = require("async")

local function start(description, options)
    local renderer = gui.headless()
    options = options or {}
    options.size = options.size or { width = 320, height = 640 }

    local runtime = gui.start(description, renderer, options)

    for _ = 1, 4 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

local function said(renderer)
    local found = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" then
            found[#found + 1] = node.props.text
        end
    end

    table.sort(found)
    return table.concat(found, ",")
end

local function shows(renderer, text)
    return said(renderer):find(text, 1, true) ~= nil
end

local ROUTES = {
    { path = "/", title = "Home", render = function() return gui.Text { text = "home" } end },
    {
        path = "/items/:id",
        title = function(where) return "Item " .. where.params.id end,
        render = function(where) return gui.Text { text = "item " .. where.params.id } end,
    },
}

async.run(function()
    -- An application opens where the host said it was asked to be, not where the entry point starts.
    do
        local _, renderer = start(gui.Router { routes = ROUTES }, { address = "/items/9" })

        assert(shows(renderer, "item 9"), "a link the host reported is the screen that opens, got " .. said(renderer))
    end

    -- A deep link and an app link land on the same screen a path does.
    do
        local _, plain = start(gui.Router { routes = ROUTES }, { address = "/items/3" })
        local _, deep = start(gui.Router { routes = ROUTES }, { address = "varn://items/3" })
        local _, app = start(gui.Router { routes = ROUTES }, { address = "https://varn.dev/items/3" })

        assert(shows(plain, "item 3"), "a path lands on the screen it names")
        assert(shows(deep, "item 3"), "and so does a deep link, got " .. said(deep))
        assert(shows(app, "item 3"), "and so does an app link, got " .. said(app))
    end

    -- A link that arrives while the application runs lands on top of what was open.
    do
        local runtime, renderer = start(gui.Router { routes = ROUTES }, { address = "/" })

        assert(shows(renderer, "home"), "it opened where it was asked to")

        runtime:setAddress("/items/4")
        runtime:commit()

        assert(shows(renderer, "item 4"), "a link that arrives later is the screen shown, got " .. said(renderer))
        assert(shows(renderer, "home"), "and what was open is still under it, so there is a way back")
    end

    -- A screen goes somewhere by naming it, from anywhere in the tree.
    do
        local Deep = gui.component({
            name = "Deep",
            render = function(self)
                local route = gui.navigation:read(self)

                return gui.Pressable {
                    accessibilityLabel = "open",
                    onPress = function() route.go("/items/8") end,
                    gui.Text { text = "at " .. route.path },
                }
            end,
        })

        local routes = {
            { path = "/", title = "Home", render = function() return Deep {} end },
            {
                path = "/items/:id",
                render = function(where) return gui.Text { text = "item " .. where.params.id } end,
            },
        }

        local runtime, renderer = start(gui.Router { routes = routes }, { address = "/" })

        assert(shows(renderer, "at /"), "a screen is told where it is, got " .. said(renderer))

        local pressable = nil

        for _, node in pairs(renderer.nodes) do
            if node.type == "pressable" then
                pressable = node
            end
        end

        runtime:dispatch(pressable.id, "onPress", nil)
        runtime:commit()

        assert(shows(renderer, "item 8"), "and goes where it named, got " .. said(renderer))
        assert(runtime:address() == "/items/8", "the application knows where it is, it says " .. runtime:address())
    end

    -- An address nothing answers lands on what the router was given for that, rather than on nothing.
    do
        local _, renderer = start(
            gui.Router {
                routes = ROUTES,
                notFound = function(where) return gui.Text { text = "no " .. where.path } end,
            },
            { address = "/nowhere" }
        )

        assert(shows(renderer, "no /nowhere"), "what nothing answers is answered, got " .. said(renderer))
    end

    -- A screen with no way back never shows one, including in the commits a pop passes through.
    --
    -- Going back holds the screen that was left for as long as its exit takes, so the tree carries two
    -- screens for a few frames while one of them travels out. A way back worked out from what is on
    -- screen rather than from where the reader is appears for exactly those frames and goes again, which
    -- is a back button flashing on the first screen of an application every time somebody swipes.
    do
        local runtime, renderer = start(gui.Router { routes = ROUTES }, { address = "/" })

        local function ways()
            local found = 0

            for _, node in pairs(renderer.nodes) do
                if node.props.accessibilityLabel == "Back" then
                    found = found + 1
                end
            end

            return found
        end

        assert(ways() == 0, "the first screen offers no way back, it offered " .. ways())

        runtime:setAddress("/items/3")
        runtime:commit()

        assert(ways() == 1, "a screen the reader went to offers one, it offered " .. ways())

        runtime:goBack()

        for _ = 1, 6 do
            runtime:commit()

            assert(ways() == 0, "and no commit a pop passes through offers one, one offered " .. ways())

            if not runtime:needsCommit() then
                break
            end
        end
    end

    -- A component declared inside a render is a new kind on every commit, which draws nothing at all
    -- and says nothing about why. It is refused where it is written instead.
    do
        local Bad = gui.component({
            name = "Bad",
            render = function()
                return gui.component({ name = "Inner", render = function() return gui.Text { text = "x" } end }) {}
            end,
        })

        local renderer = gui.headless()
        local ok, problem = pcall(function()
            local app = gui.start(Bad {}, renderer, { size = { width = 100, height = 100 } })
            app:commit()
        end)

        assert(not ok, "a component declared inside a render is refused")
        assert(tostring(problem):find("declared once", 1, true) ~= nil,
            "and says what to do instead, it said " .. tostring(problem))
    end

    -- A screen reads the address it was opened at, which is not the one the router is on while it leaves.
    --
    -- One provider for the whole stack hands every screen the top of the trail, so going back rendered
    -- the screen being taken off against the route it was leaving for. A screen written to draw its own
    -- parameter found none and the commit threw, which takes the application down rather than the screen.
    do
        local Item = gui.component({
            name = "ContextItem",
            render = function(self)
                local route = gui.navigation:read(self)

                return gui.View {
                    gui.Text { text = "item " .. tostring(route.params.id) },
                    gui.Pressable {
                        accessibilityLabel = "Back",
                        onPress = function() route.back() end,
                        gui.Text { text = "back" },
                    },
                }
            end,
        })

        local Home = gui.component({
            name = "ContextHome",
            render = function(self)
                local route = gui.navigation:read(self)

                return gui.Pressable {
                    accessibilityLabel = "Open",
                    onPress = function() route.go("/items/kettle") end,
                    gui.Text { text = "home at " .. route.path },
                }
            end,
        })

        local routes = {
            { path = "/", title = "Home", render = function() return Home {} end },
            { path = "/items/:id", title = "Item", render = function() return Item {} end },
        }

        -- The router sits inside a stack, which is where one lives: a screen of an application, not the
        -- application. What a stack keeps mounted under the screen on top is what this is about.
        local runtime, renderer = start(gui.NavigationStack {
            screens = {
                { key = "index", title = "Index", content = gui.Text { text = "index" } },
                { key = "routes", title = "Addresses", content = gui.Router { routes = routes } },
            },
            index = 2,
            onIndexChange = function() end,
        }, { address = "/" })

        for _, node in pairs(renderer.nodes) do
            if node.type == "pressable" and node.props.accessibilityLabel == "Open" then
                node.props.onPress()
            end
        end

        runtime:commit()
        assert(shows(renderer, "item kettle"), "the screen draws its own parameter, got " .. said(renderer))

        -- The screen a stack keeps under the one on top is still at the address it was opened at.
        assert(shows(renderer, "home at /,"), "the screen below reads its own address, got " .. said(renderer))

        local left = false

        for _, node in pairs(renderer.nodes) do
            if node.type == "pressable" and node.props.accessibilityLabel == "Back" then
                node.props.onPress()
                left = true
            end
        end

        assert(left, "the screen offers a way back")

        for _ = 1, 4 do
            if not runtime:needsCommit() then
                break
            end

            runtime:commit()
        end

        assert(shows(renderer, "home"), "going back lands on the screen below, got " .. said(renderer))
        assert(not shows(renderer, "item nil"), "and the screen it took off never drew against the new route")
    end

    print("gui.router ok")
end)
