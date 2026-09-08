local animation = require("gui.style.animation")
local cache = require("gui.tools.cache")
local diff = require("gui.diff")
local environment = require("gui.environment")
local component = require("gui.component")
local flex = require("gui.layout.flex")
local natural = require("gui.layout.natural")
local protocol = require("gui.bridge.protocol")
local resolve = require("gui.style.resolve")
local ref = require("gui.ref")
local themes = require("gui.style.theme")

local M = {}

local Runtime = {}
Runtime.__index = Runtime

--- How many measured strings are held at once, which is what a screen with a clock on it keeps adding to.
local MEASURED = 512

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

--- How much room is left between a revealed field and the top of the keyboard.
local MARGIN = 12

--- How many commits in a row may be asked for from inside one before it is a loop rather than settling.
local CASCADE = 50

--- Answers whether a frame is made of numbers a renderer can be given.
local function placeable(frame)
    return finite(frame.x) and finite(frame.y) and finite(frame.width) and finite(frame.height)
end


local EDGES = {
    top = "paddingTop",
    right = "paddingRight",
    bottom = "paddingBottom",
    left = "paddingLeft",
}

--- The fields that say how a box arranges its children, rather than how large the box itself is.
local ARRANGING = {
    "direction", "justify", "align", "wrap", "gap", "rowGap", "columnGap",
    "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
    "paddingHorizontal", "paddingVertical",
}

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

    for index = 1, #ARRANGING do
        local name = ARRANGING[index]
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
            local edge = EDGES[edges[index]]
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
function Runtime:layoutNodeOf(node, hosts, scrolling)
    local host = diff.hostOf(node)
    local props = host.props
    local built = host.layout

    if built == nil then
        built = { id = host.id, children = {}, revision = 0 }
        host.layout = built
    end

    local declared = self:styleOf(props.style)

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
        local style = function(value) return self:styleOf(value) end

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
    local count = #host.children

    for index = 1, count do
        local child = self:layoutNodeOf(host.children[index], hosts, scrolling)

        if children[index] ~= child then
            children[index] = child
            built.revision = built.revision + 1
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
    local tree = self:layoutNodeOf(self.root, hosts, scrolling)

    local moved = flex.compute(tree, {
        width = self.size.width,
        height = self.size.height,
        measureText = self.measurer,
    })

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

        if self.extents[node.id] ~= extent then
            self.extents[node.id] = extent
            ops[#ops + 1] = { op = "update", id = node.id, props = { contentExtent = extent } }
        end
    end
end

--- Answers the style a renderer receives, which is concrete values rather than the tokens a caller wrote.
---
--- Resolution happens here rather than in the diff, so three renderers cannot disagree about what a
--- spacing step or a theme colour means and none of them carries a theme of its own.
function Runtime:styleOf(style)
    return resolve.resolve(style, self.theme, self.breakpoint)
end

--- The props that carry styles of their own inside them, which are resolved along with the node's.
local NESTED = { spans = true }

--- The props that carry a colour inside each of their entries, which is resolved the same way.
local PAINTED = { commands = true }

--- The props that name a file in the application's bundle, by the type that reads them as one.
---
--- A prop name means what its type says it means: a placeholder is a picture on an image and the words
--- shown in an empty field on a field, so which props name a file is decided per type and never by name
--- alone.
local ASSETS = {
    image = { source = true, placeholder = true },
    video = { source = true, poster = true },
}

--- The props that carry a colour rather than a style, which are resolved the way a style's colours are.
---
--- A control tinted through a prop is tinted with a theme name like everything else, and a renderer
--- reads a colour rather than parsing one, so these arrive as the same hex a style carries.
local TINTS = {
    color = true, textColor = true, tint = true,
    onColor = true, offColor = true, thumbColor = true, trackColor = true,
}

--- The props that carry a run of colours rather than one, which are resolved the same way.
local PALETTES = { colors = true }

--- Answers whether a source names somewhere else entirely, which the platform fetches for itself.
local function remote(source)
    return source:find("^%a[%w+.-]*://") ~= nil or source:find("^/") ~= nil
end

--- Answers the path an asset name expands to, which is what a renderer can actually open.
---
--- A screen names the file it wants and nothing else, so the density variant, the cache the archive was
--- expanded into and the shape of that path are the runtime's business rather than every screen's. A
--- picture from somewhere else is fetched once and answered as a local file, since a phone hands an
--- `https://` string to its image view and quietly draws nothing.
function Runtime:assetPath(source)
    if remote(source) then
        return self:fetched(source)
    end

    if self.assets == nil then
        return source
    end

    local ok, resolved = pcall(self.assets.image, self.assets, source, self.environment.scale)

    if not ok then
        error("the bundle carries no image named " .. source, 0)
    end

    return self:openable(resolved)
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

--- Sends every picture again, which is what a fetch landing means for whatever was waiting on it.
---
--- A source that had not arrived was sent as its placeholder, so the tree has to be told again once it
--- has. Nothing else about the tree changed, so this is a restyle rather than a render.
function Runtime:invalidatePictures(url, ok)
    if self.stopped then
        return
    end

    -- A picture that never arrived changes nothing on screen, since what is drawn is already the
    -- placeholder, and repainting for it would ask for it again and repaint again for that answer too.
    if ok then
        self.repainting = true
        self:schedule()
    end

    self:reportPicture(url, ok)
end

--- Tells whatever was waiting on a picture that it arrived, or that it never will.
---
--- The engine is what fetches it, so the engine is what knows. A renderer that reported this itself
--- would report it three different ways, and two of them never reported it at all.
function Runtime:reportPicture(url, ok)
    if url == nil then
        return
    end

    local name = ok and "onLoad" or "onError"

    for _, node in pairs(self.byId) do
        if node.type == "image" and node.props.source == url and type(node.props[name]) == "function" then
            self:runHandler(name, node.props[name])
        end
    end
end

--- Runs a handler the way a dispatched one is run, so what it does is reported rather than trusted.
function Runtime:runHandler(name, handler)
    local ok, problem = pcall(handler)

    if not ok then
        self:report("a handler for " .. name .. " failed: " .. tostring(problem))
    end
end

--- Answers where a picture from somewhere else landed, or nothing at all while it is still on its way.
function Runtime:fetched(source)
    if self.pictures == nil or source:find("^data:") ~= nil or source:find("^/") ~= nil then
        return source
    end

    local landed = self.pictures:fetch(source)

    if landed == nil then
        return nil
    end

    return self:openable(landed)
end

--- Answers a picture in the shape the renderer said it wants, which is a path unless it asked for bytes.
---
--- A browser cannot open a file inside the engine's own filesystem, so it declares that it wants the
--- bytes the way it already declares it wants a font's, and is handed a data URI instead of a name.
function Runtime:openable(path)
    if not self.wantsImageBytes or self.pictures == nil then
        return path
    end

    return self.pictures:bytes(path)
end

--- Answers a list of entries with the style each one carries resolved, leaving the entries themselves alone.
function Runtime:resolveEntries(entries)
    local resolved = {}

    for index = 1, #entries do
        local entry = entries[index]
        local copy = {}

        for key, value in pairs(entry) do
            copy[key] = value
        end

        copy.style = self:styleOf(entry.style)
        resolved[index] = copy
    end

    return resolved
end

--- Answers drawing commands with the colour each one carries resolved, leaving the drawing itself alone.
function Runtime:resolvePainted(entries)
    local resolved = {}

    for index = 1, #entries do
        local entry = entries[index]
        local copy = {}

        for key, value in pairs(entry) do
            copy[key] = value
        end

        if type(entry.color) == "string" then
            copy.color = resolve.paint(entry.color, self.theme)
        end

        resolved[index] = copy
    end

    return resolved
end

--- Answers the type of the node an operation names, which a create carries and an update does not.
function Runtime:typeOf(op)
    if op.type ~= nil then
        return op.type
    end

    local node = self.byId[op.id]
    return node ~= nil and node.type or nil
end

--- Replaces the tokens a batch carries with the values they resolve to.
---
--- A node is always created with a style, even an empty one, since a renderer that is told nothing
--- leaves its widget at the platform's own defaults and draws at a size the engine never measured.
function Runtime:resolveStyles(ops)
    for index = 1, #ops do
        local op = ops[index]
        local props = op.props

        if props ~= nil then
            local styled = props.style ~= nil or op.op == "create"
            local moves = props.transition ~= nil or props.enter ~= nil
            local touched = styled or moves

            for name in pairs(NESTED) do
                touched = touched or type(props[name]) == "table"
            end

            for name in pairs(PAINTED) do
                touched = touched or type(props[name]) == "table"
            end

            local assets = ASSETS[self:typeOf(op)] or {}

            for name in pairs(assets) do
                touched = touched or type(props[name]) == "string"
            end

            for name in pairs(TINTS) do
                touched = touched or type(props[name]) == "string"
            end

            for name in pairs(PALETTES) do
                touched = touched or type(props[name]) == "table"
            end

            if touched then
                local resolved = {}

                for key, value in pairs(props) do
                    resolved[key] = value
                end

                if styled then
                    resolved.style = self:styleOf(props.style)
                end

                if props.transition ~= nil then
                    resolved.transition = animation.transition(props.transition)
                end

                if props.enter ~= nil then
                    resolved.enter = self:styleOf(props.enter)
                end

                for name in pairs(NESTED) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:resolveEntries(props[name])
                    end
                end

                for name in pairs(PAINTED) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:resolvePainted(props[name])
                    end
                end

                for name in pairs(assets) do
                    if type(props[name]) == "string" then
                        resolved[name] = self:assetPath(props[name])
                    end
                end

                if resolved.source == nil and props.source ~= nil then
                    resolved.source = resolved.placeholder
                end

                for name in pairs(PALETTES) do
                    if type(props[name]) == "table" then
                        local painted = {}

                        for index = 1, #props[name] do
                            painted[index] = resolve.paint(props[name][index], self.theme)
                        end

                        resolved[name] = painted
                    end
                end

                for name in pairs(TINTS) do
                    if type(props[name]) == "string" and assets[name] == nil then
                        resolved[name] = resolve.paint(props[name], self.theme)
                    end
                end

                op.props = resolved
            end
        end
    end
end

--- Sends every node its style again, which a new theme means for the whole tree at once.
function Runtime:restyle(ops)
    for id, node in pairs(self.byId) do
        if node.props.style ~= nil then
            ops[#ops + 1] = { op = "update", id = id, props = { style = self:styleOf(node.props.style) } }
        end
    end
end

--- Sends every picture again, so one that has just been fetched reaches the screen it was asked for by.
---
--- A source that had not landed was sent as its placeholder, and a restyle sends styles rather than
--- props, so the picture only ever appeared the next time the application was opened: the run that
--- fetched it never showed it.
function Runtime:repaintPictures(ops)
    for id, node in pairs(self.byId) do
        local assets = ASSETS[node.type]

        if assets ~= nil then
            local resolved = {}

            for name in pairs(assets) do
                if type(node.props[name]) == "string" then
                    resolved[name] = self:assetPath(node.props[name])
                end
            end

            if resolved.source == nil and node.props.source ~= nil then
                resolved.source = resolved.placeholder
            end

            if next(resolved) ~= nil then
                ops[#ops + 1] = { op = "update", id = id, props = resolved }
            end
        end
    end
end

--- Answers the size the platform draws a control at, asked once per type and remembered.
---
--- A control has a size of its own the way a string has a width, and neither is something Lua can work
--- out. It is asked for once, since a switch is the size a switch is for as long as the application runs.
function Runtime:controlSize(kind, variant)
    local key = variant ~= nil and (kind .. "/" .. variant) or kind
    local known = self.controls[key]

    if known ~= nil then
        return known
    end

    local measured = self.renderer:measureControl(kind, variant)

    if type(measured) ~= "table" or type(measured.width) ~= "number" or type(measured.height) ~= "number" then
        error("the renderer measured a " .. key .. " as something other than a size", 0)
    end

    self.controls[key] = measured
    return measured
end

--- Measures a string through the renderer, answering from the cache when the same question was asked before.
function Runtime:measureText(text, style, bound)
    local key = table.concat({
        text,
        tostring(style.fontSize),
        tostring(style.fontFamily),
        tostring(style.fontWeight),
        tostring(bound),
    }, "\1")

    local cached = self.measurements:get(key)
    if cached ~= nil then
        return cached
    end

    local measured = self.renderer:measureText(text, style, bound)

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
    self.controls = {}
    self.extents = {}
    self.generation = self.generation + 1
    self:schedule()
end

--- Runs one commit, which is the only place the tree, the layout and the renderer meet.
---
--- What a commit does is guarded rather than trusted: a render that throws, a batch the protocol
--- refuses or an asset that is not there would otherwise leave the runtime marked as committing for
--- good, and a runtime in that state never schedules another commit. The screen would stop moving while
--- the application went on running.
--- Takes the tree down, which is what a host that is done with a surface has to do.
---
--- Nothing was ever unmounted. A runtime that went out of use left every component still marked as
--- mounted, so what each of them had asked to happen later went on happening: a screen that repeats
--- something kept the engine's loop open for the life of the process.
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

--- Answers the callbacks a commit owes once it has reached the renderer.
function Runtime:build()
    local ops = {}
    local pending = {}

    if self.root == nil then
        local node, created, mounted = diff.mount(self.description)

        self.provider = node
        self.root = node.child or node
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
    self.root = self.provider.child or self.provider

    self:reindex()
    self:emitFrames(ops, pending)
    self:resolveStyles(ops)

    if self.restyling then
        self.restyling = false
        self:restyle(ops)
    end

    if self.repainting then
        self.repainting = false
        self:repaintPictures(ops)
    end

    if #ops > 0 then
        local problem = protocol.validate(ops)
        if problem ~= nil then
            error("the commit produced an invalid batch: " .. problem, 0)
        end

        self.renderer:apply(ops)
    end

    return pending
end

--- Replaces the theme, which re-resolves every style and relays out the tree.
function Runtime:setTheme(theme)
    if self.stopped then
        return
    end

    self.theme = theme
    self.chosenTheme = theme
    self.restyling = true
    self:invalidateMeasurements()
end

--- Records whether the platform is showing light or dark, and follows it.
---
--- An application that chose a theme of its own keeps it. One that did not is themed the way the
--- reader has their device set, and changes with it.
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

    if self.chosenTheme ~= nil then
        return
    end

    self.theme = appearance == "dark" and themes.dark() or themes.create()
    self.restyling = true
    self:invalidateMeasurements()
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

    if self.environment.keyboard == height then
        return
    end

    self.environment.keyboard = height
    self.generation = self.generation + 1
    self:schedule()
    self:reveal()
end

--- Scrolls whatever holds the focused node so the keyboard is not covering it.
---
--- A field halfway down a scroll view is behind the keyboard the moment it comes up, and padding the
--- bottom of the page does nothing about it. The engine already knows every frame and which node has
--- focus, so it works out how far short the field falls and asks the surface holding it to move.
function Runtime:reveal()
    local id = self.focused

    if id == nil or self.environment.keyboard <= 0 or self.size == nil or self.frames == nil then
        return
    end

    local frame = self.frames[id]
    local surface = self:scrollerOf(self.byId[id])

    if frame == nil or surface == nil then
        return
    end

    -- A cell's frame is in the content the surface scrolls over, so where it lands on screen is the
    -- surface's own position plus how far down the content it sits, less how far the surface is scrolled.
    local clear = self.size.height - self.environment.keyboard
    local target = surface.top + surface.content + frame.height + MARGIN - clear

    if target <= 0 then
        return
    end

    self.renderer:invoke(surface.id, "scrollTo", { x = 0, y = target, animated = true })
end

--- Answers the scrolling host a node sits inside, how far down its content it sits, and where it is.
function Runtime:scrollerOf(node)
    local content = 0
    local walk = node

    while walk ~= nil do
        local parent = walk.parentNode

        while parent ~= nil and parent.kind ~= "host" do
            parent = parent.parentNode
        end

        if parent == nil then
            return nil
        end

        local frame = self.frames[walk.id]

        if frame ~= nil then
            content = content + frame.y
        end

        if natural.scrolling[parent.type] then
            local top = 0
            local above = parent

            while above ~= nil do
                local sits = self.frames[above.id]

                if sits ~= nil then
                    top = top + sits.y
                end

                above = above.parentNode

                while above ~= nil and above.kind ~= "host" do
                    above = above.parentNode
                end
            end

            return { id = parent.id, content = content, top = top }
        end

        walk = parent
    end

    return nil
end

--- Reports the size the surface now has, which a rotation and a window resize both are.
function Runtime:resize(width, height)
    if self.stopped then
        return
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
        self:reveal()
    elseif name == "onBlur" and self.focused == id then
        self.focused = nil
    end

    local handler = node.props[name]
    if type(handler) ~= "function" then
        return false
    end

    -- A handler belongs to the application, so what it does is reported rather than trusted: an error
    -- from one would otherwise unwind through the host's own event delivery.
    local ok, problem = pcall(handler, payload)

    if not ok then
        self:report("a handler for " .. name .. " failed: " .. tostring(problem))
    end

    return true
end

--- Tells the application about something that went wrong where nothing could be returned to.
--- Tells whoever is listening that something a caller wrote failed, which is never a reason to stop.
---
--- An embedder that named no listener still cannot be handed a throw here: this is reached from the
--- middle of a commit and from a callback the commit owes, and raising would be the very failure this
--- exists to contain.
function Runtime:report(problem)
    if self.onProblem ~= nil then
        self.onProblem(problem)
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

local function index(node, byId, runtime)
    indexComponent(node)

    local host = diff.hostOf(node)
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
        index(host.children[position], byId, runtime)
    end
end

--- Rebuilds the id index a dispatch reads, which a commit invalidates.
function Runtime:reindex()
    self.byId = {}
    if self.root ~= nil then
        index(self.root, self.byId, self)
    end
end

--- Starts a description on a renderer, answering the runtime that owns it from then on.
function M.start(description, renderer, options)
    options = options or {}

    local size = options.size or { width = 0, height = 0 }

    local surface = {
        platform = options.platform or "web",
        appearance = options.appearance or "light",
        scale = options.scale or 1,
        width = size.width,
        height = size.height,
        breakpoint = "compact",
        insets = options.insets or { top = 0, right = 0, bottom = 0, left = 0 },
    }

    local runtime = setmetatable({
        description = environment.Provider { value = surface, description },
        surface = surface,
        renderer = renderer,
        root = nil,
        dirty = {},
        extents = {},
        measurements = cache.create(MEASURED),
        controls = {},
        byId = {},
        generation = 1,
        scheduled = true,
        committing = false,
        size = options.size or { width = 0, height = 0 },
        theme = options.theme or (options.appearance == "dark" and themes.dark() or themes.create()),
        chosenTheme = options.theme,
        environment = {
            insets = options.insets or { top = 0, right = 0, bottom = 0, left = 0 },
            keyboard = 0,
            scale = options.scale or 1,
            appearance = options.appearance or "light",
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

    runtime.controller = function(kind, variant)
        return runtime:controlSize(kind, variant)
    end

    runtime.scheduler = {
        markDirty = function(node) runtime:markDirty(node) end,
        report = function(problem) runtime:report(problem) end,
    }

    component.useScheduler(runtime.scheduler)

    runtime:describeSurface()

    runtime:commit()
    runtime:reindex()
    return runtime
end

return M
