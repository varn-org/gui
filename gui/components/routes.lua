local animation = require("gui.style.animation")
local bars = require("gui.components.bars")
local chrome = require("gui.style.chrome")
local component = require("gui.component")
local content = require("gui.components.content")
local environment = require("gui.environment")
local navigation = require("gui.navigation")
local parts = require("gui.controls.parts")
local presentation = require("gui.components.presentation")
local routing = require("gui.routing")
local structure = require("gui.components.structure")
local support = require("gui.components.support")
local visibility = require("gui.visibility")

local M = {}

local View = structure.View
local Text = content.Text

--- Where a screen sits while it is going, which is over the one it is uncovering.
local COVERING = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0 }

--- Where a screen sits once another one has been pushed over it, which is exactly where it was.
---
--- It is held rather than shown. A screen is not required to be opaque, and one that is not lets what is
--- under it through: pushing a product over a grid drew the grid's own rows through the product's price.
--- Nothing below the top is drawn, so what shows is what the top screen draws and nothing else.
local COVERED = { position = "absolute", top = 0, right = 0, bottom = 0, left = 0, opacity = 0 }

--- Answers what the caller gave as the content of a screen, ready to be a child.
---
--- A caller writes either an element or a string, and a string is what a caller writing a demo reaches
--- for first, so it is turned into the label it obviously means.
local function contentOf(value)
    if type(value) == "string" then
        return Text { text = value }
    end

    return value
end

--- Answers the states a move is made of, or nothing at all when the move is to arrive with no animation.
local function states(declared)
    local pair = animation.states(declared)

    if next(pair.enter) == nil and next(pair.exit) == nil then
        return nil
    end

    return pair
end

