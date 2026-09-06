local diff = require("gui.diff")
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

local function runCallbacks(pending)
    for index = 1, #pending do
        pending[index]()
    end
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
    self:schedule()
end

--- Marks a commit as needed and asks the host to arrange one, which happens once however often this is called.
function Runtime:schedule()
    if self.scheduled or self.committing then
        return
    end

    self.scheduled = true

    if self.arrange ~= nil and not self.arranged then
        self.arranged = true
        self.arrange(self)
    end
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

    local frames = flex.compute(tree, {
        width = self.size.width,
        height = self.size.height,
        measureText = self.measurer,
    })

    for node, frame in pairs(frames) do
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

--- The props that name a file in the application's bundle, by the type that reads them as one.
---
--- A prop name means what its type says it means: a placeholder is a picture on an image and the words
--- shown in an empty field on a field, so which props name a file is decided per type and never by name
--- alone.
local ASSETS = {
    image = { source = true, placeholder = true, fallback = true },
    video = { source = true, poster = true },
}

--- Answers whether a source names somewhere else entirely, which the platform fetches for itself.
local function remote(source)
    return source:find("^%a[%w+.-]*://") ~= nil or source:find("^/") ~= nil
end

--- Answers the path an asset name expands to, which is what a renderer can actually open.
---
--- A screen names the file it wants and nothing else, so the density variant, the cache the archive was
--- expanded into and the shape of that path are the runtime's business rather than every screen's.
function Runtime:assetPath(source)
    if self.assets == nil or remote(source) then
        return source
    end

    local ok, resolved = pcall(self.assets.image, self.assets, source, self.environment.scale)

    if not ok then
        error("the bundle carries no image named " .. source, 0)
    end

    return resolved
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
            local touched = styled

            for name in pairs(NESTED) do
                touched = touched or type(props[name]) == "table"
            end

            local assets = ASSETS[self:typeOf(op)] or {}

            for name in pairs(assets) do
                touched = touched or type(props[name]) == "string"
            end

            if touched then
                local resolved = {}

                for key, value in pairs(props) do
                    resolved[key] = value
                end

                if styled then
                    resolved.style = self:styleOf(props.style)
                end

                for name in pairs(NESTED) do
                    if type(props[name]) == "table" then
                        resolved[name] = self:resolveEntries(props[name])
                    end
                end

                for name in pairs(assets) do
                    if type(props[name]) == "string" then
                        resolved[name] = self:assetPath(props[name])
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

--- Answers the size the platform draws a control at, asked once per type and remembered.
---
--- A control has a size of its own the way a string has a width, and neither is something Lua can work
--- out. It is asked for once, since a switch is the size a switch is for as long as the application runs.
function Runtime:controlSize(kind)
    local known = self.controls[kind]

    if known ~= nil then
        return known
    end

    local measured = self.renderer:measureControl(kind)

    if type(measured) ~= "table" or type(measured.width) ~= "number" or type(measured.height) ~= "number" then
        error("the renderer measured a " .. kind .. " as something other than a size", 0)
    end

    self.controls[kind] = measured
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

    local cached = self.measurements[key]
    if cached ~= nil then
        return cached
    end

    local measured = self.renderer:measureText(text, style, bound)

    -- A renderer that answers anything but two numbers is named here, rather than inside the arithmetic.
    if type(measured) ~= "table" or type(measured.width) ~= "number" or type(measured.height) ~= "number" then
        error("the renderer measured " .. string.format("%q", tostring(text)) .. " as something other than a size", 0)
    end

    self.measurements[key] = measured
    return measured
end

--- Drops every cached measurement, which registering a font or changing the scale has to do.
function Runtime:invalidateMeasurements()
    self.measurements = {}
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
function Runtime:commit()
    if not self.scheduled then
        return false
    end

    self.scheduled = false
    self.committing = true

    local ok, pending = pcall(self.build, self)

    self.committing = false
    self.arranged = false

    if not ok then
        error(pending, 0)
    end

    self:reindex()
    runCallbacks(pending)
    return true
end

--- Answers the callbacks a commit owes once it has reached the renderer.
function Runtime:build()
    local ops = {}
    local pending = {}

    if self.root == nil then
        local node, created, mounted = diff.mount(self.description)
        self.root = node
        ops = created
        pending = mounted
    else
        local dirty = self.dirty
        self.dirty = {}

        for node in pairs(dirty) do
            local produced, callbacks = diff.reconcileComponent(node)
            for index = 1, #produced do
                ops[#ops + 1] = produced[index]
            end

            for index = 1, #callbacks do
                pending[#pending + 1] = callbacks[index]
            end
        end
    end

    self:emitFrames(ops, pending)
    self:resolveStyles(ops)

    if self.restyling then
        self.restyling = false
        self:restyle(ops)
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
    if self.environment.appearance == appearance then
        return
    end

    self.environment.appearance = appearance

    if self.chosenTheme ~= nil then
        return
    end

    self.theme = appearance == "dark" and themes.dark() or themes.create()
    self.restyling = true
    self:invalidateMeasurements()
end

--- Records the insets the platform reports, which every safe area then avoids.
function Runtime:setInsets(insets)
    self.environment.insets = {
        top = insets.top or 0,
        right = insets.right or 0,
        bottom = insets.bottom or 0,
        left = insets.left or 0,
    }

    self.generation = self.generation + 1
    self:schedule()
end

--- Records how much of the surface the keyboard covers, which every avoiding node then leaves clear.
function Runtime:setKeyboard(height)
    if self.environment.keyboard == height then
        return
    end

    self.environment.keyboard = height
    self.generation = self.generation + 1
    self:schedule()
end

--- Reports the size the surface now has, which a rotation and a window resize both are.
function Runtime:resize(width, height)
    if self.size ~= nil and self.size.width == width and self.size.height == height then
        return
    end

    self.size = { width = width, height = height }
    self.environment.size = self.size
    self.extents = {}
    self:schedule()
end

--- Routes an event a renderer reported to the handler the node carries.
function Runtime:dispatch(id, name, payload)
    local node = self.byId[id]
    if node == nil then
        return false
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
function Runtime:report(problem)
    if self.onProblem ~= nil then
        self.onProblem(problem)
        return
    end

    error(problem, 0)
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

    local runtime = setmetatable({
        description = description,
        renderer = renderer,
        root = nil,
        dirty = {},
        extents = {},
        measurements = {},
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
        },
        arrange = options.arrange,
        assets = options.assets,
        onProblem = options.onProblem,
        arranged = false,
        restyling = false,
        breakpoint = "compact",
    }, Runtime)

    runtime.measurer = function(text, style, bound)
        return runtime:measureText(text, style, bound)
    end

    runtime.controller = function(kind)
        return runtime:controlSize(kind)
    end

    component.useScheduler({
        markDirty = function(node) runtime:markDirty(node) end,
    })

    runtime:commit()
    runtime:reindex()
    return runtime
end

return M
