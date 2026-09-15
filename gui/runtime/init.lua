local cache = require("gui.tools.cache")
local component = require("gui.component")
local diff = require("gui.diff")
local element = require("gui.element")
local environment = require("gui.environment")
local flex = require("gui.layout.flex")
local natural = require("gui.layout.natural")
local protocol = require("gui.bridge.protocol")
local reads = require("gui.runtime.reads")
local ref = require("gui.ref")
local controlTheme = require("gui.controls.theme")
local controls = require("gui.controls")
local themes = require("gui.style.theme")
local theming = require("gui.theming")

local M = {}

local Runtime = {}
Runtime.__index = Runtime

-- The runtime is one object, and what it does falls into contexts of its own. Each of those is a file
-- that adds its methods here rather than a second thing beside the runtime, since a picture resolved on
-- the way out, a style resolved with it and a surface lifted clear of the keyboard are all one commit.
require("gui.runtime.sources")(Runtime)
require("gui.runtime.styles")(Runtime)
require("gui.runtime.keyboard")(Runtime)

--- How many measured strings are held at once, which is what a screen with a clock on it keeps adding to.
---
--- A cache smaller than one screen answers nothing. An index of fifty rows asks close to five hundred
--- questions — a title and a summary each, at the several widths a layout settles through — so held at
--- five hundred it filled on the way in, gave up the older half, and measured the whole screen again on
--- the way back. Each entry is a key and two numbers, so the room this takes is nothing beside the third
--- of a second it was costing every time a reader left a screen and came back to it.
local MEASURED = 4096

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--- Runs what a commit owes, reporting a failure rather than letting one stop the rest.
---
--- These are the caller's own `onMount`, `onUpdate` and `onLayout`. What they do is not the runtime's
--- to trust, and one that throws must not take the application with it or leave every callback queued
--- behind it unrun.
local function runCallbacks(pending, report)
    for index = 1, #pending do
        local ok, problem = pcall(pending[index])

        if not ok then
            report("a callback after the commit failed: " .. tostring(problem))
        end
    end
end

--- How many commits in a row may be asked for from inside one before it is a loop rather than settling.
local CASCADE = 50

--- Answers whether a value is a length the tree can be laid out against.
---
--- What a host reports is not a caller's careful table: a surface, an inset and the keyboard all arrive
--- from a platform, and one that answers a width as a word or as nothing at all lays every box out
--- against it — the failure then surfaces inside the theme, comparing a number with whatever came.
local function measurable(value)
    return finite(value) and value >= 0
end

--- Answers whether a frame is made of numbers a renderer can be given.
local function placeable(frame)
    return finite(frame.x) and finite(frame.y) and finite(frame.width) and finite(frame.height)
end

--- Lays a scrolling view's children out under its content style rather than under its own.
---
--- A scrolling view is two things at once: a viewport, sized by its own style, and the content that
--- scrolls inside it. Its style sizes the viewport and `contentStyle` arranges what is in it, so a row
--- of chips flows along the axis it scrolls rather than stacking down the one it does not.
local function arrangeContent(type, props, style, resolve)
    if type ~= "scroll" or props.contentStyle == nil then
        return style
    end

    local content = resolve(props.contentStyle)
    local merged = {}

    for key, value in pairs(style) do
        merged[key] = value
    end

    for index = 1, #reads.arranging do
        local name = reads.arranging[index]
        if content[name] ~= nil then
            merged[name] = content[name]
        end
    end

    return merged
end

--- Turns the insets the platform reports into padding on the node that asked to avoid them.
---
--- A safe area and the keyboard are layout inputs rather than a platform check, so a screen that
--- avoids the notch is written once and reads the same on a device with none.
local function avoid(type, props, style, environment)
    if type ~= "safearea" and type ~= "keyboardavoiding" then
        return style
    end

    -- The resolved style is cached by identity, so the insets go onto a copy of it.
    local inset = {}
    for key, value in pairs(style) do
        inset[key] = value
    end

    if type == "safearea" then
        local edges = props.edges or { "top", "right", "bottom", "left" }

        for index = 1, #edges do
            local edge = reads.edges[edges[index]]
            inset[edge] = (inset[edge] or 0) + environment.insets[edges[index]]
        end

        return inset
    end

    if props.behavior ~= "none" and environment.keyboard > 0 then
        local room = math.max(0, environment.keyboard - (props.offset or 0))
        inset.paddingBottom = (inset.paddingBottom or 0) + room
    end

    return inset
end

--- Answers whether a size a type declares for itself says the same thing it said last time.
local function sameNatural(before, after)
    if before == after then
        return true
    end

    if before == nil or after == nil then
        return false
    end

    return before.width == after.width and before.height == after.height
        and before.minWidth == after.minWidth and before.minHeight == after.minHeight
        and before.padding == after.padding
end