--- The screen at the top of a stack, over a bar carrying its title and the way back to the one beneath.
---
--- The first screen a stack ever shows is drawn where it is rather than arriving, since it came from
--- nowhere and there is nothing behind it for it to arrive over. That is what every platform does, and a
--- caller who wants the opening screen to arrive as well says `animatesFirstScreen`.
---
--- `transition` chooses the move every push is drawn with, `"none"` among them, and a screen may carry
--- one of its own for the push that puts it on top.
M.NavigationStack = support.component("NavigationStack", {
    props = { "screens", "index", "title", "backTitle", "hidesBar", "barStyle", "trailing",
        "transition", "animatesFirstScreen", "largeTitle", "scrolled" },
    events = { "onPop", "onIndexChange", "onBack" },
    defaults = { index = 1, hidesBar = false, animatesFirstScreen = false, largeTitle = false, scrolled = 0 },
    validate = function(spec)
        if type(spec.screens) ~= "table" or #spec.screens == 0 then
            return "needs a screens list with at least one entry"
        end
    end,
}, component.define({
    name = "NavigationStack",
    state = { leaving = nil, going = false },

    --- Holds the screen that has just been left so it can be seen going, rather than cut.
    ---
    --- A caller derives its screens from what it is showing, so the one that was on top is gone from the
    --- list by the time the stack renders again and there is nothing left to draw leaving. The stack is
    --- the only thing that saw it, so it is the one that keeps it.
    onUpdate = function(self, before)
        -- It is put back where it was and told to go on the commit after, since a node born in the state
        -- it is leaving in has never been anywhere else and there is nothing to animate.
        if self.state.leaving ~= nil and not self.state.going then
            self:setState({ going = true })
            return
        end

        local depth = math.max(1, math.min(#self.props.screens, self.props.index or 1))
        local was = math.max(1, math.min(#before.screens, before.index or 1))

        if depth >= was then
            return
        end

        local timing = animation.transition({ duration = "fast", easing = "easeOut" })

        self:setState({ leaving = before.screens[was], going = false })
        self:after(timing.duration * 2, function() self:setState({ leaving = component.none }) end)
    end,

    pop = function(self)
        -- A stack at its first screen may still have somewhere to go: the detail column of a split view
        -- with no room for both is one, and so is any stack that is not the whole of the application.
        if (self.props.index or 1) <= 1 then
            if self.props.onBack == nil then
                return false
            end

            self.props.onBack()
            return true
        end

        local index = (self.props.index or 1) - 1

        if self.props.onPop ~= nil then
            self.props.onPop()
        end

        if self.props.onIndexChange ~= nil then
            self.props.onIndexChange(index)
        end

        return true
    end,

    --- The way back, which carries the previous screen's name on a platform that names it.
    back = function(self, look, index)
        if index < 2 and self.props.onBack == nil then
            return nil
        end

        local behind = index > 1 and self.props.screens[index - 1].title or nil
        local named = self.props.backTitle or behind or "Back"

        return {
            key = "back",
            icon = look.back.symbol,
            size = 20,
            label = look.back.labelled and named or nil,
            accessibilityLabel = self.props.backTitle or "Back",
            onPress = function() self:pop() end,
        }
    end,

    --- The bar the screen is read under, which is the same bar an application draws for itself.
    Bar = function(self, screen, index)
        local surface = environment:read(self)
        local look = chrome.bar(surface.platform, surface.breakpoint)
        local leading = self:back(look, index)

        return bars.AppBar {
            key = "bar",
            title = screen.title or self.props.title or "",
            titleView = screen.titleView,
            leading = leading ~= nil and { leading } or nil,
            trailing = screen.trailing or self.props.trailing,
            largeTitle = screen.largeTitle == true or (screen.largeTitle == nil and self.props.largeTitle),
            scrolled = screen.scrolled or self.props.scrolled,
            style = screen.barStyle or self.props.barStyle,
        }
    end,

    --- Answers the move a screen is pushed with, which the screen may choose for itself.
    moving = function(self, screen, look)
        if screen.transition ~= nil then
            return screen.transition
        end

        if self.props.transition ~= nil then
            return self.props.transition
        end

        return look.push
    end,

    render = function(self)
        local screens = self.props.screens
        local index = math.max(1, math.min(#screens, self.props.index or 1))
        local screen = screens[index]
        local surface = environment:read(self)
        local look = chrome.bar(surface.platform, surface.breakpoint)

        -- A screen arrives when it was not there the last time the stack drew, which is what a push is.
        -- The first screen a stack ever shows came from nowhere and there is nothing behind it for it to
        -- arrive over, so it is drawn where it is, the way every platform draws one.
        local drawn = self.drawn
        local showing = {}
        local children = {}

        -- A screen that draws a header of its own says so for itself, since an application is rarely all
        -- one or all the other: a first screen carrying its own band and a detail screen under the
        -- platform's bar is the shape nearly every application on a phone actually has.
        local bare = screen.hidesBar

        if bare == nil then
            bare = self.props.hidesBar
        end

        if not bare then
            children[#children + 1] = self:Bar(screen, index)
        end

        -- Every screen in the stack stays where it is and the top one covers the rest.
        --
        -- Rendering only the top one unmounts everything under it, so a reader coming back arrives at a
        -- screen that has never been used: a list back at the top, a field emptied, a form forgetting
        -- what it was told. A platform keeps its whole stack alive and shows the top of it, and a screen
        -- that is still there is also what a push slides over.
        local stack = { key = "screens", style = { grow = 1 } }
        local moving = { duration = "fast", easing = "easeOut" }
        local pair = states(self:moving(screen, look))

        for at = 1, index do
            local top = at == index
            local named = tostring(screens[at].key or at)
            local enter = nil

            showing[named] = true

            local arriving = drawn ~= nil and drawn[named] == nil

            if drawn == nil then
                arriving = self.props.animatesFirstScreen
            end

            if top and arriving and pair ~= nil then
                enter = pair.enter
            end

            stack[#stack + 1] = View {
                key = "screen:" .. named,
                style = top and { grow = 1 } or COVERED,
                pointerEvents = top and "auto" or "none",
                transition = top and moving or nil,
                enter = enter,
                visibility.Showing { value = top, contentOf(screens[at].content) },
            }
        end

        -- The screen that was left goes back the way it came, over the one it uncovers.
        if self.state.leaving ~= nil then
            local left = states(self:moving(self.state.leaving, look))

            stack[#stack + 1] = View {
                key = "leaving:" .. tostring(self.state.leaving.key or index),
                style = { COVERING, self.state.going and left ~= nil and left.exit or nil },
                transition = moving,
                pointerEvents = "none",
                contentOf(self.state.leaving.content),
            }
        end

        children[#children + 1] = View(stack)
        self.drawn = showing

        return View { style = { { grow = 1 }, self.props.style }, table.unpack(children) }
    end,
}))

--- The screens an address names, and the way from one to another.
---
--- Nothing outside an application can name a screen when navigation is state a component holds: a deep
--- link, an app link and a web address all land on whatever the entry point happens to draw. A router is
--- driven by the address instead, which the host reports at start and while the application runs, so the
--- three of them land on the screen they name and a browser keeps its own history in step.
M.Router = support.component("Router", {
    props = { "routes", "notFound", "transition", "animatesFirstScreen" },
    events = { "onChange" },
    defaults = { animatesFirstScreen = false },
    validate = function(spec)
        if type(spec.routes) ~= "table" or #spec.routes == 0 then
            return "needs a routes list with at least one entry"
        end

        for index = 1, #spec.routes do
            local route = spec.routes[index]

            if type(route.path) ~= "string" then
                return "a route names the path it answers, got a " .. type(route.path)
            end

            if type(route.render) ~= "function" then
                return "the route for " .. route.path .. " is drawn by a function, got a " .. type(route.render)
            end
        end
    end,
}, component.define({
    name = "Router",

    --- Where the reader has been, which is what a way back is made of.
    ---
    --- The address is where the application is and the trail is how it got there, so a link followed
    --- from outside arrives on top of what was already open rather than in place of it.
    state = { trail = nil },

    --- Answers where a screen would land, which is what a component asks before it goes there.
    where = function(self, given)
        local route, params, parsed = routing.resolve(self.props.routes, given)

        return {
            route = route,
            address = given,
            path = parsed.path,
            params = params or {},
            query = parsed.query,
            scheme = parsed.scheme,
            host = parsed.host,
        }
    end,

    --- Where the reader has been, with a link arriving from outside landing on top of it.
    ---
    --- The router sets the address itself as well, and it does that while its own state change is still
    --- queued, so the render in between reads the trail from before against the address from after. Left
    --- to work a push out of the difference it put the screen a pop had just taken off back on top, and
    --- the trail grew by one on every round trip until the screens were drawn over each other. The trail
    --- this router drove is written where a render sees it at once rather than a commit later, and it
    --- stands until the address moves somewhere it did not drive, which is what a link arriving is.
    trailOf = function(self)
        local reported = environment:peek(self).address

        if self.drove ~= nil and self.drove[#self.drove] == reported then
            return { table.unpack(self.drove) }
        end

        local trail = self.state.trail or { reported }

        if trail[#trail] ~= reported then
            trail = { table.unpack(trail) }
            trail[#trail + 1] = reported
        end

        return trail
    end,

    --- Goes where this router decided, which is every move that is not a link arriving from outside.
    drive = function(self, trail, mode)
        self.drove = trail
        self:setState({ trail = trail })
        self.scheduler.navigate(trail[#trail], mode)
    end,

    go = function(self, given)
        local trail = self:trailOf()

        trail[#trail + 1] = given
        self:drive(trail, "push")
    end,

    replace = function(self, given)
        local trail = self:trailOf()

        trail[#trail] = given
        self:drive(trail, "replace")
    end,

    back = function(self)
        local trail = self:trailOf()

        if #trail < 2 then
            return false
        end

        table.remove(trail)
        self:drive(trail, "back")
        return true
    end,

    --- Keeps the trail the render worked out, so what was open stays under what a link opened.
    onUpdate = function(self)
        local trail = self:trailOf()

        if self.state.trail == nil or self.state.trail[#self.state.trail] ~= trail[#trail] then
            self:setState({ trail = trail })
        end
    end,

    onMount = function(self)
        local trail = self:trailOf()

        self.drove = trail
        self:setState({ trail = trail })
    end,

    render = function(self)
        -- Reading it here is what makes a link that arrives later reach this component at all.
        environment:read(self)

        local trail = self:trailOf()
        local screens = {}

        local going = {
            go = function(given) self:go(given) end,
            replace = function(given) self:replace(given) end,
            back = function() return self:back() end,
        }

        for index = 1, #trail do
            local where = self:where(trail[index])
            local title = nil

            if where.route ~= nil then
                title = where.route.title
            end

            if type(title) == "function" then
                title = title(where)
            end

            screens[index] = {
                key = trail[index],
                title = title or "",

                -- A screen reads the address it was opened at rather than the one the router is on now.
                -- Sharing one provider hands every screen the top of the trail, so the screen a pop is
                -- taking off renders once against the route it is leaving for, and a screen written to
                -- read its own parameters finds none: the pop threw where the screen drew its own id.
                content = navigation.Provider {
                    value = {
                        address = where.address,
                        path = where.path,
                        params = where.params,
                        query = where.query,
                        go = going.go,
                        replace = going.replace,
                        back = going.back,
                    },

                    self:drawn(where),
                },
            }
        end

        return M.NavigationStack {
            screens = screens,
            index = #screens,
            transition = self.props.transition,
            animatesFirstScreen = self.props.animatesFirstScreen,
            onIndexChange = function() self:back() end,
        }
    end,

    --- Answers what a route draws, or what the router draws for an address none of them answers.
    drawn = function(self, where)
        if where.route ~= nil then
            return where.route.render(where)
        end

        if self.props.notFound ~= nil then
            return self.props.notFound(where)
        end

        return Text { text = "Nothing answers " .. where.path }
    end,
}))

--- A panel that slides in from an edge over the rest of the screen, with the screen dimmed behind it.
M.Drawer = support.component("Drawer", {
    props = { "open", "side", "width", "content" },
    events = { "onClose", "onWillShow", "onShow", "onWillHide", "onHide" },
    defaults = { open = false, side = "left", width = 280 },
    validate = function(spec)
        local choices = { "left", "right" }
        if not support.oneOf(spec.side, choices) then
            return support.expected("side", spec.side, choices)
        end
    end,
}, component.define({
    name = "Drawer",

    render = function(self)
        local panel = { position = "absolute", top = 0, bottom = 0, width = self.props.width,
            background = "elevated", shadow = "lg" }

        panel[self.props.side] = 0

        local travel = self.props.side == "right" and presentation.fromRight or presentation.fromLeft

        return presentation.over(parts.themeOf(self), self.props.open, function()
            if self.props.onClose ~= nil then
                self.props.onClose()
            end
        end, travel, panel, { contentOf(self.props.content) }, self.props)
    end,
}))

return M