--- Answers the layout node a host contributes, kept on the host across commits.
---
--- A handler is a fresh closure on every render while the layout is unmoved by it, so what the engine
--- reads is compared rather than the props table it came out of. The revision is what tells the engine
--- which boxes it may keep, and it moves only when one of those inputs does.
function Runtime:layoutNodeOf(node, hosts, scrolling, layers)
    local host = diff.hostOf(node)
    local props = host.props
    local built = host.layout

    if built == nil then
        built = { id = host.id, children = {}, revision = 0 }
        host.layout = built
    end

    local declared = self:styleOf(props.style, host.wearing)

    -- A composed style is a fresh table on every render even when it says exactly the same thing, so
    -- comparing it by identity alone would move the revision and re-emit a frame for every node under
    -- a component that builds its style out of two.
    if built.declared ~= declared and diff.sameValue(built.declared, declared) then
        declared = built.declared
    end

    local text = natural.textOf(host.type, props)
    local size = natural.sizeOf(host.type, props, self.controller)
    local scrolls = natural.scrollAxisOf(host.type, props)

    if built.generation ~= self.generation
        or built.declared ~= declared
        or built.text ~= text
        or built.scrolls ~= scrolls
        or built.lines ~= props.numberOfLines
        or built.measure ~= props.measure
        or built.contentStyle ~= props.contentStyle
        or built.edges ~= props.edges
        or built.behavior ~= props.behavior
        or built.offset ~= props.offset
        or not sameNatural(built.natural, size) then
        local style = function(value) return self:styleOf(value, host.wearing) end

        built.generation = self.generation
        built.declared = declared
        built.text = text
        built.natural = size
        built.scrolls = scrolls
        built.lines = props.numberOfLines
        built.measure = props.measure
        built.contentStyle = props.contentStyle
        built.edges = props.edges
        built.behavior = props.behavior
        built.offset = props.offset
        built.style = avoid(host.type, props, arrangeContent(host.type, props, declared, style), self.environment)
        built.revision = built.revision + 1
    end

    hosts[host.id] = host

    if host.type == "scroll" then
        scrolling[#scrolling + 1] = built
    end

    local children = built.children
    local count = 0

    for index = 1, #host.children do
        local child = self:layoutNodeOf(host.children[index], hosts, scrolling, layers)

        -- What a portal holds is laid out against the surface rather than against the box it was
        -- written in, so it leaves the tree here and is worked out as a tree of its own.
        if diff.hostOf(host.children[index]).type == "layer" then
            layers[#layers + 1] = child
        else
            count = count + 1

            if children[count] ~= child then
                children[count] = child
                built.revision = built.revision + 1
            end
        end
    end

    for index = #children, count + 1, -1 do
        children[index] = nil
        built.revision = built.revision + 1
    end

    return built
end

function Runtime:markDirty(node)
    self.dirty[node] = true

    -- What a commit's own callbacks ask for is what a screen that never settles is made of.
    if self.settling then
        self.asked = node.type ~= nil and (node.type.name or "a component") or "a component"
    end

    self:schedule()
end

--- Asks the host to arrange a commit, which it does once however often it is asked.
function Runtime:arm()
    if not self.scheduled or self.committing or self.arranged or self.arrange == nil then
        return
    end

    self.arranged = true
    self.arrange(self)
end

--- Marks a commit as needed.
---
--- A commit that is running is still recorded, since a component notified by another one's render
--- changes its state during the build and would otherwise sit dirty with nothing coming for it.
--- Asks for a commit, which a runtime that has been taken down never does.
---
--- A picture that lands, a timer that fires and an event a host sends all arrive whenever they arrive,
--- and a tree that has been unmounted has nothing left to commit: building one from a root that is not
--- there reports a failure a reader can do nothing about, once per thing that was still on its way.
function Runtime:schedule()
    if self.stopped then
        return
    end

    self.scheduled = true
    self:arm()
end

--- Answers whether a commit is waiting, which is what a host checks each tick.
function Runtime:needsCommit()
    return self.scheduled
end

function Runtime:emitFrames(ops, pending)
    if self.root == nil or self.size == nil then
        return
    end

    local breakpoint = self.theme:breakpoint(self.size.width)

    if self.breakpoint ~= breakpoint then
        self.breakpoint = breakpoint
        self.generation = self.generation + 1
    end

    local hosts = {}
    local scrolling = {}
    local layers = {}
    local tree = self:layoutNodeOf(self.root, hosts, scrolling, layers)

    local surface = {
        width = self.size.width,
        height = self.size.height,
        measureText = self.measurer,
    }

    local moved = flex.compute(tree, surface)

    -- Every layer is the whole surface, which is what makes an overlay cover the application rather
    -- than the box it was written in.
    for index = 1, #layers do
        for node, frame in pairs(flex.compute(layers[index], surface)) do
            moved[node] = frame
        end
    end

    -- The layout answers what moved, and a caller that reveals a field or scrolls to a row asks about a
    -- node the layout had no reason to touch, so every frame is kept and only the moved ones are sent.
    local frames = {}

    for id, host in pairs(hosts) do
        frames[id] = flex.frameOf(host.layout)
    end

    self.frames = frames

    for node, frame in pairs(moved) do
        -- A number json cannot carry crosses as null, which a renderer reads as nothing and lays the
        -- node out at nowhere: a screen that vanishes with no error anywhere. It is reported and the
        -- node keeps the frame it had.
        if not placeable(frame) then
            self:report("a frame worked out as something that is not a number, on a "
                .. tostring(hosts[node.id].type))
            goto continue
        end

        ops[#ops + 1] = {
            op = "frame",
            id = node.id,
            x = frame.x,
            y = frame.y,
            width = frame.width,
            height = frame.height,
        }

        local onLayout = hosts[node.id].props.onLayout

        if type(onLayout) == "function" then
            local reported = { x = frame.x, y = frame.y, width = frame.width, height = frame.height }
            pending[#pending + 1] = function() onLayout(reported) end
        end

        ::continue::
    end

    self:emitContentExtents(scrolling, hosts, ops)
end

--- Tells a scrolling node how far its content reaches, which only the layout engine knows.
---
--- A list works this out for itself, since it knows every entry rather than only the realised ones. A
--- plain scrolling view does not, so the extent is measured here from the frames its children were
--- given and a renderer is spared having to work anything out.
function Runtime:emitContentExtents(scrolling, hosts, ops)
    for position = 1, #scrolling do
        local node = scrolling[position]
        local horizontal = hosts[node.id].props.horizontal == true
        local extent = 0

        for index = 1, #node.children do
            local frame = flex.frameOf(node.children[index])

            if frame ~= nil then
                extent = math.max(extent, horizontal and frame.x + frame.width or frame.y + frame.height)
            end
        end

        -- A surface the keyboard is over keeps the room it lost, which is the inset every platform adds
        -- for one. Without it a screen that fits has nothing to scroll, so a field under the keyboard
        -- can never be lifted clear of it and one that is lifted has nowhere to go back to.
        if not horizontal then
            extent = extent + self:coveredBy(hosts[node.id])
        end

        if self.extents[node.id] ~= extent then
            self.extents[node.id] = extent
            ops[#ops + 1] = { op = "update", id = node.id, props = { contentExtent = extent } }
        end

        self:holdInside(node.id, extent)
    end
end

--- Answers the control theme a caller gave, or the platform's own controls when they named none.
local function controlsOf(chosen)
    if chosen == nil then
        return controls.native
    end

    if not controlTheme.isTheme(chosen) then
        error("controls are what gui.controls.define() answers, got a " .. type(chosen), 2)
    end

    return chosen
end

--- Answers the look a caller gave, which is a look, one theme pinned on both sides, or the built-in one.
local function lookOf(theme)
    if theme == nil then
        return themes.builtin
    end

    if themes.isLook(theme) then
        return theme
    end

    if type(theme) ~= "table" or type(theme.color) ~= "function" then
        error("a theme is what gui.theme.define() or gui.theme.create() answers, got a " .. type(theme), 2)
    end

    return { light = theme, dark = theme, name = "a theme", of = function(self) return theme end }
end

--- Takes the platform's own way back, which the innermost stack on screen answers.
---
--- A swipe from the leading edge on iOS and the back key on Android are the way people leave a screen,
--- and a tree that ignored them left a reader stuck wherever they had got to.
function Runtime:goBack()
    if self.stopped then
        return false
    end

    local offered = {}
    self:collectPops(self.root, 0, offered)

    table.sort(offered, function(first, second) return first.depth > second.depth end)

    -- The innermost is asked first, and one with nowhere left to go declines so the one above it
    -- takes it. Without that a stack already at its first screen swallows every back press for ever.
    for index = 1, #offered do
        local took = false

        local ok, problem = pcall(function() took = offered[index].pop() ~= false end)

        if not ok then
            self:report("a handler for onPop failed: " .. tostring(problem))
            return false
        end

        if took then
            return true
        end
    end

    return false
end

--- Gathers every way back on screen, with how deep each one sits.
function Runtime:collectPops(node, depth, into)
    if node == nil then
        return
    end

    if node.kind == "component" and node.instance ~= nil and type(node.instance.pop) == "function" then
        into[#into + 1] = { depth = depth, pop = function() return node.instance:pop() end }
    end

    local children = node.child ~= nil and { node.child } or node.children

    for index = 1, #(children or {}) do
        self:collectPops(children[index], depth + 1, into)
    end
end

--- Answers the host a node sits under, which is what a frame is measured against.
local function hostAbove(node)
    local parent = node.parentNode

    while parent ~= nil and parent.kind ~= "host" do
        parent = parent.parentNode
    end

    return parent
end

--- Answers whether the reader can see any part of a node, which is what being in view means.
---
--- The rectangle is carried up through every surface between the node and the screen and cut by each of
--- them in turn, since a box sitting perfectly inside a list that is itself scrolled out of sight is not
--- visible. Measuring against the screen alone answers yes for it, which is the whole difficulty.
function Runtime:inView(node)
    local frame = self.frames[node.id]

    if frame == nil or self.size == nil then
        return false
    end

    local top = frame.y
    local bottom = frame.y + frame.height
    local walk = hostAbove(node)

    while walk ~= nil do
        local box = self.frames[walk.id]

        if natural.scrolling[walk.type] then
            local offset = self.offsets[walk.id] or 0
            local height = box ~= nil and box.height or self.size.height

            top = top - offset
            bottom = bottom - offset

            if bottom <= 0 or top >= height then
                return false
            end

            top = math.max(top, 0)
            bottom = math.min(bottom, height)
        end

        if box ~= nil then
            top = top + box.y
            bottom = bottom + box.y
        end

        walk = hostAbove(walk)
    end

    return bottom > 0 and top < self.size.height
end

--- Tells every box watching for it that it came into view or went out of it, once the commit is over.
---
--- A handler is free to change state and a commit may not start inside one, so what is owed is queued
--- and run afterwards, which is what a list already does with the entries that enter its window.
function Runtime:reportViews(pending)
    if self.watching == 0 then
        return
    end

    for id in pairs(self.seen) do
        local node = self.byId[id]

        if node == nil then
            self.seen[id] = nil
        else
            local inside = self:inView(node)

            if inside ~= self.seen[id].inside then
                self.seen[id].inside = inside

                local handler = node.props[inside and "onEnterView" or "onExitView"]

                if type(handler) == "function" then
                    pending[#pending + 1] = function() handler() end
                end
            end
        end
    end
end

--- Tells whoever is watching what a scroll changed, which happens outside a commit rather than inside one.
function Runtime:reportScrolled()
    if self.watching == 0 then
        return
    end

    local pending = {}
    self:reportViews(pending)

    for index = 1, #pending do
        local ok, problem = pcall(pending[index])

        if not ok then
            self:report("a handler for coming into view failed: " .. tostring(problem))
        end
    end
end

--- Holds work a component asked to happen later while the application is away, answering whether it did.
---
--- A platform suspends an application outright, keeps a window running behind another, or throttles a
--- hidden tab without stopping it, so the same timer fires three different ways. What it does here is
--- one way: it waits, and it happens on the way back.
function Runtime:hold(work)
    if self.environment.state == "active" or self.stopped then
        return false
    end

    self.held[#self.held + 1] = work
    return true
end

--- Runs everything that was waiting for the application to come back.
function Runtime:releaseHeld()
    local waiting = self.held
    self.held = {}

    for index = 1, #waiting do
        local ok, problem = pcall(waiting[index])

        if not ok then
            self:report("something held while the application was away failed: " .. tostring(problem))
        end
    end
end

--- Gives back everything the engine is holding that it can work out again, which is what a platform asks
--- for when it is about to end the application that will not.
---
--- What is given back is what can be rebuilt: a measurement is asked for again the next time a string is
--- laid out, and a picture is fetched again the next time it is drawn. Nothing a screen put there goes.
function Runtime:giveBack()
    if self.stopped then
        return
    end

    self.measurements:clear()
    self.extents = {}

    if self.pictures ~= nil then
        self.pictures:clear()
    end
end

--- Walks every component the tree holds, which is what a moment belonging to the whole application needs.
function Runtime:eachInstance(node, visit)
    if node == nil then
        return
    end

    if node.kind == "component" and node.instance ~= nil then
        visit(node.instance)
    end

    local children = node.child ~= nil and { node.child } or node.children

    for index = 1, #(children or {}) do
        self:eachInstance(children[index], visit)
    end
end

--- Takes the application from one state to another, telling every component and holding what is owed.
---
--- A platform suspends an application outright, keeps it running with its window behind another, or
--- throttles it to nothing, and which of those happens depends on the platform rather than on the tree.
--- So the engine makes the three agree: what it owns stops when the application goes away and carries on
--- when it comes back, and a component is told at both moments and need not know which platform it is.
function Runtime:setLifecycle(state)
    if self.stopped or self.environment.state == state then
        return
    end

    local away = state ~= "active"
    local was = self.environment.state ~= "active"

    self.environment.state = state
    self.surface.state = state

    self:renderReaders()
    self:schedule()

    if away == was then
        return
    end

    if not away then
        self:releaseHeld()
    end

    self:eachInstance(self.root, function(instance)
        -- A component may declare one of the two and not the other, and an `and`/`or` with nothing in
        -- the middle reaches for the wrong one: a screen would be told it had come back as it went away.
        local moment = instance.onResume

        if away then
            moment = instance.onPause
        end

        if moment ~= nil then
            local ok, problem = pcall(moment, instance, state)

            if not ok then
                self:report("a handler for " .. (away and "onPause" or "onResume") .. " failed: " .. tostring(problem))
            end
        end
    end)
end

--- Runs a handler the way a dispatched one is run, so what it does is reported rather than trusted.
function Runtime:runHandler(name, handler)
    local ok, problem = pcall(handler)

    if not ok then
        self:report("a handler for " .. name .. " failed: " .. tostring(problem))
    end
end

--- Answers the size the platform draws a control at, asked once per type and remembered.
---
--- A control has a size of its own the way a string has a width, and neither is something Lua can work
--- out. It is asked for once, since a switch is the size a switch is for as long as the application runs.
function Runtime:controlSize(kind)
    local known = self.controlSizes[kind]

    if known ~= nil then
        return known
    end

    local measured = self.renderer:measureControl(kind)

    if type(measured) ~= "table" or type(measured.width) ~= "number" or type(measured.height) ~= "number" then
        error("the renderer measured a " .. kind .. " as something other than a size", 0)
    end

    self.controlSizes[kind] = measured
    return measured
end

--- Measures a string through the renderer, answering from the cache when the same question was asked before.
---
--- The question is the string, everything it is drawn with, and the room it has. A field left out of the
--- name is the same string at a different spacing answering the previous measurement.
---
--- The room is taken to whole points, since a layout works its bounds out of shares and percentages and
--- arrives at a different fraction on every pass: unrounded, one screen asked five hundred questions a
--- frame where there were twenty strings on it, and a cache the size of one screen answered none of them.
--- It is rounded down, so a string never claims to fit where it does not.
function Runtime:measureText(text, style, bound)
    local room = bound ~= nil and math.floor(bound) or nil

    local key = table.concat({
        text,
        tostring(style.fontSize),
        tostring(style.fontFamily),
        tostring(style.fontWeight),
        tostring(style.fontStyle),
        tostring(style.letterSpacing),
        tostring(style.lineHeight),
        tostring(room),
    }, "\1")

    local cached = self.measurements:get(key)
    if cached ~= nil then
        return cached
    end

    local measured = self.renderer:measureText(text, style, room)

    -- A renderer that answers anything but two real numbers is named here, rather than inside the
    -- arithmetic. A width that is not a number at all is one way to answer wrongly, and one that is not
    -- finite is the other: it passes every type check and then spreads through every frame in the tree.
    if type(measured) ~= "table" or not finite(measured.width) or not finite(measured.height) then
        error("the renderer measured " .. string.format("%q", tostring(text)) .. " as something other than a size", 0)
    end

    self.measurements:set(key, measured)
    return measured
end

--- Drops every cached measurement, which registering a font or changing the scale has to do.
function Runtime:invalidateMeasurements()
    if self.stopped then
        return
    end

    self.measurements:clear()
    self.controlSizes = {}
    self.extents = {}
    self.generation = self.generation + 1
    self:schedule()
end

--- Takes the tree down, which is what a host that is done with a surface has to do.
---
--- Every component is told it is going and marked as no longer mounted, so what one of them asked to
--- happen later stops happening rather than keeping the engine's loop open for the life of the process.
function Runtime:stop()
    if self.provider == nil then
        return
    end

    self.stopped = true

    local ops, pending = diff.unmount(self.provider)

    self.provider = nil
    self.root = nil
    self.dirty = {}
    self.byId = {}
    self.scheduled = false

    self.renderer:apply(ops)
    runCallbacks(pending, function(problem) self:report(problem) end)
end

function Runtime:commit()
    if self.stopped or not self.scheduled then
        return false
    end

    self.scheduled = false
    self.committing = true
    self.asked = nil

    local ok, pending = pcall(self.build, self)

    self.committing = false
    self.arranged = false

    -- A build that failed leaves behind the components it had not reached, whose state has already
    -- changed, so what is owed is armed before the failure is passed on.
    if next(self.dirty) ~= nil then
        self.scheduled = true
    end

    self:arm()

    if not ok then
        error(pending, 0)
    end

    self.settling = true
    runCallbacks(pending, function(problem) self:report(problem) end)
    self.settling = false

    self:checkCascade()
    return true
end

--- Stops a screen that asks for a commit from inside one for ever, and says which component does it.
---
--- A component that changes its own state from `onUpdate` is answered with another commit, which calls
--- `onUpdate` again: the loop never idles, the device runs at full tilt with nothing on screen moving,
--- and no failure is reported anywhere. A run this long is a mistake rather than a screen settling.
function Runtime:checkCascade()
    if self.asked == nil then
        self.cascade = 0
        return
    end

    self.cascade = (self.cascade or 0) + 1

    if self.cascade <= CASCADE then
        return
    end

    self.cascade = 0
    self.scheduled = false
    self.dirty = {}

    self:report("a component asked for a commit from inside one " .. CASCADE
        .. " times over, so it was stopped: " .. self.asked)
end

--- What the runtime wraps every application in, which is what it has to provide from above the tree.
local WRAPPERS = { [environment.provider] = true, [theming.provider] = true }

--- Answers the top of the application's own tree, which is under whatever the runtime wrapped it in.
local function topOf(node)
    local found = node

    while found ~= nil and WRAPPERS[found.type] do
        found = found.child
    end

    return found or node
end

--- Answers the callbacks a commit owes once it has reached the renderer.
function Runtime:build()
    local ops = {}
    local pending = {}

    if self.root == nil then
        local node, created, mounted = diff.mount(self.description)

        self.provider = node
        self.root = topOf(node)
        ops = created
        pending = mounted
    else
        local dirty = {}

        for node in pairs(self.dirty) do
            dirty[#dirty + 1] = node
        end

        for index = 1, #dirty do
            local node = dirty[index]
            self.dirty[node] = nil

            -- A pass that marks the whole tree reaches a component that an ancestor rendered away
            -- earlier in the same pass, and reconciling it would send updates for ids just removed.
            if node.instance.mounted then
                local produced, callbacks = diff.reconcileComponent(node)

                for position = 1, #produced do
                    ops[#ops + 1] = produced[position]
                end

                for position = 1, #callbacks do
                    pending[#pending + 1] = callbacks[position]
                end
            end
        end
    end

    -- A component whose root child changed type answers a different node than the one held here.
    self.root = topOf(self.provider)

    self:reindex()
    self:emitFrames(ops, pending)
    self:reportViews(pending)
    self:resolveStyles(ops)

    if self.restyling then
        self.restyling = false
        self:restyle(ops)
    end

    if self.repainting then
        self.repainting = false
        self:repaintPictures(ops)
    end

    if self.rebinding then
        self.rebinding = false
        self:rebindScrolls(ops)
    end

    if #ops > 0 then
        local problem = protocol.validate(ops)
        if problem ~= nil then
            error("the commit produced an invalid batch: " .. problem, 0)
        end

        self.renderer:apply(ops)
    end

    self:holdSurfaces()

    if self.revealing then
        self.revealing = false
        self:reveal()
    end

    return pending
end

--- Replaces the look, which re-resolves every style and relays out the tree.
---
--- A look carries an appearance on each side of it, so an application with one of its own still follows
--- the device: what changes here is the design rather than which side of it the reader is shown. One
--- resolved theme is a look with the same side twice, which is an application pinned to it.
function Runtime:setTheme(theme)
    if self.stopped then
        return
    end

    self.look = lookOf(theme)
    self:wearTheme()
end

--- Replaces the controls, which draws every component that reads them again.
---
--- A look and a control theme are two things: one says what a control is coloured in and the other what
--- it is built out of, so either may be changed without touching the other.
function Runtime:setControls(chosen)
    if self.stopped then
        return
    end

    local wanted = controlsOf(chosen)

    if self.controls == wanted then
        return
    end

    self.controls = wanted
    self.wearing.controls = wanted
    self.generation = self.generation + 1

    local readers = theming:read_by(self.scheduler)

    for index = 1, #readers do
        self.dirty[readers[index].node] = true
    end

    self:schedule()
end

--- Records whether the platform is showing light or dark, and follows it.
function Runtime:setAppearance(appearance)
    if self.stopped then
        return
    end

    if self.environment.appearance == appearance then
        return
    end

    self.environment.appearance = appearance
    self.surface.appearance = appearance
    self.generation = self.generation + 1

    self:wearTheme()
end

--- Draws everything in the side of the look the device is set to, and paints the platform's own ground.
function Runtime:wearTheme()
    self.theme = self.look:of(self.environment.appearance)
    self.restyling = true

    -- What a chooser reads is the same table throughout, since the provider above the tree holds it: the
    -- name is written into it and whoever read it is drawn again, the way a resize reaches the surface.
    if self.wearing ~= nil then
        self.wearing.name = self.look.name

        local readers = theming:read_by(self.scheduler)

        for index = 1, #readers do
            self.dirty[readers[index].node] = true
        end
    end

    self:invalidateMeasurements()

    -- A page, a window and an activity each draw something of their own around what the tree draws, and
    -- none of it is a node: the ground behind the surface, what a selection is drawn in, and the face a
    -- control the platform owns writes its own captions in.
    self.renderer:showTheme(self.theme:ground())
end

--- Answers whether two sets of insets say the same thing, which is what decides that nothing changed.
local function sameEdges(before, after)
    if before == nil then
        return false
    end

    return before.top == after.top and before.right == after.right
        and before.bottom == after.bottom and before.left == after.left
end

--- Records the insets the platform reports, which every safe area then avoids.
function Runtime:setInsets(insets)
    if self.stopped then
        return
    end

    local edges = {
        top = insets.top or 0,
        right = insets.right or 0,
        bottom = insets.bottom or 0,
        left = insets.left or 0,
    }

    for edge, value in pairs(edges) do
        if not measurable(value) then
            error("a safe area is four lengths in points, at least nothing, and " .. edge
                .. " is " .. tostring(value), 2)
        end
    end

    -- A platform reports these on every layout it does, which during a rotation is every frame, and
    -- what follows lays out the whole tree and renders it again.
    if sameEdges(self.environment.insets, edges) then
        return
    end

    self.surface.insets = edges
    self.environment.insets = edges
    self.generation = self.generation + 1

    -- A component draws the strip the system bars sit over, so it is rendered again rather than only
    -- laid out again: what fills that strip is a node, not a size.
    self:renderReaders()
    self:schedule()
end

--- Records how much of the surface the keyboard covers, which every avoiding node then leaves clear.
function Runtime:setKeyboard(height)
    if self.stopped then
        return
    end

    if not measurable(height) then
        error("the keyboard covers a length in points, at least nothing, got " .. tostring(height), 2)
    end

    if self.environment.keyboard == height then
        return
    end

    local was = self.environment.keyboard

    self.environment.keyboard = height
    self.generation = self.generation + 1

    -- A surface is asked for its offset while the engine has a use for the answer, and lifting a field
    -- clear of the keyboard is one, so the question is put again to all of them when it changes.
    if (was > 0) ~= (height > 0) then
        self.rebinding = true
    end

    if height > 0 then
        self:askReveal()
        return
    end

    self:schedule()
end

--- Reports the size the surface now has, which a rotation and a window resize both are.
function Runtime:resize(width, height)
    if self.stopped then
        return
    end

    if not measurable(width) or not measurable(height) then
        error("a surface is a width and a height in points, at least nothing, got "
            .. tostring(width) .. " by " .. tostring(height), 2)
    end

    if self.size ~= nil and self.size.width == width and self.size.height == height then
        return
    end

    self.size = { width = width, height = height }
    self.extents = {}
    self:describeSurface()
    self:schedule()
end

--- Tells the tree how much room it has, which is what an interface adapts to rather than a device name.
---
--- A tablet, a phone held sideways, a window sharing a screen with another and a folding phone that has
--- just been opened are all the same thing: a width that changed. A component reads the breakpoint and
--- lays itself out for the room it has, so none of them is a case anybody has to write.
function Runtime:describeSurface()
    if self.size == nil then
        return
    end

    local breakpoint = self.theme:breakpoint(self.size.width)

    if self.surface.width == self.size.width
        and self.surface.height == self.size.height
        and self.surface.breakpoint == breakpoint then
        return
    end

    self.surface.width = self.size.width
    self.surface.height = self.size.height
    self.surface.breakpoint = breakpoint
    self.generation = self.generation + 1
    self:schedule()

    -- A component decides what to draw from the room it has, so it is rendered again rather than only
    -- laid out again: what a split view puts on screen is a different tree, not a different size. Only
    -- what actually read the room is rendered, since a rotation hands the engine a new size on every
    -- frame it animates and rendering the whole tree for each of them costs more than a frame is worth.
    self:renderReaders()
end

--- Marks every component that reads the surface it is drawn on, which a change to that surface is for.
function Runtime:renderReaders()
    local readers = environment:read_by(self.scheduler)

    for index = 1, #readers do
        self.dirty[readers[index].node] = true
    end
end

--- Records where the host says the application was asked to be, which is what a router reads.
---
--- A deep link, an app link and a web address all arrive through here, at start and while the
--- application runs, so nothing above a router has to know which of the three it was.
function Runtime:setAddress(where)
    if self.stopped then
        return
    end

    if type(where) ~= "string" then
        error("an address is a string, got a " .. type(where), 2)
    end

    if self.surface.address == where then
        return
    end

    self.surface.address = where
    self.generation = self.generation + 1

    self:renderReaders()
    self:schedule()
end

--- Answers where the application is, which is what a host asks when it has to draw an address bar.
function Runtime:address()
    return self.surface.address
end

--- Goes somewhere, telling the host as well when the host is somewhere an address can be shown.
---
--- A browser keeps the address in its own history, so back and forward work the way a reader expects
--- them to. A phone has nowhere to show one, which is why the host says whether it can.
function Runtime:navigate(where, mode)
    self:setAddress(where)

    if self.renderer.address ~= nil and self.renderer:can("address") then
        self.renderer:address(where, mode or "push")
    end
end

--- Routes an event a renderer reported to the handler the node carries.
function Runtime:dispatch(id, name, payload)
    if self.stopped then
        return false
    end

    local node = self.byId[id]
    if node == nil then
        return false
    end

    if name == "onFocus" then
        self.focused = id
        self:askReveal()
    elseif name == "onBlur" and self.focused == id then
        self.focused = nil
    elseif name == "onScroll" and type(payload) == "table" then
        self.offsets[id] = payload.y or 0
        self:reportScrolled()
    end

    local handler = node.props[name]
    if type(handler) ~= "function" then
        return false
    end

    -- A platform reports a number it worked out itself, and one that is not a number at all — a scroll
    -- offset during a rubber band, a fraction with no room to divide by — reaches the window that decides
    -- which cells exist and asks for an index of nothing.
    if type(payload) == "table" then
        for key, value in pairs(payload) do
            if type(value) == "number" and not finite(value) then
                self:report(name .. " reported " .. tostring(key) .. " as " .. tostring(value)
                    .. ", which is not a number a screen can be laid out against")
                return false
            end
        end
    end

    -- A handler belongs to the application, so what it does is reported rather than trusted: an error
    -- from one would otherwise unwind through the host's own event delivery.
    local ok, problem = pcall(handler, payload)

    if not ok then
        self:report("a handler for " .. name .. " failed: " .. tostring(problem))
    end

    return true
end

--- Tells whoever is listening that something a caller wrote failed, which is never a reason to stop.
---
--- An embedder that named no listener still cannot be handed a throw here: this is reached from the
--- middle of a commit and from a callback the commit owes, and raising would be the very failure this
--- exists to contain. A listener that fails while being told is written by the application too, so it
--- falls back to the log rather than raising out of the containment path itself.
function Runtime:report(problem)
    if self.onProblem ~= nil and pcall(self.onProblem, problem) then
        return
    end

    io.stderr:write("[gui] " .. tostring(problem) .. "\n")
end

--- Fills the ref a component carries with the handle its instance answers.
---
--- A component that owns native behaviour of its own, the way a list owns scrolling, hands out a
--- handle rather than the node underneath it, so a caller reaches the list rather than a scroll view.
local function indexComponent(node)
    local walk = node

    while walk ~= nil and walk.kind == "component" do
        local holder = walk.props.ref

        if ref.isRef(holder) and type(walk.instance.handle) == "function" then
            local handle = walk.instance:handle()

            handle.type = walk.type.name
            handle.call = function(method, arguments)
                local action = handle[method]

                if type(action) ~= "function" then
                    error((walk.type.name or "the component") .. " has no action named " .. method, 0)
                end

                return action(arguments)
            end

            holder.current = handle
        end

        walk = walk.child
    end
end

--- Answers the look in force under a node, which is the one above it unless something below names another.
---
--- A subtree in a look of its own is a provider holding a resolved theme, and everything under it is
--- resolved against that rather than against the application's. The walk is the one the index already
--- makes, so nothing is walked twice and no node has to be asked what it is wearing later.
local function wornUnder(node, wearing)
    local walk = node

    while walk ~= nil and walk.kind == "component" do
        local value = walk.props.value

        if walk.type == theming.provider and type(value) == "table" and value.theme ~= nil then
            wearing = value.theme
        end

        walk = walk.child
    end

    return wearing
end

local function index(node, byId, runtime, wearing)
    indexComponent(node)

    wearing = wornUnder(node, wearing)

    local host = diff.hostOf(node)

    -- A subtree told to wear another look changes what every node under it resolves against without any
    -- of them rendering again, so the change is noticed where it happens and the tree is painted again.
    if host.wearing ~= nil and host.wearing ~= wearing then
        runtime.restyling = true
        runtime.generation = runtime.generation + 1
    end

    host.wearing = wearing
    byId[host.id] = host

    local holder = host.props.ref
    if ref.isRef(holder) then
        holder.current = {
            id = host.id,
            type = host.type,
            call = function(method, arguments)
                return runtime.renderer:invoke(host.id, method, arguments)
            end,
        }
    end

    for position = 1, #host.children do
        index(host.children[position], byId, runtime, wearing)
    end
end

--- Rebuilds the id index a dispatch reads, which a commit invalidates.
function Runtime:reindex()
    self.byId = {}
    if self.root ~= nil then
        index(self.root, self.byId, self, self.theme)
    end

    self:reindexWatchers()
    self:forgetGone()
end

--- Forgets what the engine was holding about a node that has gone, since nothing will ask about it again.
---
--- A node id only ever increases, so a store keyed by one grows for the life of the process: a screen
--- opened and left a thousand times leaves a thousand offsets and a thousand extents behind, each of
--- them about a surface that does not exist. Anything keyed by what an application produces is bounded,
--- and the bound here is the tree itself.
function Runtime:forgetGone()
    for id in pairs(self.offsets) do
        if self.byId[id] == nil then
            self.offsets[id] = nil
        end
    end

    for id in pairs(self.extents) do
        if self.byId[id] == nil then
            self.extents[id] = nil
        end
    end
end

--- Answers which boxes are watching to be told they can be seen, which decides whether a scroll is asked for.
function Runtime:reindexWatchers()
    local watching = 0
    local seen = {}

    for id, node in pairs(self.byId) do
        if type(node.props.onEnterView) == "function" or type(node.props.onExitView) == "function" then
            watching = watching + 1
            seen[id] = self.seen[id] or { inside = false }
        end
    end

    self.watching = watching
    self.seen = seen
end

--- Starts a description on a renderer, answering the runtime that owns it from then on.
function M.start(description, renderer, options)
    options = options or {}

    if not element.isElement(description) then
        error("a description is an element, got " .. type(description), 2)
    end

    -- A renderer is checked by name with the other two things a tree cannot start without, since one
    -- that is not a renderer is only found several calls later, painting the ground behind the surface.
    if type(renderer) ~= "table" or type(renderer.apply) ~= "function" then
        error("a renderer is what applies a batch, got " .. type(renderer), 2)
    end

    local size = options.size or { width = 0, height = 0 }

    -- A surface arrives from a host, and one that answers a width as anything but a number lays every
    -- box out against it: the failure surfaces inside the theme, comparing a number with whatever came.
    if type(size.width) ~= "number" or type(size.height) ~= "number" or size.width < 0 or size.height < 0 then
        error("a surface is a width and a height in points, at least nothing, got "
            .. tostring(size.width) .. " by " .. tostring(size.height), 2)
    end

    local surface = {
        platform = options.platform or "web",
        address = options.address or "/",
        appearance = options.appearance or "light",
        state = options.state or "active",
        scale = options.scale or 1,
        width = size.width,
        height = size.height,
        breakpoint = "compact",
        insets = options.insets or { top = 0, right = 0, bottom = 0, left = 0 },
    }

    -- What a screen deep in the tree reads to know which look and which controls it is in, and how to
    -- ask for another of either. It is built before the runtime so the description can carry it, and
    -- filled in once there is one.
    local wearing = { name = "varn", use = function() end, controls = controls.native, useControls = function() end }

    local runtime = setmetatable({
        description = environment.Provider {
            value = surface,
            theming.Provider { value = wearing, description },
        },
        surface = surface,
        renderer = renderer,
        root = nil,
        dirty = {},
        extents = {},
        measurements = cache.create(MEASURED),
        controlSizes = {},
        controls = controlsOf(options.controls),
        byId = {},
        held = {},
        holding = {},
        offsets = {},
        seen = {},
        watching = 0,
        generation = 1,
        scheduled = true,
        committing = false,
        size = options.size or { width = 0, height = 0 },
        look = lookOf(options.theme),
        environment = {
            insets = options.insets or { top = 0, right = 0, bottom = 0, left = 0 },
            keyboard = 0,
            scale = options.scale or 1,
            appearance = options.appearance or "light",
            state = options.state or "active",
            size = options.size or { width = 0, height = 0 },
            platform = options.platform or "web",
        },
        arrange = options.arrange,
        assets = options.assets,
        pictures = options.pictures,
        wantsImageBytes = options.imageBytes == true,
        onProblem = options.onProblem,
        arranged = false,
        restyling = false,
        repainting = false,
        breakpoint = "compact",
    }, Runtime)

    runtime.measurer = function(text, style, bound)
        return runtime:measureText(text, style, bound)
    end

    runtime.controller = function(kind)
        return runtime:controlSize(kind)
    end

    runtime.scheduler = {
        markDirty = function(node) runtime:markDirty(node) end,
        report = function(problem) runtime:report(problem) end,
        navigate = function(where, mode) runtime:navigate(where, mode) end,
        rendering = function() return runtime.committing end,
        holds = function(work) return runtime:hold(work) end,
    }

    component.useScheduler(runtime.scheduler)

    runtime.wearing = wearing
    wearing.name = runtime.look.name
    wearing.use = function(look) runtime:setTheme(look) end
    wearing.controls = runtime.controls
    wearing.useControls = function(chosen) runtime:setControls(chosen) end

    runtime.theme = runtime.look:of(runtime.environment.appearance)
    runtime.renderer:showTheme(runtime.theme:ground())

    runtime:describeSurface()

    runtime:commit()
    runtime:reindex()
    return runtime
end

return M
